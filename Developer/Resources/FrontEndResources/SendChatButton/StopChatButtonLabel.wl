(* ::Package:: *)

(*
	#1 -> FrameStyle,
	#2 -> Background,
	#3 -> ImageSize of spinner *)
Function[ Evaluate @ ToBoxes @
	MouseAppearance[
		Mouseover[
			Framed[
				Overlay[
					{
						RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, GrayLevel[ 0.9 ], GrayLevel[ 0.7 ] ] ],
						Graphics[
							{ RGBColor["#3383AC"], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
							ImageSize -> #3,
							PlotRange -> 1.1
						]
					},
					Alignment -> { Center, Center }
				],
				FrameStyle -> GrayLevel[ 1 ],
				Background -> GrayLevel[ 1 ],
				RoundingRadius -> 3,
				FrameMargins -> 1
			],
			Framed[
				Overlay[
					{
						RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #3, GrayLevel[ 0.9 ], GrayLevel[ 0.7 ] ] ],
						Graphics[
							{ RGBColor["#3383AC"], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
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
