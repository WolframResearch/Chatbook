Begin[ "Wolfram`AIAssistant`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    TaggingRules   -> <| "AIAssistantSettings" -> $defaultAIAssistantSettings |>,
    MessageOptions -> { "KernelMessageAction" -> "PrintToNotebook" },
    CellEpilog :> Module[ { $CellContext`cell, $CellContext`notebook, $CellContext`settings, $CellContext`aiAssistant },

        Needs[ "Wolfram`AIAssistant`" -> None ];

        $CellContext`cell        = EvaluationCell[ ];
        $CellContext`notebook    = Notebooks @ $CellContext`cell;
        $CellContext`settings    = CurrentValue[ $CellContext`notebook, { TaggingRules, "AIAssistantSettings" }, <| |> ];
        $CellContext`aiAssistant = Symbol[ "Wolfram`AIAssistant`AIAssistant" ];

        $CellContext`aiAssistant[ "RequestAIAssistant", $CellContext`cell, $CellContext`notebook, $CellContext`settings ];

        If[ ! TrueQ @ $CellContext`aiAssistant[ "Loaded" ],
            ResourceFunction[ "MessageFailure" ][ "AI assistant is unavailable due to an unknown error." ]
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
            Needs[ "Wolfram`AIAssistant`" -> None ];
            Symbol[ "Wolfram`AIAssistant`AIAssistant" ][ "RequestAIAssistant", EvaluationCell[ ] ],
            Null
        ]
    ],
    ContextMenu -> Flatten @ {
        MenuItem[
            "Ask AI Assistant",
            KernelExecute[
                Needs[ "Wolfram`AIAssistant`" -> None ];
                Symbol[ "Wolfram`AIAssistant`AIAssistant" ][ "Ask" ]
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
(*DotDotDotMenuCell*)
Cell[
    StyleData[ "DotDotDotMenuCell", StyleDefinitions -> StyleData[ "Text" ] ],
    With[
        {
            attach = Cell @ BoxData @ ToBoxes @ Button[
                $icons[ "ChatMenuIcon" ],
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
    StyleData[ "ChatInput", StyleDefinitions -> StyleData[ "DotDotDotMenuCell" ] ],
    MenuSortingValue         -> 1000,
    AutoQuoteCharacters      -> { },
    PasteAutoQuoteCharacters -> { },
    ShowCellLabel            -> False,
    CellGroupingRules        -> "InputGrouping",
    CellMargins              -> { { 40, 25 }, { 3, 10 } },
    CellFrameMargins         -> { { 5 , 25 }, { 3,  3 } },
    StyleKeyMapping          -> { "/" -> "ChatQuery", "?" -> "ChatQuery" },
    BackgroundAppearance     -> $icons[ "ChatInput9Patch" ],
    CellFrameLabels          -> {
        { Cell @ BoxData @ ToBoxes @ $icons[ "ChatUserIcon" ], None },
        { None, None }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatQuery*)
Cell[
    StyleData[ "ChatQuery", StyleDefinitions -> StyleData[ "ChatInput" ] ],
    MenuSortingValue     -> 1000,
    FontSlant            -> Italic,
    FontColor            -> GrayLevel[ 0.25 ],
    StyleKeyMapping      -> { "/" -> "ChatInput" },
    BackgroundAppearance -> $icons[ "ChatQuery9Patch" ],
    CellFrameMargins     -> { { 5, 5 }, { 3, 3 } },
    CellMargins          -> { { 40, 25 }, { 3, 10 } },
    CellFrameLabels      -> { { Cell @ BoxData @ ToBoxes @ $icons[ "ChatQueryIcon" ], None }, { None, None } }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput", StyleDefinitions -> StyleData[ "DotDotDotMenuCell" ] ],
    GeneratedCell        -> True,
    CellAutoOverwrite    -> True,
    CellGroupingRules    -> "OutputGrouping",
    CellFrameMargins     -> { { 10, 40 }, { 10, 10 } },
    CellMargins          -> { { 40, 25 }, { 10, 3 } },
    LineSpacing          -> { 1.1, 0, 2 },
    ShowAutoSpellCheck   -> False,
    CellElementSpacings  -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 },
    BackgroundAppearance -> $icons[ "ChatOutput9Patch" ],
    CellFrameLabels      -> { { Cell @ BoxData @ TemplateBox[ { }, "AssistantIcon" ], None }, { None, None } }
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
                Needs[ "Wolfram`AIAssistant`" -> None ];
                Symbol[ "Wolfram`AIAssistant`AIAssistant" ][ "Ask" ]
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
                Needs[ "Wolfram`AIAssistant`" -> None ];
                Symbol[ "Wolfram`AIAssistant`AIAssistant" ][ "Ask" ]
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

End[ ];