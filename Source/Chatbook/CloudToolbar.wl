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
                        makeModelSelector[ ]
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
