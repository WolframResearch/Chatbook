(* ::Package:: *)

(*
	#1 -> stop icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of spinner *)
Function[ Evaluate @ ToBoxes @
	With[
		{
			baseColor      = color @ "StopChatButtonSpinnerBase",
			highlightColor = color @ "StopChatButtonSpinnerHighlight"
		},
		MouseAppearance[
			NotebookTools`Mousedown[
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
					Background       -> None,
					BaselinePosition -> Baseline,
					FrameMargins     -> 0,
					FrameStyle       -> None,
					ImageSize        -> #2,
					RoundingRadius   -> 4
				],
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
					Background       -> color @ "NA_BlueHueButtonBackgroundHover",
					BaselinePosition -> Baseline,
					FrameMargins     -> 0,
					FrameStyle       -> color @ "NA_BlueHueButtonFrameHover",
					ImageSize        -> #2,
					RoundingRadius   -> 4
				],
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
					Background       -> color @ "NA_BlueHueButtonBackgroundPressed",
					BaselinePosition -> Baseline,
					FrameMargins     -> 0,
					FrameStyle       -> color @ "NA_BlueHueButtonFramePressed",
					ImageSize        -> #2,
					RoundingRadius   -> 4
				],
				BaselinePosition -> Baseline
			],
			"LinkHand"
		]
	]
]
