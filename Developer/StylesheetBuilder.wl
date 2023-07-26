(* ::Package:: *)

(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`ChatbookStylesheetBuilder`" ];

ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];

$ChatbookStylesheet;
BuildChatbookStylesheet;

System`LinkedItems;
System`MenuAnchor;
System`MenuItem;
System`RawInputForm;
System`ToggleMenuItem;
System`Scope;

Begin[ "`Private`" ];



(* ::Section::Closed:: *)
(*Config*)


(* ::Subsection::Closed:: *)
(*Paths*)


$assetLocation      = FileNameJoin @ { DirectoryName @ $InputFileName, "Resources" };
$iconDirectory      = FileNameJoin @ { $assetLocation, "Icons" };
$ninePatchDirectory = FileNameJoin @ { $assetLocation, "NinePatchImages" };
$styleDataFile      = FileNameJoin @ { $assetLocation, "Styles.wl" };
$pacletDirectory    = DirectoryName[ $InputFileName, 2 ];
$iconManifestFile   = FileNameJoin @ { $pacletDirectory, "Assets", "Icons.wxf" };
$fullIconsFile      = FileNameJoin @ { $pacletDirectory, "Assets", "FullIcons.wxf" };
$styleSheetTarget   = FileNameJoin @ { $pacletDirectory, "FrontEnd", "StyleSheets", "Chatbook.nb" };



(* ::Subsection::Closed:: *)
(*Load Paclet*)


PacletDirectoryLoad @ $pacletDirectory;
Get[ "Wolfram`Chatbook`" ];


(* ::Section::Closed:: *)
(*Resources*)


(* ::Subsection::Closed:: *)
(*$floatingButtonNinePatch*)


$floatingButtonNinePatch = Import @ FileNameJoin @ { $ninePatchDirectory, "FloatingButtonGrid.wxf" };



(* ::Subsection::Closed:: *)
(*$suppressButtonAppearance*)


$suppressButtonAppearance = Dynamic @ FEPrivate`FrontEndResource[
    "FEExpressions",
    "SuppressMouseDownNinePatchAppearance"
];



(* ::Subsection::Closed:: *)
(*Icons*)


$iconFiles = FileNames[ "*.wl", $iconDirectory ];
$iconNames = FileBaseName /@ $iconFiles;

Developer`WriteWXFFile[ $iconManifestFile, AssociationMap[ RawBoxes @ TemplateBox[ { }, #1 ] &, $iconNames ] ];
Developer`WriteWXFFile[ $fullIconsFile   , Association @ Map[ FileBaseName @ # -> Import @ # &, $iconFiles ] ];



(* ::Subsection::Closed:: *)
(*makeIconTemplateBoxStyle*)


makeIconTemplateBoxStyle[ file_ ] :=
    With[ { icon = ToBoxes @ Import @ file },
        Cell[ StyleData @ FileBaseName @ file, TemplateBoxOptions -> { DisplayFunction -> (icon &) } ]
    ];



(* ::Subsection::Closed:: *)
(*$askMenuItem*)


$askMenuItem = MenuItem[
    "Ask AI Assistant",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Ask", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];



(* ::Subsection::Closed:: *)
(*$excludeMenuItem*)


$excludeMenuItem = MenuItem[
    "Include/Exclude From AI Chat",
    KernelExecute[
        With[
            { $CellContext`nbo = InputNotebook[ ] },
            { $CellContext`cells = SelectedCells @ $CellContext`nbo },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ExclusionToggle", $CellContext`nbo, $CellContext`cells ]
        ]
    ],
    MenuEvaluator -> Automatic,
    Method        -> "Queued"
];



(* ::Subsection::Closed:: *)
(*contextMenu*)


contextMenu[ a___, name_String, b___ ] := contextMenu[ a, FrontEndResource[ "ContextMenus", name ], b ];
contextMenu[ a___, list_List, b___ ] := contextMenu @@ Flatten @ { a, list, b };
contextMenu[ a___ ] := Flatten @ { a };



(* ::Subsection::Closed:: *)
(*menuInitializer*)


menuInitializer[ name_String, color_ ] :=
    With[ { attach = Cell[ BoxData @ TemplateBox[ { name, color }, "ChatMenuButton" ], "ChatMenu" ] },
        Initialization :>
            If[ ! TrueQ @ CloudSystem`$CloudNotebooks,
                (* TODO: we need another method for menus in the cloud *)
                With[ { $CellContext`cell = EvaluationCell[ ] },
                    NotebookDelete @ Cells[ $CellContext`cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
                    AttachCell[
                        $CellContext`cell,
                        attach,
                        { Right, Top },
                        Offset[ { -7, -7 }, { Right, Top } ],
                        { Right, Top }
                    ]
                ]
            ]
    ];



(* ::Subsection::Closed:: *)
(*assistantMenuInitializer*)


assistantMenuInitializer[ name_String, color_ ] :=
    With[
        {
            attach = Cell[
                BoxData @ ToBoxes @ Column[
                    {
                        Tooltip[
                            Button[
                                RawBoxes @ TemplateBox[ { }, "CloseAssistant" ],
                                With[ { $CellContext`cell = EvaluationCell[ ] },
                                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                                    Catch[
                                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                            "DisableAssistance",
                                            $CellContext`cell
                                        ],
                                        _
                                    ]
                                ],
                                Appearance -> $suppressButtonAppearance
                            ],
                            "Disable automatic assistance"
                        ],
                        RawBoxes @ TemplateBox[ { name, color }, "ChatMenuButton" ]
                    },
                    Spacings -> 0
                ],
                "ChatMenu"
            ]
        },
        Initialization :>
            If[ ! TrueQ @ CloudSystem`$CloudNotebooks,
                With[ { $CellContext`cell = EvaluationCell[ ] },
                    NotebookDelete @ Cells[ $CellContext`cell, AttachedCell -> True, CellStyle -> "ChatMenu" ];
                    AttachCell[
                        $CellContext`cell,
                        attach,
                        { Right, Top },
                        Offset[ { -7, -7 }, { Right, Top } ],
                        { Right, Top }
                    ]
                ]
            ]
    ];



(* ::Subsection::Closed:: *)
(*$chatOutputMenu*)


makeMenu[ items_List, frameColor_, width_ ] := Pane[
    RawBoxes @ TemplateBox[
        {
            ToBoxes @ Column[ menuItem /@ items, ItemSize -> { Full, 0 }, Spacings -> 0, Alignment -> Left ],
            FrameMargins   -> 3,
            Background     -> GrayLevel[ 0.98 ],
            RoundingRadius -> 3,
            FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
            ImageMargins   -> 0
        },
        "Highlighted"
    ],
    ImageSize -> { width, Automatic }
];

menuItem[ { args__ } ] := menuItem @ args;

menuItem[ Delimiter ] := RawBoxes @ TemplateBox[ { }, "ChatMenuItemDelimiter" ];

menuItem[ label_ :> action_ ] := menuItem[ Graphics[ { }, ImageSize -> 0 ], label, Hold @ action ];

menuItem[ section_ ] := RawBoxes @ TemplateBox[ { ToBoxes @ section }, "ChatMenuSection" ];

menuItem[ name_String, label_, code_ ] :=
    If[ MemberQ[ $iconNames, name ],
        menuItem[ RawBoxes @ TemplateBox[ { }, name ], label, code ],
        menuItem[ RawBoxes @ TemplateBox[ { name }, "ChatMenuItemToolbarIcon" ], label, code ]
    ];

menuItem[ icon_, label_, action_String ] :=
    menuItem[
        icon,
        label,
        Hold @ With[
            { $CellContext`cell = EvaluationCell[ ] },
            { $CellContext`root = ParentCell @ $CellContext`cell },
            NotebookDelete @ $CellContext`cell;
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ action, $CellContext`root ]
        ]
    ];

menuItem[ icon_, label_, None ] :=
    menuItem[
        icon,
        label,
        Hold[
            NotebookDelete @ EvaluationCell[ ];
            MessageDialog[ "Not Implemented" ]
        ]
    ];

menuItem[ icon_, label_, code_ ] :=
    RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

$chatOutputMenu := $chatOutputMenu = ToBoxes @ makeMenu[
    {
        (* Icon              , Label                      , ActionName          *)
        { "DivideCellsIcon"  , "Explode Cells (In Place)" , "ExplodeInPlace"     },
        { "OverflowIcon"     , "Explode Cells (Duplicate)", "ExplodeDuplicate"   },
        { "HyperlinkCopyIcon", "Copy Exploded Cells"      , "CopyExplodedCells"  },
        Delimiter,
        { "TypesettingIcon"  , "Toggle Formatting"        , "ToggleFormatting"   },
        { "InPlaceIcon"      , "Copy ChatObject"          , "CopyChatObject"     }
    },
    GrayLevel[ 0.85 ],
    250
];



(* ::Subsection::Closed:: *)
(*Tabbed Output CellDingbat*)


tabArrowFrame[ gfx_, opts___ ] := Framed[
    Graphics[ { GrayLevel[ 0.4 ], gfx }, ImageSize -> 4 ],
    FrameMargins   -> 3,
    FrameStyle     -> None,
    ImageMargins   -> 0,
    RoundingRadius -> 2,
    opts
];


tabArrowButtonLabel[ gfx_ ] := MouseAppearance[
    Mouseover[
        tabArrowFrame[ gfx, Background -> None ],
        tabArrowFrame[ gfx, Background -> GrayLevel[ 0.9 ] ]
    ],
    "LinkHand"
];


$tabButtonLabels = <|
    "TabLeft"  -> tabArrowButtonLabel[ Polygon @ { { 0, 0 }, { 0, 1 }, { -0.5, 0.5 } } ],
    "TabRight" -> tabArrowButtonLabel[ Polygon @ { { 0, 0 }, { 0, 1 }, { 0.5, 0.5 } } ]
|>;


tabScrollButton[ direction_, cell_ ] := Button[
    $tabButtonLabels[ direction ],
    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
    Catch[ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ direction, cell ], _ ],
    Appearance -> $suppressButtonAppearance
];


$tabbedOutputControls =
    DynamicModule[ { cell },
        Column[
            {
                Row @ { tabScrollButton[ "TabLeft", cell ], tabScrollButton[ "TabRight", cell ] },
                RawBoxes @ StyleBox[
                    RowBox @ {
                        DynamicBox @ ToBoxes[
                            CurrentValue[ cell, { TaggingRules, "PageData", "CurrentPage" }, 1 ],
                            StandardForm
                        ],
                        "/",
                        DynamicBox @ ToBoxes[
                            CurrentValue[ cell, { TaggingRules, "PageData", "PageCount" }, 1 ],
                            StandardForm
                        ]
                    },
                    FontFamily -> "Roboto",
                    FontSize   -> 10
                ]
            },
            Alignment -> Center,
            Spacings  -> 0.1
        ],
        Initialization   :> (cell = If[ $CloudEvaluation, EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
        UnsavedVariables :> { cell }
    ];


tabbedChatOutputCellDingbat[ arg_ ] := Column[
    {
        Style[ "", ShowStringCharacters -> False ],
        RawBoxes @ arg,
        $tabbedOutputControls
    },
    Alignment -> Center,
    Spacings  -> 0.1
];

$chatInputActiveCellDingbat = Wolfram`Chatbook`UI`MakeChatInputActiveCellDingbat[ ];
$chatInputCellDingbat       = Wolfram`Chatbook`UI`MakeChatInputCellDingbat[ ];
$chatDelimiterCellDingbat   = Wolfram`Chatbook`UI`MakeChatDelimiterCellDingbat[ ];


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Insertion Point Cell*)

$cellInsertionPointCell := $cellInsertionPointCell = ReplaceAll[
    FrontEndResource[ "FEExpressions", "CellInsertionMenu" ],
    item: HoldPattern[ _ :> FrontEndTokenExecute[ EvaluationNotebook[ ], "Style", "ExternalLanguage" ] ] :> Sequence[
        item,
        insertionPointMenuItem[ TemplateBox[ { }, "ChatInputIcon" ], "Chat Input", "'", "ChatInput" ],
        insertionPointMenuItem[ TemplateBox[ { }, "SideChatIcon" ], "Side Chat", "''", "SideChat" ]
    ]
];


insertionPointMenuItem // Attributes = { HoldRest };
insertionPointMenuItem[ icon_, label_, shortcut_, style_ ] :=
    GridBox[
        {
            {
                PaneBox[ icon, BaselinePosition -> Center -> Scaled[ 0.55 ] ],
                StyleBox[ label, "CellInsertionMenu" ],
                StyleBox[ StyleBox[ shortcut, "CellInsertionMenuShortcut" ], "CellInsertionMenuShortcut" ]
            }
        },
        GridBoxAlignment -> { "Columns" -> { Center, Left, Right }, "Rows" -> { { Automatic } } },
        AutoDelete -> False,
        GridBoxItemSize -> {
            "Columns" -> {
                2,
                FEPrivate`First @ FEPrivate`StringWidth[
                    {
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "MathematicaInput"      ],
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "FreeformInput"         ],
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "WAQuery"               ],
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "ExternalLanguageInput" ],
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "TextStyle"             ],
                        FEPrivate`FrontEndResource[ "CellInsertionMenu", "OtherStyle"            ]
                    },
                    "CellInsertionMenu"
                ],
                FEPrivate`First @ FEPrivate`StringWidth[
                    FEPrivate`FrontEndResource[ "CellInsertionMenu", "ShortcutColumnMaxStringLen" ],
                    "CellInsertionMenuDefaultLabel"
                ]
            },
            "Rows" -> { { Automatic } }
        },
        GridBoxSpacings -> {
            "Columns"        -> { { 0 } },
            "ColumnsIndexed" -> { 2 -> 0.3, 3 -> 0.5 },
            "Rows"           -> { { 0 } }
        }
    ] :> FrontEndTokenExecute[ EvaluationNotebook[ ], "Style", style ];



(* ::Subsection::Closed:: *)
(*Stylesheet Version*)


$stylesheetVersion = StringJoin[
    PacletObject[ File[ $pacletDirectory ] ][ "Version" ],
    ".",
    ToString @ Round @ AbsoluteTime[ ]
];



(* ::Subsection::Closed:: *)
(*inlineResources*)


inlineResources[ expr_ ] := expr /. {
    HoldPattern @ $askMenuItem              :> RuleCondition @ $askMenuItem,
    HoldPattern @ $defaultChatbookSettings  :> RuleCondition @ $defaultChatbookSettings,
    HoldPattern @ $suppressButtonAppearance :> RuleCondition @ $suppressButtonAppearance
};



(* ::Subsection::Closed:: *)
(*$styleDataCells*)


$styleDataCells := $styleDataCells = inlineResources @ Cases[ Flatten @ ReadList @ $styleDataFile, _Cell ];



(* ::Subsection::Closed:: *)
(*Default Settings*)


$defaultChatbookSettings := (
    Needs[ "Wolfram`Chatbook`" -> None ];
    KeyMap[ ToString, Association @ Options @ Wolfram`Chatbook`CreateChatNotebook ]
);



(* ::Section::Closed:: *)
(*$ChatbookStylesheet*)


$ChatbookStylesheet = Notebook[
    Flatten @ {
        Cell @ StyleData[ StyleDefinitions -> "Default.nb" ],
        $styleDataCells
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];



(* ::Section::Closed:: *)
(*BuildChatbookStylesheet*)


BuildChatbookStylesheet[ ] := BuildChatbookStylesheet @ $styleSheetTarget;

BuildChatbookStylesheet[ target_ ] :=
    Module[ { exported },
        exported = Export[ target, $ChatbookStylesheet, "NB" ];
        PacletInstall[ "Wolfram/PacletCICD" ];
        Needs[ "Wolfram`PacletCICD`" -> None ];
        SetOptions[
            ResourceFunction[ "SaveReadableNotebook" ],
            "RealAccuracy" -> 10,
            "ExcludedNotebookOptions" -> {
                ExpressionUUID,
                FrontEndVersion,
                WindowMargins,
                WindowSize
            }
        ];
        Wolfram`PacletCICD`FormatNotebooks @ exported;
        exported
    ];



(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
EndPackage[ ];
