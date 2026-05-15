(* ::Package:: *)

(*
	#1 -> icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of icon *)
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
				Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ] ],
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
