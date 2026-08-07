RawBoxes @ ToBoxes @ DynamicModule[{Typeset`t = 0.},
  Overlay[
    {
      Animator[
        Dynamic[Typeset`t],
        {0., 1.},
        DefaultDuration -> 1.882716863,
        AnimationRunning -> True,
        AnimationRepetitions -> DirectedInfinity[1],
        AppearanceElements -> {},
        ImageSize -> {1, 1}
      ],
      Graphics[
        {
          LightDarkSwitched[
            RGBColor[0.7490196078431373, 0.7843137254901961, 0.8],
            RGBColor[0.49411764705882355, 0.5215686274509804, 0.5333333333333333]
          ],
          EdgeForm @ None,
          Dynamic[RawBoxes @
          Function[
            {
              RectangleBox[
                {20.677 - 0.8755*#, 17.072 - 0.8755*#},
                {20.677 + 0.8755*#, 17.072 + 0.8755*#}
              ],
              Directive[Opacity[
                2.*(# - 1.)],
                LightDarkSwitched[
                  RGBColor[0.3843137254901961, 0.4745098039215686, 0.5137254901960784],
                  RGBColor[0.7215686274509804, 0.7803921568627451, 0.8117647058823529]
                ]
              ],
              RectangleBox[
                {20.677 - 0.8755*#, 17.072 - 0.8755*#},
                {20.677 + 0.8755*#, 17.072 + 0.8755*#}
              ]
            }][Which[
              LessEqual[Typeset`t, 0.576854550646], 1.,
              LessEqual[Typeset`t, 0.594881352056], 1. + 27.736479069583293*(Typeset`t - 0.576854550646),
              LessEqual[Typeset`t, 0.666988557695], 1.5,
              LessEqual[Typeset`t, 0.685015359104], 1.5 + -27.736479071121884*(Typeset`t - 0.666988557695),
              LessEqual[Typeset`t, 1.], 1.,
              True, 1.
            ]],
            TrackedSymbols :> {Typeset`t}
          ],

          Dynamic[RawBoxes @
          Function[
            {
              RectangleBox[
                {25.025 - 0.8755*#, 17.072 - 0.8755*#},
                {25.025 + 0.8755*#, 17.072 + 0.8755*#}
              ],
              Directive[Opacity[
                2.*(# - 1.)],
                LightDarkSwitched[
                  RGBColor[0.3843137254901961, 0.4745098039215686, 0.5137254901960784],
                  RGBColor[0.7215686274509804, 0.7803921568627451, 0.8117647058823529]
                ]
              ],
              RectangleBox[
                {25.025 - 0.8755*#, 17.072 - 0.8755*#},
                {25.025 + 0.8755*#, 17.072 + 0.8755*#}
              ]
            }][Which[
              LessEqual[Typeset`t, 0.721068961924], 1.,
              LessEqual[Typeset`t, 0.739095763334], 1. + 27.736479069583464*(Typeset`t - 0.721068961924),
              LessEqual[Typeset`t, 0.811202968972], 1.5,
              LessEqual[Typeset`t, 0.829229770382], 1.5 + -27.736479069583293*(Typeset`t - 0.811202968972),
              LessEqual[Typeset`t, 1.], 1.,
              True, 1.
            ]],
            TrackedSymbols :> {Typeset`t}
          ],

          Dynamic[RawBoxes @
            Function[
            {
              RectangleBox[
                {29.373 - 0.8755*#, 17.072 - 0.8755*#},
                {29.373 + 0.8755*#, 17.072 + 0.8755*#}
              ],
              Directive[Opacity[
                2.*(# - 1.)],
                LightDarkSwitched[
                  RGBColor[0.3843137254901961, 0.4745098039215686, 0.5137254901960784],
                  RGBColor[0.7215686274509804, 0.7803921568627451, 0.8117647058823529]
                ]
              ],
              RectangleBox[
                {29.373 - 0.8755*#, 17.072 - 0.8755*#},
                {29.373 + 0.8755*#, 17.072 + 0.8755*#}
              ]
            }][Which[
              LessEqual[Typeset`t, 0.865283373202], 1.,
              LessEqual[Typeset`t, 0.883310174611], 1. + 27.736479071121884*(Typeset`t - 0.865283373202),
              LessEqual[Typeset`t, 0.955415833018], 1.5,
              LessEqual[Typeset`t, 0.973442634428], 1.5 + -27.736479069583293*(Typeset`t - 0.955415833018),
              LessEqual[Typeset`t, 1.], 1.,
              True, 1.
            ]],
            TrackedSymbols :> {Typeset`t}
          ]
        },
        PlotRange -> {{18., 32.}, {14.6, 19.6}},
        ImageSize -> {19, Automatic},
        Background -> None
      ]
    },
    BaseStyle -> {CacheGraphics -> False},
    ContentPadding -> False
  ],
  DynamicModuleValues :> {}
]