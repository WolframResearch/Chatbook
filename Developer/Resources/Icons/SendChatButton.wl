Function[
 DynamicModule[ { cell },
  PaneSelector[
   {
    False ->
     Button[
      RawBoxes @ TemplateBox[ { #1, #2 }, "SendChatButtonLabel" ],
      SelectionMove[ cell, All, Cell ];
      FrontEndTokenExecute[ Notebooks @ cell, "EvaluateCells" ],
      FrameMargins -> 0,
     ],
    True ->
     Button[
      Overlay[
       {
        RawBoxes @ TemplateBox[ { #2 }, "ChatEvaluatingSpinner" ],
        Graphics[
         { RGBColor[ 0.71373, 0.054902, 0.0 ], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
         ImageSize -> 20,
         PlotRange -> 1.1
        ]
       },
       Alignment -> { Center, Center }
      ],
      Needs[ "Wolfram`Chatbook`" -> None ];
      Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChat" ],
      FrameMargins -> 0
     ]
   },
   Dynamic[ Wolfram`Chatbook`$ChatEvaluationCell === cell ],
   Alignment -> { Automatic, Baseline }
  ],
  Initialization :> (cell = If[ $CloudEvaluation, EvaluationCell[ ], ParentCell @ EvaluationCell[ ] ]),
  DynamicModuleValues :> { }
 ]
]