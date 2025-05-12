(* ::Package:: *)

(*
	#1 -> FrameStyle, "SendChatButtonFrameHover"
	#2 -> Background, "SendChatButtonBackgroundHover"
	#3 -> ImageSize of spinner *)
Function[ Evaluate @ ToBoxes @
	MouseAppearance[
		Mouseover[
			Framed[
				Overlay[
					{
						With[
							{
								baseColor = color @ "StopChatButtonSpinnerBase",
								highlightColor = color @ "StopChatButtonSpinnerHighlight"
							},
							RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, baseColor, highlightColor ] ]
						],
						Graphics[
							{ color @ "StopChatButtonIcon", Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment -> { Center, Center }
				],
				FrameStyle -> None,
				Background -> None,
				RoundingRadius -> 3,
				FrameMargins -> 1
			],
			Framed[
				Overlay[
					{
						With[
							{
								baseColor = color @ "StopChatButtonSpinnerBase",
								highlightColor = color @ "StopChatButtonSpinnerHighlight"
							},
							RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, baseColor, highlightColor ] ]
						],
						Graphics[
							{ color @ "StopChatButtonIcon", Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment -> { Center, Center }
				],
				FrameStyle -> #1,
				Background -> #2,
				RoundingRadius -> 3,
				FrameMargins -> 1
			]
		],
		"LinkHand"
	]
]
