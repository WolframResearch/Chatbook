{
    Cell[ "Chat Context Settings", "Title" ],
    Cell @ CellGroupData[
        {
            Cell[
                TextData @ {
                    "System Prompt Text",
                    Cell @ BoxData @ PaneSelectorBox[
                        {
                            True ->
                                TemplateBox[
                                    {
                                        "ChatContextPreprompt",
                                        Cell[
                                            BoxData @ FrameBox[
                                                Cell[
                                                    "This is the text that tells you what to do.",
                                                    "MoreInfoText"
                                                ],
                                                Background -> GrayLevel[ 0.95 ],
                                                FrameMargins -> 20,
                                                FrameStyle -> GrayLevel[ 0.9 ],
                                                RoundingRadius -> 5,
                                                ImageSize -> { Scaled[ 0.65 ], Automatic }
                                            ],
                                            "MoreInfoText",
                                            Deletable -> True,
                                            CellTags -> {
                                                "SectionMoreInfoChatContextPreprompt"
                                            },
                                            CellMargins -> { { 66, 66 }, { 15, 15 } }
                                        ]
                                    },
                                    "MoreInfoOpenerButtonTemplate"
                                ]
                        },
                        Dynamic @ CurrentValue[
                            EvaluationNotebook[ ],
                            { TaggingRules, "ResourceCreateNotebook" }
                        ],
                        ImageSize -> Automatic
                    ]
                },
                "Section",
                CellTags -> {
                    "ChatContextPreprompt",
                    "NonDefault",
                    "System Prompt Text",
                    "TemplateCellGroup"
                },
                DefaultNewCellStyle -> "Text",
                Deletable -> False,
                Editable -> False,
                TaggingRules -> { "TemplateGroupName" -> "ChatContextPreprompt" }
            ],
            TemplateSlot[
                "ChatContextPreprompt",
                InsertionFunction -> Composition[ Apply @ Sequence, Flatten, List ],
                DefaultValue -> {
                    Cell[
                        "You are a helpful Wolfram Language programming assistant. Your job is to offer Wolfram Language code suggestions based on previous inputs and offer code suggestions to fix errors.",
                        "Text",
                        CellID -> 1,
                        CellTags -> { "NonDefault" }
                    ]
                }
            ]
        },
        Open
    ],
    Cell @ CellGroupData[
        {
            Cell[
                TextData @ {
                    "Cell Processing Function",
                    Cell @ BoxData @ PaneSelectorBox[
                        {
                            True ->
                                TemplateBox[
                                    {
                                        "ChatContextCellProcessingFunction",
                                        Cell[
                                            BoxData @ FrameBox[
                                                Cell[
                                                    "This is the text that tells you what to do.",
                                                    "MoreInfoText"
                                                ],
                                                Background -> GrayLevel[ 0.95 ],
                                                FrameMargins -> 20,
                                                FrameStyle -> GrayLevel[ 0.9 ],
                                                RoundingRadius -> 5,
                                                ImageSize -> { Scaled[ 0.65 ], Automatic }
                                            ],
                                            "MoreInfoText",
                                            Deletable -> True,
                                            CellTags -> {
                                                "SectionMoreInfoChatContextCellProcessingFunction"
                                            },
                                            CellMargins -> { { 66, 66 }, { 15, 15 } }
                                        ]
                                    },
                                    "MoreInfoOpenerButtonTemplate"
                                ]
                        },
                        Dynamic @ CurrentValue[
                            EvaluationNotebook[ ],
                            { TaggingRules, "ResourceCreateNotebook" }
                        ],
                        ImageSize -> Automatic
                    ]
                },
                "Section",
                CellTags -> {
                    "Cell Processing Function",
                    "ChatContextCellProcessingFunction",
                    "NonDefault",
                    "TemplateCellGroup"
                },
                Deletable -> False,
                Editable -> False,
                TaggingRules -> { "TemplateGroupName" -> "ChatContextCellProcessingFunction" }
            ],
            TemplateSlot[
                "ChatContextCellProcessingFunction",
                InsertionFunction -> Composition[ Apply @ Sequence, Flatten, List ],
                DefaultValue -> {
                    Cell[
                        BoxData[ "Automatic" ],
                        "Input",
                        CellID -> 2,
                        CellTags -> { "NonDefault" }
                    ]
                }
            ]
        },
        Open
    ],
    Cell @ CellGroupData[
        {
            Cell[
                TextData @ {
                    "Cell Post Evaluation Function",
                    Cell @ BoxData @ PaneSelectorBox[
                        {
                            True ->
                                TemplateBox[
                                    {
                                        "ChatContextPostEvaluationFunction",
                                        Cell[
                                            BoxData @ FrameBox[
                                                Cell[
                                                    "This is the text that tells you what to do.",
                                                    "MoreInfoText"
                                                ],
                                                Background -> GrayLevel[ 0.95 ],
                                                FrameMargins -> 20,
                                                FrameStyle -> GrayLevel[ 0.9 ],
                                                RoundingRadius -> 5,
                                                ImageSize -> { Scaled[ 0.65 ], Automatic }
                                            ],
                                            "MoreInfoText",
                                            Deletable -> True,
                                            CellTags -> {
                                                "SectionMoreInfoChatContextPostEvaluationFunction"
                                            },
                                            CellMargins -> { { 66, 66 }, { 15, 15 } }
                                        ]
                                    },
                                    "MoreInfoOpenerButtonTemplate"
                                ]
                        },
                        Dynamic @ CurrentValue[
                            EvaluationNotebook[ ],
                            { TaggingRules, "ResourceCreateNotebook" }
                        ],
                        ImageSize -> Automatic
                    ]
                },
                "Section",
                CellTags -> {
                    "Cell Post Evaluation Function",
                    "ChatContextPostEvaluationFunction",
                    "NonDefault",
                    "TemplateCellGroup"
                },
                Deletable -> False,
                Editable -> False,
                TaggingRules -> { "TemplateGroupName" -> "ChatContextPostEvaluationFunction" }
            ],
            TemplateSlot[
                "ChatContextPostEvaluationFunction",
                InsertionFunction -> Composition[ Apply @ Sequence, Flatten, List ],
                DefaultValue -> {
                    Cell[
                        BoxData[ "Automatic" ],
                        "Input",
                        CellID -> 3,
                        CellTags -> { "NonDefault" }
                    ]
                }
            ]
        },
        Open
    ],
    Cell[ "", "DialogDelimiter" ]
}