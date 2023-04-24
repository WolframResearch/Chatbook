Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    TaggingRules -> <| "ChatNotebookSettings" -> $defaultChatbookSettings |>,

    CellTrayWidgets -> <|
        "ChatWidget" -> <|
            "Type"    -> "Focus",
            "Content" -> Cell[ BoxData @ TemplateBox[ { }, "ChatWidgetButton" ], "ChatWidget" ]
        |>
    |>,

    CellEpilog :> With[ { $CellContext`cell = EvaluationCell[ ] },
        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Send", $CellContext`cell ]
    ],

    ComponentwiseContextMenu -> <|
        "CellBracket" -> contextMenu[ $askMenuItem, $excludeMenuItem, Delimiter, "CellBracket" ],
        "CellGroup"   -> contextMenu[ $excludeMenuItem, Delimiter, "CellGroup" ],
        "CellRange"   -> contextMenu[ $excludeMenuItem, Delimiter, "CellRange" ]
    |>
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatExcluded*)
Cell[
    StyleData[ "ChatExcluded" ],
    CellTrayWidgets     -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CellBracketOptions  -> { "Color" -> Pink },
    GeneratedCellStyles -> {
        "Message"        -> { "Message" , "MSG", "ChatExcluded" },
        "Graphics"       -> { "Graphics"       , "ChatExcluded" },
        "Output"         -> { "Output"         , "ChatExcluded" },
        "Print"          -> { "Print"          , "ChatExcluded" },
        "PrintTemporary" -> { "PrintTemporary" , "ChatExcluded" }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text*)
Cell[
    StyleData[ "Text" ],
    Evaluatable -> True,
    CellEvaluationFunction -> Function[
        If[ TrueQ @ CloudSystem`$CloudNotebooks,
            With[ { $CellContext`cell = EvaluationCell[ ] },
                Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "Send", $CellContext`cell ]
            ],
            Null
        ]
    ],
    ContextMenu -> contextMenu[ $askMenuItem, Delimiter, "Text" ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FramedChatCell*)
Cell[
    StyleData[ "FramedChatCell", StyleDefinitions -> StyleData[ "Text" ] ],
    AutoQuoteCharacters      -> { },
    CellFrame                -> 2,
    CellFrameColor           -> RGBColor[ "#ecf0f5" ],
    CellFrameMargins         -> { { 12, 25 }, { 8, 8 } },
    PasteAutoQuoteCharacters -> { },
    ShowCellLabel            -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInput*)
Cell[
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    MenuSortingValue  -> 1000,
    CellGroupingRules -> "InputGrouping",
    CellFrameColor    -> RGBColor[ "#a3c9f2" ],
    CellMargins       -> { { 66, 25 }, { 5, 8 } },
    CellDingbat       -> Cell[
        BoxData @ RowBox[{
            TemplateBox[{}, "ChatCounterLabel"],
            TemplateBox[{}, "ChatUserIcon"]
        }],
        Background -> None
    ],
    CounterIncrements -> {"ChatInputCount"},
    StyleKeyMapping   -> { " " -> "Text", "*" -> "Item", "'" -> "ChatQuery", "Backspace" -> "Input" },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#d1d9ea" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "'" -> "ChatSystemInput", "Backspace" -> "ChatInput" },
    CellFrameColor   -> RGBColor[ "#a3c9f2" ],
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatQueryIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#d1d9ea" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatSystemInput*)
Cell[
    StyleData[ "ChatSystemInput", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    CellFrame        -> 1,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "'" -> "ChatContextDivider", "Backspace" -> "ChatQuery" },
    CellFrameColor   -> RGBColor[ "#a3c9f2" ],
    CellFrameStyle   -> Dashing @ { Small, Small },
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatSystemIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#d1d9ea" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    Background          -> RGBColor[ "#fcfdff" ],
    CellAutoOverwrite   -> True,
    CellDingbat         -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIcon" ], Background -> None ],
    CellElementSpacings -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    CellGroupingRules   -> "OutputGrouping",
    CellMargins         -> { { 66, 25 }, { 12, 5 } },
    GeneratedCell       -> True,
    LineSpacing         -> { 1.1, 0, 2 },
    ShowAutoSpellCheck  -> False,
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatOutput", RGBColor[ "#ecf0f5" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatContextDivider*)
Cell[
    StyleData[ "ChatContextDivider", StyleDefinitions -> StyleData[ "Section" ] ],
    CellGroupingRules   -> { "SectionGrouping", 30 },
    ShowCellLabel       -> False,
    CellMargins         -> { { 66, 25 }, { Inherited, Inherited } },
    CellFrame           -> { { 0, 0 }, { 0, 8 } },
    CellFrameColor      -> GrayLevel[ 0.74902 ],
    DefaultNewCellStyle -> "Input",
    FontColor           -> GrayLevel[ 0.2 ],
    FontWeight          -> "DemiBold",
    CounterAssignments  -> {{"ChatInputCount", 0}},
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,

    StyleKeyMapping -> {
        "~" -> "ChatDelimiter",
        "'" -> "ChatInput",
        "=" -> "WolframAlphaShort",
        "*" -> "Item",
        ">" -> "ExternalLanguageDefault"
    },

    menuInitializer[ "ChatSection", GrayLevel[ 0.925 ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatDelimiter*)
Cell[
    StyleData[ "ChatDelimiter" ],
    CellTrayWidgets        -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    Background             -> GrayLevel[ 0.95 ],
    CellElementSpacings    -> { "CellMinHeight" -> 6 },
    CellFrameMargins       -> { { 20, 20 }, { 2, 2 } },
    CellGroupingRules      -> { "SectionGrouping", 62 },
    CellMargins            -> { { 0, 0 }, { 10, 10 } },
    DefaultNewCellStyle    -> "Input",
    FontSize               -> 6,
    ShowCellLabel          -> False,
    CounterAssignments     -> {{"ChatInputCount", 0}},

    CellEventActions -> {
        "KeyDown" :> Switch[
            CurrentValue[ "EventKey" ],
            "UpArrow"|"LeftArrow", SelectionMove[ EvaluationCell[ ], Before, Cell ],
            "~", (
                NotebookWrite[ EvaluationCell[ ], Cell[ "", "ChatContextDivider" ], All ];
                SelectionMove[ EvaluationNotebook[ ], Before, CellContents ];
            ),
            _, SelectionMove[ EvaluationCell[ ], After, Cell ]
        ]
    },

    CellFrameLabels -> {
        {
            None,
            Cell[
                BoxData @ TemplateBox[ { "ChatSection", GrayLevel[ 0.925 ] }, "ChatMenuButton" ],
                "ChatMenu",
                Background -> None
            ]
        },
        { None, None }
    },

    Initialization :> NotebookDelete @ Cells[ EvaluationCell[ ], AttachedCell -> True, CellStyle -> "ChatMenu" ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input*)
Cell[
    StyleData[ "Input" ],
    StyleKeyMapping -> {
        "~" -> "ChatDelimiter",
        "'" -> "ChatInput",
        "=" -> "WolframAlphaShort",
        "*" -> "Item",
        ">" -> "ExternalLanguageDefault"
    },
    ContextMenu -> contextMenu[ $askMenuItem, Delimiter, "Input" ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Output*)
Cell[
    StyleData[ "Output" ],
    ContextMenu -> contextMenu[ $askMenuItem, Delimiter, "Output" ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Link*)
Cell[
    StyleData[ "Link" ],
    FontFamily -> "Source Sans Pro",
    FontColor  -> Dynamic @
        If[ CurrentValue[ "MouseOver" ],
            RGBColor[ 0.855, 0.396, 0.145 ],
            RGBColor[ 0.020, 0.286, 0.651 ]
        ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TextRefLink*)
Cell[
    StyleData[ "TextRefLink" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            TagBox[
                ButtonBox[
                    StyleBox[ #1, ShowStringCharacters -> True, FontFamily -> "Source Sans Pro" ],
                    BaseStyle      -> "Link",
                    ButtonData     -> #2,
                    ContentPadding -> False
                ],
                MouseAppearanceTag[ "LinkHand" ]
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*InlineFormula*)
Cell[
    StyleData[ "InlineFormula" ],
    AutoSpacing         -> True,
    ButtonBoxOptions    -> { Appearance -> { Automatic, None } },
    FontFamily          -> "Source Sans Pro",
    FontSize            -> 1.0 * Inherited,
    FractionBoxOptions  -> { BaseStyle -> { SpanMaxSize -> Automatic } },
    HyphenationOptions  -> { "HyphenationCharacter" -> "\[Continuation]" },
    LanguageCategory    -> "Formula",
    ScriptLevel         -> 1,
    SingleLetterItalics -> False,
    SpanMaxSize         -> 1,
    StyleMenuListing    -> None,
    GridBoxOptions      -> {
        GridBoxItemSize -> {
            "Columns"        -> { { Automatic } },
            "ColumnsIndexed" -> { },
            "Rows"           -> { { 1.0 } },
            "RowsIndexed"    -> { }
        }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatWidgetButton*)
Cell[
    StyleData[ "ChatWidgetButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            Evaluate @ ToBoxes @ Button[
                MouseAppearance[
                    Tooltip[ RawBoxes @ TemplateBox[ { }, "ChatWidgetIcon" ], "Send to AI Assistant" ],
                    "LinkHand"
                ],
                With[ { $CellContext`cell = ParentCell @ EvaluationCell[ ] },
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "WidgetSend", $CellContext`cell ]
                ],
                Appearance -> $suppressButtonAppearance
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Output Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCodeBlock*)
Cell[
    StyleData[ "ChatCodeBlock" ],
    Background -> GrayLevel[ 1 ]
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCode*)
Cell[
    StyleData[ "ChatCode", StyleDefinitions -> StyleData[ "Input" ] ],
    Background           -> GrayLevel[ 1 ],
    FontSize             -> 14,
    FontWeight           -> "Plain",
    LanguageCategory     -> "Input",
    ShowAutoStyles       -> True,
    ShowStringCharacters -> True,
    ShowSyntaxStyles     -> True
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCodeActive*)
Cell[
    StyleData[ "ChatCodeActive", StyleDefinitions -> StyleData[ "ChatCode" ] ],
    ShowAutoStyles -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCodeBlockTemplate*)
Cell[
    StyleData[ "ChatCodeBlockTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ FrameBox[
            #,
            Background   -> GrayLevel[ 1 ],
            FrameMargins -> { { 10, 10 }, { 6, 6 } },
            FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
            ImageMargins -> { { 0, 0 }, { 8, 8 } },
            ImageSize    -> { Full, Automatic }
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCodeInlineTemplate*)
Cell[
    StyleData[ "ChatCodeInlineTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ FrameBox[
            #1,
            Background       -> GrayLevel[ 1 ],
            BaselinePosition -> Scaled[ 0.275 ],
            FrameMargins     -> { { 3, 3 }, { 2, 2 } },
            FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
            ImageMargins     -> { { 0, 0 }, { 0, 0 } }
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Menus*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuButton*)
Cell[
    StyleData[ "ChatMenuButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ TagBox[
            PaneSelectorBox[
                {
                    False -> FrameBox[
                        ButtonBox[
                            TemplateBox[ { }, "ChatMenuIcon" ],
                            ButtonFunction :> With[ { $CellContext`cell = EvaluationCell[ ] },
                                Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", #1, $CellContext`cell ]
                            ],
                            Appearance -> $suppressButtonAppearance,
                            Evaluator  -> Automatic,
                            Method     -> "Preemptive"
                        ],
                        RoundingRadius -> 3,
                        FrameStyle     -> GrayLevel[ 1, 0 ],
                        Background     -> None,
                        FrameMargins   -> 0,
                        ContentPadding -> False,
                        StripOnInput   -> False
                    ],
                    True -> FrameBox[
                        ButtonBox[
                            TemplateBox[ { }, "ChatMenuIcon" ],
                            ButtonFunction :> With[ { $CellContext`cell = EvaluationCell[ ] },
                                Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", #1, $CellContext`cell ]
                            ],
                            Appearance -> $suppressButtonAppearance,
                            Evaluator  -> Automatic,
                            Method     -> "Preemptive"
                        ],
                        RoundingRadius -> 3,
                        FrameStyle     -> GrayLevel[ 1, 0 ],
                        Background     -> #2,
                        FrameMargins   -> 0,
                        ContentPadding -> False,
                        StripOnInput   -> False
                    ]
                },
                Dynamic @ CurrentValue[ "MouseOver" ],
                ImageSize    -> Automatic,
                FrameMargins -> 0
            ],
            MouseAppearanceTag[ "LinkHand" ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuItemToolbarIcon*)
Cell[
    StyleData[ "ChatMenuItemToolbarIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            PaneBox[
                DynamicBox @ FEPrivate`FrontEndResource[ "NotebookToolbarExpressions", # ],
                ImageSize       -> { 16, 16 },
                ImageSizeAction -> "ShrinkToFit"
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuItemDelimiter*)
Cell[
    StyleData[ "ChatMenuItemDelimiter" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            PaneBox[
                StyleBox[
                    GraphicsBox[
                        {
                            CapForm[ "Round" ],
                            GrayLevel[ 0.9 ],
                            AbsoluteThickness[ 1 ],
                            LineBox @ { { -1, 0 }, { 1, 0 } }
                        },
                        AspectRatio  -> Full,
                        ImageMargins -> { { 0, 0 }, { 2, 2 } },
                        ImagePadding -> { { 5, 5 }, { 0, 0 } },
                        ImageSize    -> { Full, 2 },
                        PlotRange    -> { { -1, 1 }, { -1, 1 } }
                    ],
                    LineIndent -> 0
                ],
                BaselinePosition -> Baseline,
                FrameMargins     -> 0,
                ImageMargins     -> 0,
                ImageSize        -> Full
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuItem*)
Cell[
    StyleData[ "ChatMenuItem" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ ButtonBox[
            TemplateBox[
                {
                    TagBox[
                        GridBox[
                            {
                                {
                                    #1,
                                    TemplateBox[ { 7 }, "Spacer1" ],
                                    PaneBox[
                                        StyleBox[ #2, "ChatMenuLabel" ],
                                        FrameMargins     -> 0,
                                        ImageMargins     -> 0,
                                        BaselinePosition -> Baseline,
                                        ImageSize        -> Full
                                    ]
                                }
                            },
                            GridBoxAlignment -> { "Columns" -> { { Left } }, "Rows" -> { { Top } } },
                            AutoDelete       -> False,
                            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings  -> { "Columns" -> { { 0 } } }
                        ],
                        "Grid"
                    ],
                    FrameStyle     -> None,
                    RoundingRadius -> 0,
                    FrameMargins   -> { { 5, 2 }, { 2, 2 } },
                    ImageSize      -> Full,
                    ImageMargins   -> { { 0, 0 }, { 0, 0 } },
                    Background     -> Dynamic @ If[ CurrentValue[ "MouseOver" ], GrayLevel[ 0.96 ], GrayLevel[ 1. ] ]
                },
                "Highlighted"
            ],
            ButtonFunction :> ReleaseHold @ #3,
            Appearance     -> $suppressButtonAppearance,
            Method         -> "Queued",
            Evaluator      -> Automatic
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatOutputMenu*)
Cell[
    StyleData[ "ChatOutputMenu" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ $chatOutputMenu
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Icons*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AssistantIcon*)
Cell[
    StyleData[ "AssistantIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "AssistantIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AssistantIconActive*)
Cell[
    StyleData[ "AssistantIconActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "AssistantIconActive" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatUserIcon*)
Cell[
    StyleData[ "ChatUserIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "ChatUserIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuIcon*)
Cell[
    StyleData[ "ChatMenuIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "ChatMenuIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatQueryIcon*)
Cell[
    StyleData[ "ChatQueryIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "ChatQueryIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatSystemIcon*)
Cell[
    StyleData[ "ChatSystemIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "ChatSystemIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MinimizedChat*)
Cell[
    StyleData[ "MinimizedChat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "MinimizedChat" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*MinimizedChatActive*)
Cell[
    StyleData[ "MinimizedChatActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "MinimizedChatActive" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatWidgetIcon*)
Cell[
    StyleData[ "ChatWidgetIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "ChatWidgetIcon" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*OpenAILogo*)
Cell[
    StyleData[ "OpenAILogo" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "OpenAILogo" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatMenuLabel*)
Cell[
    StyleData[ "ChatMenuLabel" ],
    FontColor       -> GrayLevel[ 0.2 ],
    FontFamily      -> "Source Sans Pro",
    FontSize        -> 13,
    FontWeight      -> Plain,
    LineBreakWithin -> False,
    LineIndent      -> 0
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCounterLabel*)
Cell[
    StyleData["ChatCounterLabel"],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ StyleBox[
            CounterBox["ChatInputCount"],
            FontFamily -> "Source Sans Pro",
            FontSize -> 10,
            FontColor -> GrayLevel[ 0.2 ],
            FontWeight -> Plain
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
