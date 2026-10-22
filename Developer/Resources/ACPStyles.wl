(* ::Section::Closed:: *)
(*Package Header*)
Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];

(* Styles for agent (ACP) windows: Wolfram/ACPChat.nb inherits Wolfram/WorkspaceChat.nb and only replaces the
   notebook-level setup (docked cells, settings, event actions) and makes ChatInput cells inert.
   Templates are not defined here: ACP cells use the standard UserMessageBox, AssistantMessageBox[Active],
   ThoughtsOpener and ShortThoughts templates, so copied/converted cells render anywhere. *)

color = Wolfram`Chatbook`Common`color;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Docked Cells*)
$acpChatDockedCells = {
    (* Same style name as the notebook assistance window's progress stripe, but driven by the notebook-level busy flag
       ({TaggingRules, "ACP", "Busy"}), which the kernel sets while a turn is running. The animation runs entirely in
       the front end. *)
    With[
        {
            background  = LightDarkSwitched[ RGBColor[ "#128ED1" ], RGBColor[ "#7FC7FB" ] ],
            colorCenter = LightDarkSwitched[ RGBColor[ "#E0F2FC" ], RGBColor[ "#F5F5F5" ] ],
            colorEdges  = LightDarkSwitched[ RGBColor[ "#128ED1" ], RGBColor[ "#7FC7FB" ] ]
        },
        Cell[ BoxData @
            ToBoxes @ PaneSelector[
                {
                    True -> RawBoxes @ DynamicModuleBox[ { Typeset`v$$ = 0 },
                        OverlayBox[
                            {
                                AnimatorBox[ Dynamic[ Typeset`v$$ ], { 0, 1.2 }, AppearanceElements -> { }, ImageSize -> { 1, 1 }, DefaultDuration -> 2.5 ],
                                GraphicsBox[
                                    {
                                        Thickness[ 1 ],
                                        LineBox[
                                            Dynamic[ { { -0.2 + Typeset`v$$, 0 }, { -0.1 + Typeset`v$$, 0 }, { Typeset`v$$, 0 } } ],
                                            VertexColors -> { colorEdges, colorCenter, colorEdges }
                                        ]
                                    },
                                    AspectRatio      -> Full,
                                    Background       -> background,
                                    ImageMargins     -> 0,
                                    ImageSize        -> { Scaled[ 1 ], 15 },
                                    PlotRange        -> { { 0, 1 }, Automatic },
                                    PlotRangePadding -> None
                                ]
                            }
                        ],
                        DynamicModuleValues :> { }
                    ]
                },
                Dynamic @ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Busy" } ],
                Graphics[ Background -> background, ImageSize -> { 1, 1 } ],
                ImageSize -> Automatic
            ],
            "NotebookAssistant`TopStripe",
            Background       -> background,
            CellFrame        -> False,
            CellFrameMargins -> { { 0, 0 }, { 0, -5 } },
            CellMargins      -> 0,
            CellSize         -> { Automatic, 12 },
            Evaluator        -> None
        ]
    ],
    (* The toolbar is built by the kernel once (DestroyAfterEvaluation). Its Initialization attaches the input field and
       starts connecting. The options must match acpToolbarDockedCell in Source/Chatbook/ACP/UI.wl. *)
    Cell[
        BoxData @ DynamicBox[
            ToBoxes[
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeACPChatDockedCell" ],
                StandardForm
            ],
            DestroyAfterEvaluation -> True
        ],
        CellFrame        -> 0,
        CellFrameMargins -> 0,
        CellMargins      -> { { -1, -5 }, { -1, -1 } },
        CellTags         -> "ACPToolbar",
        Magnification    -> Dynamic[ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
    ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)
Cell[
    StyleData[ "Notebook" ],
    DockedCells          -> $acpChatDockedCells,
    NotebookEventActions -> {
        ParentList,
        (* Disconnect the agent when the window is closed (the action only schedules the cleanup) *)
        "WindowClose" :> (
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "WindowClosed", EvaluationNotebook[ ] ]
        )
    },
    TaggingRules -> <|
        "ChatNotebookSettings" -> <|
            $workspaceDefaultSettings,
            "ACPWindow"             -> True,
            "AppName"               -> "ACP",
            "AutoGenerateTitle"     -> False,
            "AutoSaveConversations" -> False
        |>
    |>,
    WindowTitle -> Dynamic @ FEPrivate`FrontEndResource[ "ChatbookStrings", "ACPWindowTitle" ]
]


Cell[
    StyleData[ "ACPChatStyleSheetInformation" ],
    TaggingRules -> <| "ACPChatStyleSheetVersion" -> $stylesheetVersion |>
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ChatInput*)

(* User messages are sent by the input field; they must never start the Chatbook LLM pipeline (e.g. through
   "Evaluate Cells" or Regenerate). *)
Cell[
    StyleData[ "ChatInput" ],
    CellEvaluationFunction -> (Null &),
    Evaluatable            -> False
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
