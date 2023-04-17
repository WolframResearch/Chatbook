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
    CellFrameColor           -> GrayLevel[ 0.92941 ],
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
    CellFrameColor    -> RGBColor[ "#cfd9e9" ],
    CellMargins       -> { { 66, 25 }, { 5, 8 } },
    CellDingbat       -> Cell[ BoxData @ TemplateBox[ { }, "ChatUserIcon" ], Background -> None ],
    StyleKeyMapping   -> { " " -> "Text", "*" -> "Item", "/" -> "ChatQuery", "Backspace" -> "Input" },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#cfd9e9" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "/" -> "ChatSystemInput", "Backspace" -> "ChatInput" },
    CellFrameColor   -> RGBColor[ "#d3deae" ],
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatQueryIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#d3deae" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatSystemInput*)
Cell[
    StyleData[ "ChatSystemInput", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    CellFrame        -> 1,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "/" -> "ChatContextDivider", "Backspace" -> "ChatQuery" },
    CellFrameColor   -> RGBColor[ "#b38794" ],
    CellFrameStyle   -> Dashing @ { Small, Small },
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatSystemIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatInput", RGBColor[ "#b38794" ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    Background          -> GrayLevel[ 0.97647 ],
    CellAutoOverwrite   -> True,
    CellDingbat         -> Cell[ BoxData @ TemplateBox[ { }, "AssistantIcon" ], Background -> None ],
    CellElementSpacings -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    CellGroupingRules   -> "OutputGrouping",
    CellMargins         -> { { 66, 25 }, { 12, 5 } },
    GeneratedCell       -> True,
    LineSpacing         -> { 1.1, 0, 2 },
    ShowAutoSpellCheck  -> False,
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatOutput", GrayLevel[ 0.898039 ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatContextDivider*)
Cell[
    StyleData[ "ChatContextDivider", StyleDefinitions -> StyleData[ "Section" ] ],
    StyleKeyMapping     -> { " " -> "Text", "*" -> "Item", "/" -> "Input", "Backspace" -> "ChatSystemInput" },
    CellGroupingRules   -> { "SectionGrouping", 58 },
    ShowCellLabel       -> False,
    CellMargins         -> { { 66, 25 }, { Inherited, Inherited } },
    CellFrame           -> { { 0, 0 }, { 0, 8 } },
    CellFrameColor      -> GrayLevel[ 0.74902 ],
    DefaultNewCellStyle -> "Input",
    FontColor           -> GrayLevel[ 0.2 ],
    FontWeight          -> "DemiBold",
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    menuInitializer[ "ChatSection", GrayLevel[ 0.925 ] ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatCodeBlock*)
Cell[
    StyleData[ "ChatCodeBlock" ],
    FrameBoxOptions -> {

    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input*)
Cell[
    StyleData[ "Input" ],
    StyleKeyMapping -> {
        "~" -> "ChatDelimiter",
        "/" -> "ChatInput",
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
(*ChatDelimiter*)
Cell[
    StyleData[ "ChatDelimiter" ],
    CellTrayWidgets        -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    Background             -> GrayLevel[ 0.95 ],
    CellBracketOptions     -> { "OverlapContent" -> True },
    CellElementSpacings    -> { "CellMinHeight" -> 6 },
    CellFrameMargins       -> { { 20, 20 }, { 2, 2 } },
    CellGroupingRules      -> { "SectionGrouping", 58 },
    CellMargins            -> { { 0, 0 }, { 10, 10 } },
    DefaultNewCellStyle    -> "Input",
    Evaluatable            -> True,
    FontSize               -> 6,
    Selectable             -> False,
    ShowCellBracket        -> False,
    ShowCellLabel          -> False
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
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ $icons[ "AssistantIcon" ] (* TODO: get active icon *)
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
(*Package Footer*)
End[ ];
