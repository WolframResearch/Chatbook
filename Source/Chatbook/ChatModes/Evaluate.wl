(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`Evaluate`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Evaluate Alternate Chat Inputs*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateWorkspaceChat*)
evaluateWorkspaceChat // beginDefinition;

evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input: _Symbol|_CurrentValue ] ] := Enclose[
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

evaluateWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreWorkspaceChatInput*)
restoreWorkspaceChatInput // beginDefinition;

restoreWorkspaceChatInput[ Dynamic[ input_ ], value_ ] :=
    If[ ! validInputStringQ @ input, input = $WorkspaceChatInput = value ];

restoreWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*appendCellToSidebarChat*)
appendCellToSidebarChat // beginDefinition;

appendCellToSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, cell_Cell, uuid_String ] := Enclose[
    Module[ { scrollablePaneCell, lastDockedCell, chatCells, lastContentCell, cellObject },
        (* find the last top cell, or docked cell if there are no content cells *)
        (* all old top-cells are within an inline cell that scrolls. Overwrite that cell if it exists, otherwise create it anew *)
        scrollablePaneCell = First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], Missing @ "NoScrollingContent" ];
        If[ MissingQ @ scrollablePaneCell,
            lastDockedCell = ConfirmMatch[ Last[ Cells[ sidebarCell, CellTags -> "SidebarDockedCell" ], $Failed ], _CellObject, "SidebarDockedCell" ];
            NotebookWrite[ NotebookLocationSpecifier[ lastDockedCell, "After" ], makeSidebarChatScrollingCell[ nbo, sidebarCell, { cell } ] ];
            scrollablePaneCell = ConfirmMatch[ First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], $Failed ], _CellObject, "UpdatedSidebarScrollableCell" ];
            , (* ELSE *)
            chatCells = Cells[ scrollablePaneCell, CellTags -> "SidebarTopCell" ];
            If[ chatCells === { }, (* rewrite the entire cell if it has no content; this removes the "AskAnything" content *)
                NotebookWrite[ scrollablePaneCell, makeSidebarChatScrollingCell[ nbo, sidebarCell, { cell } ] ];
                scrollablePaneCell = ConfirmMatch[ First[ Cells[ sidebarCell, CellTags -> "SidebarScrollingContentCell" ], $Failed ], _CellObject, "NoNewScrollingContentCell" ];
                ,
                lastContentCell = ConfirmMatch[ Last[ chatCells, $Failed ], _CellObject, "NoSidebarScrollingContentCell" ];
                NotebookWrite[ NotebookLocationSpecifier[ lastContentCell, "After" ], cell ]
            ]
        ];

        cellObject = ConfirmMatch[ Last[ Cells[ scrollablePaneCell, CellTags -> uuid ], $Failed ], _CellObject, "SidebarChatInputCellObject" ];
        setCurrentValue[ cellObject, CellTags, "SidebarTopCell" ];
        cellObject
    ],
    throwInternalFailure
];

appendCellToSidebarChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateSidebarChat*)
evaluateSidebarChat // beginDefinition;

(* The input field is optional, since the sidebar input cell of a front end session that started with an older version
   of Chatbook doesn't give it: *)
evaluateSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, input_, Dynamic[ cellObject_ ], field_: None ] := Enclose[
    WithCleanup[
        Module[ { text, uuid, cell, result },

            text = makeBoxesInputMoreTextLike @ input;
            uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];

            cell = Cell[
                BoxData @ TemplateBox[
                    { Cell[ text, Background -> None, Selectable -> True, Editable -> True ] },
                    "NotebookAssistant`Sidebar`UserMessageBox"
                ],
                "NotebookAssistant`Sidebar`ChatInput",
                (* If we were writing this CellObject as a top-level cell then we could use ExpressoinUUID to coerce the front end use a pre-specified UUID.
                    However, the side bar is a more complicated Cell within a Cell and in that case the ExpressoinUUID is dropped. *)
                CellTags -> uuid
            ];

            cellObject = appendCellToSidebarChat[ nbo, sidebarCell, cell, uuid ];
            result = ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ];

            If[ unansweredChatInputQ[ cellObject, result ],
                NotebookDelete @ cellObject;
                restoreSidebarChatInput[ field, input ]
            ];

            result
        ],
        With[ { selections = CurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" } ] },
            If[ AssociationQ @ selections, FE`Evaluate @ FEPrivate`ReleaseSelectionObjects @ selections ];
            setCurrentValue[ sidebarCell, { TaggingRules, "CurrentSelections" }, Inherited ]
        ]
    ],
    throwInternalFailure
];

evaluateSidebarChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreSidebarChatInput*)
restoreSidebarChatInput // beginDefinition;
restoreSidebarChatInput[ Dynamic[ field_ ], input_ ] := If[ ! validInputStringQ @ field, field = input ];
restoreSidebarChatInput[ None, _ ] := Null;
restoreSidebarChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeBoxesInputMoreTextLike*)
makeBoxesInputMoreTextLike // beginDefinition;

makeBoxesInputMoreTextLike[ input_String ] := input;

makeBoxesInputMoreTextLike[ boxes_ ] := Enclose[
    Module[ { simplerStringLikeBoxes, nonStringBoxPositions },
        (* Flatten input boxes *)
        simplerStringLikeBoxes =
            ReplaceRepeated[
                boxes,
                {
                    RowBox[ { a___, b1_String, b2_String, c___ } ] :> RowBox[ { a, StringJoin[ b1, b2 ], c} ],
                    RowBox[ { a___, RowBox[ { b___ } ],   c___ } ] :> RowBox[ { a, b, c } ]
                }
            ];

        (* wrap non-string box expressions in BoxData cells *)
        nonStringBoxPositions = Cases[ Position[ simplerStringLikeBoxes, Except[ RowBox | List, _Symbol ], Heads -> True ], { e___, 0 } :> { e } ];
        nonStringBoxPositions = Pick[ nonStringBoxPositions, Length /@ nonStringBoxPositions, Min[ Length /@ nonStringBoxPositions ] ];
        simplerStringLikeBoxes =
            ReplacePart[
                simplerStringLikeBoxes,
                Thread[
                    Rule[
                        nonStringBoxPositions,
                        Map[ Cell[ BoxData[ # ] ]&, Extract[ simplerStringLikeBoxes, nonStringBoxPositions ] ]
                    ]
                ]
            ];

        (* *)
        Switch[ simplerStringLikeBoxes,
            RowBox[ { _String } ], simplerStringLikeBoxes[[ 1, 1 ]],
            RowBox[ { __ } ],      TextData @@ simplerStringLikeBoxes,
            _List,                 TextData @ simplerStringLikeBoxes,
            _,                     Cell @ simplerStringLikeBoxes (* FIXME: should we throw an error instead? *)
        ]
    ],
    throwInternalFailure
];

makeBoxesInputMoreTextLike // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unansweredChatInputQ*)
(* A chat that is stopped before its response arrives leaves no cell after its input, since StopChat removes the output
   cell. Its input would stay in the chat history, and the next message's response would answer it too (#1710). A
   regular ChatInput cell is left as it is, since it can be evaluated again or deleted. In the assistant window and the
   sidebar, the input is removed, and its text is put back in the input field (unless something was typed there since
   the chat was sent), where it can be edited and sent again.
   A chat that got a response gives a ChatObject, so the front end is only asked for the next cell otherwise. A failed
   request also gives Null, but it leaves an error cell (which isn't a chat output cell) after the input.
   Note: appendCellToSidebarChat writes new sidebar chats after the last "SidebarTopCell", which an error cell isn't, so
   after a failed request, later sidebar inputs are followed by the error cell and are kept even if stopped: *)
unansweredChatInputQ // beginDefinition;
unansweredChatInputQ[ _CellObject, _ChatObject ] := False;
unansweredChatInputQ[ cell_CellObject, Null ] := ! MatchQ[ NextCell @ cell, _CellObject ];
unansweredChatInputQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validInputStringQ*)
(* LLM-712: adding images as allowed input means we must be much more permissive in validating chat input *)
validInputStringQ // beginDefinition;
validInputStringQ[ "" ] := False;
validInputStringQ[ input_String? StringQ ] := ! StringMatchQ[ input, WhitespaceCharacter... ];
validInputStringQ[ Null ] := False;
validInputStringQ[ RowBox[ boxes_List ] ] := AnyTrue[ boxes, validInputStringQ ];
validInputStringQ[ boxes_ ] := True;
validInputStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
