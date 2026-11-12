(* ::Package:: *)

(*
	#1 -> icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of icon *)
Function[ Evaluate @ ToBoxes @
	With[
		{
			baseColor      = color @ "Gray94_20",
			highlightColor = color @ "Blue_75C2EB_669CBD",
			bgHover        = color @ "Gray100_10",
			frameHover     = color @ "Blue_B1D5E8_607D8F"
		},
		MouseAppearance[
			Framed[
				Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatArrow" ][ #1, #3 ] ],
				Alignment        -> { Center, Center },
				Background       -> ThemeColor[ "Background" ],
				BaselinePosition -> Baseline,
				FrameMargins     -> 0,
				FrameStyle       -> Dynamic @ If[ CurrentValue[ "MouseOver" ], frameHover, ThemeColor[ "Background" ] ],
				ImageSize        -> #2,
				RoundingRadius   -> 4
			],
			"LinkHand"
		]
	]
]
