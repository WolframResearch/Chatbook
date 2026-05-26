(* ::Package:: *)

(*
	#1 -> Color: icon,
	#2 -> ImageSize: button frame,
	#3 -> ImageSize: send icon
	#4 -> ImageSize: stop icon *)
Function[ Evaluate @ ToBoxes @
	PaneSelector[
		{
			True ->
				PaneSelector[
					{
						False ->
							Button[
								MouseAppearance[
									Framed[
										RawBoxes @ FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ],
										Alignment        -> { Center, Center },
										Background       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], LightDarkSwitched[ GrayLevel[ 1. ], GrayLevel[ 0.0980392 ] ], ThemeColor[ "Background" ] ],
										BaselinePosition -> Baseline,
										FrameMargins     -> 0,
										FrameStyle       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], LightDarkSwitched[ RGBColor[ 0.6941176, 0.8352941, 0.9098039 ], RGBColor[ 0.3764705, 0.490196, 0.5607843 ] ], ThemeColor[ "Background" ] ],
										ImageSize        -> #2,
										RoundingRadius   -> 4
									],
									"LinkHand"
								],
								With[ { Typeset`cell = EvaluationCell[ ] },
									Wolfram`Chatbook`$ChatEvaluationCell = Typeset`cell;
									SelectionMove[ Typeset`cell, All, Cell ];
									FrontEndTokenExecute[ "EvaluateCells" ]
								],
								Appearance   -> "Suppressed",
								FrameMargins -> 0,
								Method       -> "Queued"
							],
						True ->
							Button[
								MouseAppearance[
									Framed[
										Graphics[
											{
												Thickness[ 0.05 ], LightDarkSwitched[ RGBColor[ 0.9411764, 0.9411764, 0.9411764 ], GrayLevel[ 0.2 ] ], CircleBox[ { 0, 0 }, 1 ],
												#1, Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ]
											},
											ImageSize -> #4,
											PlotRange -> 1.1
										],
										Alignment        -> { Center, Center },
										Background       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], LightDarkSwitched[ GrayLevel[ 1. ], GrayLevel[ 0.0980392 ] ], ThemeColor[ "Background" ] ],
										BaselinePosition -> Baseline,
										FrameMargins     -> 0,
										FrameStyle       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], LightDarkSwitched[ RGBColor[ 0.6941176, 0.8352941, 0.9098039 ], RGBColor[ 0.3764705, 0.490196, 0.5607843 ] ], ThemeColor[ "Background" ] ],
										ImageSize        -> #2,
										RoundingRadius   -> 4
									],
									"LinkHand"
								],
								With[ { Typeset`cell = EvaluationCell[ ] },
									If[ Wolfram`Chatbook`$ChatEvaluationCell =!= Typeset`cell,
										NotebookWrite[ Typeset`cell, NotebookRead @ Typeset`cell, None, AutoScroll -> False ]
										,
										Needs[ "Wolfram`Chatbook`" -> None ];
										Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
									]
								],
								Appearance   -> "Suppressed",
								FrameMargins -> 0,
								Method       -> "Preemptive"
							]
					},
					Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === EvaluationCell[ ] ],
					Alignment -> { Automatic, Baseline },
					ImageSize -> Automatic
				],
			False ->
				DynamicModule[ { Typeset`cell },
					PaneSelector[
						{
							False ->
								Button[
									Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ],
									Wolfram`Chatbook`$ChatEvaluationCell = Typeset`cell;
									SelectionMove[ Typeset`cell, All, Cell ];
									FrontEndTokenExecute[ Notebooks @ Typeset`cell, "EvaluateCells" ],
									Appearance   -> "Suppressed",
									FrameMargins -> 0,
									Method       -> "Queued"
								],
							True ->
								Button[
									Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #4 ] ],
									If[ Wolfram`Chatbook`$ChatEvaluationCell =!= Typeset`cell,
										NotebookWrite[ Typeset`cell, NotebookRead @ Typeset`cell, None, AutoScroll -> False ],
										Needs[ "Wolfram`Chatbook`" -> None ];
										Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
									],
									Appearance   -> "Suppressed",
									FrameMargins -> 0,
									Method       -> "Preemptive"
								]
						},
						Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === Typeset`cell ],
						Alignment -> { Automatic, Baseline },
						ImageSize -> Automatic
					],
					Initialization      :> (Typeset`cell = ParentCell @ EvaluationCell[ ]),
					DynamicModuleValues :> { },
					UnsavedVariables    :> { Typeset`cell }
				]
		},
		Dynamic @ TrueQ @ $CloudEvaluation,
		ImageSize -> Automatic
	]
]