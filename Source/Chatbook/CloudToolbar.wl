(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CloudToolbar`" ];

HoldComplete[
    `makeChatCloudDockedCellContents;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                    ];
Needs[ "Wolfram`Chatbook`Common`"             ];
Needs[ "Wolfram`Chatbook`Dialogs`"            ];
Needs[ "Wolfram`Chatbook`Dynamics`"           ];
Needs[ "Wolfram`Chatbook`PreferencesContent`" ];
Needs[ "Wolfram`Chatbook`Services`"           ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$notebookTypeLabelOptions = Sequence[
    FontColor  -> RGBColor[ "#333333" ],
    FontFamily -> "Source Sans Pro",
    FontSize   -> 16,
    FontWeight -> "DemiBold"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Docked Cell Contents*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatCloudDockedCellContents*)
makeChatCloudDockedCellContents // beginDefinition;

makeChatCloudDockedCellContents[ ] :=
    Block[ { $preferencesScope := EvaluationNotebook[ ] },
        DynamicWrapper[
            Grid[
                {
                    {
                        Item[ $cloudChatBanner, Alignment -> Left ],
                        Item[ "", ItemSize -> Fit ],
                        makePersonaSelector[ ],
                        cloudModelSelector[ ]
                    }
                },
                Alignment  -> { Left, Baseline },
                Dividers   -> { { False, False, False, True }, False },
                Spacings   -> { 2, 0 },
                BaseStyle  -> { "Text", FontSize -> 14, FontColor -> GrayLevel[ 0.4 ] },
                FrameStyle -> Directive[ Thickness[ 2 ], GrayLevel[ 0.9 ] ]
            ],
            Needs[ "GeneralUtilities`" -> None ];
            CurrentValue[ EvaluationNotebook[ ], TaggingRules ] =
                GeneralUtilities`ToAssociations @ Replace[
                    CurrentValue[ EvaluationNotebook[ ], TaggingRules ],
                    Except[ KeyValuePattern @ { } ] :> <| |>
                ]
        ]
    ];

makeChatCloudDockedCellContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudModelSelector*)
cloudModelSelector // beginDefinition;

cloudModelSelector[ ] :=
    DynamicModule[ { serviceSelector, modelSelector },

        serviceSelector = PopupMenu[
            Dynamic[
                Replace[
                    CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatNotebookSettings", "Model" } ],
                    {
                        _String|Inherited :> "OpenAI",
                        KeyValuePattern[ "Service" -> service_String ] :> service,
                        _ :> Set[
                            CurrentValue[
                                EvaluationNotebook[ ],
                                { TaggingRules, "ChatNotebookSettings", "Model" }
                            ],
                            $DefaultModel
                        ][ "Service" ]
                    }
                ],
                Function[
                    CurrentValue[
                        EvaluationNotebook[ ],
                        { TaggingRules, "ChatNotebookSettings", "Model", "Service" }
                    ] = #1;

                    CurrentValue[
                        EvaluationNotebook[ ],
                        { TaggingRules, "ChatNotebookSettings", "Model", "Name" }
                    ] = Automatic;

                    cloudModelNameSelector[ Dynamic @ modelSelector, #1 ]
                ]
            ],
            KeyValueMap[
                #1 -> Row @ { inlineTemplateBoxes[ #2[ "Icon" ] ], Spacer[ 1 ], #2[ "Service" ] } &,
                $availableServices
            ]
        ];

        cloudModelNameSelector[
            Dynamic @ modelSelector,
            Replace[
                CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatNotebookSettings", "Model" } ],
                {
                    _String|Inherited :> "OpenAI",
                    KeyValuePattern[ "Service" -> service_String ] :> service,
                    _ :> Set[
                        CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatNotebookSettings", "Model" } ],
                        $DefaultModel
                    ][ "Service" ]
                }
            ]
        ];

        Row @ {
            "LLM Service: ", serviceSelector,
            Spacer[ 5 ],
            "Model: ", Dynamic @ modelSelector
        }
    ];

cloudModelSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudModelNameSelector*)
cloudModelNameSelector // beginDefinition;

cloudModelNameSelector[ Dynamic[ modelSelector_ ], service_String ] :=
    modelSelector = DynamicModule[ { display, models },
        display = ProgressIndicator[ Appearance -> "Percolate" ];
        Dynamic[ display ],
        Initialization :> (
            models = getServiceModelList @ service;
            If[ SameQ[
                    CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatNotebookSettings", "Model", "Name" } ],
                    Automatic
                ],
                CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatNotebookSettings", "Model", "Name" } ] =
                    First[ models, <| "Name" -> Automatic |> ][ "Name" ]
            ];

            display = PopupMenu[
                Dynamic[
                    Replace[
                        CurrentChatSettings[ EvaluationNotebook[ ], "Model" ],
                        { KeyValuePattern[ "Name" -> model_String ] :> model, _ :> Automatic }
                    ],
                    Function[
                        CurrentValue[
                            EvaluationNotebook[ ],
                            { TaggingRules, "ChatNotebookSettings", "Model", "Name" }
                        ] = #1
                    ]
                ],
                (#Name -> #DisplayName &) /@ models
            ]
        ),
        SynchronousInitialization -> False
    ];

cloudModelNameSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Type Label*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$cloudChatBanner*)
$cloudChatBanner := $cloudChatBanner = cvExpand @ PaneSelector[
    { True -> $chatDrivenNotebookLabel, False -> $chatEnabledNotebookLabel },
    Dynamic @ TrueQ @ cv[ EvaluationNotebook[ ], "ChatDrivenNotebook" ],
    ImageSize -> Automatic
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatDrivenNotebookLabel*)
$chatDrivenNotebookLabel := Grid[
    {
        {
            "",
            chatbookIcon[ "ChatDrivenNotebookIcon", False ],
            Style[ "Chat-Driven Notebook", $notebookTypeLabelOptions ]
        }
    },
    Alignment -> { Automatic, Center },
    Spacings  -> 0.5
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatEnabledNotebookLabel*)
$chatEnabledNotebookLabel := Grid[
    {
        {
            "",
            chatbookIcon[ "ChatEnabledNotebookIcon", False ],
            Style[ "Chat-Enabled Notebook", $notebookTypeLabelOptions ]
        }
    },
    Alignment -> { Automatic, Center },
    Spacings  -> 0.5
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $cloudChatBanner;
];

End[ ];
EndPackage[ ];
