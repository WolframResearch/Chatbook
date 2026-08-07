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
				Graphics[
					{
						Thickness[0.09090909090909091], FaceForm[LightDarkSwitched[RGBColor[0.0705882, 0.55686275, 0.8196078, 1.], RGBColor[0.49803922, 0.78039216, 0.9843137]]], 
						RawBoxes @ FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}}, {{{9., 0.}, {2., 0.}, {0.8949995040893555, 0.},
							{0., 0.8949999809265137}, {0., 2.}, {0., 9.}, {0., 10.105000495910645`}, {0.8949995040893555, 11.}, {2., 11.}, {9., 11.}, {10.105000019073486`, 11.},
							{11., 10.105000495910645`}, {11., 9.}, {11., 2.}, {11., 0.8949999809265137}, {10.105000019073486`, 0.}, {9., 0.}}}]
					},
					ImageSize -> #3*0.7,
					PlotRange -> {{-0.5, 11.5}, {-0.5, 11.5}}
				],
				Alignment        -> { Center, Center },
				Background       -> ThemeColor[ "Background" ],
				BaselinePosition -> Baseline,
				FrameMargins     -> 0,
				FrameStyle       -> frameHover,
				ImageSize        -> #2,
				RoundingRadius   -> 4
			],
			"LinkHand"
		]
	]
]
