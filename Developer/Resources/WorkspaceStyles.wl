(* ::Section::Closed:: *)
(*Package Header*)
Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


color = Wolfram`Chatbook`Common`color;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    Background             -> color @ "NA_NotebookBackground",
    CellInsertionPointCell -> None,
    "ClosingSaveDialog"    -> False,
    DefaultNewCellStyle    -> "AutoMoveToChatInputField",
    DockedCells            -> $workspaceChatDockedCells,
    Magnification          -> 0.85,
    NotebookEventActions   -> {
        ParentList,
        { "MenuCommand", "SaveRename" } :> (
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`SaveAsChatNotebook" ][ EvaluationNotebook[ ] ]
        )
    },
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
(* ::Subsection::Closed:: *)
(*Fade When Not Selected*)

Cell[
    StyleData[ "AttachedCell" ],
    PrivateCellOptions -> { "ContentsOpacity" -> Dynamic @ If[ CurrentValue[ "NotebookSelected" ], 1, 0.5 ] }
]


Cell[
    StyleData[ "DockedCell" ],
    PrivateCellOptions -> { "ContentsOpacity" -> Dynamic @ If[ CurrentValue[ "NotebookSelected" ], 1, 0.5 ] }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceChatToolbarLabel*)
Cell[
    StyleData[ "WorkspaceChatToolbarButtonLabel", StyleDefinitions -> StyleData[ "Text" ] ],
    FontColor  -> color @ "NA_ToolbarFont",
    FontSize   -> 13,
    FontWeight -> "DemiBold"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceChatToolbarTitle*)
Cell[
    StyleData[ "WorkspaceChatToolbarTitle", StyleDefinitions -> StyleData[ "WorkspaceChatToolbarButtonLabel" ] ],
    FontColor -> color @ "NA_ToolbarTitleFont",
    FontSize  -> 12
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
    CellMargins           -> { { 10, 15 }, { 30, 12 } },
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
                Background     -> color @ "UserMessageBoxBackground",
                FrameMargins   -> { { 8, 15 }, { 8, 8 } },
                FrameStyle     -> color @ "UserMessageBoxFrame",
                RoundingRadius -> 8, (* TWEAK *)
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
                Background     -> color @ "NA_AssistantMessageBoxBackground", (* TWEAK *)
                FrameMargins   -> 8,
                FrameStyle     -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_AssistantMessageBoxFrame" ], (* TWEAK *)
                ImageSize      -> { Scaled[ 1 ], Automatic },
                RoundingRadius -> 8, (* tweaked *)
                StripOnInput   -> False
            ],
            EventHandlerTag @ {
                "MouseEntered" :>
                    If[ TrueQ @ $CloudEvaluation,
                        Null,
                        With[ { cell = EvaluationCell[ ] },
                            Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AttachAssistantMessageButtons", cell ]
                        ]
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
                        PaneBox[
                            #1,
                            AppearanceElements -> None,
                            ImageSize          -> { Scaled[ 1 ], UpTo[ 400 ] },
                            Scrollbars         -> Automatic
                        ],
                        Background   -> color @ "NA_ChatCodeBlockTemplateBackgroundTop",
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_ChatCodeBlockTemplateFrame" ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ] },
                {
                    FrameBox[
                        DynamicBox[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ #1, #2 ] ],
                        Background   -> color @ "NA_ChatCodeBlockTemplateBackgroundBottom",
                        FrameMargins -> { { 7, 2 }, { 2, 2 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_ChatCodeBlockTemplateFrame" ],
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
                                FontColor  -> color @ "WelcomeToCodeAssistanceSplashTitleFont"
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
                    BaseStyle -> { "Text", FontSize -> 13, FontColor -> color @ "WelcomeToCodeAssistanceSplashFont", LineBreakWithin -> False },
                    Spacings  -> { 1, { 0, 1.25, 1.25, 0.75 } }
                ],
                Alignment       -> { Center, Automatic },
                ImageSize       -> { Scaled[ 1 ], Automatic },
                ImageSizeAction -> "ShrinkToFit"
            ],
            Alignment      -> { Center, Automatic },
            Background     -> color @ "WelcomeToCodeAssistanceSplashBackground",
            FrameMargins   -> { { 10, 10 }, { 10, 10 } },
            FrameStyle     -> color @ "WelcomeToCodeAssistanceSplashFrame",
            ImageSize      -> { Automatic, Automatic },
            RoundingRadius -> 10
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Generated Styles*)
Cell[
    StyleData[ "PrintTemporary" ],
    CellMargins -> { { 30, Inherited }, { Inherited, Inherited } },
    Selectable  -> True
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];