RawBoxes @ ToBoxes @
  DynamicModule[{Typeset`t = 0., Typeset`v1 = 1., Typeset`v2 = 1., Typeset`v3 = 1.},
    With[
    {
      bgColor = LightDarkSwitched[
        RGBColor[0.7490196078431373, 0.7843137254901961, 0.8],
        RGBColor[0.49411764705882355, 0.5215686274509804, 0.5333333333333333]
      ],
      fgColor = LightDarkSwitched[
        RGBColor[0.3843137254901961, 0.4745098039215686, 0.5137254901960784],
        RGBColor[0.7215686274509804, 0.7803921568627451, 0.8117647058823529]
      ],
      y = 17.072,
      half = 0.8755,
      bars = {
        {20.677, 0.576854550646, 0.594881352056, 0.666988557695, 0.685015359104},
        {25.025, 0.721068961924, 0.739095763334, 0.811202968972, 0.829229770382},
        {29.373, 0.865283373202, 0.883310174611, 0.955415833018, 0.973442634428}
      }
    },
    {
      animatorFuncs = Thread[
        Prepend[
          {
            With[{a = #[[2]], b = #[[3]], c = #[[4]], d = #[[5]]},
              Function[(* needed because FEPrivate`Set is not HoldFirst *)
                FEPrivate`Set[Typeset`v1,
                  FEPrivate`Which[
                    FEPrivate`LessEqual[#, a], 1.,
                    FEPrivate`LessEqual[#, b], 1. + 27.7364790695833*(# - a),
                    FEPrivate`LessEqual[#, c], 1.5,
                    FEPrivate`LessEqual[#, d], 1.5 - 27.7364790695833*(# - c),
                    FEPrivate`LessEqual[#, 1.], 1.,
                    True, 1.
                  ]
                ]
              ]
            ]& @ bars[[1]],
            With[{a = #[[2]], b = #[[3]], c = #[[4]], d = #[[5]]},
              Function[(* needed because FEPrivate`Set is not HoldFirst *)
                FEPrivate`Set[Typeset`v2,
                  FEPrivate`Which[
                    FEPrivate`LessEqual[#, a], 1.,
                    FEPrivate`LessEqual[#, b], 1. + 27.7364790695833*(# - a),
                    FEPrivate`LessEqual[#, c], 1.5,
                    FEPrivate`LessEqual[#, d], 1.5 - 27.7364790695833*(# - c),
                    FEPrivate`LessEqual[#, 1.], 1.,
                    True, 1.
                  ]
                ]
              ]
            ]& @ bars[[2]],
            With[{a = #[[2]], b = #[[3]], c = #[[4]], d = #[[5]]},
              Function[(* needed because FEPrivate`Set is not HoldFirst *)
                FEPrivate`Set[Typeset`v3,
                  FEPrivate`Which[
                    FEPrivate`LessEqual[#, a], 1.,
                    FEPrivate`LessEqual[#, b], 1. + 27.7364790695833*(# - a),
                    FEPrivate`LessEqual[#, c], 1.5,
                    FEPrivate`LessEqual[#, d], 1.5 - 27.7364790695833*(# - c),
                    FEPrivate`LessEqual[#, 1.], 1.,
                    True, 1.
                  ]
                ]
              ]
            ]& @ bars[[3]]
          },
          Function[FEPrivate`Set[Typeset`t, #]]
        ],
        Function
      ]
    },
    Overlay[
      {
        Animator[
          Dynamic[Typeset`t, animatorFuncs],
          {0., 1.},
          DefaultDuration -> 1.882716863,
          AnimationRunning -> True,
          AnimationRepetitions -> DirectedInfinity[1],
          AppearanceElements -> {},
          ImageSize -> {1, 1}
        ],
        Graphics[
          Join[
            {bgColor, EdgeForm[None]},
            (Rectangle[{#[[1]] - half, y - half}, {#[[1]] + half, y + half}] &) /@ bars,
            {fgColor},
            {
              Dynamic[
                RawBoxes @ {
                  Opacity[2.*(Typeset`v1 - 1.)],
                  RectangleBox[
                    {# - half*Typeset`v1, y - half*Typeset`v1},
                    {# + half*Typeset`v1, y + half*Typeset`v1}
                  ]
                }
              ]& @ bars[[1, 1]],
              Dynamic[
                RawBoxes @ {
                  Opacity[2.*(Typeset`v2 - 1.)],
                  RectangleBox[
                    {# - half*Typeset`v2, y - half*Typeset`v2},
                    {# + half*Typeset`v2, y + half*Typeset`v2}
                  ]
                }
              ]& @ bars[[2, 1]],
              Dynamic[
                RawBoxes @ {
                  Opacity[2.*(Typeset`v3 - 1.)],
                  RectangleBox[
                    {# - half*Typeset`v3, y - half*Typeset`v3},
                    {# + half*Typeset`v3, y + half*Typeset`v3}
                  ]
                }
              ]& @ bars[[3, 1]]
            }
          ],
          PlotRange -> {{18., 32.}, {14.6, 19.6}},
          ImageSize -> {19, Automatic},
          Background -> None
        ]
      },
      BaseStyle -> {CacheGraphics -> False},
      ContentPadding -> False
    ]
  ],
  DynamicModuleValues :> {}
]