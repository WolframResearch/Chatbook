(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    TaggingRules   -> <| "AIAssistantSettings" -> $defaultAIAssistantSettings |>,
    MessageOptions -> { "KernelMessageAction" -> "PrintToNotebook" },
    CellEpilog :> Module[ { cell, notebook, settings, id, birdChat },

        cell     = EvaluationCell[ ];
        notebook = Notebooks @ cell;
        settings = CurrentValue[ notebook, { TaggingRules, "AIAssistantSettings" }, <| |> ];
        id       = Lookup[ settings, "ResourceID", "AIAssistant" ];
        birdChat = Function[ Once @ ResourceFunction[ #, "Function" ] ][ id ];

        birdChat[ "RequestAIAssistant", cell, notebook, settings ];

        If[ ! TrueQ @ birdChat[ "Loaded" ],
            Function[ Quiet @ Unset @ Once @ ResourceFunction[ #, "Function" ] ][ id ];
            ResourceFunction[ "MessageFailure" ][ "Chat assistant is unavailable due to an unknown error." ]
        ]
    ]
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text*)
Cell[
    StyleData[ "Text" ],
    Evaluatable            -> True,
    CellEvaluationFunction -> Function[
        If[ TrueQ @ CloudSystem`$CloudNotebooks,
            Function[ Once @ ResourceFunction[ #1, "Function" ] ][
                CurrentValue[
                    EvaluationNotebook[ ],
                    { TaggingRules, "AIAssistantSettings", "ResourceID" },
                    "AIAssistant"
                ]
            ][ "RequestAIAssistant" ],
            Null
        ]
    ],
    ContextMenu -> Flatten @ {
        MenuItem[
            "Ask AI Assistant",
            KernelExecute[
                Function[ Once @ ResourceFunction[ #1, "Function" ] ][
                    CurrentValue[
                        EvaluationNotebook[ ],
                        { TaggingRules, "AIAssistantSettings", "ResourceID" },
                        "AIAssistant"
                    ]
                ][ "Ask" ]
            ],
            MenuEvaluator -> Automatic,
            Method        -> "Queued"
        ],
        Delimiter,
        FrontEndResource[ "ContextMenus", "Text" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInput*)
Cell[
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "Text" ] ],
    MenuSortingValue         -> 1000,
    AutoQuoteCharacters      -> { },
    PasteAutoQuoteCharacters -> { },
    CellFrame                -> 2,
    CellFrameColor           -> RGBColor[ 0.81053, 0.85203, 0.91294 ],
    ShowCellLabel            -> False,
    CellGroupingRules        -> "InputGrouping",
    CellMargins              -> { { 36, 24 }, { 5, 12 } },
    CellFrameMargins         -> { { 8, 8 }, { 4, 4 } },
    CellFrameLabelMargins    -> 15,
    StyleKeyMapping          -> { "/" -> "ChatQuery", "?" -> "ChatQuery" },
    CellFrameLabels          -> {
        {
            Cell @ BoxData @ ToBoxes @ Graphics[
                { RGBColor[ 0.62105, 0.70407, 0.82588 ], First @ $images[ "Comment" ] },
                ImageSize -> 24
            ],
            None
        },
        { None, None }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue -> 1000,
    CellFrameColor   -> RGBColor[ 0.82407, 0.87663, 0.67795 ],
    FontSlant        -> Italic,
    FontColor        -> GrayLevel[ 0.25 ],
    StyleKeyMapping  -> { "/" -> "ChatInput" },
    CellFrameLabels  -> {
        {
            Cell @ BoxData @ ToBoxes @ Graphics[
                { RGBColor[ 0.60416, 0.72241, 0.2754 ], First @ $images[ "ChatQuestion" ] },
                ImageSize -> 24
            ],
            None
        },
        { None, None }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "Text" ] ],
    GeneratedCell       -> True,
    CellAutoOverwrite   -> True,
    CellGroupingRules   -> "OutputGrouping",
    CellMargins         -> { { 36, 24 }, { 12, 5 } },
    CellFrame           -> 2,
    CellFrameColor      -> GrayLevel[ 0.85 ],
    LineSpacing         -> { 1.1, 0, 2 },
    ShowAutoSpellCheck  -> False,
    CellElementSpacings -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    CellFrameLabels     -> { { Cell @ BoxData @ TemplateBox[ { }, "AssistantIcon" ], None }, { None, None } }
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
    ContextMenu -> Flatten @ {
        MenuItem[
            "Ask AI Assistant",
            KernelExecute[
                Function[ Once @ ResourceFunction[ #1, "Function" ] ][
                    CurrentValue[
                        EvaluationNotebook[ ],
                        { TaggingRules, "AIAssistantSettings", "ResourceID" },
                        "AIAssistant"
                    ]
                ][ "Ask" ]
            ],
            MenuEvaluator -> Automatic,
            Method        -> "Queued"
        ],
        Delimiter,
        FrontEndResource[ "ContextMenus", "Input" ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Output*)
Cell[
    StyleData[ "Output" ],
    ContextMenu -> Flatten @ {
        MenuItem[
            "Ask AI Assistant",
            KernelExecute[
                Function[ Once @ ResourceFunction[ #1, "Function" ] ][
                    CurrentValue[
                        EvaluationNotebook[ ],
                        { TaggingRules, "AIAssistantSettings", "ResourceID" },
                        "AIAssistant"
                    ]
                ][ "Ask" ]
            ],
            MenuEvaluator -> Automatic,
            Method        -> "Queued"
        ],
        Delimiter,
        FrontEndResource[ "ContextMenus", "Input" ]
    }
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