(* ::Package:: *)

(*
	#1 -> stop icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of spinner *)
Function[ Evaluate @ ToBoxes @
	With[
		{
			baseColor      = color @ "StopChatButtonSpinnerBase",
			highlightColor = color @ "StopChatButtonSpinnerHighlight",
			bgHover        = color @ "NA_BlueHueButtonBackgroundHover",
			frameHover     = color @ "NA_BlueHueButtonFrameHover"
		},
		MouseAppearance[
			Framed[
				Overlay[
					{
						RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, baseColor, highlightColor ] ],
						Graphics[
							{  #1, Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment        -> { Center, Center },
					BaselinePosition -> Baseline
				],
				Alignment        -> { Center, Center },
				Background       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], bgHover, None ],
				BaselinePosition -> Baseline,
				FrameMargins     -> 0,
				FrameStyle       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], frameHover, None ],
				ImageSize        -> #2,
				RoundingRadius   -> 4
			],
			"LinkHand"
		]
	]
]
