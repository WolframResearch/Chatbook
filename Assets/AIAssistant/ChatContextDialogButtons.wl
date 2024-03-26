Function[
 { ok, cancel },
 RowBox @ {
  DynamicModuleBox[
   { hoverQ$$ = False, mouseDownQ$$ = False },
   TagBox[
    ButtonBox[
     FrameBox[
      TagBox[
       GridBox[
        {
         {
          TagBox[
           GridBox[
            {
             {
              StyleBox[
               TemplateBox[
                { ToBoxes[tr["CancelButton"]] },
                "Row",
                DisplayFunction ->
                 (Function[
                  FrameBox[
                   #1,
                   FrameMargins -> { { 8, 8 }, { 1, 1 } },
                   FrameStyle -> Directive[ 1, RGBColor[ 0, 0, 0, 0 ] ]
                  ]
                 ]),
                InterpretationFunction ->
                 (Function[
                  RowBox @ {
                   "Row",
                   "[",
                   RowBox @ {
                    RowBox @ { "{", #1, "}" },
                    ",",
                    RowBox @ { "Frame", "->", "True" },
                    ",",
                    RowBox @ {
                     "FrameStyle",
                     "->",
                     RowBox @ {
                      "Directive",
                      "[",
                      RowBox @ {
                       "1",
                       ",",
                       RowBox @ { "RGBColor", "[", RowBox @ { "0", ",", "0", ",", "0", ",", "0" }, "]" }
                      },
                      "]"
                     }
                    },
                    ",",
                    RowBox @ {
                     "FrameMargins",
                     "->",
                     RowBox @ {
                      "{",
                      RowBox @ {
                       RowBox @ { "{", RowBox @ { "8", ",", "8" }, "}" },
                       ",",
                       RowBox @ { "{", RowBox @ { "1", ",", "1" }, "}" }
                      },
                      "}"
                     }
                    }
                   },
                   "]"
                  }
                 ])
               ],
               StripOnInput -> False,
               FontFamily -> "Source Sans Pro",
               FontSize -> 13,
               FontColor ->
                Dynamic @ Which[
                 hoverQ$$ && mouseDownQ$$,
                 GrayLevel[ 1 ],
                 hoverQ$$,
                 RGBColor[ 0.2, 0.2, 0.2 ],
                 True,
                 RGBColor[ 0.2, 0.2, 0.2 ]
                ]
              ]
             }
            },
            AutoDelete -> False,
            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
           ],
           "Grid"
          ]
         }
        },
        AutoDelete -> False,
        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
        GridBoxSpacings -> { "Columns" -> { 20, 0.25 }, "Rows" -> { 0, 0 } }
       ],
       "Grid"
      ],
      Alignment -> Center,
      Background ->
       Dynamic @ Which[
        hoverQ$$ && mouseDownQ$$,
        RGBColor[ 0.651, 0.651, 0.651 ],
        hoverQ$$,
        RGBColor[ 0.96078, 0.96078, 0.96078 ],
        True,
        RGBColor[ 0.89804, 0.89804, 0.89804 ]
       ],
      FrameMargins -> 4,
      FrameStyle ->
       Dynamic @ Directive[
        AbsoluteThickness[ 1 ],
        Which[
         hoverQ$$ && mouseDownQ$$,
         RGBColor[ 0.651, 0.651, 0.651 ],
         hoverQ$$,
         RGBColor[ 0.89804, 0.89804, 0.89804 ],
         True,
         RGBColor[ 0.89804, 0.89804, 0.89804 ]
        ]
       ],
      ImageSize -> { { 38, Full }, { 19.5, Full } },
      RoundingRadius -> 3,
      StripOnInput -> False
     ],
     Appearance -> {
      "Default" -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ],
      "Hover"   -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ],
      "Pressed" -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ]
     },
     ButtonFunction :> cancel,
     Evaluator -> Automatic,
     Method -> "Preemptive"
    ],
    EventHandlerTag @ {
     "MouseEntered" :> FEPrivate`Set[ hoverQ$$, True ],
     "MouseExited"  :> FEPrivate`Set[ hoverQ$$, False ],
     "MouseDown"    :> FEPrivate`Set[ mouseDownQ$$, True ],
     "MouseUp"      :> FEPrivate`Set[ mouseDownQ$$, False ],
     PassEventsDown -> True,
     Method         -> "Preemptive",
     PassEventsUp   -> True
    }
   ],
   DynamicModuleValues :> { }
  ],
  "  ",
  DynamicModuleBox[
   { hoverQ$$ = False, mouseDownQ$$ = False },
   TagBox[
    ButtonBox[
     FrameBox[
      TagBox[
       GridBox[
        {
         {
          TagBox[
           GridBox[
            {
             {
              StyleBox[
               TemplateBox[
                { ToBoxes[tr["OKButton"]] },
                "Row",
                DisplayFunction ->
                 (Function[
                  FrameBox[
                   #1,
                   FrameMargins -> { { 8, 8 }, { 0, 0.8 } },
                   FrameStyle -> Directive[ 1, RGBColor[ 0, 0, 0, 0 ] ]
                  ]
                 ]),
                InterpretationFunction ->
                 (Function[
                  RowBox @ {
                   "Row",
                   "[",
                   RowBox @ {
                    RowBox @ { "{", #1, "}" },
                    ",",
                    RowBox @ { "Frame", "->", "True" },
                    ",",
                    RowBox @ {
                     "FrameStyle",
                     "->",
                     RowBox @ {
                      "Directive",
                      "[",
                      RowBox @ {
                       "1",
                       ",",
                       RowBox @ { "RGBColor", "[", RowBox @ { "0", ",", "0", ",", "0", ",", "0" }, "]" }
                      },
                      "]"
                     }
                    },
                    ",",
                    RowBox @ {
                     "FrameMargins",
                     "->",
                     RowBox @ {
                      "{",
                      RowBox @ {
                       RowBox @ { "{", RowBox @ { "8", ",", "8" }, "}" },
                       ",",
                       RowBox @ { "{", RowBox @ { "0", ",", "0.8`" }, "}" }
                      },
                      "}"
                     }
                    }
                   },
                   "]"
                  }
                 ])
               ],
               StripOnInput -> False,
               FontFamily -> "Source Sans Pro",
               FontSize -> 13,
               FontColor ->
                Dynamic @ Which[
                 hoverQ$$ && mouseDownQ$$,
                 GrayLevel[ 1 ],
                 hoverQ$$,
                 GrayLevel[ 1 ],
                 True,
                 GrayLevel[ 1 ]
                ]
              ]
             }
            },
            AutoDelete -> False,
            GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
           ],
           "Grid"
          ]
         }
        },
        AutoDelete -> False,
        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } },
        GridBoxSpacings -> { "Columns" -> { 20, 0.25 }, "Rows" -> { 0, 0 } }
       ],
       "Grid"
      ],
      Alignment -> Center,
      Background ->
       Dynamic @ Which[
        hoverQ$$ && mouseDownQ$$,
        RGBColor[ 0.6902, 0.058824, 0.0 ],
        hoverQ$$,
        RGBColor[ 0.99608, 0.0, 0.0 ],
        True,
        RGBColor[ 0.86667, 0.066666, 0.0 ]
       ],
      FrameMargins -> 4,
      FrameStyle ->
       Dynamic @ Directive[
        AbsoluteThickness[ 1 ],
        Which[
         hoverQ$$ && mouseDownQ$$,
         RGBColor[ 0.6902, 0.058824, 0.0 ],
         hoverQ$$,
         RGBColor[ 0.86667, 0.066666, 0.0 ],
         True,
         RGBColor[ 0.86667, 0.066666, 0.0 ]
        ]
       ],
      ImageSize -> { { 38, Full }, { 10, Full } },
      RoundingRadius -> 3,
      StripOnInput -> False
     ],
     Appearance -> {
      "Default" -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ],
      "Hover"   -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ],
      "Pressed" -> FrontEnd`FileName[ { "Misc" }, "TransparentBG.9.png" ]
     },
     ButtonFunction :> ok,
     Evaluator -> Automatic,
     Method -> "Preemptive"
    ],
    EventHandlerTag @ {
     "MouseEntered" :> FEPrivate`Set[ hoverQ$$, True ],
     "MouseExited"  :> FEPrivate`Set[ hoverQ$$, False ],
     "MouseDown"    :> FEPrivate`Set[ mouseDownQ$$, True ],
     "MouseUp"      :> FEPrivate`Set[ mouseDownQ$$, False ],
     PassEventsDown -> True,
     Method         -> "Preemptive",
     PassEventsUp   -> True
    }
   ],
   DynamicModuleValues :> { }
  ]
 },
 { HoldAllComplete }
]