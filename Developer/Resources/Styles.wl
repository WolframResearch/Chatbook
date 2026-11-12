(* ::Package:: *)

Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


color = Wolfram`Chatbook`Common`color;
System`CellFrameRoundingRadius; (* in case stylesheets build prior to 15.0 *)


(* ::Section::Closed:: *)
(*Resources*)


(* ::Subsection::Closed:: *)
(*tr suppport *)


tr[name_?StringQ] := Dynamic[FEPrivate`FrontEndResource["ChatbookStrings", name]]


(* ::Section::Closed:: *)
(*Notebook*)


Cell[
    StyleData[ "Notebook" ],
    TaggingRules -> <| "ChatNotebookSettings" -> <| |> |>,

    CellTrayWidgets -> <|
        "GearMenu"     -> <| "Condition" -> False |>,
        "ChatWidget"   -> <|
            "Type"    -> "Focus",
            "Content" -> Cell[ BoxData @ TemplateBox[ { }, "ChatWidgetButton" ], "ChatWidget" ]
        |>
    |>,

    ComponentwiseContextMenu -> <|
        "CellBracket" -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellBracket" ],
        "CellGroup"   -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellGroup" ],
        "CellRange"   -> contextMenu[ { $excludeMenuItem, Delimiter }, "CellRange" ]
    |>
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
    CellFrame                -> 1.75,
    CellFrameColor           -> color @ "Blue_ECF0F5_48505F",
    CellFrameMargins         -> { { 12, 25 }, { 8, 8 } },
    CellFrameRoundingRadius  -> 8,
    PasteAutoQuoteCharacters -> { },
    ShowCellLabel            -> False,
    ShowGroupOpener          -> { },
    TaggingRules             -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Subsection::Closed:: *)
(*ChatInput*)


Cell[
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    CellFrameColor        -> color @ "Blue_B1D5E8_607D8F",
    CellFrameLabelMargins -> -32,
    CellGroupingRules     -> "InputGrouping",
    CellMargins           -> { { 66, 32 }, { 1, 8 } },
    CellTrayWidgets       -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements     -> { "ChatInputCount" },
    Evaluatable           -> True,
    MenuSortingValue      -> 1543,
    StyleKeyMapping       -> { "~" -> "ChatDelimiter", "=" -> "WolframAlphaShort", "*" -> "Item", ">" -> "ExternalLanguageDefault" },
    TaggingRules          -> <| "ChatNotebookSettings" -> <| |> |>,
    CellFrameLabels -> {
        {
            None,
            Cell[
                BoxData[
                    DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButton" ][ #1, { 24, 24 }, 12, 18 ] ]&[
                        color @ "Blue_B1D5E8_607D8F"
                    ]
                ],
                Background -> None
            ]
        },
        { None, None }
    },
	CellDingbat -> TemplateBox[ { }, "ChatInputCellDingbat" ],
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
        (* the following three events swap the effects of Enter and Shift+Enter, PassEventsDown -> False is also needed *)
        "ReturnKeyDown" :> MathLink`CallFrontEnd @ FrontEnd`CellEvaluate @ EvaluationCell[ ]
        ,
        { "MenuCommand", "HandleShiftReturn" } :> NotebookWrite[ InputNotebook[ ], "\n" ]
        ,
        { "MenuCommand", "EvaluateCells" } :> NotebookWrite[ InputNotebook[ ], "\n" ]
        ,
        PassEventsDown -> False
    }
]


(* ::Subsubsection::Closed:: *)
(*ChatInputCellDingbat*)


Cell[
    StyleData[ "ChatInputCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ Wolfram`Chatbook`UI`MakeChatInputCellDingbat[ ]
    }
]



(* ::Subsection::Closed:: *)
(*SideChat*)


(* By using negative margins on the FrameLabels and CellDingbat,
    we're able to pull the CellFrame completely across the top of the cell.
    We adjust the CellMargins and CellFrameMargins to compensate.
    We use Background in order to coerce all frames to exist as invisible edges,
    otherwise the CellFrameMargin wouldn't work. *)
Cell[
    StyleData[ "SideChat", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue      -> 1544,
    Background            -> Transparent,
    CellDingbat           -> TemplateBox[ { }, "ChatInputCellDingbat" ],
    CellDingbatMargin     -> -20,
    CellFrame             -> { { 0, 0 }, { 0, 2.5 } },
    CellFrameLabels       -> { { "", Inherited }, { Inherited, Inherited } },
    CellFrameLabelMargins -> { { -25, -45 }, { 0, 0 } },
    CellFrameMargins      -> { {  62, Inherited }, { Inherited, 10 } },
    CellMargins           -> { {  42,  32 }, { Inherited, Inherited } },
    CellTrayWidgets       -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements     -> { },
    StyleKeyMapping       -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules          -> <| "ChatNotebookSettings" -> <| "IncludeHistory" -> False |> |>
]



(* ::Subsection::Closed:: *)
(*ChatQuery*)


Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    CellDingbat     -> DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatQueryIcon" ],
    CellTrayWidgets -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    StyleKeyMapping -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules    -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Subsection::Closed:: *)
(*ChatSystemInput*)


Cell[
    StyleData[ "ChatSystemInput", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    CellDingbat       -> DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatSystemIcon" ],
    CellFrame         -> 1,
    CellFrameStyle    -> Dashing @ { Small, Small },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterIncrements -> { },
    MenuSortingValue  -> 1545,
    StyleKeyMapping   -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules      -> <| "ChatNotebookSettings" -> <| |> |>
]



(* ::Section::Closed:: *)
(*Chat Output Styles*)


(* ::Subsection::Closed:: *)
(*ChatOutput*)


Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    Background           -> color @ "Blue_F9FDFF_1D1F21",
    CellAutoOverwrite    -> True,
    CellDingbat          -> TemplateBox[ { }, "ChatOutputCellDingbat" ],
    CellDingbatMargin    -> 6.5, (* the ChatInput dingbat is a button with frame margins so nudge over the output *)
    CellElementSpacings  -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    CellFrameColor       -> color @ "Blue_EBF3F7_37424A",
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
        "ChatFeedback" -> <| "Content" ->
            Cell[ BoxData @ ToBoxes @
                PaneSelector[
                    { True -> $feedbackButtonsV, False -> Graphics[ ImageSize -> 0 ] },
                    Dynamic[ CurrentValue[ ParentCell @ EvaluationCell[ ], { TaggingRules, "ChatData" } ] =!= Inherited ],
                    ImageSize -> Automatic ],
                "ChatFeedback" ] |>
    |>,
    menuInitializer[ "ChatOutput", LightDarkSwitched[ RGBColor[ "#ECF0F5" ], RGBColor[ "#282C35" ] ] ]
]


(* ::Subsubsection::Closed:: *)
(*ChatOutputCellDingbat*)


Cell[
    StyleData[ "ChatOutputCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ Wolfram`Chatbook`UI`MakeChatOutputCellDingbat[ ]
    }
]


(* ::Subsection::Closed:: *)
(*AssistantOutput*)


Cell[
    StyleData[ "AssistantOutput", StyleDefinitions -> StyleData[ "ChatOutput" ] ],
    Background     -> LightDarkSwitched[ RGBColor[ "#EDF2F7" ], RGBColor[ "#3F4856" ] ],
    CellFrameColor -> color @ "Blue_D0DEEC_4F5C6F",
    assistantMenuInitializer[ "AssistantOutput", color @ "Blue_D0DEEC_4F5C6F" ]
]



(* ::Subsection::Closed:: *)
(*AssistantOutputWarning*)


Cell[
    StyleData[ "AssistantOutputWarning", StyleDefinitions -> StyleData[ "AssistantOutput" ] ],
    Background     -> LightDarkSwitched[ RGBColor[ "#FDFAF4" ], RGBColor[ "#4B4A2E" ] ],
    CellFrameColor -> color @ "Orange_F1E7DE_5D5442",
    assistantMenuInitializer[ "AssistantOutput", color @ "Orange_F1E7DE_5D5442" ]
]



(* ::Subsection::Closed:: *)
(*AssistantOutputError*)


Cell[
    StyleData[ "AssistantOutputError", StyleDefinitions -> StyleData[ "AssistantOutput" ] ],
    Background     -> LightDarkSwitched[ RGBColor[ "#FDF4F4" ], RGBColor[ "#733126" ] ],
    CellFrameColor -> color @ "Red_F1DEDE_804840",
    assistantMenuInitializer[ "AssistantOutput", color @ "Red_F1DEDE_804840" ]
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
    CellFrameColor      -> color @ "Gray75_54",
    CellFrameLabels     -> { { TemplateBox[ { }, "ChatDelimiterCellDingbat" ], None }, { None, None } },
    CellFrameMargins    -> 4,
    CellGroupingRules   -> { "SectionGrouping", 30 },
    CellMargins         -> { { 5, 25 }, { 8, 18 } },
    CellTrayWidgets     -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterAssignments  -> { { "ChatInputCount", 0 } },
    CounterIncrements   -> "Section",
    FontColor           -> color @ "Gray20_94",
    FontFamily          -> "Source Sans Pro",
    FontSize            -> 28,
    FontWeight          -> "DemiBold",
    LanguageCategory    -> "NaturalLanguage",
    LineSpacing         -> { 1, 2 },
    PageBreakBelow      -> False,
    ShowCellLabel       -> False,
    StyleKeyMapping     -> { "~" -> "ChatDelimiter", "'" -> "ChatInput" },
    TaggingRules        -> <| "ChatNotebookSettings" -> <| "ChatDelimiter" -> True |> |>
]



(* ::Subsection::Closed:: *)
(*ChatDelimiter*)


Cell[
    StyleData[ "ChatDelimiter" ],
    MenuSortingValue    -> 1547,
    Background          -> LightDarkSwitched[ GrayLevel[ 0.95 ], GrayLevel[ 0.2438 ] ],
    CellElementSpacings -> { "CellMinHeight" -> 6 },
    CellFrameLabels     -> { { TemplateBox[ { }, "ChatDelimiterCellDingbat" ], None }, { None, None } },
    CellFrameMargins    -> { { 20, 20 }, { 2, 2 } },
    CellGroupingRules   -> { "SectionGrouping", 62 },
    CellMargins         -> { { 5, 0 }, { 10, 10 } },
    CellTrayWidgets     -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    CounterAssignments  -> { { "ChatInputCount", 0 } },
    FontSize            -> 6,
    ShowCellLabel       -> False,
    StyleKeyMapping     -> { "~" -> "ChatBlockDivider", "'" -> "ChatInput", "=" -> "WolframAlphaShort", "*" -> "Item", ">" -> "ExternalLanguageDefault" },
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

    Initialization :> NotebookDelete @ Cells[ EvaluationCell[ ], AttachedCell -> True, CellStyle -> "ChatMenu" ]
]



(* ::Subsubsection::Closed:: *)
(*ChatDelimiterCellDingbat*)


Cell[
    StyleData[ "ChatDelimiterCellDingbat" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ Wolfram`Chatbook`UI`MakeChatDelimiterCellDingbat[ ]
    }
]



(* ::Section::Closed:: *)
(*Chat Output Formatting*)


(* ::Subsection::Closed:: *)
(*ChatCodeBlock*)


Cell[
    StyleData[ "ChatCodeBlock" ],
    Background -> None
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
    Background               -> color @ "Gray100_26",
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


With[
    {
        frameColor = color @ "Gray93_32",
        bg1        = color @ "Gray100_10",
        bg2        = color @ "Blue_FCFDFF_232A32"
    },

Cell[
    StyleData[ "ChatCodeBlockTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @
        GridBox[
            {
                {
                    FrameBox[
                        #1,
                        Background   -> bg1,
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ] },
                {
                    FrameBox[
                        DynamicBox[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ #1, #2 ] ],
                        Background   -> bg2,
                        FrameMargins -> { { 7, 2 }, { 2, 2 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
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

]


With[
    {
        frameColor = color @ "Gray93_32",
        bg1        = color @ "Gray100_10",
        bg2        = color @ "Blue_FCFDFF_232A32"
    },

Cell[
    StyleData[ "ChatCodeBlockTemplateActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @
        GridBox[
            {
                {
                    FrameBox[
                        #1,
                        Background   -> bg1,
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ] },
                {
                    FrameBox[
                        ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ "Disabled", None ],
                        Background   -> bg2,
                        FrameMargins -> { { 7, 2 }, { 2, 2 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
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

]


(* ::Subsection::Closed:: *)
(*ChatCodeInlineTemplate*)


With[
    {
        frameColor = color @ "Gray93_32",
        bg1 =        color @ "Gray100_26"
    },

Cell[
    StyleData[ "ChatCodeInlineTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ FrameBox[
            #1,
            Background       -> bg1,
            BaselinePosition -> Scaled[ 0.275 ],
            FrameMargins     -> { { 3, 3 }, { 2, 2 } },
            FrameStyle       -> Directive[ AbsoluteThickness[ 1 ], frameColor ],
            ImageMargins     -> { { 0, 0 }, { 0, 0 } },
            BaseStyle        -> { "InlineCode", AutoSpacing -> False, AutoMultiplicationSymbol -> False }
        ]
    }
]

]



(* ::Subsection::Closed:: *)
(*Link*)


Cell[
    StyleData[ "Link" ],
    FontFamily -> "Source Sans Pro",
    FontColor  -> With[
        {
            hover   = LightDarkSwitched[ RGBColor[ "#DA6525" ], RGBColor[ "#FAA685" ] ],
            default = color @ "Blue_0549A6_48AAF2" },
        Dynamic @ If[ CurrentValue[ "MouseOver" ], hover, default ] ]
]



(* ::Subsection::Closed:: *)
(*TextRefLink*)


With[ { fc = color @ "Blue_0549A6_48AAF2" },

Cell[
    StyleData[ "TextRefLink" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            TagBox[
                ButtonBox[
                    StyleBox[ #1, ShowStringCharacters -> True, FontFamily -> "Source Sans Pro" ],
                    BaseStyle      -> {"Link", FontColor -> fc},
                    ButtonData     -> #2,
                    ContentPadding -> False
                ],
                MouseAppearanceTag[ "LinkHand" ]
            ]
        ]
    }
]

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


With[
    {
        frameColor = LightDarkSwitched[ GrayLevel[ 1, 0 ], GrayLevel[ 0.2192, 0 ] ]
    },

Cell[
    StyleData[ "ChatMenuButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ TagBox[ ToBoxes @
            Button[
                Wolfram`Chatbook`Common`blueHueButtonAppearance[ Wolfram`Chatbook`Common`chatbookIcon[ "ChatMenuIcon", False ], { 14, 20 } ],
                Quiet @ Needs[ "Wolfram`Chatbook`" -> None ]; Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", #1, EvaluationCell[ ] ],
                Appearance -> $suppressButtonAppearance,
                Evaluator  -> Automatic,
                ImageSize  -> Automatic,
                Method     -> "Preemptive"
            ],
            MouseAppearanceTag[ "LinkHand" ]
        ]
    }
]

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


With[
    {
        delimiterColor = color @ "Gray90_35"
    },

Cell[
    StyleData[ "ChatMenuItemDelimiter" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            PaneBox[
                StyleBox[
                    GraphicsBox[
                        {
                            CapForm[ "Round" ],
                            delimiterColor,
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

]



(* ::Subsection::Closed:: *)
(*ChatMenuItem*)


With[
    {
        frameHover   = color @ "Gray80_47",
        frameDefault = color @ "Gray98_19",
        bgHover      = color @ "Gray100_26",
        bgDefault    = color @ "Gray98_19"
    },

Cell[
    StyleData[ "ChatMenuItem" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @
            FrameBox[
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
                Background       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], bgHover, bgDefault ],
                BaselinePosition -> Baseline,
                FrameMargins     -> { { 5, 2 }, { 2, 2 } },
                FrameStyle       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], frameHover, frameDefault ],
                ImageMargins     -> { { 0, 0 }, { 0, 0 } },
                ImageSize        -> Full,
                RoundingRadius   -> 0
            ]
    }
]

]



(* ::Subsection::Closed:: *)
(*ChatMenuSection*)


With[
    {
        bg = LightDarkSwitched[ GrayLevel[ 0.937 ], GrayLevel[ 0.2314 ] ]
    },

Cell[
    StyleData[ "ChatMenuSection" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @
            FrameBox[
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
                Background       -> bg,
                BaselinePosition -> Baseline,
                FrameMargins     -> { { 5, 2 }, { 2, 2 } },
                FrameStyle       -> None,
                ImageMargins     -> { { 0, 0 }, { 0, 0 } },
                ImageSize        -> Full,
                RoundingRadius   -> 0
            ]
    }
]

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
    FontColor       -> color @ "Gray20_94",
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
    FontColor -> color @ "Gray35_86"
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
                        True  -> DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatOutputStopButton" ]
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
                        True -> DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatOutputStopButton" ]
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
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ Wolfram`Chatbook`UI`MakeChatOutputCellDingbat[ ]
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
                Background     -> color @ "Gray100_10",
                FrameMargins   -> { { 8, 15 }, { 8, 8 } },
                FrameStyle     -> color @ "Blue_D4F0FF_344858",
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
            assistantMessageBoxFrameChatbook[ # ],
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
    StyleData[ "AssistantMessageBoxActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ assistantMessageBoxFrameChatbook[ # ]
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
    FontColor -> color @ "Gray20_94" (* only shows up in 14.1 *)
]

Cell[
    StyleData[ "NotebookAssistant`InlineReferenceText", StyleDefinitions -> StyleData[ "NotebookAssistant`Text" ] ],
    FontColor -> color @ "Gray20_94"
]



(* ::Subsection::Closed:: *)
(*ChatExcluded*)


Cell[
    StyleData[ "ChatExcluded" ],
    CellTrayWidgets -> <|
        "ChatWidget"         -> <| "Visible" -> False |>,
        "ChatExcludedWidget" -> <|
            "Type"    -> "Focus",
            "Content" -> Cell[ BoxData @ DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatExcludedWidget" ], "ChatExcludedWidget" ]
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
                    Tooltip[
                        RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatWidgetIcon" ],
                        tr["StylesheetChatWidgetButtonTooltip"]
                    ],
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


With[
    {
        fontColor = LightDarkSwitched[ RGBColor[ "#8DB5EC" ], RGBColor[ "#769FDA" ] ]
    },

Cell[
    StyleData["ChatCounterLabel"],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ StyleBox[
            CounterBox["ChatInputCount"],
            FontFamily -> "Source Sans Pro",
            FontSize -> 10,
            FontColor -> fontColor,
            FontWeight -> Plain
        ]
    }
]

]


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*DiscardedMaterialOpener*)


With[
    {
        bg         = color @ "Blue_F2F7FC_2D3646",
        frameColor = color @ "Blue_E8EEF3_4A545F"
    },

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
                                        Background     -> bg,
                                        FrameMargins   -> 10,
                                        FrameStyle     -> frameColor,
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


With[
    {
        font1      = color @ "Gray47_78",
        font1hover = color @ "Gray39_83"
    },
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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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
]



(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ThoughtsOpener*)


With[
    {
        font1      = color @ "Gray47_78",
        font1hover = color @ "Gray39_83"
    },

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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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
                                                        BaseStyle -> { FontColor -> font1hover }
                                                    ]
                                                },
                                                Dynamic[ CurrentValue[ "MouseOver" ] ],
                                                BaseStyle -> { FontColor -> font1, FontFamily -> "Source Sans Pro", FontSize -> 13.5 },
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

]


With[ { font1 = color[ "Gray47_78" ] },
    Cell[
        StyleData[ "EmptyThoughts" ],
        TemplateBoxOptions -> {
            DisplayFunction -> Function[
                StyleBox[
                    PaneBox[
                        PaneBox[
                            StyleBox[ #2, FontSlant -> "Italic" ],
                            BaseStyle -> {
                                FontColor -> font1,
                                FontFamily -> "Source Sans Pro",
                                FontSize -> 13.5
                            },
                            ImageSize -> Automatic,
                            FrameMargins -> 0
                        ],
                        Alignment -> Automatic,
                        ImageSize -> Automatic,
                        ImageMargins -> { { 0, 0 }, { 10, 10 } },
                        BaseStyle -> { },
                        DefaultBaseStyle -> "OpenerView",
                        BaselinePosition -> Baseline
                    ],
                    Deployed -> False,
                    StripOnInput -> False
                ]
            ]
        }
    ]
]


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ThinkingContent*)


With[
    {
        font    = color @ "Gray35_86",
        divider = color @ "Gray82_46",
        bg      = color @ "Gray100_26"
    },

Cell[
    StyleData[ "ThinkingContent" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ GridBox[
            { {
                PaneBox[
                    Cell[ #, "Text", FontColor -> font, FontSize -> 12, Background -> None, Editable -> True ],
                    Alignment    -> Left,
                    ImageMargins -> { { 5, 5 }, { 5, 5 } },
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            } },
            AutoDelete        -> False,
            GridBoxBackground -> { "Columns" -> { { bg } } },
            GridBoxItemSize   -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxDividers   -> {
                "ColumnsIndexed" -> { 1 -> Directive[ divider, AbsoluteThickness[ 2 ] ] },
                "Rows"           -> { { False } }
            }
        ]
    }
]

]


(* ::Section::Closed:: *)
(*Package Footer*)


End[ ];
