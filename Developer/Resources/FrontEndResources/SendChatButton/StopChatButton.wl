(* icon used within sidebar and windowed assistant input fields; frame and hover effects added elsewhere *)
Function @ Evaluate @ ToBoxes @
Overlay[
	{
		With[
			{
				baseColor = color @ "Gray94_20",
				highlightColor = color @ "Blue_75C2EB_669CBD"
			},
			RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #, baseColor, highlightColor ] ]
		],
		Graphics[
			{ color @ "Blue_128ED1_7FC7FB", Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
			ImageSize -> #,
			PlotRange -> 1.1
		]
	},
	Alignment        -> { Center, Center },
	BaselinePosition -> Baseline
]