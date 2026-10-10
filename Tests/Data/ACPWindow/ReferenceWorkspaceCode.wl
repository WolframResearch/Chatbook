(* Reference copies of Notebook Assistant window code as it was before agent (ACP) windows were added
   (git 1dc660a4, Source/Chatbook/ChatModes/UI.wl and Source/Chatbook/ChatModes/Evaluate.wl).
   Tests/ACPWindow.wlt loads this file in the original private contexts and checks that the current code still gives
   identical results. Do not edit these definitions. *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*attachedWorkspaceChatInputCell*)
Begin[ "Wolfram`Chatbook`ChatModes`UI`Private`" ];

referenceAttachedWorkspaceChatInputCell[ location_String ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB, cachedSessionID = $SessionID, cachedChatInput = "", kernelWasQuitQ = False },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            Framed[
                                Grid[
                                    { {
                                        workspaceInputField[ Dynamic @ cachedChatInput ],
                                        (* no need to templatize an attached cell as it is ephemeral *)
                                        PaneSelector[
                                            {
                                                None -> Button[
                                                    blueHueButtonAppearance[ chatbookIcon[ "SendChatArrow", False, color @ "NA_BlueHueButtonIcon", 13 ], { 24.5, 24.5 } ],
                                                    Needs[ "Wolfram`Chatbook`" -> None ];
                                                    (* in case kernel was quit and the user hasn't typed something new into the search field, restore it to the cached value *)
                                                    If[ kernelWasQuitQ,
                                                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                                                        If[ $WorkspaceChatInput =!= cachedChatInput, $WorkspaceChatInput = cachedChatInput ];
                                                        kernelWasQuitQ = False ];
                                                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                                        "EvaluateWorkspaceChat",
                                                        thisNB,
                                                        Dynamic @ $WorkspaceChatInput
                                                    ],
                                                    Appearance   -> "Suppressed",
                                                    BoxID        -> "NASendChatButton",
                                                    FrameMargins -> 0,
                                                    Method       -> "Queued"
                                                ]
                                            },
                                            Dynamic @ Wolfram`Chatbook`$ChatEvaluationCell,
                                            Button[
                                                blueHueButtonAppearance[ chatbookIcon[ "StopChatButton", False, 21 ], { 24.5, 24.5 } ],
                                                Needs[ "Wolfram`Chatbook`" -> None ];
                                                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
                                                Appearance   -> "Suppressed",
                                                BoxID        -> "NAStopChatButton",
                                                FrameMargins -> 0
                                            ],
                                            Alignment -> { Automatic, Baseline }
                                        ]
                                    } },
                                    Alignment        -> { Left, Baseline },
                                    BaselinePosition -> { 1, 1 },
                                    Spacings         -> { 0, 0 }
                                ],
                                $inputFieldFrameOptions
                            ]
                        },
                        {
                            Item[ Dynamic @ focusedNotebookDisplay[ thisNB, None ], Alignment -> Left ]
                        }
                    },
                    Alignment -> { Left, Baseline },
                    BaseStyle -> { Magnification -> $inputFieldGridMagnification },
                    Spacings  -> { 0.5, 0.0 }
                ],
                FrameMargins -> $inputFieldPaneMargins,
                ImageSize ->
                    If[ location === "Top",
                        Dynamic @ {
                            Automatic,
                            AbsoluteCurrentValue[ thisNB, { WindowSize, 2 } ] /
                                AbsoluteCurrentValue[ thisNB, Magnification ]
                        },
                        Automatic
                    ]
            ],
            {
                "ReturnKeyDown" :> (
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    (* in case kernel was quit and the user hasn't typed something new into the search field, restore it to the cached value *)
                    If[ kernelWasQuitQ,
                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                        If[ $WorkspaceChatInput =!= cachedChatInput, $WorkspaceChatInput = cachedChatInput ];
                        kernelWasQuitQ = False ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        thisNB,
                        Dynamic @ $WorkspaceChatInput
                    ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ]; kernelWasQuitQ = cachedSessionID =!= $SessionID; cachedSessionID = $SessionID)
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> location,
    Magnification :> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ],
    Selectable    -> True
];

End[ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*evaluateWorkspaceChat*)
Begin[ "Wolfram`Chatbook`ChatModes`Evaluate`Private`" ];

referenceEvaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
    Catch @ Module[ { text, uuid, cell, cellObject },

        If[ ! validInputStringQ @ input, input = ""; Throw @ Null ];
        text = makeBoxesInputMoreTextLike @ input;
        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];

        cell = Cell[
            BoxData @ TemplateBox[
                { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                "UserMessageBox"
            ],
            "ChatInput",
            CellTags -> uuid
        ];

        input = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        setCurrentValue[ cellObject, CellTags, { } ];
        ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
    ],
    throwInternalFailure
];

End[ ];

(* :!CodeAnalysis::EndBlock:: *)
