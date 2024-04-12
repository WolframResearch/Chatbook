RawBoxes @ Cell[
    TextData @ {
        trExprTemplate["APIKeyDialogCreateKeyTemplate"][<|"1" ->
        Cell @ BoxData @ TagBox[
            ButtonBox[
                StyleBox[ "here", FontFamily -> "Source Sans Pro" ],
                ButtonFunction :> SystemOpen[ "https://platform.openai.com/account/api-keys" ],
                Evaluator      -> Automatic,
                Method         -> "Preemptive",
                ButtonNote     -> "https://platform.openai.com/account/api-keys",
                ContentPadding -> False,
                BaseStyle      -> Dynamic @ FEPrivate`If[
                    CurrentValue[ "MouseOver" ],
                    { "Link", FontColor -> RGBColor[ 0.855, 0.396, 0.145 ] },
                    { "Link", FontColor -> RGBColor[ 0.020, 0.286, 0.651 ] }
                ]
            ],
            MouseAppearanceTag[ "LinkHand" ]
        ]|>],
        "\n",
        trExprTemplate["APIKeyDialogSaveKeyTemplate"][<|"1" ->
        Cell[
            BoxData @ RowBox @ {
                TagBox[
                    ButtonBox[
                        StyleBox[
                            "SystemCredential",
                            "SymbolsRefLink",
                            ShowStringCharacters -> True,
                            FontFamily           -> "Source Sans Pro"
                        ],
                        ButtonData     -> "paclet:ref/SystemCredential",
                        ContentPadding -> False,
                        BaseStyle      -> Dynamic @ FEPrivate`If[
                            CurrentValue[ "MouseOver" ],
                            { "Link", FontColor -> RGBColor[ 0.855, 0.396, 0.145 ] },
                            { "Link", FontColor -> RGBColor[ 0.020, 0.286, 0.651 ] }
                        ]
                    ],
                    MouseAppearanceTag[ "LinkHand" ]
                ],
                "[", "\"OPENAI_API_KEY\"", "]"
            },
            "InlineFormula",
            FontFamily           -> "Source Sans Pro",
            ShowStringCharacters -> True,
            FontSize             -> Inherited * 0.9
        ]|>]
    },
    "Text",
    FontSize -> 12
]