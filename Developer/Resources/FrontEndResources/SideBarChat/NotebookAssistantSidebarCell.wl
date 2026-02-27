Cell[
	BoxData @
		DynamicBox[
			ToBoxes[
				Needs[ "Wolfram`Chatbook`" -> None ];
				RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSidebarChatDockedCell" ],
				StandardForm ],
			DestroyAfterEvaluation -> True
		],
	"NotebookAssistant`Sidebar`NotebookAssistantSidebarCell",
	Background        -> color @ "NA_ChatInputFieldBackgroundArea", (* this colors the entire initial sidebar as gray to make it easier to see *)
	CellFrameMargins  -> 0,
	CellMargins       -> { { 0, 0 }, { 0, 0 } },
	CellTags          -> "NotebookAssistantSidebarCell",
	Editable          -> True,
	FontSize          -> 0.5, (* needed to workaround line wrapping issue where newlines are given their full line-height based on the FontSize *)
	LineIndent        -> 0,
	LineSpacing       -> { 1, 0 },
	Magnification     -> 1.,
	Selectable        -> False,
	ShowCursorTracker -> False
]