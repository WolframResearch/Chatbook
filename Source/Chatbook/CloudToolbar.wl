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
Needs[ "Wolfram`Chatbook`UI`"                 ];

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
            cloudPreferencesButton[ ]
        }
    },
    Alignment  -> { Left, Baseline },
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
    Module[ { iconTemplate, colorTemplate, buttonLabel, mouseover, buttonIcon, button },

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

        buttonLabel = Grid[
            { { Style[ "Chat Settings", FontColor -> # ], colorTemplate @ # } },
            Alignment -> { Left, Baseline }
        ] &;

        mouseover = Mouseover[ buttonLabel @ GrayLevel[ 0.25 ], buttonLabel @ Hue[ 0.59, 0.9, 0.93 ] ];

        buttonIcon = DeleteCases[
            mouseover (*/. HoldPattern[ ImageSize -> _ ] :> ImageSize -> { 22, 22 }*),
            BaselinePosition -> _,
            Infinity
        ];

        button = Button[ buttonIcon, togglePreferences @ EvaluationNotebook[ ], Method -> "Queued" ];

        cloudPreferencesButton[ ] = Pane[ button, FrameMargins -> { { 0, 10 }, { 0, 0 } } ]
    ],
    throwInternalFailure
];

cloudPreferencesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*togglePreferences*)
togglePreferences // beginDefinition;

togglePreferences[ nbo_NotebookObject ] :=
    togglePreferences[ nbo, Flatten @ List @ CurrentValue[ nbo, DockedCells ] ];

togglePreferences[ nbo_NotebookObject, { cell_Cell } ] :=
    SetOptions[ nbo, DockedCells -> { cell, $cloudPreferencesCell } ];

togglePreferences[ nbo_NotebookObject, { Inherited|$Failed } ] := SetOptions[
    nbo,
    DockedCells -> {
        Cell[ BoxData @ DynamicBox @ ToBoxes @ MakeChatCloudDockedCellContents[ ], Background -> None ],
        $cloudPreferencesCell
    }
];

togglePreferences[ nbo_NotebookObject, { cell_Cell, _Cell } ] :=
    SetOptions[ nbo, DockedCells -> { cell } ];

togglePreferences[ nbo_NotebookObject, _ ] :=
    SetOptions[ nbo, DockedCells -> Inherited ];

togglePreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*$cloudPreferencesCell*)
$cloudPreferencesCell := $cloudPreferencesCell = Cell[
    BoxData @ ToBoxes @ Pane[
        Dynamic[
            Replace[
                createCloudPreferencesContent[ ],
                _createCloudPreferencesContent -> ProgressIndicator[ Appearance -> "Percolate" ]
            ],
            BaseStyle -> { "Text" }
        ],
        ImageSize -> { Scaled[ 1 ], Automatic },
        Alignment -> { Center, Top }
    ],
    Background -> GrayLevel[ 0.95 ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createCloudPreferencesContent*)
createCloudPreferencesContent // beginDefinition;
createCloudPreferencesContent[ ] := createCloudPreferencesContent[ ] = createPreferencesContent[ ];
createCloudPreferencesContent // endDefinition;

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
