(* ::Package:: *)

(* ::Section::Closed:: *)
(*Package Header*)


BeginPackage[ "Wolfram`ChatbookStylesheetBuilder`" ];

ClearAll[ "`*" ];
ClearAll[ "`Private`*" ];

$ChatbookStylesheet;
$WorkspaceStylesheet;
BuildStylesheets;
BuildChatbookStylesheet;
BuildWorkspaceStylesheet;
BuildCoreExtensionsStylesheet;
CompileTemplateData;

Begin[ "`Private`" ];



(* ::Section::Closed:: *)
(*Config*)


$sideChatWidth = 350;

$workspaceDefaultSettings = <|
    "SetCellDingbat" -> False,
    "TabbedOutput"   -> False, (* FIXME: this is temporarily set to False to avoid some bad bugs *)
    "WorkspaceChat"  -> True
|>;


(* ::Subsection::Closed:: *)
(*Paths*)

$inputFileName          = Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$assetLocation          = FileNameJoin @ { DirectoryName @ $inputFileName, "Resources" };
$iconDirectory          = FileNameJoin @ { $assetLocation, "Icons" };
$ninePatchDirectory     = FileNameJoin @ { $assetLocation, "NinePatchImages" };
$styleDataFile          = FileNameJoin @ { $assetLocation, "Styles.wl" };
$workspaceStyleDataFile = FileNameJoin @ { $assetLocation, "WorkspaceStyles.wl" };
$pacletDirectory        = DirectoryName[ $inputFileName, 2 ];
$iconManifestFile       = FileNameJoin @ { $pacletDirectory, "Assets", "Icons.wxf" };
$displayFunctionsFile   = FileNameJoin @ { $pacletDirectory, "Assets", "DisplayFunctions.wxf" };
$coreExtensionsTarget   = FileNameJoin @ { $pacletDirectory, "FrontEnd", "Assets", "Extensions", "CoreExtensions.nb" };
$styleSheetTarget       = FileNameJoin @ { $pacletDirectory, "FrontEnd", "StyleSheets", "Chatbook.nb" };
$floatStyleSheetTarget  = FileNameJoin @ { $pacletDirectory, "FrontEnd", "StyleSheets", "Wolfram", "WorkspaceChat.nb" };



(* ::Subsection::Closed:: *)
(*Load Paclet*)


PacletDirectoryLoad @ $pacletDirectory;
Get[ "Wolfram`Chatbook`" ];


(* ::Section::Closed:: *)
(*Resources*)


(* ::Subsection::Closed:: *)
(*tr*)


tr[ name_?StringQ ] := Dynamic[ FEPrivate`FrontEndResource[ "ChatbookStrings", name ] ]
trBox[ name_?StringQ ] := DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookStrings", name ] ]


(* ::Subsection::Closed:: *)
(*$floatingButtonNinePatch*)


$floatingButtonNinePatch = Import @ FileNameJoin @ { $ninePatchDirectory, "FloatingButtonGrid.wxf" };


(* ::Subsection::Closed:: *)
(*Drop Shadows*)

$dropShadowConfig = <|
    "CenterColor"     -> GrayLevel[ 0.95 ],
    "FrameColor"      -> GrayLevel[ 0.85 ],
    "FrameThickness"  -> 1,
    "Offset"          -> { 0, -2 },
    "Radius"          -> 10,
    "ShadowColor"     -> GrayLevel[ 0.5, 0.5 ],
    "ShadowIntensity" -> 0.4
|>;


$dropShadowPaneBox := $dropShadowPaneBox =
    With[ { img = createNinePatch @ $dropShadowConfig },
        Function[
            PaneBox[
                PanelBox[
                    #,
                    Appearance     -> img,
                    ContentPadding -> False,
                    FrameMargins   -> { { 0, 0 }, { 0, 0 } }
                ],
                ImageMargins -> { { 40, 50 }, { 0, 0 } }
            ]
        ]
    ];


(* ::Subsubsection::Closed:: *)
(*createNinePatch*)


createNinePatch[ config_ ] := set9PatchPixels[ createBaseImage @ config, config ];


(* ::Subsubsection::Closed:: *)
(*set9PatchPixels*)


set9PatchPixels[ image_, config: KeyValuePattern[ "Offset" -> { oh_, ov_ } ] ] :=
    Module[ { padded, w, h },
        padded = ImagePad[ image, 1, White ];
        { w, h } = ImageDimensions @ padded;
        toByteImage @ ReplacePixelValue[
            padded,
            {
                { Ceiling[ w / 2 ] - oh, 1 },
                { Ceiling[ w / 2 ] - oh, h },
                { 1, Ceiling[ h / 2 ] - ov },
                { w, Ceiling[ h / 2 ] - ov }
            } -> Black
        ]
    ];


(* ::Subsubsection::Closed:: *)
(*createBaseImage*)


createBaseImage[ config: KeyValuePattern @ { "ShadowColor" -> shadowColor_ } ] :=
    With[ { alpha = createAlphaMask @ config },
        setFramePixels[ SetAlphaChannel[ ConstantImage[ shadowColor, ImageDimensions @ alpha ], alpha ], config ]
    ];


(* ::Subsubsection::Closed:: *)
(*toByteImage*)


toByteImage[ img_ ] := Image[
    NumericArray[ Round @ Clip[ 255 * ImageData @ ColorConvert[ img, "RGB" ], { 0, 255 } ], "UnsignedInteger8" ],
    "Byte",
    ColorSpace      -> "RGB",
    Interleaving    -> True,
    ImageResolution -> 72
];


(* ::Subsubsection::Closed:: *)
(*createAlphaMask*)


createAlphaMask[ config: KeyValuePattern @ { "Radius" -> radius_, "ShadowIntensity" -> shadowIntensity_ } ] :=
    setFramePixels[
        Image[ shadowIntensity * Rescale @ GaussianMatrix @ { radius, 0.4 * radius } ],
        <| config, "FrameColor" -> White, "CenterColor" -> Black |>
    ];


(* ::Subsubsection::Closed:: *)
(*setFramePixels*)


setFramePixels[
    image_,
    KeyValuePattern @ {
        "CenterColor"    -> centerColor_,
        "FrameColor"     -> frameColor_,
        "FrameThickness" -> frameThickness_,
        "Offset"         -> { oh_, ov_ },
        "Radius"         -> radius_
    }
] :=
    With[ { r = radius, ft = frameThickness },
        ReplacePixelValue[
            ReplacePixelValue[
                image,
                { r - ft - oh + 1 ;; r + ft - oh + 1, r - ft - ov + 1 ;; r + ft - ov + 1 } -> frameColor
            ],
            { r - oh + 1, r - ov + 1 } -> centerColor
        ]
    ];


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
    makeIconTemplateBoxStyle[
        file,
        func,
        ToBoxes @ func[ $$slot1, $$slot2, $$slot3 ] /. {
            ToBoxes @ $$slot1 -> $$slot1,
            ToBoxes @ $$slot2 -> $$slot2,
            ToBoxes @ $$slot3 -> $$slot3
        } /. {
            $$slot1 -> $$slot[ 1 ],
            $$slot2 -> $$slot[ 2 ],
            $$slot3 -> $$slot[ 3 ]
        } /. {
            $$slot -> Slot
        }
    ];

makeIconTemplateBoxStyle[ file_, icon_ ] :=
    makeIconTemplateBoxStyle[ file, icon, ToBoxes @ icon ];

makeIconTemplateBoxStyle[ file_, icon_, boxes_ ] :=
    Cell[ StyleData @ FileBaseName @ file, TemplateBoxOptions -> { DisplayFunction -> (boxes &) } ];



(* ::Subsection::Closed:: *)
(*$excludeMenuItem*)


$excludeMenuItem = MenuItem[
    "StylesheetContextMenuIncludeExclude",
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


(* Note:
    MenuItem cannot have Dynamic or FEPrivate`FrontEndResource expressions as its first argument.
    Maybe this is a bug, but a workaround is to use ContextMenu -> Dynamic[Function[...][args]].
    The purpose of the Function is to inject resolved versions of FEPrivate`FrontEndResource.
    Said differently, MenuItem can only take a String as its first argument, so we coerce the
    FrontEnd to first resolve the string resources before it tries to resolve the ContextMenu. *)

contextMenu[name_String] := FEPrivate`FrontEndResource[ "ContextMenus", name ]
contextMenu[ a___, name_String, b___ ] := contextMenu[ a, FEPrivate`FrontEndResource[ "ContextMenus", name ], b ];
contextMenu[ a : (_List | _FEPrivate`FrontEndResource).. ] := With[ { slot = Slot },
    Replace[
        Reap @ Module[ { i = 1 },
            Replace[
                FEPrivate`Join[ a ],
                MenuItem[ s_String, rest__ ] :> ( Sow[ FEPrivate`FrontEndResource[ "ChatbookStrings", s ] ]; MenuItem[ slot[ i++ ], rest ] ),
                { 2 }
            ]
        ],
        { menu_FEPrivate`Join, { { resourceStrings__ } } } :> Dynamic[ Function[ menu ][ resourceStrings ] ]
    ]
]


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
                            tr[ "StylesheetAssistantMenuInitializerButtonTooltip" ]
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



$feedbackButtonsV := Column[ { feedbackButton @ True, feedbackButton @ False }, Spacings -> { 0, { 0, 0.25, 0 } } ];
$feedbackButtonsH := Grid[ { { feedbackButton @ True, feedbackButton @ False } }, Spacings -> 0.2 ];

feedbackButton[ True  ] := feedbackButton[ True , "ThumbsUp"   ];
feedbackButton[ False ] := feedbackButton[ False, "ThumbsDown" ];

feedbackButton[ positive: True|False, name_String ] :=
    Button[
        MouseAppearance[
            Tooltip[
                Mouseover[
                    Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", # ] ]&[ name<>"Inactive" ],
                    Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", # ] ]&[ name<>"Active" ]
                ],
                tr[ "StylesheetFeedbackButtonTooltip" ]
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

menuItem[ icon_, label_, Hold[ code_ ] ] :=
    Button[
        RawBoxes @ TemplateBox[ { ToBoxes @ icon, ToBoxes @ label }, "ChatMenuItem" ],
        code,
        Appearance -> $suppressButtonAppearance,
        Method     -> "Queued",
        Evaluator  -> Automatic
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
        Initialization   :> (
            cell = If[ $CloudEvaluation,
                       Wolfram`ChatNB`x; EvaluationCell[ ],
                       ParentCell @ EvaluationCell[ ]
                   ]
        ),
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


(*
The cell structures used by the cell insertion point cell in the 14.2 FE are
significantly different than in 14.1 and earlier FEs. Also note that 14.2 FEs
already have chat-related styles in its insertion menu, so this menu re-ordering
and additions won't be necessary starting in 14.2.

Because of that, when the code below is run in 14.2 or later FEs,
$cellInsertionPointCell will be set to Inherited. And the 14.1-specific code can
be very particular about what the boxes actually look like.
*)


$cellInsertionPointCell := $cellInsertionPointCell =
If[BoxForm`sufficientVersionQ[14.2], Inherited,
	ReplaceAll[
		reorderAndAddMenuItems[ FrontEndResource[ "FEExpressions", "CellInsertionMenu" ] ],
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
	    }
	]
]


reorderAndAddMenuItems[boxexpr_] :=
ReplaceAll[ boxexpr, ActionMenuBox[label_, items_, rest___] :>
	ActionMenuBox[
		label,
		Replace[items,
			{
				input:    (_ :> FrontEndTokenExecute[EvaluationNotebook[], "Style", "Input"]),
				Delimiter,
				washort:  (_ :> FrontEndTokenExecute[EvaluationNotebook[], "Style", "WolframAlphaShort"]),
				walong:   (_ :> FrontEndTokenExecute[EvaluationNotebook[], "Style", "WolframAlphaLong"]),
				ext:      (_ :> FrontEndTokenExecute[EvaluationNotebook[], "Style", "ExternalLanguage"]),
				Delimiter,
				text:     (_ :> FrontEndTokenExecute[EvaluationNotebook[], "Style", "Text"]),
				other:    (_ :> FrontEndTokenExecute[EvaluationNotebook[], "StyleOther"])
			}  :>
			{
				input,
				text,
				other,
				Delimiter,
				insertionPointMenuItem[ TemplateBox[ { }, "ChatInputIcon" ], trBox[ "StylesheetInsertionMenuChatInput" ], "'", "ChatInput" ],
				insertionPointMenuItem[ TemplateBox[ { }, "SideChatIcon" ], trBox[ "StylesheetInsertionMenuChatBreak" ], "~", "ChatDelimiter" ],
				Delimiter,
				washort,
				walong,
				ext
			}
		],
		rest
	]
]


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
(*$workspaceChatDockedCells*)


$workspaceChatDockedCells = {
    Cell[
        BoxData @ DynamicBox[
            ToBoxes[
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeWorkspaceChatDockedCell" ],
                StandardForm
            ],
            Initialization :> With[ { nbo = EvaluationNotebook[ ] },
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                    "AttachWorkspaceChatInput",
                    nbo,
                    If[ Cells[ nbo ] =!= { }, Bottom, Top ]
                ]
            ],
            TrackedSymbols :> { }
        ],
        CellFrame        -> 0,
        CellFrameMargins -> 0,
        CellMargins      -> { { -1, -5 }, { -1, -1 } },
        Magnification -> Dynamic[ AbsoluteCurrentValue[ EvaluationNotebook[ ], Magnification ] ]
    ]
};


(* ::Subsection::Closed:: *)
(*Stylesheet Version*)


$stylesheetVersion := $stylesheetVersion = StringJoin[
    PacletObject[ File[ $pacletDirectory ] ][ "Version" ],
    ".",
    ToString @ Round @ AbsoluteTime[ ]
];



(* ::Subsection::Closed:: *)
(*inlineResources*)


inlineResources[ expr_ ] := expr /. {
    HoldPattern @ $defaultChatbookSettings  :> RuleCondition @ $defaultChatbookSettings,
    HoldPattern @ $suppressButtonAppearance :> RuleCondition @ $suppressButtonAppearance,
    HoldPattern @ $discardedMaterialLabel   :> RuleCondition @ $discardedMaterialLabel
};



(* ::Subsection::Closed:: *)
(*$styleDataCells*)


$styleDataCells = inlineResources @ Cases[ Flatten @ ReadList @ $styleDataFile, _Cell ];


$workspaceStyleDataCells = inlineResources @ Cases[ Flatten @ ReadList @ $workspaceStyleDataFile, _Cell ];


(* ::Subsection::Closed:: *)
(*$templateBoxDisplayFunctions*)


$templateBoxDisplayFunctions = Association @ Cases[
    $styleDataCells,
    Cell[ StyleData[ name_String ], ___, TemplateBoxOptions -> KeyValuePattern[ DisplayFunction -> func_ ], ___ ] :>
        (name -> func)
];


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
(*$WorkspaceStylesheet*)


$WorkspaceStylesheet = Notebook[
    Flatten @ {
        Cell @ StyleData[ StyleDefinitions -> "Chatbook.nb" ],
        $workspaceStyleDataCells
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];



(* ::Section::Closed:: *)
(*BuildStylesheets*)


BuildStylesheets[                       ] := BuildStylesheets @ All;
BuildStylesheets[ All | Automatic       ] := BuildStylesheets @ $validStylesheetNames;
BuildStylesheets[ styles: { ___String } ] := AssociationMap[ BuildStylesheets, styles ];
BuildStylesheets[ "Chatbook"            ] := BuildChatbookStylesheet[ ];
BuildStylesheets[ "WorkspaceChat"       ] := BuildWorkspaceStylesheet[ ];
BuildStylesheets[ "CoreExtensions"      ] := BuildCoreExtensionsStylesheet[ ];

BuildStylesheets[ style_String ] := Failure[
    "UnknownStyle",
    <|
        "MessageTemplate"   -> "Unknown style: `1`. Valid styles are `2`.",
        "MessageParameters" -> { style, $validStylesheetNames }
    |>
];

BuildStylesheets[ other___ ] := Failure[
    "InvalidArguments",
    <|
        "MessageTemplate"   -> "Invalid arguments for BuildStylesheets: `1`. Expected a list of style names or All.",
        "MessageParameters" -> { { other } }
    |>
];


$validStylesheetNames = { "Chatbook", "CoreExtensions", "WorkspaceChat" };

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
            CompileTemplateData[ ];
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
(*BuildWorkspaceStylesheet*)


BuildWorkspaceStylesheet[ ] := BuildWorkspaceStylesheet @ $floatStyleSheetTarget;

BuildWorkspaceStylesheet[ target_ ] :=
    Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } },
        Module[ { exported },
            exported = Export[ target, fixContexts @ $WorkspaceStylesheet, "NB" ];
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


(* CoreExtensions.nb is a 14.2 feature. It is ignored entirely by 14.1. *)
BuildCoreExtensionsStylesheet[ ] := BuildCoreExtensionsStylesheet @ $coreExtensionsTarget;

revisedCoreExtensions[ ] :=
Module[ { excludedCoreExtensions },
    (* These styles are excluded because they are appended to Core and Core already contains them,
        or we needed to rename and modify the original versions and we want to avoid cluttering Core. *)
    excludedCoreExtensions = Alternatives[
        "InlineFormula",
        "InlineReferenceText",
        "Input",
        "Link",
        "Message",
        "Notebook",
        "Output",
        "Text"
    ];

    Replace[
        DeleteCases[ Flatten @ $styleDataCells, Cell[ StyleData[ excludedCoreExtensions, ___ ], ___ ] ],
        Cell[ sd:StyleData[ "ChatInput", ___ ], a___, CellEventActions -> b_List, c___ ] :>
            Cell[ sd, a, CellEventActions -> DeleteCases[ b, _[ "MouseEntered" | "MouseExited", _ ] ], c ],
        1]
]

BuildCoreExtensionsStylesheet[ target_ ] :=
    Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } },
        Module[ { exported },
            CompileTemplateData[ ];
            exported =
                Export[
                    target,
                    fixContexts @
                        Notebook[
                            Flatten @ { Cell[ "Chatbook Core.nb Extensions", "Title" ], revisedCoreExtensions[ ] },
                            StyleDefinitions -> "Default.nb" ],
                    "NB" ];
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
(*CompileTemplateData*)


CompileTemplateData[ ] := Developer`WriteWXFFile[ $displayFunctionsFile, fixContexts @ $templateBoxDisplayFunctions ];


(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
EndPackage[ ];
