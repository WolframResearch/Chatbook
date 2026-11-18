(* Reference copies of Notebook Assistant window code as it is without agent (ACP) windows
   (main at git a9d24e2b, Source/Chatbook/ChatModes/UI.wl and Source/Chatbook/ChatModes/Evaluate.wl).
   Tests/ACPWindow.wlt loads this file in the original private contexts and checks that the current code still gives
   identical results. Do not edit these definitions; copy them again from main when main changes them. *)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*attachedWorkspaceChatInputCell*)
Begin[ "Wolfram`Chatbook`ChatModes`UI`Private`" ];

referenceAttachedWorkspaceChatInputCell[ location_String ] := Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB, thisCell, cachedSessionID = $SessionID, kernelWasQuitQ = False },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            Framed[
                                Grid[
                                    { {
                                        (* the text is stored in the cell's TaggingRules, so typing does not need the
                                           kernel once the Initialization below has set thisCell *)
                                        workspaceInputField[ Dynamic @ CurrentValue[ thisCell, { TaggingRules, "ChatInputString" } ] ],
                                        (* no need to templatize an attached cell as it is ephemeral *)
                                        (* use explicit keys for both buttons: the front end keeps animating the stop
                                           button's spinner in the default pane even while it's hidden, which burns CPU
                                           when idle. With no default pane, nothing shows for a value that matches no
                                           key, so chatEvaluatingInDynamic always gives True or False *)
                                        PaneSelector[
                                            {
                                                False -> Button[
                                                    blueHueButtonAppearance[ chatbookIcon[ "SendChatArrow", False, color @ "Blue_128ED1_7FC7FB", 13 ], { 24.5, 24.5 } ],
                                                    Needs[ "Wolfram`Chatbook`" -> None ];
                                                    (* in case kernel was quit *)
                                                    If[ kernelWasQuitQ,
                                                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                                                        kernelWasQuitQ = False ];
                                                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                                        "EvaluateWorkspaceChat",
                                                        thisNB,
                                                        Dynamic @ CurrentValue[ thisCell, { TaggingRules, "ChatInputString" } ]
                                                    ],
                                                    Appearance   -> "Suppressed",
                                                    BoxID        -> "NASendChatButton",
                                                    FrameMargins -> 0,
                                                    Method       -> "Queued"
                                                ],
                                                True -> Button[
                                                    blueHueButtonAppearance[ chatbookIcon[ "StopChatButton", False, 21 ], { 24.5, 24.5 } ],
                                                    Needs[ "Wolfram`Chatbook`" -> None ];
                                                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChatIn", EvaluationNotebook[ ] ],
                                                    Appearance   -> "Suppressed",
                                                    BoxID        -> "NAStopChatButton",
                                                    FrameMargins -> 0
                                                ]
                                            },
                                            chatEvaluatingInDynamic @ EvaluationNotebook[ ],
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
                            (*
                                The display reads Chatbook globals that change on every catchTop call and during chats
                                (e.g. catchTop and $currentSettingsCache), so only track thisNB in the kernel. The front
                                end still tracks the front end values it reads, such as Notebooks[], SelectedNotebook[],
                                InputNotebook[] and TaggingRules (e.g. the focus menu lock), but not window titles from
                                NotebookInformation (with any TrackedSymbols), so a renamed notebook shows its new title
                                after the next tracked change. *)
                            Item[
                                Dynamic[ focusedNotebookDisplay[ thisNB, None ], TrackedSymbols :> { thisNB } ],
                                Alignment -> Left
                            ]
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
                    (* in case kernel was quit *)
                    If[ kernelWasQuitQ,
                        If[ Not @ TrueQ @ $workspaceChatInitialized, initializeWorkspaceChat[ ] ];
                        kernelWasQuitQ = False ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateWorkspaceChat",
                        thisNB,
                        Dynamic @ CurrentValue[ thisCell, { TaggingRules, "ChatInputString" } ]
                    ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ]; thisCell = EvaluationCell[ ]; kernelWasQuitQ = cachedSessionID =!= $SessionID; cachedSessionID = $SessionID)
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> location,
    Magnification :> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ],
    Selectable    -> True,
    TaggingRules  -> <| "ChatInputString" -> $WorkspaceChatInput |>
];

End[ ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*evaluateWorkspaceChat*)
Begin[ "Wolfram`Chatbook`ChatModes`Evaluate`Private`" ];

referenceEvaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
    Catch @ Module[ { value, text, uuid, cell, cellObject, result },

        value = input;

        (* The input cell no longer exists, e.g. a send that was queued behind a chat runs after "New Chat" replaced the
           input cell. Its text is in the new input cell, so nothing is sent or cleared (#1719): *)
        If[ value === $Failed, Throw @ Null ];

        (* $WorkspaceChatInput is a kernel-side copy of the input field text, so it is cleared along with the input: *)
        If[ ! validInputStringQ @ value, input = $WorkspaceChatInput = ""; Throw @ Null ];
        text = makeBoxesInputMoreTextLike @ value;
        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];

        cell = Cell[
            BoxData @ TemplateBox[
                { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                "UserMessageBox"
            ],
            "ChatInput",
            CellTags -> uuid
        ];

        input = $WorkspaceChatInput = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        setCurrentValue[ cellObject, CellTags, { } ];
        result = ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ];

        If[ unansweredChatInputQ[ cellObject, result ],
            NotebookDelete @ cellObject;
            (* The input cell may have been moved to the bottom of the window since the chat was sent: *)
            restoreWorkspaceChatInput[ workspaceChatInput @ nbo, value ];
            (* Like "New Chat", an empty window has the input cell at the top. Note: this replaces the input cell, so a
               send that was queued behind this chat isn't sent, though its text is kept in the new input cell (#1719): *)
            If[ Cells @ nbo === { }, moveChatInputToTop @ nbo ]
        ];

        result
    ],
    throwInternalFailure
];

End[ ];

(* :!CodeAnalysis::EndBlock:: *)
