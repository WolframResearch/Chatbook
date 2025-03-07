(* ::Package:: *)

Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


(* ::Section::Closed:: *)
(*Resources*)


(* ::Subsection::Closed:: *)
(*tr*)


tr[name_?StringQ] := Dynamic[FEPrivate`FrontEndResource["ChatbookStrings", name]]


(* ::Section::Closed:: *)
(*Notebook*)


Cell[
    StyleData[ "Notebook" ],
    TaggingRules           -> <| "ChatNotebookSettings" -> <| |> |>,
    CellInsertionPointCell -> $cellInsertionPointCell,

    CellTrayWidgets -> <|
        "GearMenu"     -> <| "Condition" -> False |>,
        "ChatIncluded" -> <| "Condition" -> False, "Content" -> $includedCellWidget |>,
        "ChatWidget"   -> <|
            "Type"    -> "Focus",
            "Content" -> Cell[ BoxData @ TemplateBox[ { }, "ChatWidgetButton" ], "ChatWidget" ]
        |>
    |>,

    ComponentwiseContextMenu -> <|
        "CellBracket" -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellBracket" ],
        "CellGroup"   -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellGroup" ],
        "CellRange"   -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellRange" ]
    |>,

    PrivateCellOptions -> {
        "AccentStyle" -> {
            CellTrayWidgets -> <| "ChatIncluded" -> <| "Condition" -> True |> |>
        }
    }
]


Cell[
    StyleData[ "ChatStyleSheetInformation" ],
    TaggingRules -> <| "StyleSheetVersion" -> $stylesheetVersion |>
]



(* ::Section::Closed:: *)
(*Text*)


Cell[
    StyleData[ "NotebookAssistant`Text" ],
    ContextMenu -> contextMenu[ "Text" ],
    CellMargins -> { { 66, 10 }, { 7, 8 } },
    FontFamily -> "Source Sans Pro",
    FontSize -> 15,
    LineSpacing -> { 1, 3 },
    TabSpacings -> { 2.5 }
]



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
    CellEpilog :> With[ { $CellContext`cell = (FinishDynamic[ ]; EvaluationCell[ ]) },
        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AIAutoAssist", $CellContext`cell ]
    ]
]



(* ::Section::Closed:: *)
(*Output*)


Cell[
    StyleData[ "Output" ],
    CellTrayWidgets -> <| "GearMenu" -> <| "Condition" -> False |> |>
]



(* ::Section::Closed:: *)
(*Message*)


Cell[
    StyleData[ "Message" ],
    CellTrayWidgets -> <| "GearMenu" -> <| "Condition" -> False |> |>
]



(* ::Section::Closed:: *)
(*Chat Input Styles*)


(* ::Subsection::Closed:: *)
(*FramedChatCell*)


Cell[
    StyleData[ "FramedChatCell", StyleDefinitions -> StyleData[ "NotebookAssistant`Text" ] ],
    AutoQuoteCharacters      -> { },
    CellFrame                -> 2,
    CellFrameColor           -> RGBColor[ "#ecf0f5" ],
    CellFrameMargins         -> { { 12, 25 }, { 8, 8 } },
    PasteAutoQuoteCharacters -> { },
    ShowCellLabel            -> False,
    TaggingRules             -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Subsection::Closed:: *)
(*ChatInput*)


Cell[
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    CellFrameColor        -> RGBColor[ "#a3c9f2" ],
    CellFrameLabelMargins -> -32,
    CellGroupingRules     -> "InputGrouping",
    CellMargins           -> { { 66, 32 }, { 1, 8 } },
    CellTrayWidgets       -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements     -> { "ChatInputCount" },
    Evaluatable           -> True,
    MenuSortingValue      -> 1543,
    StyleKeyMapping       -> { "~" -> "ChatDelimiter", "'" -> "SideChat", "=" -> "WolframAlphaShort", "*" -> "Item" },
    TaggingRules          -> <| "ChatNotebookSettings" -> <| |> |>,
    CellFrameLabels -> {
        {
            None,
            Cell[
                BoxData[ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButton" ][ #1, #2, 20 ] ]&[ RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ] ] ],
                Background -> None
            ]
        },
        { None, None }
    },
	CellDingbat -> Cell[
        BoxData @ DynamicBox @ ToBoxes[
            If[ TrueQ @ CloudSystem`$CloudNotebooks,
                RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                RawBoxes @ TemplateBox[ { }, "ChatInputActiveCellDingbat" ]
            ],
            StandardForm
        ],
		Background -> None,
		CellFrame -> 0,
        CellMargins -> 0
	],
    CellEvaluationFunction -> Function @ With[ { $CellContext`cell = (FinishDynamic[ ]; EvaluationCell[ ]) },
        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "EvaluateChatInput", $CellContext`cell ]
    ],
    CellEventActions -> {
        (* Insert persona prompt input template: *)
        { "KeyDown", "@" } :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "InsertInlineReference", "PersonaTemplate", $CellContext`cell ]
        ]
        ,
        (* Insert function prompt input template: *)
        { "KeyDown", "!" } :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "InsertInlineReference", "FunctionTemplate", $CellContext`cell ]
        ]
        ,
        (* Insert modifier prompt input template: *)
        { "KeyDown", "#" } :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "InsertInlineReference", "ModifierTemplate", $CellContext`cell ]
        ]
        ,
        (* Insert WL code input template: *)
        { "KeyDown", "\\" } :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "InsertInlineReference", "WLTemplate", $CellContext`cell ]
        ]
        ,
        (* NOTE: MouseEntered/Exited actions are removed from the version of this style in CoreExtensions.nb, see StyleSheetBuilder.wl. *)
        (* Highlight cells that will be included in chat context: *)
        "MouseEntered" :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AccentIncludedCells", $CellContext`cell ]
        ]
        ,
        (* Remove cell highlights: *)
        "MouseExited" :> With[ { $CellContext`cell = EvaluationCell[ ] },
            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "RemoveCellAccents", $CellContext`cell ]
        ]
    }
]



(* ::Subsubsection::Closed:: *)
(*ChatInputActiveCellDingbat*)


Cell[
    StyleData[ "ChatInputActiveCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $chatInputActiveCellDingbat
    }
]



(* ::Subsubsection::Closed:: *)
(*ChatInputCellDingbat*)


Cell[
    StyleData[ "ChatInputCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $chatInputCellDingbat
    }
]



(* ::Subsection::Closed:: *)
(*SideChat*)


Cell[
    StyleData[ "SideChat", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue  -> 1544,
    Background        -> RGBColor[ "#fafcff" ],
    CellMargins       -> { { 79, 26 }, { Inherited, Inherited } },
    CellDingbatMargin -> 0,
    CellFrame         -> { { 0, 0 }, { 0, 2 } },
    CellFrameMargins  -> { { 0, Inherited }, { Inherited, Inherited } },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements -> { },
    StyleKeyMapping   -> { "~" -> "ChatDelimiter", "'" -> "ChatSystemInput", "Backspace" -> "ChatInput" },
    TaggingRules      -> <| "ChatNotebookSettings" -> <| "IncludeHistory" -> False |> |>,
    CellDingbat       -> Cell[
        BoxData @ RowBox @ {
            DynamicBox @ ToBoxes[
                If[ TrueQ @ CloudSystem`$CloudNotebooks,
                    RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                    RawBoxes @ TemplateBox[ { }, "ChatInputActiveCellDingbat" ]
                ],
                StandardForm
            ],
            TemplateBox[ { 12 }, "Spacer1" ]
        },
        CellFrame        -> { { 0, 0 }, { 0, 2 } },
        CellFrameColor   -> RGBColor[ "#a3c9f2" ],
        CellFrameMargins -> 6
    ]
]



(* ::Subsection::Closed:: *)
(*ChatQuery*)


Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    CellDingbat     -> Cell[ BoxData @ TemplateBox[ { }, "ChatQueryIcon" ], Background -> None ],
    CellFrameColor  -> RGBColor[ "#a3c9f2" ],
    CellTrayWidgets -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    StyleKeyMapping -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules    -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Subsection::Closed:: *)
(*ChatSystemInput*)


Cell[
    StyleData[ "ChatSystemInput", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    CellDingbat       -> Cell[ BoxData @ TemplateBox[ { }, "ChatSystemIcon" ], Background -> None ],
    CellFrame         -> 1,
    CellFrameColor    -> RGBColor[ "#a3c9f2" ],
    CellFrameStyle    -> Dashing @ { Small, Small },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements -> { },
    MenuSortingValue  -> 1545,
    StyleKeyMapping   -> { "~" -> "ChatDelimiter", "'" -> "ChatInput", "Backspace" -> "SideChat" },
    TaggingRules      -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Section::Closed:: *)
(*Chat Output Styles*)


(* ::Subsection::Closed:: *)
(*ChatOutput*)


Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    Background           -> RGBColor[ "#fcfdff" ],
    CellAutoOverwrite    -> True,
    CellDingbat          -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIcon" ], Background -> None ],
    CellElementSpacings  -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    CellGroupingRules    -> "OutputGrouping",
    CellMargins          -> { { 66, 25 }, { 12, 5 } },
    CodeAssistOptions    -> { "AutoDetectHyperlinks" -> False },
    GeneratedCell        -> True,
    Graphics3DBoxOptions -> { ImageSizeRaw -> { { 300 }, { 220 } } },
    GraphicsBoxOptions   -> { ImageSizeRaw -> { { 300 }, { 220 } } },
    LanguageCategory     -> None,
    LineSpacing          -> { 1.1, 0, 2 },
    ShowAutoSpellCheck   -> False,
    TaggingRules         -> <| "ChatNotebookSettings" -> <| |> |>,
    CellTrayWidgets      -> <|
        "ChatWidget"   -> <| "Visible" -> False |>,
        "ChatFeedback" -> <| "Content" -> Cell[ BoxData @ ToBoxes @ $feedbackButtonsV, "ChatFeedback" ] |>
    |>,
    menuInitializer[ "ChatOutput", RGBColor[ "#ecf0f5" ] ]
]



(* ::Subsection::Closed:: *)
(*AssistantOutput*)


Cell[
    StyleData[ "AssistantOutput", StyleDefinitions -> StyleData[ "ChatOutput" ] ],
    Background     -> RGBColor[ "#edf2f7" ],
    CellFrameColor -> RGBColor[ "#d0deec" ],
    assistantMenuInitializer[ "AssistantOutput", RGBColor[ "#d0deec" ] ]
]



(* ::Subsection::Closed:: *)
(*AssistantOutputWarning*)


Cell[
    StyleData[ "AssistantOutputWarning", StyleDefinitions -> StyleData[ "AssistantOutput" ] ],
    Background     -> RGBColor[ "#fdfaf4" ],
    CellFrameColor -> RGBColor[ "#f1e7de" ],
    assistantMenuInitializer[ "AssistantOutput", RGBColor[ "#f1e7de" ] ]
]



(* ::Subsection::Closed:: *)
(*AssistantOutputError*)


Cell[
    StyleData[ "AssistantOutputError", StyleDefinitions -> StyleData[ "AssistantOutput" ] ],
    Background     -> RGBColor[ "#fdf4f4" ],
    CellFrameColor -> RGBColor[ "#f1dede" ],
    assistantMenuInitializer[ "AssistantOutput", RGBColor[ "#f1dede" ] ]
]



(* ::Section::Closed:: *)
(*Chat Block Delimiters*)


(* ::Subsection::Closed:: *)
(*ChatBlockDivider*)


(*
    14.2 CoreExtensions: this had inherited from Section which is defined in Default.
    Instead, hard-code what we were inheriting from Default's definition. *)
Cell[
    StyleData[ "ChatBlockDivider" ],
    MenuSortingValue    -> 1546,
    CellFrame           -> { { 0, 0 }, { 0, 8 } },
    CellFrameColor      -> GrayLevel[ 0.74902 ],
    CellFrameMargins    -> 4,
    CellGroupingRules   -> { "SectionGrouping", 30 },
    CellMargins         -> { { 5, 25 }, { 8, 18 } },
    CellTrayWidgets     -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterAssignments  -> { { "ChatInputCount", 0 } },
    CounterIncrements   -> "Section",
    FontColor           -> GrayLevel[ 0.2 ],
    FontFamily          -> "Source Sans Pro",
    FontSize            -> 28,
    FontWeight          -> "DemiBold",
    LanguageCategory    -> "NaturalLanguage",
    LineSpacing         -> { 1, 2 },
    PageBreakBelow      -> False,
    ShowCellLabel       -> False,
    StyleKeyMapping     -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules        -> <| "ChatNotebookSettings" -> <| "ChatDelimiter" -> True |> |>,

    CellFrameLabels -> {
        {
            Cell[
                BoxData @ DynamicBox @ ToBoxes[
                    If[ TrueQ @ CloudSystem`$CloudNotebooks,
                        "",
                        RawBoxes @ TemplateBox[ { }, "ChatDelimiterCellDingbat" ]
                    ],
                    StandardForm
                ],
                "Text",
                Background           -> None,
                CellFrame            -> 0,
                CellMargins          -> 0,
                ShowStringCharacters -> False
            ],
            None
        },
        { None, None }
    }
]



(* ::Subsection::Closed:: *)
(*ChatDelimiter*)


Cell[
    StyleData[ "ChatDelimiter" ],
    MenuSortingValue    -> 1547,
    Background          -> GrayLevel[ 0.95 ],
    CellElementSpacings -> { "CellMinHeight" -> 6 },
    CellFrameMargins    -> { { 20, 20 }, { 2, 2 } },
    CellGroupingRules   -> { "SectionGrouping", 62 },
    CellMargins         -> { { 5, 0 }, { 10, 10 } },
    CellTrayWidgets     -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterAssignments  -> { { "ChatInputCount", 0 } },
    FontSize            -> 6,
    ShowCellLabel       -> False,
    StyleKeyMapping     -> { "~" -> "ChatBlockDivider", "'" -> "ChatInput" },
    TaggingRules        -> <| "ChatNotebookSettings" -> <| "ChatDelimiter" -> True |> |>,

    CellEventActions -> {
        "KeyDown" :> Switch[
            CurrentValue[ "EventKey" ],
            "UpArrow"|"LeftArrow", SelectionMove[ EvaluationCell[ ], Before, Cell ],
            "~", (
                NotebookWrite[ EvaluationCell[ ], Cell[ "", "ChatBlockDivider" ], All ];
                SelectionMove[ EvaluationNotebook[ ], Before, CellContents ];
            ),
            "'", (
                NotebookDelete @ Cells[ EvaluationCell[ ], AttachedCell -> True, CellStyle -> "ChatMenu" ];
                NotebookWrite[ EvaluationCell[ ], Cell[ "", "ChatInput" ], All ];
                SelectionMove[ EvaluationNotebook[ ], Before, CellContents ];
            ),
            _, SelectionMove[ EvaluationCell[ ], After, Cell ]
        ]
    },

    CellFrameLabels -> {
        {
            Cell[
                BoxData @ DynamicBox @ ToBoxes[
                    If[ TrueQ @ CloudSystem`$CloudNotebooks,
                        "",
                        RawBoxes @ TemplateBox[ { }, "ChatDelimiterCellDingbat" ]
                    ],
                    StandardForm
                ],
                Background           -> None,
                CellFrame            -> 0,
                CellMargins          -> 0,
                ShowStringCharacters -> False
            ],
            None
        },
        { None, None }
    },

    Initialization :> NotebookDelete @ Cells[ EvaluationCell[ ], AttachedCell -> True, CellStyle -> "ChatMenu" ]
]



(* ::Subsubsection::Closed:: *)
(*ChatDelimiterCellDingbat*)


Cell[
    StyleData[ "ChatDelimiterCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $chatDelimiterCellDingbat
    }
]



(* ::Section::Closed:: *)
(*Chat Output Formatting*)


(* ::Subsection::Closed:: *)
(*ChatCodeBlock*)


Cell[
    StyleData[ "ChatCodeBlock" ],
    Background -> GrayLevel[ 1 ]
]



(* ::Subsection::Closed:: *)
(*ChatCodeBlockButtonPanel*)


Cell[
    StyleData[ "ChatCodeBlockButtonPanel" ](* ,
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ PanelBox[
            #,
            Appearance   -> $floatingButtonNinePatch,
            ImageMargins -> 0
        ]
    } *)
]



(* ::Subsection::Closed:: *)
(*ChatPreformatted*)


(*
    14.2 CoreExtensions: this had inherited from Program which is defined in Default.
    Instead, hard-code what we were inheriting from Default's definition. *)
Cell[
    StyleData[ "ChatPreformatted" ],
    AutoQuoteCharacters      -> { },
    Background               -> GrayLevel[ 1 ],
    CellFrame                -> None,
    CellMargins              -> { { 66, 10 }, { 8, 8 } },
    CodeAssistOptions        -> { "AutoDetectHyperlinks" -> False },
    FontFamily               -> Dynamic[ AbsoluteCurrentValue[ { StyleHints, "CodeFont" } ] ],
    FontSize                 -> 13,
    FontWeight               -> "Plain",
    Hyphenation              -> False,
    LanguageCategory         -> "Formula",
    PasteAutoQuoteCharacters -> { },
    ScriptLevel              -> 1,
    ShowStringCharacters     -> True,
    StripStyleOnPaste        -> True
]



(* ::Subsection::Closed:: *)
(*ChatCodeActive*)


Cell[
    StyleData[ "ChatCodeActive", StyleDefinitions -> StyleData[ "Input" ] ],
    CodeAssistOptions -> { "AutoDetectHyperlinks" -> False },
    FontSize          -> 13,
    ShowAutoStyles    -> False
]



(* ::Subsection::Closed:: *)
(*ChatCodeBlockTemplate*)


Cell[
    StyleData[ "ChatCodeBlockTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @
        GridBox[
            {
                {
                    FrameBox[
                        #1,
                        Background   -> GrayLevel[ 1 ],
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ] },
                {
                    FrameBox[
                        DynamicBox[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ #1, #2 ] ],
                        Background   -> RGBColor[ 0.98824, 0.99216, 1. ],
                        FrameMargins -> { { 7, 2 }, { 2, 2 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
                        ImageMargins -> { { 0, 0 }, { 8, -1 } }, (* negative margin to barely overlap the frame above *)
                        ImageSize    -> { Full, Automatic }
                    ] }
            },
            DefaultBaseStyle -> "Column",
            GridBoxAlignment -> { "Columns" -> { { Left } } },
            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxSpacings -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
        ]
    }
]



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
            ImageMargins     -> { { 0, 0 }, { 0, 0 } },
            BaseStyle        -> { "InlineCode", AutoSpacing -> False, AutoMultiplicationSymbol -> False }
        ]
    }
]



(* ::Subsection::Closed:: *)
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



(* ::Subsection::Closed:: *)
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



(* ::Subsection::Closed:: *)
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



(* ::Section::Closed:: *)
(*Chat Menus*)


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
                            AbsoluteThickness[ 2 ],
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
                            GridBoxAlignment -> { "Columns" -> { { Left } }, "Rows" -> { { Baseline } } },
                            AutoDelete       -> False,
                            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings  -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
                        ],
                        "Grid"
                    ],
                    FrameStyle     -> Dynamic @ If[ CurrentValue[ "MouseOver" ], GrayLevel[ 0.8 ], GrayLevel[ 0.98 ] ],
                    RoundingRadius -> 0,
                    FrameMargins   -> { { 5, 2 }, { 2, 2 } },
                    ImageSize      -> Full,
                    ImageMargins   -> { { 0, 0 }, { 0, 0 } },
                    Background     -> Dynamic @ If[ CurrentValue[ "MouseOver" ], GrayLevel[ 1 ], GrayLevel[ 0.98 ] ]
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



(* ::Subsection::Closed:: *)
(*ChatMenuSection*)


Cell[
    StyleData[ "ChatMenuSection" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ TemplateBox[
            {
                TagBox[
                    GridBox[
                        {
                            {
                                PaneBox[
                                    StyleBox[ #1, "ChatMenuSectionLabel" ],
                                    FrameMargins     -> 0,
                                    ImageMargins     -> 0,
                                    BaselinePosition -> Baseline,
                                    ImageSize        -> Full
                                ]
                            }
                        },
                        GridBoxAlignment -> { "Columns" -> { { Left } }, "Rows" -> { { Baseline } } },
                        AutoDelete       -> False,
                        GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                        GridBoxSpacings  -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
                    ],
                    "Grid"
                ],
                Background     -> GrayLevel[ 0.937 ],
                FrameMargins   -> { { 5, 2 }, { 2, 2 } },
                FrameStyle     -> None,
                ImageMargins   -> { { 0, 0 }, { 0, 0 } },
                ImageSize      -> Full,
                RoundingRadius -> 0
            },
            "Highlighted"
        ]
    }
]



(* ::Subsection::Closed:: *)
(*ChatOutputMenu*)


Cell[
    StyleData[ "ChatOutputMenu" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ $chatOutputMenu
    }
]



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



(* ::Subsection::Closed:: *)
(*ChatMenuSectionLabel*)


Cell[
    StyleData[ "ChatMenuSectionLabel", StyleDefinitions -> StyleData[ "ChatMenuLabel" ] ],
    FontSize  -> 13,
    FontColor -> GrayLevel[ 0.35 ]
]



(* ::Section::Closed:: *)
(*Icons*)


makeIconTemplateBoxStyle /@ FileNames[ "*.wl", $iconDirectory ]



(* ::Subsection::Closed:: *)
(*ChatOutputStopButtonWrapper*)


Cell[
    StyleData[ "ChatOutputStopButtonWrapper" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ OverlayBox[
            {
                #1,
                PaneSelectorBox[
                    {
                        False -> " ",
                        True  -> TemplateBox[ { }, "ChatOutputStopButton" ]
                    },
                    Dynamic @ CurrentValue[ "MouseOver" ],
                    ImageSize    -> All,
                    FrameMargins -> 0
                ]
            },
            { 1, 2 },
            2,
            Alignment -> { Right, Top }
        ]
    }
]



(* ::Subsection::Closed:: *)
(*ChatOutputStopButtonProgressWrapper*)


Cell[
    StyleData[ "ChatOutputStopButtonProgressWrapper" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ OverlayBox[
            {
                #1,
                PaneSelectorBox[
                    {
                        False -> PaneBox[
                            (* FIXME: add a white background to progress indicator *)
                            InterpretationBox[
                                DynamicBox @ FEPrivate`FrontEndResource[ "FEExpressions", "NecklaceAnimator" ][ Tiny ],
                                ProgressIndicator[ Appearance -> "Necklace", ImageSize -> Tiny ],
                                BaseStyle -> { "Deploy" }
                            ],
                            ImageSize -> { 33, Automatic },
                            Alignment -> Left
                        ],
                        True -> TemplateBox[ { }, "ChatOutputStopButton" ]
                    },
                    Dynamic @ CurrentValue[ "MouseOver" ],
                    ImageSize    -> All,
                    FrameMargins -> 0
                ]
            },
            { 1, 2 },
            2,
            Alignment -> { Right, Top }
        ]
    }
]



(* ::Subsection::Closed:: *)
(*AssistantIconTabbed*)


Cell[
    StyleData[ "AssistantIconTabbed" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ tabbedChatOutputCellDingbat @ #
    }
]


(* ::Section::Closed:: *)
(*Inline Chat Styles*)


(* ::Subsection::Closed:: *)
(*MessageAuthorLabel*)


Cell[
    StyleData[ "MessageAuthorLabel", StyleDefinitions -> StyleData[ "NotebookAssistant`Text" ] ],
    FontSize             -> 14,
    FontWeight           -> "DemiBold",
    ShowStringCharacters -> False
]


(* ::Subsection::Closed:: *)
(*UserMessageLabel*)


Cell[
    StyleData[ "UserMessageLabel" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ PaneBox[
            #,
            BaseStyle    -> { "MessageAuthorLabel" },
            ImageSize    -> { Scaled[ 1 ], Automatic },
            Alignment    -> Right,
            FrameMargins -> { { 0, 11 }, { 0, 0 } }
        ]
    }
]


(* ::Subsection::Closed:: *)
(*AssistantMessageLabel*)


Cell[
    StyleData[ "AssistantMessageLabel" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ PaneBox[
            #,
            BaseStyle    -> { "MessageAuthorLabel" },
            ImageSize    -> { Scaled[ 1 ], Automatic },
            Alignment    -> Left,
            FrameMargins -> { { 11, 0 }, { 0, 0 } }
        ]
    }
]


(* ::Subsection::Closed:: *)
(*UserMessageBox*)


Cell[
    StyleData[ "UserMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ PaneBox[
            FrameBox[
                #,
                BaseStyle      -> { "Text", Editable -> False, Selectable -> False },
                Background     -> RGBColor[ "#edf4fc" ],
                FrameMargins   -> { { 8, 15 }, { 8, 8 } },
                FrameStyle     -> RGBColor[ "#a3c9f2" ],
                RoundingRadius -> 10,
                StripOnInput   -> False
            ],
            Alignment -> Right,
            ImageSize -> { Full, Automatic }
        ]
    }
]


(* ::Subsection::Closed:: *)
(*AssistantMessageBox*)


Cell[
    StyleData[ "AssistantMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ TagBox[
            FrameBox[
                #,
                BaseStyle      -> { "Text", Editable -> False, Selectable -> False },
                Background     -> RGBColor[ "#fcfdff" ],
                FrameMargins   -> { { 15, 8 }, { 8, 8 } },
                FrameStyle     -> RGBColor[ "#c9ccd0" ],
                ImageSize      -> { Scaled[ 1 ], Automatic },
                RoundingRadius -> 10,
                StripOnInput   -> False
            ],
            EventHandlerTag @ {
                "MouseEntered" :>
                    With[ { cell = EvaluationCell[ ] },
                        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AttachAssistantMessageButtons", cell ]
                    ],
                Method         -> "Preemptive",
                PassEventsDown -> Automatic,
                PassEventsUp   -> True
            }
        ]
    }
]


Cell[
    StyleData[ "FeedbackButtonsHorizontal" ],
    TemplateBoxOptions -> { DisplayFunction -> Function @ Evaluate @ ToBoxes @ $feedbackButtonsH }
]



(* ::Subsection::Closed:: *)
(*InlineItem*)


Cell[
    StyleData[ "InlineItem" ],
    ParagraphIndent -> -10
]



(* ::Subsection::Closed:: *)
(*InlineSubitem*)


Cell[
    StyleData[ "InlineSubitem" ],
    ParagraphIndent -> -16
]



(* ::Subsection::Closed:: *)
(*DropShadowPaneBox*)


Cell[
    StyleData[ "DropShadowPaneBox" ],
    TemplateBoxOptions -> { DisplayFunction -> $dropShadowPaneBox }
]


(* ::Section::Closed:: *)
(*Templates*)


(* ::Subsection::Closed:: *)
(*ChatbookPersona*)


Cell[
	StyleData["ChatbookPersona"],
	TemplateBoxOptions -> {
		DisplayFunction -> (
			NamespaceBox["ChatbookPersonaID",
				DynamicModuleBox[{},
					DynamicBox[ToBoxes @ Wolfram`Chatbook`Common`personaTemplateBoxes[1, #input, #state, #uuid]],
					Initialization :> (
						Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
						Wolfram`Chatbook`$LastInlineReferenceCell = EvaluationCell[ ]
					)
				]
			]&),
		InterpretationFunction -> (InterpretationBox["", "@"<>#input]&)
	}
]


(* ::Subsection::Closed:: *)
(*ChatbookModifier*)


Cell[
	StyleData["ChatbookModifier"],
	TemplateBoxOptions -> {
		DisplayFunction -> (
			NamespaceBox["ChatbookModifierID",
				DynamicModuleBox[{},
					DynamicBox[ToBoxes @ Wolfram`Chatbook`Common`modifierTemplateBoxes[1, #input, #params, #state, #uuid]],
					Initialization :> (
						Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
						Wolfram`Chatbook`$LastInlineReferenceCell = EvaluationCell[ ]
					)
				]
			]&),
		InterpretationFunction -> (InterpretationBox["", "#"<>#input]&)
	}
]


(* ::Subsection::Closed:: *)
(*ChatbookFunction*)


Cell[
	StyleData["ChatbookFunction"],
	TemplateBoxOptions -> {
		DisplayFunction -> (
			NamespaceBox["ChatbookFunctionID",
				DynamicModuleBox[{},
					DynamicBox[ToBoxes @ Wolfram`Chatbook`Common`functionTemplateBoxes[1, #input, #params, #state, #uuid]],
					Initialization :> (
						Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
						Wolfram`Chatbook`$LastInlineReferenceCell = EvaluationCell[ ]
					)
				]
			]&),
		InterpretationFunction -> (InterpretationBox["", "!"<>#input]&)
	}
]


(* ::Subsection::Closed:: *)
(*ChatbookWLTemplate*)


Cell[
	StyleData["ChatbookWLTemplate"],
	TemplateBoxOptions -> {
		DisplayFunction -> (
			NamespaceBox["ChatbookWLTemplateID",
				DynamicModuleBox[{},
					DynamicBox[ToBoxes @ Wolfram`Chatbook`Common`wlTemplateBoxes[1, #input, #state, #uuid]],
					Initialization :> (
						Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
						Wolfram`Chatbook`$LastInlineReferenceCell = EvaluationCell[ ]
					)
				]
			]&),
		InterpretationFunction -> (InterpretationBox["", RowBox[{"\\",#input}]]&)
	}
]


(* ::Section::Closed:: *)
(*Misc Styles*)


(* ::Subsection::Closed:: *)
(*InlineReferenceText*)


(* TODO: unclear if this style is serialized into pre-14.1 chatbooks, so hang on to it, but exclude from CoreExtensions. *)
Cell[
    StyleData[ "InlineReferenceText", StyleDefinitions -> StyleData[ "NotebookAssistant`Text" ] ],
    FontColor -> GrayLevel[ 0.2 ]
]

Cell[
    StyleData[ "NotebookAssistant`InlineReferenceText", StyleDefinitions -> StyleData[ "NotebookAssistant`Text" ] ],
    FontColor -> GrayLevel[ 0.2 ]
]



(* ::Subsection::Closed:: *)
(*ChatExcluded*)


Cell[
    StyleData[ "ChatExcluded" ],
    CellTrayWidgets -> <|
        "ChatWidget"         -> <| "Visible" -> False |>,
        "ChatExcludedWidget" -> <|
            "Type"    -> "Focus",
            "Content" -> Cell[ BoxData @ TemplateBox[ { }, "ChatExcludedWidget" ], "ChatExcludedWidget" ]
        |>
    |>,
    CellBracketOptions  -> { "Color" -> Pink },
    GeneratedCellStyles -> {
        "Message"        -> { "Message" , "MSG", "ChatExcluded" },
        "Graphics"       -> { "Graphics"       , "ChatExcluded" },
        "Output"         -> { "Output"         , "ChatExcluded" },
        "Print"          -> { "Print"          , "ChatExcluded" },
        "PrintTemporary" -> { "PrintTemporary" , "ChatExcluded" }
    }
]



(* ::Subsection::Closed:: *)
(*ChatWidgetButton*)


Cell[
    StyleData[ "ChatWidgetButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            Evaluate @ ToBoxes @ Button[
                MouseAppearance[
                    Tooltip[ RawBoxes @ TemplateBox[ { }, "ChatWidgetIcon" ], tr["StylesheetChatWidgetButtonTooltip"] ],
                    "LinkHand"
                ],
                With[ { $CellContext`cell = ParentCell @ EvaluationCell[ ] },
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Catch[ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "WidgetSend", $CellContext`cell ], _ ]
                ],
                Appearance -> $suppressButtonAppearance
            ]
        ]
    }
]



(* ::Subsection::Closed:: *)
(*ChatCounterLabel*)


Cell[
    StyleData["ChatCounterLabel"],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ StyleBox[
            CounterBox["ChatInputCount"],
            FontFamily -> "Source Sans Pro",
            FontSize -> 10,
            FontColor -> RGBColor[0.55433, 0.707942, 0.925795],
            FontWeight -> Plain
        ]
    }
]



(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DiscardedMaterialOpener*)


Cell[
    StyleData[ "DiscardedMaterialOpener" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ DynamicModuleBox[
            { Typeset`hover$$ = False, Typeset`open$$ = False },
            PaneSelectorBox[
                {
                    False -> TagBox[
                        GridBox[
                            { { $discardedMaterialLabel } },
                            DefaultBaseStyle -> "Column",
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings  -> { "Columns" -> { { Automatic } }, "Rows" -> { { 0.25 } } }
                        ],
                        "Column"
                    ],
                    True -> TagBox[
                        GridBox[
                            {
                                { $discardedMaterialLabel },
                                {
                                    FrameBox[
                                        #1,
                                        Background     -> RGBColor[ 0.94902, 0.96863, 0.98824 ],
                                        FrameMargins   -> 10,
                                        FrameStyle     -> RGBColor[ 0.9098, 0.93333, 0.95294 ],
                                        ImageSize      -> { Full, Automatic },
                                        RoundingRadius -> 5,
                                        StripOnInput   -> False
                                    ]
                                }
                            },
                            DefaultBaseStyle -> "Column",
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings  -> { "Columns" -> { { Automatic } }, "Rows" -> { { 0.25 } } }
                        ],
                        "Column"
                    ]
                },
                Dynamic @ Typeset`open$$,
                ImageMargins   -> { { 0, 0 }, { 8, 8 } },
                ImageSize      -> Automatic,
                Alignment      -> Left,
                ContentPadding -> False
            ],
            DynamicModuleValues :> { },
            UnsavedVariables    :> { Typeset`hover$$ }
        ]
    }
]


Cell[
    StyleData[ "DiscardedMaterialOpenerIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ GraphicsBox[
            {
                #1,
                Thickness[ 0.090909 ],
                Opacity[ 1.0 ],
                FilledCurveBox[
                    {
                        {
                            { 0, 2, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 },
                            { 0, 1, 0 }
                        }
                    },
                    {
                        {
                            { 8.5, 4.5 },
                            { 6.5, 4.5 },
                            { 6.5, 2.5 },
                            { 4.5, 2.5 },
                            { 4.5, 4.5 },
                            { 2.5, 4.5 },
                            { 2.5, 6.5 },
                            { 4.5, 6.5 },
                            { 4.5, 8.5 },
                            { 6.5, 8.5 },
                            { 6.5, 6.5 },
                            { 8.5, 6.5 }
                        }
                    }
                ]
            },
            AspectRatio      -> Automatic,
            BaselinePosition -> Center -> Center,
            ImageSize        -> { 11.0, 11.0 },
            PlotRange        -> { { 0.0, 11.0 }, { 0.0, 11.0 } }
        ]
    }
]


Cell[
    StyleData[ "DiscardedMaterialCloserIcon" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ GraphicsBox[
            {
                #1,
                Thickness[ 0.090909 ],
                Opacity[ 1.0 ],
                FilledCurveBox[
                    { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
                    { { { 8.5, 4.5 }, { 2.5, 4.5 }, { 2.5, 6.5 }, { 8.5, 6.5 } } }
                ]
            },
            AspectRatio      -> Automatic,
            BaselinePosition -> Center -> Center,
            ImageSize        -> { 11.0, 11.0 },
            PlotRange        -> { { 0.0, 11.0 }, { 0.0, 11.0 } }
        ]
    }
]



(* ::Subsection::Closed:: *)
(*TextExpressionLink*)


Cell[
    StyleData[ "TextExpressionLink" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ ButtonBox[
            #1,
            Appearance       -> None,
            BaseStyle        -> { "Text", "Hyperlink" },
            ButtonFunction   :> CreateDocument @ BinaryDeserialize @ BaseDecode @ #2,
            DefaultBaseStyle -> { },
            Evaluator        -> Automatic,
            Method           -> "Queued"
        ]
    }
]



(* ::Subsection::Closed:: *)
(*ThinkingOpener*)


Cell[
    StyleData[ "ThinkingOpener" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ DynamicModuleBox[
            { Typeset`var$$ = True },
            StyleBox[
                PaneSelectorBox[
                    {
                        False -> GridBox[
                            {
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f442" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f43b" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                }
                            },
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            AutoDelete -> False,
                            GridBoxBackground -> { "Columns" -> { { Automatic } } },
                            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings -> { "Columns" -> { { 0.2 } }, "Rows" -> { { 0.5 } } },
                            BaselinePosition -> { 1, 1 }
                        ],
                        True -> GridBox[
                            {
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f442" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f43b" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                },
                                {
                                    PaneBox[
                                        Cell[ BoxData @ TemplateBox[ { #1 }, "ThinkingContent" ], Background -> None ],
                                        Alignment -> Left,
                                        ImageMargins -> { { 5, 0 }, { 0, 0 } }
                                    ]
                                },
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { {
                                                            AdjustmentBox[ RotationBox[ "\:f443", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ],
                                                            StyleBox[
                                                                DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingHide" ], StandardForm] ],
                                                                FontSlant -> "Italic"
                                                            ]
                                                        } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { {
                                                            AdjustmentBox[ RotationBox[ "\:f449", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ],
                                                            StyleBox[
                                                                DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingHide" ], StandardForm] ],
                                                                FontSlant -> "Italic"
                                                            ]
                                                        } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                }
                            },
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            AutoDelete -> False,
                            GridBoxBackground -> { "Columns" -> { { Automatic } } },
                            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings -> { "Columns" -> { { 0.2 } }, "Rows" -> { { 0.5 } } },
                            BaselinePosition -> { 1, 1 }
                        ]
                    },
                    Dynamic @ TrueQ @ Typeset`var$$,
                    Alignment -> Automatic,
                    ImageSize -> Automatic,
                    ImageMargins -> { { 0, 0 }, { 10, 10 } },
                    BaseStyle -> { },
                    DefaultBaseStyle -> "OpenerView",
                    BaselinePosition -> Baseline
                ],
                Deployed -> False,
                StripOnInput -> False
            ],
            DynamicModuleValues -> Automatic
        ]
    }
]



(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ThoughtsOpener*)


Cell[
    StyleData[ "ThoughtsOpener" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ DynamicModuleBox[
            { Typeset`var$$ = False },
            StyleBox[
                PaneSelectorBox[
                    {
                        False -> GridBox[
                            {
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f442" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f43b" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                }
                            },
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            AutoDelete -> False,
                            GridBoxBackground -> { "Columns" -> { { Automatic } } },
                            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings -> { "Columns" -> { { 0.2 } }, "Rows" -> { { 0.5 } } },
                            BaselinePosition -> { 1, 1 }
                        ],
                        True -> GridBox[
                            {
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f443" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { { StyleBox[ #2, FontSlant -> "Italic" ], "\:f449" } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                },
                                {
                                    PaneBox[
                                        Cell[ BoxData @ TemplateBox[ { #1 }, "ThinkingContent" ], Background -> None ],
                                        Alignment -> Left,
                                        ImageMargins -> { { 5, 0 }, { 0, 0 } }
                                    ]
                                },
                                {
                                    TagBox[
                                        TagBox[
                                            PaneSelectorBox[
                                                {
                                                    False -> GridBox[
                                                        { {
                                                            AdjustmentBox[ RotationBox[ "\:f443", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ],
                                                            StyleBox[
                                                                DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingHide" ], StandardForm] ],
                                                                FontSlant -> "Italic"
                                                            ]
                                                        } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
                                                    ],
                                                    True -> GridBox[
                                                        { {
                                                            AdjustmentBox[ RotationBox[ "\:f449", BoxRotation -> 3.14159 ], BoxBaselineShift -> -0.2 ],
                                                            StyleBox[
                                                                DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", "FormattingHide" ], StandardForm] ],
                                                                FontSlant -> "Italic"
                                                            ]
                                                        } },
                                                        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                                                        BaseStyle -> { FontColor -> GrayLevel[ 0.39215 ] }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> GrayLevel[ 0.4666 ], FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
                                                ImageSize -> Automatic,
                                                FrameMargins -> 0
                                            ], 
                                            MouseAppearanceTag[ "Arrow" ]
                                        ],
                                        EventHandlerTag @ {
                                            "MouseClicked" :> (Typeset`var$$ = ! Typeset`var$$),
                                            Method -> "Preemptive",
                                            PassEventsDown -> Automatic,
                                            PassEventsUp -> True
                                        }
                                    ]
                                }
                            },
                            GridBoxAlignment -> { "Columns" -> { { Left } } },
                            AutoDelete -> False,
                            GridBoxBackground -> { "Columns" -> { { Automatic } } },
                            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
                            GridBoxSpacings -> { "Columns" -> { { 0.2 } }, "Rows" -> { { 0.5 } } },
                            BaselinePosition -> { 1, 1 }
                        ]
                    },
                    Dynamic @ TrueQ @ Typeset`var$$,
                    Alignment -> Automatic,
                    ImageSize -> Automatic,
                    ImageMargins -> { { 0, 0 }, { 10, 10 } },
                    BaseStyle -> { },
                    DefaultBaseStyle -> "OpenerView",
                    BaselinePosition -> Baseline
                ],
                Deployed -> False,
                StripOnInput -> False
            ],
            DynamicModuleValues -> Automatic
        ]
    }
]


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ThinkingContent*)


Cell[
    StyleData[ "ThinkingContent" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ GridBox[
            { {
                PaneBox[
                    Cell[ #, "Text", FontColor -> GrayLevel[ 0.35 ], FontSize -> 12, Background -> None, Editable -> True ],
                    Alignment    -> Left,
                    ImageMargins -> { { 5, 5 }, { 5, 5 } },
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            } },
            AutoDelete        -> False,
            GridBoxBackground -> { "Columns" -> { { GrayLevel[ 1 ] } } },
            GridBoxItemSize   -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxDividers   -> {
                "ColumnsIndexed" -> { 1 -> Directive[ GrayLevel[ 0.8196 ], AbsoluteThickness[ 2 ] ] },
                "Rows"           -> { { False } }
            }
        ]
    }
]



(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
