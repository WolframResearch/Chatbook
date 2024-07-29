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
(*Template Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*WorkspaceSendChatButton*)
Cell[
    StyleData[ "WorkspaceSendChatButton" ],
    TemplateBoxOptions -> {
        DisplayFunction -> Function @ Evaluate @ ToBoxes @ PaneSelector[
            {
                None -> Button[
                    RawBoxes @ TemplateBox[ { #1, #2, #3 }, "SendChatButtonLabel" ],
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
                RawBoxes @ TemplateBox[ { #1, #2, #3 }, "StopChatButtonLabel" ],
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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];