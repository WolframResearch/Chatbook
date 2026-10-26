RawBoxes @ ToBoxes @ DynamicModule[{Typeset`t = 0.0},
  Overlay[{
    Animator[
     Dynamic[Typeset`t],
     {0.0, 1.0},
     AppearanceElements -> {},
     DefaultDuration -> 1.882716863,
     ImageSize -> {1, 1},
     AnimationRunning -> True
     ],
    Graphics[{
       Opacity[1.0, LightDarkSwitched[RGBColor["#128ed1"],RGBColor["#354957"]]],
      EdgeForm[{
        Opacity[1., LightDarkSwitched[RGBColor["#128ed1"],RGBColor["#354957"]]],
        AbsoluteThickness[1.5],
        JoinForm["Miter"]
        }],
      Translate[
       GeometricTransformation[
        FilledCurve[{
          Line[{{-5.029, -5.126}, {-8.941, -5.126}}],
          BezierCurve[{{-8.941, -5.126}, {-9.249, -5.126}, {-9.5, -4.875}, {-9.5, -4.568}}],
          Line[{{-9.5, -4.568}, {-9.5, 8.844}}],
          BezierCurve[{{-9.5, 8.844}, {-9.5, 9.152}, {-9.249, 9.403}, {-8.941, 9.403}}],
          Line[{{-8.941, 9.403}, {8.942, 9.403}}],
          BezierCurve[{{8.942, 9.403}, {9.25, 9.403}, {9.5, 9.152}, {9.5, 8.844}}],
          Line[{{9.5, 8.844}, {9.5, -4.569}}],
          BezierCurve[{{9.5, -4.569}, {9.5, -4.876}, {9.25, -5.126}, {8.942, -5.126}}],
          Line[{{8.942, -5.126}, {0.097, -5.126}, {-5.029, -9.403}, {-5.029, -5.126}}]
          }],
        ScalingTransform[{0.97, 0.97}]
        ],
       {25.025, 15.114}
       ],

      EdgeForm[None],
      
      {
        LightDarkSwitched[RGBColor[0.7490196078431373,0.7843137254901961,0.8],
          RGBColor[0.49411764705882355,0.5215686274509804,0.5333333333333333]],
        Rectangle[{19.8015, 16.1965}, {21.5525, 17.947499999999998}]
      },
      {Opacity[
        Dynamic[
          Times[
            2.,
            Which[
              LessEqual[Typeset`t, 0.576854550646],
                1.,
              LessEqual[Typeset`t, 0.594881352056],
                1. + 27.736479069583293 * (Typeset`t - 0.576854550646),
              LessEqual[Typeset`t, 0.666988557695],
                1.5,
              LessEqual[Typeset`t, 0.685015359104],
                1.5 + -27.736479071121884 * (Typeset`t - 0.666988557695),
              LessEqual[Typeset`t, 1.],
                1.,
              True,
                1.
            ] - 1.
          ]
        ],
        White
      ],
      Rectangle[{19.8015, 16.1965}, {21.5525, 17.947499999999998}]
      },

      {
        LightDarkSwitched[RGBColor[0.7490196078431373,0.7843137254901961,0.8],
          RGBColor[0.49411764705882355,0.5215686274509804,0.5333333333333333]],
        Rectangle[{24.135113227868022, 16.182113227868022}, {25.914886772131975, 17.961886772131976}]
      },
      {Opacity[
        Dynamic[
          Times[
            2.,
            Which[
              LessEqual[Typeset`t, 0.721068961924],
                1.,
              LessEqual[Typeset`t, 0.739095763334],
                1. + 27.736479069583464 * (Typeset`t - 0.721068961924),
              LessEqual[Typeset`t, 0.811202968972],
                1.5,
              LessEqual[Typeset`t, 0.829229770382],
                1.5 + -27.736479069583293 * (Typeset`t - 0.811202968972),
              LessEqual[Typeset`t, 1.],
                1.,
              True,
                1.
            ] - 1.
          ]
        ],
        White
      ],
      Rectangle[{24.135113227868022, 16.182113227868022}, {25.914886772131975, 17.961886772131976}]},

      {
        LightDarkSwitched[RGBColor[0.7490196078431373,0.7843137254901961,0.8],
          RGBColor[0.49411764705882355,0.5215686274509804,0.5333333333333333]],
        Rectangle[{28.497500000000002, 16.1965}, {30.2485, 17.947499999999998}]
      },
      {Opacity[
        Dynamic[
          Times[
            2.,
            Which[
              LessEqual[Typeset`t, 0.865283373202],
                1.,
              LessEqual[Typeset`t, 0.883310174611],
                1. + 27.736479071121884 * (Typeset`t - 0.865283373202),
              LessEqual[Typeset`t, 0.955415833018],
                1.5,
              LessEqual[Typeset`t, 0.973442634428],
                1.5 + -27.736479069583293 * (Typeset`t - 0.955415833018),
              LessEqual[Typeset`t, 1.],
                1.,
              True,
                1.
            ] - 1.
          ]
        ],
        White
      ],
      Rectangle[{28.497500000000002, 16.1965}, {30.2485, 17.947499999999998}]}
      },
     PlotRange -> {{15.0, 35.0}, {5.0, 25.0}},
     ImageSize -> {19, 19},
     Background -> None
     ]
    },
   BaseStyle -> {CacheGraphics -> False},
   ContentPadding -> False
   ],
  DynamicModuleValues :> {}
  ]