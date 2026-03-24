Function @ Evaluate @ ToBoxes @
Overlay[
	{
		With[
			{
				baseColor = color @ "StopChatButtonSpinnerBase",
				highlightColor = color @ "StopChatButtonSpinnerHighlight"
			},
			RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ChatEvaluatingSpinner" ][ #, baseColor, highlightColor ] ]
		],
		Graphics[
			{ color @ "NA_BlueHueButtonIcon", Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
			ImageSize -> #,
			PlotRange -> 1.1
		]
	},
	Alignment        -> { Center, Center },
	BaselinePosition -> Baseline
]