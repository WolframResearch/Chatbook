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
    FontColor  -> color @ "CloudToolbarFont",
    FontFamily -> "Source Sans Pro",
    FontSize   -> 16,
    FontWeight -> "DemiBold"
];

$buttonHeight     = 20;
$menuItemIconSize = { 20, 20 };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Notebook Docked Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*ToggleCloudNotebookAssistantMenu*)
ToggleCloudNotebookAssistantMenu // beginDefinition

(* Try not to mess up any existing DockedCells *)
(* NA cell is added to the top of the stack of DockedCells, but below the Chatbook cell if it exists *)
ToggleCloudNotebookAssistantMenu[ ] := (
    CurrentValue[ EvaluationNotebook[ ], DockedCells ] =
        Replace[
            CurrentValue[ FrontEnd`EvaluationNotebook[ ], DockedCells ],
            {
                (* ============ Remove if it exists ============ *)
                (* Case: NA cell is all alone (likely in default notebooks) *)
                Cell[ ___, CellTags -> "NotebookAssistantDockedCell", ___ ] -> Inherited,
                (* Case: NA cell is with other cells *)
                { first___, Cell[ ___, CellTags -> "NotebookAssistantDockedCell", ___ ], last___ } :> { first, last },

                (* ============ Add if it does not  ============ *)
                (* Case: Chatbook cell exists so put NA cell right below it *)
                { first___, cb:Cell[ ___, CellTags -> "ChatNotebookDockedCell", ___ ], last___ } :> { first, cb, makeChatCloudDefaultNotebookDockedCell[ ], last },
                (* Case: no Chatbook cell but others exist so prepend NA cell *)
                { existing___ } :> { makeChatCloudDefaultNotebookDockedCell[ ], existing },
                (* Case: standalone cell is the Chatbook cell *)
                c:Cell[ ___, CellTags -> "ChatNotebookDockedCell", ___ ] :> { c, makeChatCloudDefaultNotebookDockedCell[ ] },
                (* Case: standalone cell is something else *)
                c_Cell :> { makeChatCloudDefaultNotebookDockedCell[ ], c },
                (* Fallthrough: add the NA cell as the only cell *)
                _ :> { makeChatCloudDefaultNotebookDockedCell[ ] }
            }
        ];
)

ToggleCloudNotebookAssistantMenu // endDefinition

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatCloudDefaultNotebookDockedCell*)
makeChatCloudDefaultNotebookDockedCell // beginDefinition;

(* FIXME: if Cloud can support a pressed state, then use Chatbook's mouseDown function with FontColor -> GrayLevel[1] and Background -> RGBColor["#44A2D4"] *)
makeChatCloudDefaultNotebookDockedCell[ ] := Cell[ BoxData @ ToBoxes @
    Grid[
        {
            {
                Button[
                    Framed[
                        Grid[
                            { { chatbookIcon[ "NewChat", False ], tr[ "WorkspaceToolbarButtonLabelNew" ] } },
                            Alignment -> { Center, Baseline },
                            Spacings  -> { 0.3, 0 } ],
                        FrameMargins -> { { 4, 4 }, { 1, 1 } },
                        FrameStyle   -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                            color @ "NA_CloudToolbarButtonFrameHover",
                            color @ "NA_CloudToolbarButtonFrame"
                        ] )
                    ],
                    insertCellStyle @ "ChatDelimiter",
                    Appearance   -> "Suppressed",
                    ImageMargins -> { { 0, 0 }, { 2, 3 } },
                    ImageSize    -> Automatic
                ],
                Button[
                    Framed[
                        Grid[
                            { { chatbookIcon[ "InsertChatCell", False ], tr[ "ChatToolbarInsertChatCell" ] } },
                            Alignment -> { Center, Baseline },
                            Spacings  -> { 0.3, 0 } ],
                        FrameMargins -> { { 4, 4 }, { 1, 1 } },
                        FrameStyle   -> (Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[
                            color @ "NA_CloudToolbarButtonFrameHover",
                            color @ "NA_CloudToolbarButtonFrame"
                        ] )
                    ]                    ,
                    insertCellStyle @ "ChatInput",
                    Appearance   -> "Suppressed",
                    ImageMargins -> { { 0, 0 }, { 2, 3 } },
                    ImageSize    -> Automatic
                ]
            }
        },
        Alignment  -> { Left, Center },
        Spacings   -> { 0.3, 0 },
        BaseStyle  -> {
            "Text", FontSize -> 1, (* FontSize sets the Spacing scale *)
            FrameBoxOptions -> {
                Background     -> color @ "NA_CloudToolbarBackground",
                BaseStyle      -> { FontColor -> color @ "NA_CloudToolbarFont", FontFamily -> "Source Sans Pro", FontSize -> 12, FrameMargins -> { { 4, 4 }, { 2, 2 } } },
                RoundingRadius -> 4
            }
        }
    ],
    Background       -> color @ "NA_CloudToolbarBackground",
    CellFrameMargins -> 1,
    CellTags         -> "NotebookAssistantDockedCell",
    TextAlignment    -> Center
]

makeChatCloudDefaultNotebookDockedCell // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ToggleCloudPreferences*)
ToggleCloudPreferences // beginDefinition;
ToggleCloudPreferences[ ] := catchMine @ toggleCloudPreferences @ EvaluationNotebook[ ];
ToggleCloudPreferences[ nbo_NotebookObject ] := catchMine @ toggleCloudPreferences @ nbo;
ToggleCloudPreferences // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toggleCloudPreferences*)
toggleCloudPreferences // beginDefinition;

(* These cells are added to the bottom of the stack of DockedCells *)
toggleCloudPreferences[ nbo_NotebookObject ] :=
(
    CurrentValue[ nbo, DockedCells ] =
        Replace[
            CurrentValue[ nbo, DockedCells ],
            {
                (* ============ Remove if it exists ============ *)
                (* Case: preferences cell is all alone (unlikely) *)
                Cell[ ___, CellTags -> "CloudChatPreferencesDockedCell", ___ ] -> Inherited,
                (* Case: chat notebook cell is all alone (possible but don't remove if in a Chatbook.nb notebook) *)
                Cell[ ___, CellTags -> "ChatNotebookDockedCell", ___ ] -> Inherited /; CurrentValue[ nbo, StyleDefinitions ] =!= "Chatbook.nb",
                (* Case: preferences cell is with other cells *)
                { first___, Cell[ ___, CellTags -> "CloudChatPreferencesDockedCell", ___ ], last___ } :> { first, last },

                (* ============ Add if it does not  ============ *)
                (* Case: other cells exist so append preferences cell *)
                { existing___ } :> { existing, $cloudPreferencesCell },
                (* Case: one other cell exist so append preferences cell *)
                c_Cell :> { c, $cloudPreferencesCell },
                (* Fallthrough: reset all Chatbook DockedCells *)
                _ :> {
                        Cell[ BoxData @ DynamicBox @ ToBoxes @ MakeChatCloudDockedCellContents[ ], Background -> None, CellTags -> "ChatNotebookDockedCell"],
                        $cloudPreferencesCell
                    }
            }
        ];
)

toggleCloudPreferences // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
    Background -> color @ "CloudToolbarPreferencesCellBackground",
    CellTags -> "CloudChatPreferencesDockedCell"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createCloudPreferencesContent*)
createCloudPreferencesContent // beginDefinition;

createCloudPreferencesContent[ ] /; ! $CloudEvaluation :=
    Block[ { $CloudEvaluation = True }, createCloudPreferencesContent[ ] ];

createCloudPreferencesContent[ ] := createCloudPreferencesContent[ ] =
    inlineChatbookExpressions @ createPreferencesContent[ ];

createCloudPreferencesContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudModelSelector*)
cloudModelSelector // beginDefinition;
cloudModelSelector[ ] := makeModelSelector[ "Cloud" ];
cloudModelSelector // endDefinition;

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
    BaseStyle  -> { "Text", FontSize -> 14 }(*,
    FrameStyle -> Directive[ Thickness[ 2 ], GrayLevel[ 0.9 ] ] *)(* FIXME: no-op, grid has no dividers *)
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
        insertStyleMenuItem[ "SideChatIcon", "SideChat", "" ],
        insertStyleMenuItem[ "ChatSystemIcon", "ChatSystemInput", "" ],
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
    insertStyleMenuItem[ chatbookIcon @ icon, style, shortcut ];

insertStyleMenuItem[ None, style_, shortcut_ ] :=
    insertStyleMenuItem[ Spacer[ 0 ], style, shortcut ];

insertStyleMenuItem[ icon_, style_, shortcut_ ] :=
    Grid[
        { {
            Pane[ icon, ImageSize -> $menuItemIconSize ],
            Item[ style, ItemSize -> 12 ],
            Style[ shortcut, FontColor -> color @ "CloudToolbarMenuShortcutFont" ]
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
        SelectionMove[ nbo, After, Cell ]; (* prevents inline cells *)
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
        chatbookExpression[ "AdvancedSettings" ]
    },
    toggleCloudPreferences @ EvaluationNotebook[ ],
    FrameMargins -> { { 0, 4 }, { 0, 0 } }
];

cloudPreferencesButton // endDefinition;

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
            chatbookExpression[ "ChatDrivenNotebookIcon" ],
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
            chatbookExpression[ "ChatEnabledNotebookIcon" ],
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

forceRefreshCloudPreferences[ ] := If[ $cloudNotebooks, forceRefreshCloudPreferences @ EvaluationNotebook[ ], Null ];

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
