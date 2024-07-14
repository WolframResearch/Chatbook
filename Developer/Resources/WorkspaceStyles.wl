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
    WindowElements         -> { "VerticalScrollBar" },
    WindowFrame            -> "ModelessDialog",
    WindowFrameElements    -> { "CloseBox", "ResizeArea" },
    WindowMargins          -> { { 0, Automatic }, { 0, 0 } },
    WindowSize             -> { $sideChatWidth, Automatic },
    WindowTitle            -> "Code Assistance Chat",
    WindowToolbars         -> { }
]


Cell[
    StyleData[ "WorkspaceChatStyleSheetInformation" ],
    TaggingRules -> <| "WorkspaceChatStyleSheetVersion" -> $stylesheetVersion |>
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInput*)
Cell[
    StyleData[ "ChatInput" ],
    CellDingbat           -> None,
    CellFrame             -> 0,
    CellFrameLabelMargins -> 6,
    CellMargins           -> { { 15, 10 }, { 5, 10 } },
    Selectable            -> True,
    ShowCellBracket       -> False,
    TextAlignment         -> Right,
    CellFrameLabels       -> {
        { None, None },
        {
            None,
            Cell @ BoxData @ TemplateBox[
                {
                    DynamicBox[
                        ToBoxes[
                            Needs[ "Wolfram`Chatbook`" -> None ];
                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "UserMessageLabel" ],
                            StandardForm
                        ],
                        SingleEvaluation -> True
                    ]
                },
                "UserMessageLabel"
            ]
        }
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatOutput*)
Cell[
    StyleData[ "ChatOutput" ],
    Background      -> None,
    CellDingbat     -> None,
    CellFrame       -> 0,
    CellMargins     -> { { 10, 15 }, { 15, 12 } },
    Initialization  -> None,
    Selectable      -> True,
    ShowCellBracket -> False,
    CellFrameLabels -> {
        { None, None },
        {
            None,
            Cell @ BoxData @ TemplateBox[
                {
                    DynamicBox[
                        ToBoxes[
                            Needs[ "Wolfram`Chatbook`" -> None ];
                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AssistantMessageLabel" ],
                            StandardForm
                        ],
                        SingleEvaluation -> True
                    ]
                },
                "AssistantMessageLabel"
            ]
        }
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
(*MessageAuthorLabel*)
Cell[
    StyleData[ "MessageAuthorLabel", StyleDefinitions -> StyleData[ "Text" ] ],
    FontSize             -> 14,
    FontWeight           -> "DemiBold",
    ShowStringCharacters -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Template Boxes*)

(* ::**************************************************************************************************************:: *)
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

(* ::**************************************************************************************************************:: *)
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*UserMessageBox*)
Cell[
    StyleData[ "UserMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ FrameBox[
            Cell[ #, "Text", Background -> None ],
            Background     -> RGBColor[ "#edf4fc" ],
            FrameMargins   -> 8,
            FrameStyle     -> RGBColor[ "#a3c9f2" ],
            RoundingRadius -> 10,
            StripOnInput   -> False
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*AssistantMessageBox*)
Cell[
    StyleData[ "AssistantMessageBox" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ FrameBox[
            #,
            BaseStyle      -> "ChatOutput",
            Background     -> RGBColor[ "#fcfdff" ],
            FrameMargins   -> 8,
            FrameStyle     -> RGBColor[ "#c9ccd0" ],
            ImageSize      -> { Scaled[ 1 ], Automatic },
            RoundingRadius -> 10,
            StripOnInput   -> False
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
                    RawBoxes @ TemplateBox[ { #1, #2 }, "SendChatButtonLabel" ],
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        #3,
                        Dynamic @ CurrentValue[ #3, { TaggingRules, "ChatInputString" } ]
                    ],
                    FrameMargins -> 0,
                    Method       -> "Queued"
                ]
            },
            Dynamic @ Wolfram`Chatbook`$ChatEvaluationCell,
            Button[
                Overlay[
                    {
                        RawBoxes @ TemplateBox[ { #2 }, "ChatEvaluatingSpinner" ],
                        Graphics[
                            { RGBColor[ 0.71373, 0.054902, 0.0 ], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
                            ImageSize -> #2,
                            PlotRange -> 1.1
                        ]
                    },
                    Alignment -> { Center, Center }
                ],
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                FrameMargins -> 0
            ],
            Alignment -> { Automatic, Baseline }
        ]
    }
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];