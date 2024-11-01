(* ::Package:: *)

(*
	#1 -> ImageSize,
	#2 -> base ring color,
	#3 -> moving color *)
Function[
	DynamicBox[
		If[ TrueQ @ $CloudEvaluation,
			GraphicsBox[
				{ Thickness[ 0.05 ], #2, CircleBox[ { 0, 0 }, 1 ] },
				PlotRange -> 1.1,
				ImageSize -> #1
			],
			DynamicModuleBox[
				{ Typeset`i },
				OverlayBox[
					{
						PaneBox[
							AnimatorBox[
								Dynamic @ Typeset`i,
								{ 1, 30, 1 },
								AutoAction -> False,
								AnimationRate -> Automatic,
								DisplayAllSteps -> True,
								DefaultDuration -> 2,
								AppearanceElements -> None
							],
							ImageSize -> { 0, 0 }
						],
						GraphicsBox[
							{ Thickness[ 0.05 ], #2, CircleBox[ { 0, 0 }, 1, { 0.0, 6.2832 } ] },
							PlotRange -> 1.1,
							ImageSize -> #1
						],
						PaneSelectorBox[
							{
								1 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.5332, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								2 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.5151, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								3 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.4611, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								4 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.3713, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								5 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.2463, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								6 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 4.0869, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								7 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.894, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								8 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.6686, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								9 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.412, 4.9332 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								10 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 3.1258, 4.924 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								11 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.8116, 4.8802 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								12 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.4711, 4.8006 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								13 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 2.1064, 4.6856 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								14 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 1.7195, 4.5359 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								15 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 1.3127, 4.3525 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								16 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 0.88824, 4.1362 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								17 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { 0.44865, 3.8884 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								18 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.0035846, 3.6105 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								19 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.46585, 3.3041 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								20 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -0.9355, 2.9709 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								21 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.4098, 2.6129 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								22 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 2.2322 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								23 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 1.8308 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								24 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 1.4112 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								25 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.97565 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								26 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.52676 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								27 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, 0.067093 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								28 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -0.40072 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								29 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -0.87399 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									],
								30 ->
									GraphicsBox[
										{ Thickness[ 0.06 ], #3, CircleBox[ { 0, 0 }, 1, { -1.75, -1.35 } ] },
										PlotRange -> 1.1,
										ImageSize -> #1
									]
							},
							Dynamic @ Typeset`i,
							ContentPadding -> False,
							FrameMargins -> 0,
							ImageSize -> All,
							Alignment -> Automatic,
							BaseStyle -> None,
							TransitionDirection -> Horizontal,
							TransitionDuration -> 0.5,
							TransitionEffect -> Automatic
						]
					},
					ContentPadding -> False,
					FrameMargins -> 0
				],
				DynamicModuleValues :> { }
			]
		],
		SingleEvaluation -> True
	]
]