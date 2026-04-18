Cell[
	BoxData @ TagBox[
		RowBox @ {
			With[
		        {
		            background  = LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ],
		            colorCenter = LightDarkSwitched[ RGBColor["#E0F2FC"], RGBColor["#F5F5F5"] ],
		            colorEdges  = LightDarkSwitched[ RGBColor["#128ED1"], RGBColor["#7FC7FB"] ]
		        },
		        Cell[ BoxData @
		            ToBoxes @ PaneSelector[
		                {
		                    True  -> RawBoxes @ DynamicModuleBox[ { Typeset`v$$ = 0 },
		                        OverlayBox[
		                            {
		                                AnimatorBox[ Dynamic[ Typeset`v$$ ], { 0, 1.2 }, AppearanceElements -> { }, ImageSize -> { 1, 1 }, DefaultDuration -> 2.5 ],
		                                GraphicsBox[
		                                    {
		                                        Thickness[1],
		                                        LineBox[
		                                            Dynamic[ { { -0.2 + Typeset`v$$, 0 }, { -0.1 + Typeset`v$$, 0 }, { Typeset`v$$, 0 } } ],
		                                            VertexColors -> { colorEdges, colorCenter, colorEdges }
		                                        ]
		                                    },
		                                    AspectRatio      -> Full,
		                                    Background       -> background,
		                                    ImageMargins     -> 0,
		                                    ImageSize        -> { Scaled[ 1 ], 6 }, (* much taller than it needs to be to compensate for negative CellFrameMargins *)
		                                    PlotRange        -> { { 0, 1 }, Automatic },
		                                    PlotRangePadding -> None
		                                ]
		                            }
		                        ],
		                        DynamicModuleValues :> { }
		                    ]
		                },
		                Dynamic @ AbsoluteCurrentValue[ FrontEnd`EvaluationCell[ ], { TaggingRules, "ProgressIndicator" } ],
		                Graphics[ Background -> background, ImageSize -> { Scaled[ 1 ], 6 } ],
		                ImageSize -> Automatic
		            ],
		            "NotebookAssistant`TopStripe",
		            Background       -> background,
		            CellFrame        -> False,
		            CellMargins      -> 0,
		            Evaluator        -> None, (* animation runs entirely in the front end *)
		            TaggingRules     -> <| "ProgressIndicator" -> False |>
		        ]
		    ],
			DynamicBox[
				ToBoxes[
					Needs[ "Wolfram`Chatbook`" -> None ];
					RawBoxes @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "MakeSidebarChatDockedCell" ],
					StandardForm ],
				DestroyAfterEvaluation -> True
			]
		},
		"NotebookSelectionSnapshotExclusionZone"
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