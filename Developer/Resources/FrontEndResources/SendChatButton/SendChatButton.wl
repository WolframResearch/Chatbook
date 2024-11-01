(* ::Package:: *)

(*
	#1 -> FaceForm / FrameStyle,
	#2 -> Background,
	#3 -> ImageSize *)
Function[ Evaluate @ ToBoxes @
	DynamicModule[ { Typeset`cell },
		PaneSelector[
			{
				False ->
					Button[
						Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButtonLabel" ][ #1, #2, #3 ] ],
						Wolfram`Chatbook`$ChatEvaluationCell = Typeset`cell;
						SelectionMove[ Typeset`cell, All, Cell ];
						FrontEndTokenExecute[ Notebooks @ Typeset`cell, "EvaluateCells" ],
						Appearance -> "Suppressed",
						FrameMargins -> 0,
						Method -> "Queued"
					],
				True ->
					Button[
						Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #3 ] ],
						If[ Wolfram`Chatbook`$ChatEvaluationCell =!= Typeset`cell,
							NotebookWrite[ Typeset`cell, NotebookRead @ Typeset`cell, None, AutoScroll -> False ],
							Needs[ "Wolfram`Chatbook`" -> None ];
							Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
						],
						Appearance -> "Suppressed",
						FrameMargins -> 0
					]
			},
			Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === Typeset`cell ],
			Alignment -> { Automatic, Baseline },
			ImageSize -> Automatic
		], (* TODO: what is this x?? *)
		Initialization :> (Typeset`cell = If[ $CloudEvaluation, x; EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
		DynamicModuleValues :> { },
		UnsavedVariables :> { Typeset`cell }
	]
]