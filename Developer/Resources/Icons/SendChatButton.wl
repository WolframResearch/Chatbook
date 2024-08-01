Function[
 DynamicModule[ { cell },
  PaneSelector[
   {
    False ->
     Button[
      RawBoxes @ TemplateBox[ { #1, #2, #3 }, "SendChatButtonLabel" ],
      Wolfram`Chatbook`$ChatEvaluationCell = cell;
      SelectionMove[ cell, All, Cell ];
      FrontEndTokenExecute[ Notebooks @ cell, "EvaluateCells" ],
      Appearance -> "Suppressed",
      FrameMargins -> 0,
      Method -> "Queued"
     ],
    True ->
     Button[
      RawBoxes @ TemplateBox[ { #1, #2, #3 }, "StopChatButtonLabel" ],
      If[ Wolfram`Chatbook`$ChatEvaluationCell =!= cell,
       NotebookWrite[ cell, NotebookRead @ cell, None, AutoScroll -> False ],
       Needs[ "Wolfram`Chatbook`" -> None ];
       Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ]
      ],
      Appearance -> "Suppressed",
      FrameMargins -> 0
     ]
   },
   Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === cell ],
   Alignment -> { Automatic, Baseline },
   ImageSize -> Automatic
  ],
  Initialization :> (cell = If[ $CloudEvaluation, x; EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
  DynamicModuleValues :> { },
  UnsavedVariables :> { cell }
 ]
]