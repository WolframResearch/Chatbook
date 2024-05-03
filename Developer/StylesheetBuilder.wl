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


$assetLocation        = FileNameJoin @ { DirectoryName @ $InputFileName, "Resources" };
$iconDirectory        = FileNameJoin @ { $assetLocation, "Icons" };
$ninePatchDirectory   = FileNameJoin @ { $assetLocation, "NinePatchImages" };
$styleDataFile        = FileNameJoin @ { $assetLocation, "Styles.wl" };
$pacletDirectory      = DirectoryName[ $InputFileName, 2 ];
$iconManifestFile     = FileNameJoin @ { $pacletDirectory, "Assets", "Icons.wxf" };
$displayFunctionsFile = FileNameJoin @ { $pacletDirectory, "Assets", "DisplayFunctions.wxf" };
$styleSheetTarget     = FileNameJoin @ { $pacletDirectory, "FrontEnd", "StyleSheets", "Chatbook.nb" };



(* ::Subsection::Closed:: *)
(*Load Paclet*)


PacletDirectoryLoad @ $pacletDirectory;
Get[ "Wolfram`Chatbook`" ];


(* ::Section::Closed:: *)
(*Resources*)


(* ::Subsection::Closed:: *)
(*tr*)


tr[name_?StringQ] := Dynamic[FEPrivate`FrontEndResource["ChatbookStrings", name]]


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



(* ::Subsection::Closed:: *)
(*$includedCellWidget*)


$includedCellWidget = Cell[
    BoxData @ ToBoxes @ Dynamic[ $IncludedCellWidget, SingleEvaluation -> True ],
    "ChatIncluded"
];



(* ::Subsection::Closed:: *)
(*makeIconTemplateBoxStyle*)


makeIconTemplateBoxStyle[ file_ ] := makeIconTemplateBoxStyle[ file, Import @ file ];

makeIconTemplateBoxStyle[ file_, func_Function ] :=
    makeIconTemplateBoxStyle[ file, func, ToBoxes @ func @ $$slot[ 1 ] /. $$slot -> Slot ];

makeIconTemplateBoxStyle[ file_, icon_ ] :=
    makeIconTemplateBoxStyle[ file, icon, ToBoxes @ icon ];

makeIconTemplateBoxStyle[ file_, icon_, boxes_ ] :=
    Cell[ StyleData @ FileBaseName @ file, TemplateBoxOptions -> { DisplayFunction -> (boxes &) } ];



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
                            tr["StylesheetAssistantMenuInitializerButtonTooltip"]
                        ],
                        RawBoxes @ TemplateBox[ { name, color }, "ChatMenuButton" ]
                    },
                    Alignment -> Center,
                    Spacings  -> 0
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



$feedbackButtons = Column[ { feedbackButton @ True, feedbackButton @ False }, Spacings -> { 0, { 0, 0.25, 0 } } ];

feedbackButton[ True  ] := feedbackButton[ True , "ThumbsUp"   ];
feedbackButton[ False ] := feedbackButton[ False, "ThumbsDown" ];

feedbackButton[ positive: True|False, name_String ] :=
    Button[
        MouseAppearance[
            Tooltip[
                Mouseover[
                    RawBoxes @ TemplateBox[ { }, name<>"Inactive" ],
                    RawBoxes @ TemplateBox[ { }, name<>"Active" ]
                ],
                tr["StylesheetFeedbackButtonTooltip"]
            ],
            "LinkHand"
        ],
        With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Catch[ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "SendFeedback", $CellContext`cell, positive ], _ ]
        ],
        Appearance -> $suppressButtonAppearance
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
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ action, $CellContext`root ];
            NotebookDelete @ $CellContext`cell;
        ]
    ];

menuItem[ icon_, label_, None ] :=
    menuItem[
        icon,
        label,
        Hold[
            MessageDialog[ "Not Implemented" ];
            NotebookDelete @ EvaluationCell[ ];
        ]
    ];

menuItem[ icon_, label_, code_ ] :=
    RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label, code }, "ChatMenuItem" ];

$chatOutputMenu := $chatOutputMenu = ToBoxes @ makeMenu[
    {
        (* Icon              , Label                                  , ActionName          *)
        { "DivideCellsIcon"  , tr[ "StylesheetExplodeCellsInPlace" ]  , "ExplodeInPlace"     },
        { "OverflowIcon"     , tr[ "StylesheetExplodeCellsDuplicate" ], "ExplodeDuplicate"   },
        { "HyperlinkCopyIcon", tr[ "StylesheetCopyExplodedCells" ]    , "CopyExplodedCells"  },
        Delimiter,
        { "TypesettingIcon"  , tr[ "StylesheetToggleFormatting" ]     , "ToggleFormatting"   },
        { "InPlaceIcon"      , tr[ "StylesheetCopyChatObject" ]       , "CopyChatObject"     }
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
        Initialization   :> (cell = If[ $CloudEvaluation, x; EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
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
    {
        PaneSelectorBox[
            args: {
                True -> StyleBox[
                    DynamicBox[ FEPrivate`FrontEndResource[ "CellInsertionMenu", "TextStyle2Mac" ], ___ ],
                    ___
                ],
                ___
            },
            True|False,
            opts___
        ] :> PaneSelectorBox[ args, Dynamic[ $OperatingSystem === "MacOSX" ], opts ]
        ,
        item: HoldPattern[ _ :> FrontEndTokenExecute[ EvaluationNotebook[ ], "Style", "ExternalLanguage" ] ] :>
            Sequence[
                item,
                insertionPointMenuItem[ TemplateBox[ { }, "ChatInputIcon" ], "Chat Input", "'", "ChatInput" ],
                insertionPointMenuItem[ TemplateBox[ { }, "SideChatIcon" ], "Side Chat", "''", "SideChat" ]
            ]
    }
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


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DiscardedMaterialOpener*)

discardedMaterialLabelBox[ Dynamic[ hover_ ], Dynamic[ open_ ] ] := TagBox[
    TagBox[
        FrameBox[
            TagBox[
                GridBox[
                    {
                        {
                            TemplateBox[ { }, "DiscardedMaterial" ],
                            "\"Discarded material\"",
                            discardedMaterialLabelIcon[ Dynamic @ hover, Dynamic @ open ]
                        }
                    },
                    GridBoxAlignment -> { "Columns" -> { { Automatic } }, "Rows" -> { { Baseline } } },
                    AutoDelete -> False,
                    GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                ],
                "Grid"
            ],
            Background -> Dynamic @ FEPrivate`If[ hover, GrayLevel[ 1 ], RGBColor[ 0.94902, 0.96863, 0.98824 ] ],
            BaseStyle -> { "Text", "IconizedDefaultName", ShowStringCharacters -> False },
            FrameMargins -> 2,
            FrameStyle -> RGBColor[ 0.9098, 0.93333, 0.95294 ],
            RoundingRadius -> 5,
            StripOnInput -> False
        ],
        EventHandlerTag @ {
            "MouseEntered" :> FEPrivate`Set[ hover, True ],
            "MouseExited"  :> FEPrivate`Set[ hover, False ],
            "MouseClicked" :> FEPrivate`Set[ open, FEPrivate`If[ open, False, True ] ],
            PassEventsDown -> True,
            Method         -> "Preemptive",
            PassEventsUp   -> True
        }
    ],
    MouseAppearanceTag[ "LinkHand" ]
];

discardedMaterialLabelIcon[ Dynamic[ hover_ ], Dynamic[ open_ ] ] :=
    With[ { hoverColor = RGBColor[ 0.3451, 0.72157, 0.98039 ], defaultColor = GrayLevel[ 0.7451 ] },
        PaneSelectorBox[
            {
                { True , False } -> TemplateBox[ { hoverColor   }, "DiscardedMaterialOpenerIcon" ],
                { False, False } -> TemplateBox[ { defaultColor }, "DiscardedMaterialOpenerIcon" ],
                { True , True  } -> TemplateBox[ { hoverColor   }, "DiscardedMaterialCloserIcon" ],
                { False, True  } -> TemplateBox[ { defaultColor }, "DiscardedMaterialCloserIcon" ]
            },
            Dynamic[ { hover, open } ]
        ]
    ];


$discardedMaterialLabel = discardedMaterialLabelBox[ Dynamic @ Typeset`hover$$, Dynamic @ Typeset`open$$ ];

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
    HoldPattern @ $suppressButtonAppearance :> RuleCondition @ $suppressButtonAppearance,
    HoldPattern @ $discardedMaterialLabel   :> RuleCondition @ $discardedMaterialLabel
};



(* ::Subsection::Closed:: *)
(*$styleDataCells*)


$styleDataCells = inlineResources @ Cases[ Flatten @ ReadList @ $styleDataFile, _Cell ];



(* ::Subsection::Closed:: *)
(*$templateBoxDisplayFunctions*)


$templateBoxDisplayFunctions = Association @ Cases[
    $styleDataCells,
    Cell[ StyleData[ name_String ], ___, TemplateBoxOptions -> KeyValuePattern[ DisplayFunction -> func_ ], ___ ] :>
        (name -> func)
];


Developer`WriteWXFFile[ $displayFunctionsFile, $templateBoxDisplayFunctions ];



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


fixContexts[ expr_ ] := ResourceFunction[ "ReplaceContext" ][
    expr,
    {
        "Wolfram`ChatbookStylesheetBuilder`"         -> "Wolfram`ChatNB`",
        "Wolfram`ChatbookStylesheetBuilder`Private`" -> "Wolfram`ChatNB`",
        "$CellContext`"                              -> "Wolfram`ChatNB`",
        $Context                                     -> "Wolfram`ChatNB`"
    }
];


BuildChatbookStylesheet[ ] := BuildChatbookStylesheet @ $styleSheetTarget;

BuildChatbookStylesheet[ target_ ] :=
    Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } },
        Module[ { exported },
            exported = Export[ target, fixContexts @ $ChatbookStylesheet, "NB" ];
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
        ]
    ];



(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
EndPackage[ ];
