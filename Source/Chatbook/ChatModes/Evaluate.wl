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
    Catch @ Module[ { text, uuid, cell, cellObject },

        (* $WorkspaceChatInput is a kernel-side copy of the input field text, so it is cleared along with the input: *)
        If[ ! validInputStringQ @ input, input = $WorkspaceChatInput = ""; Throw @ Null ];
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

        input = $WorkspaceChatInput = "";
        SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
        NotebookWrite[ nbo, cell ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        setCurrentValue[ cellObject, CellTags, { } ];
        ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
    ],
    throwInternalFailure
];

evaluateWorkspaceChat // endDefinition;

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

evaluateSidebarChat[ nbo_NotebookObject, sidebarCell_CellObject, input_, Dynamic[ cellObject_ ] ] := Enclose[
    WithCleanup[
        Module[ { text, uuid, cell },

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
            ConfirmMatch[ ChatCellEvaluate[ cellObject, nbo ], _ChatObject|Null, "ChatCellEvaluate" ]
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
