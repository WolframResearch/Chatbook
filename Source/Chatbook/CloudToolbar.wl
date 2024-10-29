(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CloudToolbar`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`UI`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$notebookTypeLabelOptions = Sequence[
    FontColor  -> RGBColor[ "#333333" ],
    FontFamily -> "Source Sans Pro",
    FontSize   -> 16,
    FontWeight -> "DemiBold"
];

$buttonHeight     = 20;
$menuItemIconSize = { 20, 20 };

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
            cloudCellInsertMenu[ ],
            cloudPreferencesButton[ ]
        }
    },
    Alignment  -> { Left, Center },
    Spacings   -> { 0.7, 0 },
    BaseStyle  -> { "Text", FontSize -> 14 },
    FrameStyle -> Directive[ Thickness[ 2 ], GrayLevel[ 0.9 ] ]
];

makeChatCloudDockedCellContents // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudCellInsertMenu*)
cloudCellInsertMenu // beginDefinition;

cloudCellInsertMenu[ ] := ActionMenu[
    toolbarButtonLabel @ Row @ {
        tr[ "ChatToolbarInsertChatCell" ],
        Spacer[ 5 ],
        RawBoxes @ TemplateBox[ { }, "ChatInputIcon" ]
    },
    {
        insertStyleMenuItem[ "ChatInputIcon", "ChatInput", "'" ],
        insertStyleMenuItem[ "SideChatIcon", "SideChat", "' '" ],
        insertStyleMenuItem[ "ChatSystemIcon", "ChatSystemInput", "' ' '" ],
        Delimiter,
        insertStyleMenuItem[ None, "ChatDelimiter", "~" ],
        insertStyleMenuItem[ None, "ChatBlockDivider", "~ ~" ]
    },
    FrameMargins -> { { 0, 0 }, { 0, 0 } }
];

cloudCellInsertMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolbarButtonLabel*)
toolbarButtonLabel // beginDefinition;

toolbarButtonLabel[ label_ ] := Pane[
    label,
    ImageSize    -> { Automatic, $buttonHeight },
    Alignment    -> { Center, Baseline },
    FrameMargins -> { { 8, 0 }, { 2, 2 } }
];

toolbarButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertStyleMenuItem*)
insertStyleMenuItem // beginDefinition;

insertStyleMenuItem[ icon_String, style_, shortcut_ ] :=
    insertStyleMenuItem[ chatbookIcon[ icon, False ], style, shortcut ];

insertStyleMenuItem[ None, style_, shortcut_ ] :=
    insertStyleMenuItem[ Spacer[ 0 ], style, shortcut ];

insertStyleMenuItem[ icon_, style_, shortcut_ ] :=
    Grid[
        { {
            Pane[ icon, ImageSize -> $menuItemIconSize ],
            Item[ style, ItemSize -> 12 ],
            Style[ shortcut, FontColor -> GrayLevel[ 0.75 ] ]
        } },
        Alignment -> { { Center, Left, Right }, Center }
    ] :> insertCellStyle @ style;

insertStyleMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCellStyle*)
insertCellStyle // beginDefinition;

insertCellStyle[ style_String ] :=
    insertCellStyle[ style, EvaluationNotebook[ ] ];

insertCellStyle[ style_String, nbo_NotebookObject ] := Enclose[
    Module[ { tag, cell, cellObject },
        tag = ConfirmBy[ CreateUUID[ ], StringQ, "UUID" ];
        cell = Cell[ "", style, CellTags -> tag ];
        SelectionMove[ nbo, After, Notebook ];
        NotebookWrite[ nbo, cell ];
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> tag ], $Failed ], _CellObject, "CellObject" ];
        If[ style =!= "ChatDelimiter", SelectionMove[ cellObject, Before, CellContents ] ];
        SetOptions[ cellObject, CellTags -> Inherited ];
        cellObject
    ],
    throwInternalFailure
];

insertCellStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudPreferencesButton*)
cloudPreferencesButton // beginDefinition;

cloudPreferencesButton[ ] := Button[
    toolbarButtonLabel @ Row @ {
        tr[ "ChatToolbarChatSettings" ],
        Spacer[ 5 ],
        Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "AdvancedSettings" ]
    },
    toggleCloudPreferences @ EvaluationNotebook[ ],
    FrameMargins -> { { 0, 4 }, { 0, 0 } }
];

cloudPreferencesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toggleCloudPreferences*)
toggleCloudPreferences // beginDefinition;

toggleCloudPreferences[ nbo_NotebookObject ] :=
    toggleCloudPreferences[ nbo, Flatten @ List @ CurrentValue[ nbo, DockedCells ] ];

toggleCloudPreferences[ nbo_NotebookObject, { cell_Cell } ] :=
    SetOptions[ nbo, DockedCells -> { cell, $cloudPreferencesCell } ];

toggleCloudPreferences[ nbo_NotebookObject, { Inherited|$Failed } ] := SetOptions[
    nbo,
    DockedCells -> {
        Cell[ BoxData @ DynamicBox @ ToBoxes @ MakeChatCloudDockedCellContents[ ], Background -> None ],
        $cloudPreferencesCell
    }
];

toggleCloudPreferences[ nbo_NotebookObject, { cell_Cell, _Cell } ] :=
    SetOptions[ nbo, DockedCells -> { cell } ];

toggleCloudPreferences[ nbo_NotebookObject, _ ] :=
    SetOptions[ nbo, DockedCells -> Inherited ];

toggleCloudPreferences // endDefinition;

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
cloudModelSelector[ ] := makeModelSelector[ "Cloud" ];
cloudModelSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Type Label*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$cloudChatBanner*)
$cloudChatBanner := Block[ { $CloudEvaluation = True },
    $cloudChatBanner = cvExpand @ PaneSelector[
        { True -> $chatDrivenNotebookLabel, False -> $chatEnabledNotebookLabel },
        Dynamic @ TrueQ @ cv[ EvaluationNotebook[ ], "ChatDrivenNotebook" ],
        ImageSize -> Automatic
    ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatDrivenNotebookLabel*)
$chatDrivenNotebookLabel := Grid[
    {
        {
            "",
            chatbookIcon[ "ChatDrivenNotebookIcon", False ],
            Style[ tr[ "ChatToolbarChatDrivenLabel" ], $notebookTypeLabelOptions ]
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
            Style[ tr[ "ChatToolbarChatEnabledLabel" ], $notebookTypeLabelOptions ]
        }
    },
    Alignment -> { Automatic, Center },
    Spacings  -> 0.5
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*forceRefreshCloudPreferences*)
forceRefreshCloudPreferences // beginDefinition;

forceRefreshCloudPreferences[ ] /; ! TrueQ @ $cloudNotebooks := Null;

forceRefreshCloudPreferences[ ] := forceRefreshCloudPreferences @ EvaluationNotebook[ ];

forceRefreshCloudPreferences[ nbo_NotebookObject ] := (
    SetOptions[ nbo, DockedCells -> Inherited ];
    Pause[ 0.5 ];
    toggleCloudPreferences @ nbo
);

forceRefreshCloudPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $cloudChatBanner;
];

End[ ];
EndPackage[ ];
