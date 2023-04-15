Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    TaggingRules -> <| "ChatNotebookSettings" -> $defaultChatbookSettings |>,
    CellEpilog   :> { $sendChatFunction[ EvaluationCell[ ] ] }
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
    CellFrameMargins         -> { { 12, 25 }, { 8, 8 } },
    PasteAutoQuoteCharacters -> { },
    ShowCellLabel            -> False,
    With[
        {
            attach = Cell @ BoxData @ ToBoxes @ Button[
                RawBoxes @ TemplateBox[ { }, "ChatMenuIcon" ],
                MessageDialog[ "Not implemented" ],
                Appearance -> Dynamic @ FEPrivate`FrontEndResource[
                    "FEExpressions",
                    "SuppressMouseDownNinePatchAppearance"
                ]
            ]
        },
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
(*ChatInput*)
Cell[
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "FramedChatCell" ] ],
    MenuSortingValue         -> 1000,
    CellGroupingRules        -> "InputGrouping",
    CellFrameColor           -> RGBColor[ 0.81053, 0.85203, 0.91294 ],
    CellMargins              -> { { 56, 25 }, { 3, 10 } },
    CellDingbat              -> Cell[ BoxData @ TemplateBox[ { }, "ChatUserIcon" ], Background -> None ],
    StyleKeyMapping          -> { "/" -> "ChatQuery", "?" -> "ChatQuery" }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue     -> 1000,
    StyleKeyMapping      -> { "/" -> "ChatInput" },
    CellFrameColor       -> RGBColor[ 0.82745, 0.87059, 0.68235 ],
    CellDingbat          -> Cell[ BoxData @ TemplateBox[ { }, "ChatQueryIcon" ], Background -> None ]
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
    CellMargins         -> { { 56, 25 }, { 10,  3 } },
    GeneratedCell       -> True,
    LineSpacing         -> { 1.1, 0, 2 },
    ShowAutoSpellCheck  -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatCodeBlock*)
Cell[
    StyleData[ "ChatCodeBlock" ],
    FrameBoxOptions -> {
        Background   -> GrayLevel[ 1 ],
        FrameMargins -> { { 10, 10 }, { 6, 6 } },
        FrameStyle   -> Directive[ AbsoluteThickness[ 1 ], GrayLevel[ 0.92941 ] ],
        ImageMargins -> 0,
        ImageSize    -> { Full, Automatic }
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

End[ ];