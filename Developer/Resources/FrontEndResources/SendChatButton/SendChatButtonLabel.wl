(* ::Package:: *)

(*
	#1 -> icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of icon *)
Function[ Evaluate @ ToBoxes @
	With[
		{
			baseColor      = color @ "StopChatButtonSpinnerBase",
			highlightColor = color @ "StopChatButtonSpinnerHighlight"
		},
		MouseAppearance[
			NotebookTools`Mousedown[
				Framed[
					Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ] ],
					Alignment        -> { Center, Center },
					Background       -> None,
					BaselinePosition -> Baseline,
					FrameMargins     -> 0,
					FrameStyle       -> None,
					ImageSize        -> #2,
					RoundingRadius   -> 4
				],
				Framed[
					Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ] ],
					Alignment        -> { Center, Center },
					Background       -> color @ "NA_BlueHueButtonBackgroundHover",
					BaselinePosition -> Baseline,
					FrameMargins     -> 0,
					FrameStyle       -> color @ "NA_BlueHueButtonFrameHover",
					ImageSize        -> #2,
					RoundingRadius   -> 4
				],
				Framed[
					Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ] ],
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
