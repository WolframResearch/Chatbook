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

makeChatCloudDockedCellContents[ ] := Grid[
    {
        {
            Item[ $cloudChatBanner, Alignment -> Left ],
            Item[ "", ItemSize -> Fit ],
            makePersonaSelector[ ],
            cloudModelSelector[ ],
            cloudPreferencesButton[ ]
        }
    },
    Alignment  -> { Left, Baseline },
    Dividers   -> { { False, False, False, True, True }, False },
    Spacings   -> { 2, 0 },
    BaseStyle  -> { "Text", FontSize -> 14, FontColor -> GrayLevel[ 0.4 ] },
    FrameStyle -> Directive[ Thickness[ 2 ], GrayLevel[ 0.9 ] ]
];

makeChatCloudDockedCellContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudPreferencesButton*)
cloudPreferencesButton // beginDefinition;

cloudPreferencesButton[ ] := Enclose[
    Module[ { iconTemplate, colorTemplate, mouseover, buttonIcon, button },

        iconTemplate = ConfirmMatch[
            chatbookIcon[ "ToolManagerCog", False ],
            RawBoxes @ TemplateBox[ { }, __ ],
            "IconTemplate"
        ];

        colorTemplate = ConfirmMatch[
            Insert[ iconTemplate, #, { 1, 1, 1 } ],
            RawBoxes @ TemplateBox[ { _? ColorQ }, __ ],
            "Colorize"
        ] &;

        mouseover = Mouseover[
            colorTemplate @ GrayLevel[ 0.65 ],
            colorTemplate @ Hue[ 0.59, 0.9, 0.93 ]
        ];

        buttonIcon = DeleteCases[
            mouseover /. HoldPattern[ ImageSize -> _ ] :> ImageSize -> { 22, 22 },
            BaselinePosition -> _,
            Infinity
        ];

        button = Button[
            Tooltip[ buttonIcon, "Global chat preferences" ],
            $cloudEvaluationNotebook = EvaluationNotebook[ ];
            CreateDialog @ Style[ Dynamic @ notebookSettingsPanel[ ], "Text" ],
            Appearance -> "Suppressed",
            Method     -> "Queued"
        ];

        cloudPreferencesButton[ ] = Pane[ button, FrameMargins -> { { 0, 10 }, { 0, 0 } } ]
    ],
    throwInternalFailure
];

cloudPreferencesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudModelSelector*)
cloudModelSelector // beginDefinition;
cloudModelSelector[ ] := makeModelSelector[ ];
cloudModelSelector // endDefinition;

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
