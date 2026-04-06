(* ::Package:: *)

(*
	#1 -> Color: icon,
	#2 -> ImageSize: button frame,
	#3 -> ImageSize: send icon
	#4 -> ImageSize: stop icon *)
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
						Appearance   -> "Suppressed",
						FrameMargins -> 0,
						Method       -> "Queued"
					],
				True ->
					Button[
						Dynamic[ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "StopChatButtonLabel" ][ #1, #2, #4 ] ],
						If[ Wolfram`Chatbook`$ChatEvaluationCell =!= Typeset`cell,
							NotebookWrite[ Typeset`cell, NotebookRead @ Typeset`cell, None, AutoScroll -> False ],
							Needs[ "Wolfram`Chatbook`" -> None ];
							Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
						],
						Appearance   -> "Suppressed",
						FrameMargins -> 0,
						Method       -> "Preemptive"
					]
			},
			Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === Typeset`cell ],
			Alignment -> { Automatic, Baseline },
			ImageSize -> Automatic
		],
		Initialization      :> (Typeset`cell = If[ $CloudEvaluation, EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
		DynamicModuleValues :> { },
		UnsavedVariables    :> { Typeset`cell }
	]
]