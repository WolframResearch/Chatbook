(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PersonaInstaller`" ];

`$PersonaInstallationDirectory;
`GetInstalledResourcePersonaData;
`GetInstalledResourcePersonas;
`PersonaInstallFromResourceSystem;
`PersonaInstallFromURL;
`PersonaInstall;
`createPersonaManagerDialog;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Personas`" ];
Needs[ "Wolfram`Chatbook`UI`"       ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

$personaBrowseURL   = "https://resources.wolframcloud.com/PromptRepository/category/personas";
$channelPermissions = "Public";
$keepChannelOpen    = True;
$debug              = False;

$unsavedResourceProperties = {
    "AuthorNotes",
    "DefinitionNotebook",
    "Documentation",
    "ExampleNotebook",
    "Notes",
    "SampleChat",
    "Usage"
};

(* TODO: need to add a DeleteResource hook for PromptResources that removes corresponding items here *)
$PersonaInstallationDirectory := GeneralUtilities`EnsureDirectory @ {
    ExpandFileName @ LocalObject @ $LocalBase,
    "Chatbook",
    "Personas"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaInstall*)
PersonaInstall // beginDefinition;
PersonaInstall[ ro_ResourceObject ] := catchMine @ personaInstall @ ro;
PersonaInstall[ id_ ] := With[ { ro = ResourceObject @ id }, PersonaInstall @ ro /; MatchQ[ ro, _ResourceObject ] ];
PersonaInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaInstall*)
personaInstall // beginDefinition;

personaInstall[ resource_ResourceObject ] := Enclose[
    Module[ { info, target, config, installed },
        ConfirmAssert[ resource[ "ResourceType" ] === "Prompt", "ResourceType" ];
        info      = ConfirmBy[ resource[ All ], AssociationQ, "ResourceInformation" ];
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

        GetPersonaData[]; (* refresh cache since dialog depends on that value *)
        If[!MatchQ[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}], {___String}],
            CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}] =
                DeleteCases[Keys[$CachedPersonaData], Alternatives["Birdnardo", "RawModel", "Wolfie"]]];
        AppendTo[
            CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}],
            StringReplace[resource["Name"], StartOfString ~~ "Prompt: " -> ""]];

        installed
    ],
    throwInternalFailure[ personaInstall @ resource, ##1 ] &
];

personaInstall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GetInstalledResourcePersonaData*)
GetInstalledResourcePersonaData // beginDefinition;

GetInstalledResourcePersonaData[ ] := catchMine @ Enclose[
    Module[ { data },
        data = ConfirmMatch[ GetInstalledResourcePersonas[ ], { ___Association }, "GetInstalledResourcePersonas" ];
        KeySort @ Association @ Cases[
            data,
            KeyValuePattern @ {
				"Name" -> name_String,
				"Configuration" -> config_Association,
				"ResourceInformation" -> resourceAssoc_Association
			} :> (
				(* Include the resource description in the returned persona data. *)
				name -> Merge[
					{
						config,
						KeyTake[resourceAssoc, {"Description", "UUID", "Version", "LatestUpdate", "ReleaseDate", "DocumentationLink"}],
                        <|"Origin" -> "PromptRepository", "InstallationDate" -> FileDate[FileNameJoin[{$PersonaInstallationDirectory, name <> ".mx"}], "Creation"]|>
					},
					First
				]
			)
        ]
    ],
    throwInternalFailure[ GetInstalledResourcePersonaData[ ], ## ] &
];

GetInstalledResourcePersonaData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaInstallFromFile*)
PersonaInstallFromFile // beginDefinition;

PersonaInstallFromFile[ ] := catchMine @ Enclose[
    Module[ { filepath },

        filepath = ConfirmMatch[
            SystemDialogInput["FileOpen"],
            _String|$Canceled,
            "InputString"
        ];

        If[ filepath === $Canceled,
            $Canceled,
            ConfirmBy[ PersonaInstallFromFile @ filepath, AssociationQ, "Install" ]
        ]
    ],
    throwInternalFailure[ PersonaInstallFromFile[ ], ## ] &
];

PersonaInstallFromFile[ filepath_String ] := Enclose[
    (*FIXME: TODO*)
    Null
    (* Module[ { ro, file },
        ro = ConfirmMatch[ resourceFromFile @ filepath, _ResourceObject, "ResourceObject" ];
        ConfirmAssert[ ro[ "ResourceType" ] === "Prompt", "ResourceType" ];
        file = ConfirmBy[ PersonaInstall @ ro, FileExistsQ, "PersonaInstall" ];
        ConfirmBy[ getPersonaFile @ file, AssociationQ, "GetPersonaFile" ]
    ] *),
    throwInternalFailure[ PersonaInstallFromFile @ filepath, ## ] &
];

PersonaInstallFromURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaInstallFromURL*)
PersonaInstallFromURL // beginDefinition;

PersonaInstallFromURL[ ] := catchMine @ Enclose[
    Module[ { url },

        url = ConfirmMatch[
            DefinitionNotebookClient`FancyInputString[ "Prompt", "Enter a URL" ], (* FIXME: needs custom dialog *)
            _String|$Canceled,
            "InputString"
        ];

        If[ url === $Canceled,
            $Canceled,
            ConfirmBy[ PersonaInstallFromURL @ url, AssociationQ, "Install" ]
        ]
    ],
    throwInternalFailure[ PersonaInstallFromURL[ ], ## ] &
];

PersonaInstallFromURL[ url_String ] := Enclose[
    Module[ { ro, file },
        ro = ConfirmMatch[ resourceFromURL @ url, _ResourceObject, "ResourceObject" ];
        ConfirmAssert[ ro[ "ResourceType" ] === "Prompt", "ResourceType" ];
        file = ConfirmBy[ PersonaInstall @ ro, FileExistsQ, "PersonaInstall" ];
        ConfirmBy[ getPersonaFile @ file, AssociationQ, "GetPersonaFile" ]
    ],
    throwInternalFailure[ PersonaInstallFromURL @ url, ## ] &
];

PersonaInstallFromURL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*resourceFromURL*)
resourceFromURL // beginDefinition;

resourceFromURL[ url_String ] := Block[ { PrintTemporary },
    Quiet[ resourceFromURL0 @ url, { CloudObject::cloudnf, Lookup::invrl, ResourceObject::notfname } ]
];

resourceFromURL // endDefinition;

resourceFromURL0 // beginDefinition;
resourceFromURL0[ url_String ] := With[ { ro = ResourceObject @ url }, ro /; promptResourceQ @ ro ];
resourceFromURL0[ url_String ] := scrapeResourceFromShingle @ url;
resourceFromURL0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrapeResourceFromShingle*)
scrapeResourceFromShingle // beginDefinition;
(* TODO: we should have something in RSC to do this cleaner/better *)
scrapeResourceFromShingle[ url_String ] := Enclose[
    Module[ { returnInvalid, resp, bytes, xml },

        returnInvalid = Throw[
            DefinitionNotebookClient`FancyMessageDialog[ (* FIXME: needs custom dialog *)
                "Prompt",
                "The specified URL does not represent a valid prompt resource."
            ],
            $catchTopTag
        ] &;

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
                    With[ { ro = Quiet @ ResourceObject @ uuid }, ro /; promptResourceQ @ ro ]
                ,
                FirstCase[
                    xml
                    ,
                    XMLElement[ "div", { ___, "data-clipboard-text" -> c2c_String, ___ }, _ ] :>
                        With[ { ro = Quiet @ ToExpression[ c2c, InputForm ] }, ro /; promptResourceQ @ ro ]
                    ,
                    returnInvalid[ ]
                    ,
                    Infinity
                ],
                Infinity
            ],
            promptResourceQ,
            "ResourceObject"
        ]
    ],
    throwInternalFailure[ scrapeResourceFromShingle @ url, ## ] &
];

scrapeResourceFromShingle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*promptResourceQ*)
promptResourceQ[ ro_ResourceObject ] := ro[ "ResourceType" ] === "Prompt";
promptResourceQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*PersonaInstallFromResourceSystem*)
PersonaInstallFromResourceSystem // beginDefinition;

PersonaInstallFromResourceSystem[ ] := catchMine @ Enclose[
    Module[ { data },
        data = ConfirmMatch[
            withExternalChannelFunctions @ browseWithChannelCallback[ ],
            KeyValuePattern @ { "Listener" -> _ChannelListener, "Channel" -> _ChannelObject },
            "BrowseWithCallback"
        ];

        Append[ data, "Dialog" -> EvaluationNotebook[ ] ]
    ],
    (
        throwInternalFailure[ PersonaInstallFromResourceSystem[ ], ## ]
    ) &
];

PersonaInstallFromResourceSystem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createPersonaManagerDialog*)
createPersonaManagerDialog // beginDefinition;

createPersonaManagerDialog[ ] :=
    CreateDialog[
        ExpressionCell[
            DynamicModule[{favorites, data = None, delimColor},
                favorites =
                    Replace[
                        CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PersonaFavorites"}],
                        Except[{___String}] :> $corePersonaNames];

                Framed[
                    Grid[
                        {
                            {
                                Pane[
                                    Style["Add & Manage Personas", "DialogHeader"],
                                    FrameMargins -> Dynamic[CurrentValue[{StyleDefinitions, "DialogHeader", CellMargins}]],
                                    ImageSize -> {501, Automatic}]},
                            {
                                Pane[
                                    Dynamic[
                                        StringTemplate["`n1` personas being shown in the prompt menu. `n2` total personas available."][
                                            <|
                                                "n1" -> If[ListQ[#], Length[#], "\[LongDash]"]&[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}]],
                                                "n2" -> If[Length[#] > 0, Length[#], "\[LongDash]"]&[$CachedPersonaData]|>],
                                        TrackedSymbols :> {$CachedPersonaData}],
                                    BaseStyle -> "DialogBody",
                                    FrameMargins -> Dynamic[Replace[CurrentValue[{StyleDefinitions, "DialogBody", CellMargins}], {{l_, r_}, {b_, t_}} :> {{l, r}, {0, t}}]]]},
                            {
                                Pane[
                                    Grid[{{
                                        "Install from",
                                        Button[
                                            NotebookTools`Mousedown[
                                                Framed["Prompt Repository", BaseStyle -> "ButtonGray1Normal", BaselinePosition -> Baseline],
                                                Framed["Prompt Repository", BaseStyle -> "ButtonGray1Hover", BaselinePosition -> Baseline],
                                                Framed["Prompt Repository", BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline],
                                                BaseStyle -> "DialogTextBasic"],
                                            data = PersonaInstallFromResourceSystem[],
                                            Appearance -> "Suppressed", BaselinePosition -> Baseline, Method -> "Queued"],
                                        Button[
                                            NotebookTools`Mousedown[
                                                Framed["URL", BaseStyle -> "ButtonGray1Normal", BaselinePosition -> Baseline],
                                                Framed["URL", BaseStyle -> "ButtonGray1Hover", BaselinePosition -> Baseline],
                                                Framed["URL", BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline],
                                                BaseStyle -> "DialogTextBasic"],
                                            Block[ { PrintTemporary }, PersonaInstallFromURL[] ],
                                            Appearance -> "Suppressed", BaselinePosition -> Baseline, Method -> "Queued"](* ,
                                        (* FIXME: FUTURE *)
                                        Button[
                                            NotebookTools`Mousedown[
                                                Framed["File", BaseStyle -> "ButtonGray1Normal", BaselinePosition -> Baseline],
                                                Framed["File", BaseStyle -> "ButtonGray1Hover", BaselinePosition -> Baseline],
                                                Framed["File", BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline],
                                                BaseStyle -> "DialogTextBasic"],
                                            If[AssociationQ[PersonaInstallFromFile[]], GetPersonaData[]],
                                            Appearance -> "Suppressed", BaselinePosition -> Baseline, Method -> "Queued"] *)}}],
                                    BaseStyle -> "DialogBody",
                                    FrameMargins -> Dynamic[Replace[CurrentValue[{StyleDefinitions, "DialogBody", CellMargins}], {{l_, r_}, {b_, t_}} :> {{l, r}, {15, 5}}]]]},
                            {
                                Pane[#, AppearanceElements -> None, ImageSize -> {Full, UpTo[300]}, Scrollbars -> {False, Automatic}]& @
                                Dynamic[
                                    Grid[
                                        Prepend[
                                            KeyValueMap[
                                                formatPersonaData[#1, #2]&,
                                                Join[
                                                    KeyTake[$CachedPersonaData, favorites],
                                                    KeySort[$CachedPersonaData]]],
                                            {"", "In Menu", "", "Name", ""(*FITME*), (*"Description",*) "Version", ""}],
                                        Alignment -> {{Center, Center, {Left}}, Center},
                                        Background -> {{}, {RGBColor["#e5e5e5"]}},
                                        BaseStyle -> "DialogBody",
                                        Dividers -> Dynamic @ {
                                            {},
                                            {
                                                {{True}},
                                                {
                                                    2 -> False,
                                                    Length[favorites] + 2 -> Directive[delimColor, AbsoluteThickness[5]]}}},
                                        FrameStyle -> Dynamic[delimColor],
                                        ItemSize -> {{Automatic, Automatic, Automatic, Automatic, Fit, {Automatic}}, {}},
                                        Spacings -> {
                                            {{{1}}, {2 -> 1, 4 -> 0.5}},
                                            0.5}],
                                    TrackedSymbols :> {$CachedPersonaData}]},
                            {
                                Item[
                                    Button[(* give Default properties using specific FEExpression *)
                                        NotebookTools`Mousedown[
                                            Framed["OK", BaseStyle -> "ButtonRed1Normal", BaselinePosition -> Baseline],
                                            Framed["OK", BaseStyle -> "ButtonRed1Hover", BaselinePosition -> Baseline],
                                            Framed["OK", BaseStyle -> "ButtonRed1Pressed", BaselinePosition -> Baseline],
                                            BaseStyle -> "DialogTextBasic"],
                                        DialogReturn @ If[AssociationQ[data], channelCleanup],
                                        Appearance -> FEPrivate`FrontEndResource["FEExpressions", "DefaultSuppressMouseDownNinePatchAppearance"],
                                        ImageMargins -> {{0, 31}, {14, 14}},
                                        ImageSize -> Automatic ],
                                    Alignment -> {Right, Center}]}},
                        Alignment -> Left,
                        BaseStyle -> {FontSize -> 1}, (* useful setting in case we want fixed-width columns; ItemSize would scale at the same rate as ImageSize *)
                        Dividers -> {{}, {2 -> True, 4 -> Directive[delimColor, AbsoluteThickness[5]], -2 -> Directive[delimColor, AbsoluteThickness[5]]}},
                        FrameStyle -> Dynamic[delimColor],
                        Spacings -> {0, 0}],
                    ContentPadding -> 0,
                    FrameMargins -> -1,
                    FrameStyle -> None,
                    ImageSize -> {501, All}],
                Initialization :> (
                    delimColor = CurrentValue[{StyleDefinitions, "DialogDelimiter", CellFrameColor}];
                    GetPersonaData[]; (* sets $CachedPersonaData *)
                    (* make sure there are no unexpected extra personas *)
                    CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}] =
                        Intersection[
                            CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}],
                            Keys[$CachedPersonaData]]),
                Deinitialization :> (CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "PersonaFavorites"}] = favorites)
            ],
            CellMargins -> 0],
        Background -> White,
        CellInsertionPointCell -> None,
        NotebookEventActions -> {
            "ReturnKeyDown" :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
            { "MenuCommand", "EvaluateCells" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
            { "MenuCommand", "HandleShiftReturn" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
            { "MenuCommand", "EvaluateNextCell" } :> FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ],
            "EscapeKeyDown" :> (
                FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];
                If[AssociationQ[data], channelCleanup];
                DialogReturn @ $Canceled
            ),
            "WindowClose" :> (
                FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];
                If[AssociationQ[data], channelCleanup];
                DialogReturn @ $Canceled
            )
        },
        StyleDefinitions ->
            Notebook[{(* private stylesheet must inherit from Dialog.nb; only used to modify url link colors to match PeelOff.wl graphics *)
                Cell[StyleData[StyleDefinitions -> "Dialog.nb"]],
                Cell[StyleData["HyperlinkActive"], FontColor -> RGBColor[0.2392, 0.7960, 1.]],
                Cell[StyleData["Hyperlink"], FontColor ->  RGBColor[0.0862, 0.6196, 0.8156]]}],
        WindowTitle -> "Add & Manage Personas"];

createPersonaManagerDialog // endDefinition;

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
(*formatPersonaData*)
formatPersonaData // beginDefinition;

formatPersonaData[ name_String, as_Association ] :=
    formatPersonaData[ name, as, as[ "DocumentationLink" ], as[ "Description" ], as[ "Version" ], as[ "PersonaIcon" ], as[ "Origin" ], as[ "PacletName" ] ];

formatPersonaData[ name_String, as_Association, link_, desc_, version_, KeyValuePattern[ "Default" -> icon_ ], origin_, pacletName_ ] :=
    formatPersonaData[ name, as, link, desc, version, icon, origin, pacletName ];

formatPersonaData[ name_String, as_Association, link_, desc_, version_, icon_, origin_, pacletName_ ] := {
    formatPacletLink[ origin, link, pacletName ],
    addRemovePersonaListingCheckbox[ name ],
    formatIcon @ icon,
    formatName[ origin, personaDisplayName @ name, link ],
    "", (* used for Grid's ItemSize -> Fit *)
    (* formatDescription @ desc, *) (* not enough room for a fixed-width dialog where the "Name" column can be quite large *)
    formatVersion @ version,
    Which[
        FileExistsQ[ personaInstallLocation @ name ], uninstallButton[ name, True, "\[LongDash]" ],
        MissingQ[origin], uninstallButton[ name, False, "\[LongDash]" ],
        origin === "LocalPaclet", uninstallButton[ name, False, pacletName ],
        origin === "Wolfram/Chatbook", uninstallButton[ name, False, origin ] ]
};

formatPersonaData // endDefinition;

formatName // beginDefinition;
formatName[ name_String ] := StringJoin[ Riffle[ DeleteCases[ StringTrim @ StringSplit[ name, RegularExpression[ "([A-Z])([a-z]+)" ] -> "$1$2 " ], "" ], " " ] ]
formatName[ origin_String, name_String, link_Missing ] :=  formatName[ name ]
formatName[ "PacletRepository", name_String, link_ ] := formatName[ name ]
formatName[ origin_String, name_String, link_ ] :=
    Hyperlink[
        Mouseover[
            Grid[{{formatName[ name ], chatbookIcon["PeelOff", False]}}],
            Grid[{{formatName[ name ], chatbookIcon["PeelOff-hover", False]}}]],
        link,
        BaseStyle -> {LineBreakWithin -> False}];
formatName // endDefinition;

formatDescription // beginDefinition;
formatDescription[ _Missing ] := Style["\[LongDash]", FontColor -> GrayLevel[0.808]];
formatDescription[ desc_String ] :=
    Pane[(* If desc becomes a text resource then use FEPrivate`TruncateStringToWidth *)
        If[StringLength[desc] > #nChars, StringTake[desc, UpTo[#nChars - 2]] <> "\[Ellipsis]", desc],
        ImageSize -> {Full, Automatic},
        ImageSizeAction -> "Clip"
    ]&[<|"nChars" -> 30|>];
formatDescription // endDefinition;

formatVersion // beginDefinition;
formatVersion[ _Missing ] := Style["\[LongDash]", FontColor -> GrayLevel[0.808]];
formatVersion[ version: _String|None ] := version;
formatVersion // endDefinition;

formatIcon // beginDefinition;
formatIcon[ _Missing ] := "";
formatIcon[ KeyValuePattern[ "Default" -> icon_ ] ] := formatIcon @ icon;
formatIcon[ icon_ ] := Pane[ icon, ImageSize -> { 20, 20 }, ImageSizeAction -> "ShrinkToFit" ];
formatIcon // endDefinition;

formatPacletLink // beginDefinition;
formatPacletLink[ origin_String, url_, pacletName_ ] :=
    Switch[origin,
        "Wolfram/Chatbook",
            Tooltip[
                Hyperlink[
                    formatIcon @ Mouseover[chatbookIcon["PacletRepo", False], chatbookIcon["PacletRepo-hover", False]],
                    ResourceObject["Wolfram/Chatbook"]["DocumentationLink"],
                    ImageMargins -> {{13, 0}, {0, 0}}],
                "Persona installed from the Wolfram/Chatbook paclet. Visit page \[RightGuillemet]"],
        "PacletRepository",
            Tooltip[
                Hyperlink[
                    formatIcon @ Mouseover[chatbookIcon["PacletRepo", False], chatbookIcon["PacletRepo-hover", False]],
                    url,
                    ImageMargins -> {{13, 0}, {0, 0}}],
                StringTemplate["Persona installed from the `name` paclet. Visit page \[RightGuillemet]."][<|"name" -> pacletName|>]],
        _,
            ""];
formatPacletLink // endDefinition;

addRemovePersonaListingCheckbox // beginDefinition;
addRemovePersonaListingCheckbox[ name_String ] :=
    DynamicModule[{val},
        Checkbox[
            Dynamic[val,
                Function[
                    val = #;
                    CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}] =
                        If[#,
                            Union[Replace[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}], Except[{___String}] :> {}], {name}]
                            ,
                            DeleteCases[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}], name]]]]],
        Initialization :> (val = MemberQ[CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "VisiblePersonas"}], name])];
addRemovePersonaListingCheckbox // endDefinition;

uninstallButton // beginDefinition;
uninstallButton[ name_String, installedQ_, pacletName_String ] :=
    Button[
        PaneSelector[
            {
                "Default" -> formatIcon @ chatbookIcon["Delete", False],
                "Hover" -> formatIcon @ chatbookIcon["Delete-hover", False],
                "Disabled" ->
                    Tooltip[
                        formatIcon @ chatbookIcon["Delete-disabled", False],
                        StringTemplate["This persona cannot be uninstalled because it is provided by the `1` paclet."][pacletName]]},
            Dynamic[Which[!installedQ, "Disabled", CurrentValue["MouseOver"], "Hover", True, "Default"]],
            ImageSize -> Automatic],
        Block[ { PrintTemporary }, uninstallPersona @ name; GetPersonaData[] ],
        Appearance -> "Suppressed",
        Enabled -> installedQ,
        ImageMargins -> {{0, 13}, {0, 0}},
        Method -> "Queued" ];
uninstallButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uninstallPersona*)
uninstallPersona // beginDefinition;

uninstallPersona[ name_String ] := Enclose[
    Module[ { file },
        file = ConfirmBy[ personaInstallLocation @ name, FileExistsQ, "PersonaInstallLocation" ];
        Confirm[ DeleteFile @ file, "DeleteFile" ];
        ConfirmMatch[ GetInstalledResourcePersonas[ ], { ___Association }, "GetInstalledResourcePersonas" ]
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
    Module[ { message, resource },
        message   = ConfirmBy[ messageData[ "Message" ], AssociationQ, "Message" ];
        resource  = ConfirmMatch[ acquireResource @ message, _ResourceObject, "ResourceObject" ];
        personaInstall @ resource
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
    installPersonaConfiguration0[
        installedResourceInfo @ info,
        config,
        target,
        personaName @ info,
        personaContext @ config
    ];

installPersonaConfiguration // endDefinition;


installPersonaConfiguration0 // beginDefinition;

installPersonaConfiguration0[ info_, config_, target_, name_String, None ] :=
    Block[ { $PersonaConfig = <| "Name" -> name, "ResourceInformation" -> info, "Configuration" -> config |> },
        With[ { symbol = ToString @ Unevaluated @ $PersonaConfig },
            DumpSave[ target, symbol, "SymbolAttributes" -> False ];
            target
        ]
    ];

installPersonaConfiguration0[ info_, config_, target_, name_String, context_String ] :=
    Block[ { $PersonaConfig = <| "Name" -> name, "ResourceInformation" -> info, "Configuration" -> config |> },
        With[ { symbol = ToString @ Unevaluated @ $PersonaConfig },
            DumpSave[ target, { symbol, context }, "SymbolAttributes" -> False ];
            target
        ]
    ];

installPersonaConfiguration0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*installedResourceInfo*)
installedResourceInfo // beginDefinition;
installedResourceInfo[ info_Association? AssociationQ ] := KeyDrop[ info, $unsavedResourceProperties ];
installedResourceInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaName*)
personaName // beginDefinition;
personaName[ KeyValuePattern[ "Name" -> name_ ] ] := personaName @ name;

personaName[ name_String ] := (
    needsPromptResource[ ];
    StringDelete[ name, StartOfString ~~ ResourceSystemClient`ResourceType`NamePrefix[ "Prompt" ] ]
);

personaName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*personaInstallLocation*)
personaInstallLocation // beginDefinition;

personaInstallLocation[ KeyValuePattern[ "Name" -> name_ ] ] := personaInstallLocation @ name;

personaInstallLocation[ name0_String ] := Enclose[
    Module[ { name, fileName, directory },
        name      = ConfirmBy[ personaName @ name0, StringQ, "Name" ];
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
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $debug = False;
];

End[ ];
EndPackage[ ];
