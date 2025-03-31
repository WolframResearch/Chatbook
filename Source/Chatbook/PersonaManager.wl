(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PersonaManager`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`CreatePersonaManagerDialog;
`CreatePersonaManagerPanel;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`UI`"                ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$chatbookDocumentationURL = "https://resources.wolframcloud.com/PacletRepository/resources/Wolfram/Chatbook";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreatePersonaManagerDialog*)
CreatePersonaManagerDialog // beginDefinition;

CreatePersonaManagerDialog[ args___ ] := createDialog[
    CreatePersonaManagerPanel @ args,
    WindowTitle -> tr[ "PersonaManagerTitle" ]
];

CreatePersonaManagerDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreatePersonaManagerPanel*)
CreatePersonaManagerPanel // beginDefinition;

CreatePersonaManagerPanel[ ] := DynamicModule[{favorites, delimiterColor},
    favorites = Replace[
        CurrentChatSettings[ $FrontEnd, "PersonaFavorites" ],
        Except[ { ___String } ] :> $corePersonaNames
    ];

    Framed[
        Grid[
            {
                If[ TrueQ @ $inDialog, dialogHeader @ tr[ "PersonaManagerTitle" ], Nothing ],

                (* ----- Install Personas ----- *)
                dialogSubHeader @ tr[ "PersonaManagerInstallPersonas" ],
                dialogBody[
                    Grid @ {
                        {
                            tr[ "PersonaManagerInstallFrom" ],
                            Button[
                                grayDialogButtonLabel @ tr[ "PersonaManagerInstallFromPromptRepo" ],
                                If[ $CloudEvaluation, SetOptions[ EvaluationNotebook[ ], DockedCells -> Inherited ] ];
                                ResourceInstallFromRepository[ "Prompt" ],
                                Appearance       -> "Suppressed",
                                BaselinePosition -> Baseline,
                                Method           -> "Queued"
                            ],
                            Button[
                                grayDialogButtonLabel @ tr[ "URLButton" ],
                                If[ $CloudEvaluation, SetOptions[ EvaluationNotebook[ ], DockedCells -> Inherited ] ];
                                Block[ { PrintTemporary }, ResourceInstallFromURL[ "Prompt" ] ],
                                Appearance       -> "Suppressed",
                                BaselinePosition -> Baseline,
                                Method           -> "Queued"
                            ],
                            Button[
                                grayDialogButtonLabel @ tr[ "PersonaManagerInstallFromFile" ],
                                If[ $CloudEvaluation, SetOptions[ EvaluationNotebook[ ], DockedCells -> Inherited ] ];
                                Block[ { PrintTemporary }, ResourceInstallFromFile[ "Prompt" ] ],
                                Appearance       -> "Suppressed",
                                BaselinePosition -> Baseline,
                                Method           -> "Queued"
                            ]
                        }
                    }
                ],

                (* ----- Configure and Enable Personas ----- *)
                dialogSubHeader[ tr[ "PersonaManagerManagePersonas" ], { Automatic, { 5, Automatic } } ],
                {
                    If[ $inDialog, Pane[#, AppearanceElements -> None, ImageSize -> {Full, UpTo[300]}, Scrollbars -> {False, Automatic}], # ]& @
                    Dynamic[
                        $CachedPersonaData;
                        Grid[
                            Prepend[
                                KeyValueMap[
                                    formatPersonaData[#1, #2]&,
                                    Join[
                                        KeyTake[GetCachedPersonaData[ "IncludeHidden" -> False ], favorites],
                                        KeySort[GetCachedPersonaData[ "IncludeHidden" -> False ]]]],
                                {
                                    "",
                                    tr[ "PersonaManagerInMenu" ],
                                    "",
                                    tr[ "PersonaManagerName" ],
                                    "",
                                    tr[ "PersonaManagerVersion" ],
                                    ""
                                }
                            ],
                            Alignment -> {{Center, Center, {Left}}, Center},
                            Background -> {{}, { #1, { #2 }}},
                            BaseStyle -> "DialogBody",
                            Dividers -> Dynamic @ {
                                {},
                                {
                                    {{True}},
                                    {
                                        2 -> False,
                                        Length[favorites] + 2 -> Directive[delimiterColor, AbsoluteThickness[5]]
                                    }
                                }
                            },
                            FrameStyle -> Dynamic[delimiterColor],
                            ItemSize -> {{Automatic, Automatic, Automatic, Automatic, Fit, {Automatic}}, {}},
                            Spacings -> {
                                {{{1}}, {2 -> 1, 4 -> 0.5}},
                                {{{0.5}}, {Length[favorites] + 2 -> 1}}
                            }
                        ],
                        TrackedSymbols :> {$CachedPersonaData}
                    ]&[
                        color @ "ManagerGridHeaderBackground",
                        color @ "ManagerGridItemBackground"
                    ]
                },

                (* ----- Dialog Buttons ----- *)
                If[ TrueQ @ $inDialog,
                    {
                        Item[
                            Button[(* give Default properties using specific FEExpression *)
                                redDialogButtonLabel @ tr[ "OKButton" ],
                                DialogReturn @ channelCleanup[ ],
                                Appearance -> FEPrivate`FrontEndResource["FEExpressions", "DefaultSuppressMouseDownNinePatchAppearance"],
                                ImageMargins -> {{0, 31}, {14, 14}},
                                ImageSize -> Automatic
                            ],
                            Alignment -> {Right, Center}
                        ]
                    },
                    { "" }
                ]
            },
            Alignment -> Left,
            BaseStyle -> $baseStyle, (* useful setting in case we want fixed-width columns; ItemSize would scale at the same rate as ImageSize *)
            Dividers -> {
                {},
                If[ TrueQ @ $inDialog,
                    {
                        2 -> True,
                        4 -> True,
                        -2 -> Directive[AbsoluteThickness[5]]
                    },
                    {
                        3 -> True
                    }
                ]
            },
            FrameStyle -> Dynamic[delimiterColor],
            Spacings -> {0, 0}
        ],
        ContentPadding -> 0,
        FrameMargins -> -1,
        FrameStyle -> None,
        ImageSize -> { If[ TrueQ @ $inDialog, 501, Automatic ], All}],
    Initialization :> (
        delimiterColor = CurrentValue[{StyleDefinitions, "DialogDelimiter", CellFrameColor}];
        GetPersonaData[]; (* sets $CachedPersonaData *)
        (* make sure there are no unexpected extra personas *)
        Enclose[
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ] = ConfirmBy[
                Quiet @ Intersection[ CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ], Keys @ $CachedPersonaData ],
                ListQ
            ]
        ]
    ),
    Deinitialization :> If[ MatchQ[ favorites, { ___String } ],
        CurrentChatSettings[ $FrontEnd, "PersonaFavorites" ] = favorites
    ]
];

CreatePersonaManagerPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatPersonaData*)
formatPersonaData // beginDefinition;

formatPersonaData[ name_String, as_Association ] :=
    formatPersonaData[
        name,
        as,
        as[ "DocumentationLink" ],
        as[ "Description" ],
        as[ "Version" ],
        getPersonaIcon @ as,
        as[ "Origin" ],
        as[ "PacletName" ]
    ];

formatPersonaData[
    name_String,
    as_Association,
    link_,
    desc_,
    version_,
    KeyValuePattern[ "Default" -> icon_ ],
    origin_,
    pacletName_
] :=
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
        FileExistsQ @ ResourceInstallLocation[ "Prompt", name ], uninstallButton[ name, True, "\[LongDash]" ],
        MissingQ[origin], uninstallButton[ name, False, "\[LongDash]" ],
        origin === "LocalPaclet", uninstallButton[ name, False, pacletName ],
        origin === "Wolfram/Chatbook", uninstallButton[ name, False, origin ] ]
};

formatPersonaData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatName*)
formatName // beginDefinition;

formatName[ name_String ] := StringRiffle @ DeleteCases[
    StringTrim @ StringSplit[ name, RegularExpression[ "([A-Z])([a-z]+)" ] -> "$1$2 " ],
    ""
];

formatName[ name: Except[ $$unspecified ] ] :=
    name;

formatName[ origin_String, name: Except[ $$unspecified ], link_Missing ] :=
    formatName @ name;

formatName[ "PacletRepository", name: Except[ $$unspecified ], link_ ] :=
    formatName @ name;

formatName[ origin_String, name: Except[ $$unspecified ], link_ ] :=
    Hyperlink[
        Mouseover[
            Grid @ { { formatName @ name, chatbookExpression[ "PeelOff" ] } },
            Grid @ { { formatName @ name, chatbookExpression[ "PeelOff-hover" ] } }
        ],
        link,
        BaseStyle -> { LineBreakWithin -> False }
    ];

formatName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDescription*)
formatDescription // beginDefinition;
formatDescription[ _Missing ] := Style["\[LongDash]", FontColor -> color @ "ManagerGridFont_1"];
formatDescription[ desc_String ] :=
    Pane[(* If desc becomes a text resource then use FEPrivate`TruncateStringToWidth *)
        If[StringLength[desc] > #nChars, StringTake[desc, UpTo[#nChars - 2]] <> "\[Ellipsis]", desc],
        ImageSize -> {Full, Automatic},
        ImageSizeAction -> "Clip"
    ]&[<|"nChars" -> 30|>];
formatDescription // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatVersion*)
formatVersion // beginDefinition;
formatVersion[ _Missing ] := Style["\[LongDash]", FontColor -> color @ "ManagerGridFont_1"];
formatVersion[ version: _String|None ] := version;
formatVersion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatIcon*)
formatIcon // beginDefinition;
formatIcon[ _Missing ] := "";
formatIcon[ KeyValuePattern[ "Default" -> icon_ ] ] := formatIcon @ icon;
formatIcon[ icon_ ] := Pane[ icon, ImageSize -> { 20, 20 }, ImageSizeAction -> "ShrinkToFit" ];
formatIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPacletLink*)
formatPacletLink // beginDefinition;
formatPacletLink[ origin_String, url_, pacletName_ ] :=
    Switch[origin,
        "Wolfram/Chatbook",
            Tooltip[
                Hyperlink[
                    formatIcon @ Mouseover[chatbookExpression["PacletRepo"], chatbookExpression["PacletRepo-hover"]],
                    $chatbookDocumentationURL,
                    ImageMargins -> {{13, 0}, {0, 0}}],
                tr[ "PersonaManagerOriginChatbookTooltip" ]],
        "PacletRepository",
            Tooltip[
                Hyperlink[
                    formatIcon @ Mouseover[chatbookExpression["PacletRepo"], chatbookExpression["PacletRepo-hover"]],
                    url,
                    ImageMargins -> {{13, 0}, {0, 0}}],
                trStringTemplate[ "PersonaManagerOriginRepositoryTooltip" ][ <| "name" -> pacletName |> ]],
        _,
            ""];
formatPacletLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addRemovePersonaListingCheckbox*)
addRemovePersonaListingCheckbox // beginDefinition;

addRemovePersonaListingCheckbox[ name_String ] :=
    With[ { core = $corePersonaNames },
        Checkbox @ Dynamic[
            MemberQ[ CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ], name ],
            Function[
                CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ] = With[
                    { current = Replace[ CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ], Except[ { ___String } ] :> core ] },
                    If[ #1, Union[ current, { name } ], Complement[ current, { name } ] ]
                ]
            ]
        ]
    ];

addRemovePersonaListingCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uninstallButton*)
uninstallButton // beginDefinition;
uninstallButton[ name_String, installedQ_, pacletName_String ] :=
    Button[
        PaneSelector[
            {
                "Default" -> formatIcon @ chatbookExpression["Delete"],
                "Hover" -> formatIcon @ chatbookExpression["Delete-hover"],
                "Disabled" ->
                    Tooltip[
                        formatIcon @ chatbookExpression["Delete-disabled"],
                        trStringTemplate[ "PersonaManagerPersonaUninstallTooltip" ][ pacletName ]]},
            Dynamic[Which[!installedQ, "Disabled", CurrentValue["MouseOver"], "Hover", True, "Default"]],
            ImageSize -> Automatic],
        Block[ { PrintTemporary },
            ResourceUninstall[ "Prompt", name ];
            GetPersonaData[ ];
            forceRefreshCloudPreferences[ ]
        ],
        Appearance -> "Suppressed",
        Enabled -> installedQ,
        ImageMargins -> {{0, 13}, {0, 0}},
        Method -> "Queued" ];
uninstallButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
