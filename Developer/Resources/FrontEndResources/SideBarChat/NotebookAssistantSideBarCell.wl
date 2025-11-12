Cell[
	BoxData[
		RowBox[
			{
				DynamicBox[
					ToBoxes[
						Needs[ "Wolfram`Chatbook`" -> None ];
						RawBoxes @ Cell[
							BoxData @ ToBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSideBarChatDockedCell" ],
							CellTags      -> "SideBarDockedCell",
							Magnification -> Dynamic[ 0.85*AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ] ]
						],
						StandardForm ],
					DestroyAfterEvaluation -> True
				],
				"\n",
				DynamicBox[
					ToBoxes[
						Needs[ "Wolfram`Chatbook`" -> None ];
						RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatModes`Common`sideBarChatInputCell" ][ ],
						StandardForm ],
					DestroyAfterEvaluation -> True
				]
			}
		]
	],
	Background       -> color @ "NA_NotebookBackground",
	CellFrameMargins -> 0,
	CellMargins      -> { { 0, 0 }, { 0, 0 } },
	CellTags         -> "NotebookAssistantSideBarCell",
	Editable         -> True,
	FontSize         -> 0.5, (* needed to workaround line wrapping issue where newlines are given their full line-height based on the FontSize *)
    Initialization   :> AttachCell[ EvaluationCell[ ], Cell[ "", CellTags -> "NotebookAssistantSideBarAttachedHelperCell" ], { Left, Top }, 0, { Left, Top } ],
    LineIndent       -> 0,
    LineSpacing      -> { 1, 0 },
    Magnification    -> 1.,
    Selectable       -> False
]