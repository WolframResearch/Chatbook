(* ::Section::Closed:: *)
(*Package Header*)
Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    Background             -> White,
    CellInsertionPointCell -> None,
    "ClosingSaveDialog"    -> False,
    DefaultNewCellStyle    -> "AutoMoveToChatInputField",
    DockedCells            -> $workspaceChatDockedCells,
    Magnification          -> 0.85,
    Saveable               -> False,
    Selectable             -> False,
    ShowCellBracket        -> False,
    TaggingRules           -> <| "ChatNotebookSettings" -> $workspaceDefaultSettings |>,
    WindowClickSelect      -> True,
    WindowElements         -> { "VerticalScrollBar", "MagnificationPopUp" },
    WindowFrameElements    -> { "CloseBox", "ResizeArea", "ZoomBox" },
    WindowMargins          -> { { 0, Automatic }, { Automatic, 0 } },
    WindowSize             -> { $sideChatWidth, Automatic },
    WindowTitle            -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "WorkspaceWindowTitle" ],
    WindowToolbars         -> { }
]


(* Ensure that raw cell expressions can be toggled back to formatted view: *)
Cell[
    StyleData[ "CellExpression" ],
    Selectable -> True
]


Cell[
    StyleData[ "WorkspaceChatStyleSheetInformation" ],
    TaggingRules -> <| "WorkspaceChatStyleSheetVersion" -> $stylesheetVersion |>
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceChatToolbarLabel*)
Cell[
    StyleData[ "WorkspaceChatToolbarButtonLabel", StyleDefinitions -> StyleData[ "Text" ] ],
    FontColor  -> White,
    FontSize   -> 13,
    FontWeight -> "DemiBold"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceChatToolbarTitle*)
Cell[
    StyleData[ "WorkspaceChatToolbarTitle", StyleDefinitions -> StyleData[ "WorkspaceChatToolbarButtonLabel" ] ],
    FontSlant  -> Italic,
    FontWeight -> Plain
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInput*)
Cell[
    StyleData[ "ChatInput" ],
    CellDingbat           -> None,
    CellEventActions      -> None,
    CellFrame             -> 0,
    CellFrameLabelMargins -> -15,
    CellMargins           -> { { 15, 15 }, { 5, 10 } },
    FrameBoxOptions       -> { BaselinePosition -> Baseline },
    PaneBoxOptions        -> { BaselinePosition -> Baseline },
    Selectable            -> False,
    ShowCellBracket       -> False,
    CellFrameLabels       -> {
        {
            None,
            Cell[
                BoxData @ DynamicBox[
                    ToBoxes[
                        Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "UserMessageLabel" ],
                        StandardForm
                    ],
                    SingleEvaluation -> True
                ],
                Background   -> None,
                CellBaseline -> Baseline
            ]
        },
        { None, None }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput" ],
    Background            -> None,
    CellDingbat           -> None,
    CellFrame             -> 0,
    CellFrameLabelMargins -> -5,
    CellMargins           -> { { 10, 15 }, { 25, 12 } },
    FrameBoxOptions       -> { BaselinePosition -> Baseline },
    Initialization        -> None,
    PaneBoxOptions        -> { BaselinePosition -> Baseline },
    Selectable            -> False,
    ShowCellBracket       -> False,
    CellFrameLabels       -> {
        {
            Cell[
                BoxData @ DynamicBox[
                    ToBoxes[
                        Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AssistantMessageLabel" ],
                        StandardForm
                    ],
                    SingleEvaluation -> True
                ],
                Background   -> None,
                CellBaseline -> Baseline
            ],
            None
        },
        { None, None }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInputField*)
Cell[
    StyleData[ "ChatInputField" ],
    CellFrame        -> 1,
    CellFrameColor   -> GrayLevel[ 0.85 ],
    CellFrameMargins -> { { 5, 5 }, { 0, 0 } }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AutoMoveToChatInputField*)
Cell[
    StyleData[ "AutoMoveToChatInputField" ],
    Initialization :> (
        NotebookDelete @ EvaluationCell[ ];
        Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MoveToChatInputField", EvaluationNotebook[ ], True ];
    )
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CodeAssistanceWelcomeCell*)
Cell[
    StyleData[ "CodeAssistanceWelcomeCell" ],
    CellMargins          -> { { 10, 10 }, { 30, 10 } },
    ShowStringCharacters -> False,
    TaggingRules         -> <| "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Template Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UserMessageBox - one minor style tweaks compared to definition in Chatbook.nb *)
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
                RoundingRadius -> 8, (* tweaked *)
                StripOnInput   -> False
            ],
            Alignment -> Right,
            ImageSize -> { Full, Automatic }
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AssistantMessageBox - only a few minor style tweaks compared to definition in Chatbook.nb *)
Cell[
    StyleData[ "AssistantMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ TagBox[
            FrameBox[
                #,
                BaseStyle      -> { "Text", Editable -> False, Selectable -> False },
                Background     -> RGBColor[ "#f9fdff" ], (* tweaked *)
                FrameMargins   -> 8,
                FrameStyle     -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#e0eff7" ] ], (* tweaked *)
                ImageSize      -> { Scaled[ 1 ], Automatic },
                RoundingRadius -> 8, (* tweaked *)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ChatCodeBlockTemplate - only a few minor style tweaks compared to definition in Chatbook.nb*)
Cell[
    StyleData[ "ChatCodeBlockTemplate" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @
        GridBox[
            {
                {
                    FrameBox[
                        #1,
                        Background   -> GrayLevel[ 1 ],
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], GrayLevel[ 0.89804 ] ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ] },
                {
                    FrameBox[
                        DynamicBox[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ #1, #2 ] ],
                        Background   -> RGBColor[ "#f9fdff" ],
                        FrameMargins -> { { 7, 2 }, { 2, 2 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], GrayLevel[ 0.89804 ] ],
                        ImageMargins -> { { 0, 0 }, { 8, -2 } }, (* negative margin to barely overlap the frame above *)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceSendChatButton*)
Cell[
    StyleData[ "WorkspaceSendChatButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ PaneSelector[
            {
                None -> Button[
                    Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ],
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        #4,
                        Dynamic @ CurrentValue[ #4, { TaggingRules, "ChatInputString" } ]
                    ],
                    Appearance   -> "Suppressed",
                    FrameMargins -> 0,
                    Method       -> "Queued"
                ]
            },
            Dynamic @ Wolfram`Chatbook`$ChatEvaluationCell,
            Button[
                Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #3 ] ],
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                Appearance   -> "Suppressed",
                FrameMargins -> 0
            ],
            Alignment -> { Automatic, Baseline }
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WelcomeToCodeAssistanceSplash*)
Cell[
    StyleData[ "WelcomeToCodeAssistanceSplash" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ Framed[
            Pane[
                Grid[
                    {
                        { Magnify[ RawBoxes @ TemplateBox[ { }, "ChatIconCodeAssistant" ], 5 ] },
                        {
                            Style[
                                "Welcome to Code Assistance Chat",
                                FontWeight -> Bold,
                                FontSize   -> 17,
                                FontColor  -> GrayLevel[ 0.25 ]
                            ]
                        },
                        { "Ask me anything using the input field below." },
                        {
                            Button[
                                "View Tutorial \[RightGuillemet]",
                                MessageDialog[ "Not implemented yet." ],
                                Appearance -> None,
                                BaseStyle  -> { "Link" }
                            ]
                        }
                    },
                    BaseStyle -> { "Text", FontSize -> 13, FontColor -> GrayLevel[ 0.5 ], LineBreakWithin -> False },
                    Spacings  -> { 1, { 0, 1.25, 1.25, 0.75 } }
                ],
                Alignment       -> { Center, Automatic },
                ImageSize       -> { Scaled[ 1 ], Automatic },
                ImageSizeAction -> "ShrinkToFit"
            ],
            Alignment      -> { Center, Automatic },
            Background     -> RGBColor[ "#fcfdff" ],
            FrameMargins   -> { { 10, 10 }, { 10, 10 } },
            FrameStyle     -> RGBColor[ "#ecf0f5" ],
            ImageSize      -> { Automatic, Automatic },
            RoundingRadius -> 10
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];