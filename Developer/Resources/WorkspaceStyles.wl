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
    "ShowChatbar"          -> False,
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
    FontColor       -> color @ "NA_BlueHueButtonIcon",
    FontFamily      -> "Source Sans Pro",
    FontSize        -> 13.5,
    FontWeight      -> "DemiBold",
    LineBreakWithin -> False
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
    CellDingbat      -> None,
    CellEventActions -> None,
    CellFrame        -> 0,
    CellFrameLabels  -> None,
    CellMargins      -> { { 10, 5 }, { 5, 10 } },
    FrameBoxOptions  -> { BaselinePosition -> Baseline },
    PaneBoxOptions   -> { BaselinePosition -> Baseline },
    Selectable       -> False,
    ShowCellBracket  -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput" ],
    Background      -> None,
    CellDingbat     -> None,
    CellFrame       -> 0,
    CellMargins     -> { { 10, 5 }, { 30, 12 } },
    FrameBoxOptions -> { BaselinePosition -> Baseline },
    Initialization  -> None,
    PaneBoxOptions  -> { BaselinePosition -> Baseline },
    Selectable      -> False,
    ShowCellBracket -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInputField*)
Cell[
    StyleData[ "ChatInputField" ],
    CellFrame        -> 1,
    CellFrameColor   -> color @ "NA_ChatInputFieldCellFrame",
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
(*UserMessageBox - user icon on left side but content right-aligned *)
Cell[
    StyleData[ "UserMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ userMessageBoxFrame[ # ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AssistantMessageBox - only a few minor style tweaks compared to definition in Chatbook.nb *)
Cell[
    StyleData[ "AssistantMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ TagBox[ assistantMessageBoxFrame[ # ], assistantMessageBoxEventHandler ]
    }
]

(*AssistantMessageBoxActive - during stream-of-thought from the LLM, don't add attachments *)
Cell[
    StyleData[ "AssistantMessageBoxActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ assistantMessageBoxFrame[ # ]
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
                            (* Don't line break: assume the LLM returns code that is compact, and rely on automatic scrollbars otherwise *)
                            AppearanceElements -> None,
                            BaseStyle          -> { LineBreakWithin -> False }, 
                            ImageSize          -> { Scaled[ 1 ], UpTo[ 400 ] },
                            Scrollbars         -> Automatic
                        ],
                        Background   -> color @ "NA_ChatCodeBlockTemplateBackgroundTop",
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_ChatCodeBlockTemplateFrame" ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Full, Automatic }
                    ]
                },
                { chatCodeBlockTemplateButtonFrame[ DynamicBox[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ #1, #2 ], SingleEvaluation -> True ] ] }
            },
            DefaultBaseStyle -> "Column",
            GridBoxAlignment -> { "Columns" -> { { Left } } },
            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxSpacings  -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
        ]
    }
]

(*ChatCodeBlockTemplateActive - during stream-of-thought from the LLM, show inactive buttons *)
Cell[
    StyleData[ "ChatCodeBlockTemplateActive" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @
        GridBox[
            {
                { 
                    FrameBox[
                        #1, (* don't use Pane during active stream-of-thought as it may capture mouse-wheel events *)
                        Alignment    -> { Left, Top },
                        Background   -> color @ "NA_ChatCodeBlockTemplateBackgroundTop",
                        BaseStyle    -> { LineBreakWithin -> False }, 
                        FrameMargins -> { { 10, 10 }, { 6, 6 } },
                        FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_ChatCodeBlockTemplateFrame" ],
                        ImageMargins -> { { 0, 0 }, { 0, 8 } },
                        ImageSize    -> { Scaled[ 1 ], UpTo[ 400 ] }
                    ]
                },
                { chatCodeBlockTemplateButtonFrame[ ToBoxes @ Wolfram`Chatbook`Common`floatingButtonGrid[ "Disabled", None ] ] }
            },
            DefaultBaseStyle -> "Column",
            GridBoxAlignment -> { "Columns" -> { { Left } } },
            GridBoxItemSize  -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
            GridBoxSpacings  -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
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