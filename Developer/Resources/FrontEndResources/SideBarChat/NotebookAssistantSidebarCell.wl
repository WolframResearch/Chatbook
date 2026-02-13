Cell[
	BoxData[
		RowBox[
			{
				DynamicBox[
					ToBoxes[
						Needs[ "Wolfram`Chatbook`" -> None ];
						RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSidebarChatDockedCell" ],
						StandardForm ],
					DestroyAfterEvaluation -> True
				],
				DynamicBox[
					ToBoxes[
						Needs[ "Wolfram`Chatbook`" -> None ];
						RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSidebarChatScrollingCell" ],
						StandardForm ],
					DestroyAfterEvaluation -> True
				],
				DynamicBox[
					ToBoxes[
						Needs[ "Wolfram`Chatbook`" -> None ];
						RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSidebarChatInputCell" ],
						StandardForm ],
					DestroyAfterEvaluation -> True
				]
			}
		]
	],
	Background        -> color @ "NA_ChatInputFieldBackgroundArea", (* this colors the entire initial sidebar as gray to make it easier to see *)
	CellFrameMargins  -> 0,
	CellMargins       -> { { 0, 0 }, { 0, 0 } },
	CellTags          -> "NotebookAssistantSidebarCell",
	Editable          -> True,
	FontSize          -> 0.5, (* needed to workaround line wrapping issue where newlines are given their full line-height based on the FontSize *)
	Initialization    :>
		With[ { Typeset`ec = EvaluationCell[ ] },
			AttachCell[ Typeset`ec, Cell[ "", CellTags -> "NotebookAssistantSidebarAttachedHelperCell" ], { Left, Top }, 0, { Left, Top } ];
			Needs[ "Wolfram`Chatbook`" -> None ];
			CurrentValue[ Typeset`ec, TaggingRules ] = <| "ChatNotebookSettings" -> Wolfram`Chatbook`NotebookAssistanceSidebarSettings[ ], "ConversationTitle" -> "" |>],
	LineIndent        -> 0,
	LineSpacing       -> { 1, 0 },
	Magnification     -> 1.,
	Selectable        -> False,
	ShowCursorTracker -> False
]