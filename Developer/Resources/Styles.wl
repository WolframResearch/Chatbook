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

    CellEpilog :> { $sendChatFunction[ EvaluationCell[ ] ] },

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
            $sendChatFunction[ EvaluationCell[ ] ],
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
    CellFrameMargins         -> { { 12, 20 }, { 8, 8 } },
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
    CellFrameColor    -> RGBColor[ 0.81053, 0.85203, 0.91294 ],
    CellMargins       -> { { 66, 20 }, { 5, 8 } },
    CellDingbat       -> Cell[ BoxData @ TemplateBox[ { }, "ChatUserIcon" ], Background -> None ],
    StyleKeyMapping   -> { " " -> "Text", "*" -> "Item", "/" -> "ChatQuery", "Backspace" -> "Input" },
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    With[ { attach = Cell[ BoxData @ TemplateBox[ { }, "ChatInputMenuButton" ], "ChatMenu" ] },
        Initialization :>
            AttachCell[
                EvaluationCell[ ],
                attach,
                { Right, Top },
                Offset[ { -10, -5 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "/" -> "ChatSystemInput", "Backspace" -> "ChatInput" },
    CellFrameColor   -> RGBColor[ 0.82745, 0.87059, 0.68235 ],
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatQueryIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    With[ { attach = Cell[ BoxData @ TemplateBox[ { }, "ChatInputMenuButton" ], "ChatMenu" ] },
        Initialization :>
            AttachCell[
                EvaluationCell[ ],
                attach,
                { Right, Top },
                Offset[ { -10, -5 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatSystemInput*)
Cell[
    StyleData[ "ChatSystemInput", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    CellFrame        -> 1,
    StyleKeyMapping  -> { " " -> "Text", "*" -> "Item", "/" -> "ChatContextDivider", "Backspace" -> "ChatQuery" },
    CellFrameColor   -> RGBColor[ 0.70196, 0.52941, 0.58039 ],
    CellFrameStyle   -> Dashing @ { Small, Small },
    CellDingbat      -> Cell[ BoxData @ TemplateBox[ { }, "ChatSystemIcon" ], Background -> None ],
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    With[ { attach = Cell[ BoxData @ TemplateBox[ { }, "ChatInputMenuButton" ], "ChatMenu" ] },
        Initialization :>
            AttachCell[
                EvaluationCell[ ],
                attach,
                { Right, Top },
                Offset[ { -10, -5 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
    ]
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
    CellMargins         -> { { 66, 20 }, { 12, 5 } },
    GeneratedCell       -> True,
    LineSpacing         -> { 1.1, 0, 2 },
    ShowAutoSpellCheck  -> False,
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    With[ { attach = Cell[ BoxData @ TemplateBox[ { }, "ChatOutputMenuButton" ], "ChatMenu" ] },
        Initialization :>
            AttachCell[
                EvaluationCell[ ],
                attach,
                { Right, Top },
                Offset[ { -10, -5 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatContextDivider*)
Cell[
    StyleData[ "ChatContextDivider", StyleDefinitions -> StyleData[ "Section" ] ],
    StyleKeyMapping     -> { " " -> "Text", "*" -> "Item", "/" -> "Input", "Backspace" -> "ChatSystemInput" },
    CellGroupingRules   -> { "SectionGrouping", 58 },
    ShowCellLabel       -> False,
    CellMargins         -> { { 66, 20 }, { Inherited, Inherited } },
    CellFrame           -> { { 0, 0 }, { 0, 8 } },
    CellFrameColor      -> RGBColor[ 0.74902, 0.74902, 0.74902 ],
    DefaultNewCellStyle -> "Input",
    FontColor           -> GrayLevel[ 0.2 ],
    FontWeight          -> "DemiBold",
    CellTrayWidgets   -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    With[ { attach = Cell[ BoxData @ TemplateBox[ { }, "ChatSectionMenuButton" ], "ChatMenu" ] },
        Initialization :>
            AttachCell[
                EvaluationCell[ ],
                attach,
                { Right, Top },
                Offset[ { -10, -5 }, { Right, Top } ],
                { Right, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ]
    ]
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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
Cell[
    StyleData[ "ChatDelimiter" ],
    CellTrayWidgets        -> <| "ChatWidget" -> <| "Visible" -> False |> |>,
    Background             -> GrayLevel[ 0.95 ],
    CellBracketOptions     -> { "OverlapContent" -> True },
    CellElementSpacings    -> { "CellMinHeight" -> 6 },
    CellEvaluationFunction -> Function[ $Line = 0; ],
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
(* :!CodeAnalysis::EndBlock:: *)

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
                Function[
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "WidgetSend", # ]
                ][ ParentCell @ EvaluationCell[ ] ],
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
(*ChatInputMenuButton*)
Cell[
    StyleData[ "ChatInputMenuButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            Evaluate @ ButtonBox[
                TemplateBox[ { }, "ChatMenuIcon" ],
                ButtonFunction :> (
                    Function[
                        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", "ChatInput", # ]
                    ][ EvaluationCell[ ] ]
                ),
                Appearance -> $suppressButtonAppearance,
                Evaluator  -> Automatic,
                Method     -> "Preemptive"
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatOutputMenuButton*)
Cell[
    StyleData[ "ChatOutputMenuButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            Evaluate @ ButtonBox[
                TemplateBox[ { }, "ChatMenuIcon" ],
                ButtonFunction :> (
                    Function[
                        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", "ChatOutput", # ]
                    ][ EvaluationCell[ ] ]
                ),
                Appearance -> $suppressButtonAppearance,
                Evaluator  -> Automatic,
                Method     -> "Preemptive"
            ]
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatSectionMenuButton*)
Cell[
    StyleData[ "ChatSectionMenuButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function[
            Evaluate @ ButtonBox[
                TemplateBox[ { }, "ChatMenuIcon" ],
                ButtonFunction :> (
                    Function[
                        Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "OpenChatMenu", "ChatSection", # ]
                    ][ EvaluationCell[ ] ]
                ),
                Appearance -> $suppressButtonAppearance,
                Evaluator  -> Automatic,
                Method     -> "Preemptive"
            ]
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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
