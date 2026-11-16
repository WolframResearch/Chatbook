(* ::Package:: *)

(*
	#1 -> stop icon color
	#2 -> ImageSize of framed button
	#3 -> ImageSize of spinner *)
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
				Graphics[
					{
						Thickness[0.09090909090909091], FaceForm[color @ "Blue_128ED1_7FC7FB"], 
						RawBoxes @ FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}}, {{{9., 0.}, {2., 0.}, {0.8949995040893555, 0.},
							{0., 0.8949999809265137}, {0., 2.}, {0., 9.}, {0., 10.105000495910645`}, {0.8949995040893555, 11.}, {2., 11.}, {9., 11.}, {10.105000019073486`, 11.},
							{11., 10.105000495910645`}, {11., 9.}, {11., 2.}, {11., 0.8949999809265137}, {10.105000019073486`, 0.}, {9., 0.}}}]
					},
					ImageSize -> #3*0.7,
					PlotRange -> {{-0.5, 11.5}, {-0.5, 11.5}}
				],
				Alignment        -> { Center, Center },
				Background       -> Dynamic @ If[ CurrentValue[ "MouseOver" ],
					LightDarkSwitched[RGBColor[0.071, 0.557, 0.820, 0.08], RGBColor[0.498, 0.78, 0.984, 0.22]],
					GrayLevel[ 0, 0 ]
				],
				BaselinePosition -> Baseline,
				FrameMargins     -> 0,
				FrameStyle       -> color @ "Blue_128ED1_7FC7FB",
				ImageSize        -> #2,
				RoundingRadius   -> 4
			],
			"LinkHand"
		]
	]
]
