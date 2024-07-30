Function[
 MouseAppearance[
  Mouseover[
   Framed[
    Overlay[
     {
      RawBoxes @ TemplateBox[ { #3 }, "ChatEvaluatingSpinner" ],
      Graphics[
       { RGBColor[ 0.71373, 0.054902, 0.0 ], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
       ImageSize -> #3,
       PlotRange -> 1.1
      ]
     },
     Alignment -> { Center, Center }
    ],
    FrameStyle -> GrayLevel[ 1 ],
    Background -> GrayLevel[ 1 ],
    RoundingRadius -> 3,
    FrameMargins -> 1
   ],
   Framed[
    Overlay[
     {
      RawBoxes @ TemplateBox[ { #3 }, "ChatEvaluatingSpinner" ],
      Graphics[
       { RGBColor[ 0.71373, 0.054902, 0.0 ], Rectangle[ { -0.5, -0.5 }, { 0.5, 0.5 } ] },
       ImageSize -> #3,
       PlotRange -> 1.1
      ]
     },
     Alignment -> { Center, Center }
    ],
    FrameStyle -> #1,
    Background -> #2,
    RoundingRadius -> 3,
    FrameMargins -> 1
   ]
  ],
  "LinkHand"
 ]
]