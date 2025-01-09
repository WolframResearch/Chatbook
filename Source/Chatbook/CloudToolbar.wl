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
(*Default Notebook Docked Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)

ToggleCloudNotebookAssistantMenu // beginDefinition

(* Try not to mess up any existing DockedCells *)
ToggleCloudNotebookAssistantMenu[ ] := (
    CurrentValue[ EvaluationNotebook[ ], DockedCells ] =
        Replace[
            CurrentValue[ EvaluationNotebook[ ], DockedCells ],
            {
                (* Remove if it exists *)
                Cell[ ___, CellTags -> "NotebookAssistantDockedCell", ___ ] -> Inherited,
                { first___, Cell[ ___, CellTags -> "NotebookAssistantDockedCell", ___ ], last___ } :> { first, last },
                (* Add if it does not exist *)
                { existing___ } :> { makeChatCloudDefaultNotebookDockedCell[ ], existing },
                c_Cell :> { makeChatCloudDefaultNotebookDockedCell[ ], c },
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
                            { { inlineCloudChatbookIcon[ "NewChat" ], tr[ "WorkspaceToolbarButtonLabelNew" ] } },
                            Alignment -> { Center, Baseline },
                            Spacings  -> { 0.3, 0 } ],
                        FrameMargins -> { { 4, 4 }, { 1, 1 } },
                        FrameStyle   -> ( Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[ RGBColor["#A1CDE4"], RGBColor["#E9F7FF"] ] )
                    ],
                    insertCellStyle @ "ChatDelimiter",
                    Appearance   -> "Suppressed",
                    ImageMargins -> { { 0, 0 }, { 2, 3 } },
                    ImageSize    -> Automatic
                ],
                Button[
                    Framed[
                        Grid[
                            { { inlineCloudChatbookIcon[ "InsertChatCell" ], tr[ "ChatToolbarInsertChatCell" ] } },
                            Alignment -> { Center, Baseline },
                            Spacings  -> { 0.3, 0 } ],
                        FrameMargins -> { { 4, 4 }, { 1, 1 } },
                        FrameStyle   -> ( Dynamic[ If[ CurrentValue[ "MouseOver" ], #1, #2 ] ]&[ RGBColor["#A1CDE4"], RGBColor["#E9F7FF"] ] )
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
                Background     -> RGBColor["#E9F7FF"],
                BaseStyle      -> { FontColor -> RGBColor["#333333"], FontFamily -> "Source Sans Pro", FontSize -> 12, FrameMargins -> { { 4, 4 }, { 2, 2 } } },
                RoundingRadius -> 4
            }
        }
    ],
    Background       -> RGBColor["#E9F7FF"],
    CellFrameMargins -> 1,
    CellTags         -> "NotebookAssistantDockedCell",
    TextAlignment    -> Center
]

makeChatCloudDefaultNotebookDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineCloudChatbookIcon*)
inlineCloudChatbookIcon // beginDefinition;

(* We inline these to so we don't have to release a new cloud version.
    FIXME: when a new cloud is built we can switch usage from inlineCloudChatbookIcon[name] to chatbookIcon[name, False] *)
inlineCloudChatbookIcon[ name_String ] := RawBoxes @ Lookup[<|
"InsertChatCellActive" -> GraphicsBox[
  {Thickness[0.06617782981861016], 
   {FaceForm[{RGBColor[
    0.8274509803921568, 0.8745098039215686, 0.9019607843137255], Opacity[
    1.]}], FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{
     12.77199935913086, 1.7160000801086426`}, {13.812999725341797`, 
     1.7160000801086426`}, {13.812999725341797`, 8.301000595092773}, {
     12.77199935913086, 8.301000595092773}, {12.77199935913086, 
     1.7160000801086426`}}}]}, 
   {FaceForm[{RGBColor[1., 1., 1.], Opacity[1.]}], 
    FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{10.692900657653809`, 
     10.008000373840332`}, {10.692900657653809`, 0.008000373840332031}, {
     15.11090087890625, 0.008000373840332031}, {15.11090087890625, 
     0.9569997787475586}, {11.692900657653809`, 0.9569997787475586}, {
     11.692900657653809`, 9.008000373840332}, {15.11090087890625, 
     9.008000373840332}, {15.11090087890625, 10.008000373840332`}, {
     10.692900657653809`, 10.008000373840332`}}}]}, 
   {FaceForm[{RGBColor[1., 1., 1.], Opacity[1.]}], 
    FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}, {{0, 2,
      0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {CompressedData["
1:eJxTTMoPSmViYGAQAWIQDQJM2ooOEJYSmHbovmOPzI/YdRKFDwVrZGYpIvM5
1sig8A/49zIj8x16pzOimceAZh+Y3+DJw+CAgw8CAjH8IsjySO4H8Ru2fV2B
zGfguskHdjfMfhgf5j4YH+Z+GB/qP2TzlNDsU3IAAGMLKnM=
      "], {{8.028999626636505, 8.}, {8.028999626636505, 3.}, {
      5.014999628067017, 3.}, {4.7129998207092285`, 3.}, {4.460999965667725, 
      2.8330001831054688`}, {3.0059995651245117`, 1.864999771118164}, {
      3.0059995651245117`, 2.}, {3.0059995651245117`, 3.}, {
      2.0059995651245117`, 3.}, {0.9999995231628418, 3.}, {0.9999995231628418,
       8.}, {8.028999626636505, 8.}}}]}},
  AspectRatio->Automatic,
  BaselinePosition->(Center -> Center),
  ImageSize->{17., 12.},
  PlotRange->{{-0.5, 15.610800743103027`}, {-0.5, 10.508200645446777`}}],

"InsertChatCell" -> GraphicsBox[
  {Thickness[0.06617782981861016], 
   {FaceForm[{RGBColor[
    0.6470588235294118, 0.7529411764705882, 0.8117647058823529], Opacity[
    1.]}], FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{
     12.77199935913086, 1.7160000801086426`}, {13.812999725341797`, 
     1.7160000801086426`}, {13.812999725341797`, 8.301000595092773}, {
     12.77199935913086, 8.301000595092773}, {12.77199935913086, 
     1.7160000801086426`}}}]}, 
   {FaceForm[{RGBColor[
    0.27450980392156865`, 0.6196078431372549, 0.796078431372549], Opacity[
    1.]}], FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1,
      0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{10.692900657653809`, 
     10.008000373840332`}, {10.692900657653809`, 0.008000373840332031}, {
     15.11090087890625, 0.008000373840332031}, {15.11090087890625, 
     0.9569997787475586}, {11.692900657653809`, 0.9569997787475586}, {
     11.692900657653809`, 9.008000373840332}, {15.11090087890625, 
     9.008000373840332}, {15.11090087890625, 10.008000373840332`}, {
     10.692900657653809`, 10.008000373840332`}}}]}, 
   {FaceForm[{RGBColor[
    0.27450980392156865`, 0.6196078431372549, 0.796078431372549], Opacity[
    1.]}], FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1,
      0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 
     3}}, {{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {CompressedData["

1:eJxTTMoPSmViYGAQAWIQDQJM2ooOEJYSmHbovmOPzI/YdRKFDwVrZGYpIvM5
1sig8A/49zIj8x16pzOimceAZh+Y3+DJw+CAgw8CAjH8IsjySO4H8Ru2fV2B
zGfguskHdjfMfhgf5j4YH+Z+GB/qP2TzlNDsU3IAAGMLKnM=
      "], {{8.028999626636505, 8.}, {8.028999626636505, 3.}, {
      5.014999628067017, 3.}, {4.7129998207092285`, 3.}, {4.460999965667725, 
      2.8330001831054688`}, {3.0059995651245117`, 1.864999771118164}, {
      3.0059995651245117`, 2.}, {3.0059995651245117`, 3.}, {
      2.0059995651245117`, 3.}, {0.9999995231628418, 3.}, {0.9999995231628418,
       8.}, {8.028999626636505, 8.}}}]}},
  AspectRatio->Automatic,
  BaselinePosition->(Center -> Center),
  ImageSize->{17., 12.},
  PlotRange->{{-0.5, 15.610800743103027`}, {-0.5, 10.508200645446777`}}],

"NewChatActive" -> GraphicsBox[
  {Thickness[0.09057068177375761], 
   {FaceForm[{RGBColor[1., 1., 1.], Opacity[1.]}], 
    FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{0., 
     10.}, {11.041000366210938`, 10.}, {11.041000366210938`, 11.}, {0., 
     11.}, {0., 10.}}}]}, 
   {FaceForm[{RGBColor[1., 1., 1.], Opacity[1.]}], 
    FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}, {{0, 2,
      0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {CompressedData["
1:eJxTTMoPSmViYGAQAWIQDQQJ7HrKDhCmEpj+bfXdHplf5v8Zha8t8QHEXyMz
SxGZz7FGBoV/wL+XGZnv0DudEc08BjT7IPx4CQ4HHHwQuJAmKoEsj+R+EL9B
7PdqZD5D1j1BFQck+2F8mPtgfJj7YXyo/5DNU0KzT8kBAHlvMuM=
      "], {{9.03490000963211, 8.}, {9.03490000963211, 3.}, {6.020900011062622,
       3.}, {5.718900203704834, 3.}, {5.46690034866333, 
      2.8330001831054688`}, {4.011899948120117, 1.864999771118164}, {
      4.011899948120117, 2.}, {4.011899948120117, 3.}, {3.011899948120117, 
      3.}, {2.0058999061584473`, 3.}, {2.0058999061584473`, 8.}, {
      9.03490000963211, 8.}}}]}},
  AspectRatio->Automatic,
  BaselinePosition->(Center -> Center),
  ImageSize->{13., 12.},
  PlotRange->{{-0.5, 11.54110050201416}, {-0.5, 11.5}}],

"NewChat" -> GraphicsBox[
  {Thickness[0.09057068177375761], 
   {FaceForm[{RGBColor[
    0.2784313725490196, 0.6235294117647059, 0.796078431372549], Opacity[1.]}],
     FilledCurveBox[{{{0, 2, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {{{0., 
     10.}, {11.041000366210938`, 10.}, {11.041000366210938`, 11.}, {0., 
     11.}, {0., 10.}}}]}, 
   {FaceForm[{RGBColor[
    0.2784313725490196, 0.6235294117647059, 0.796078431372549], Opacity[1.]}],
     FilledCurveBox[{{{0, 2, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {1, 3, 3}, {0, 1, 0}, {1, 3, 3}}, {{0, 2,
      0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {
     0, 1, 0}, {0, 1, 0}, {0, 1, 0}, {0, 1, 0}}}, {CompressedData["
1:eJxTTMoPSmViYGAQAWIQDQQJ7HrKDhCmEpj+bfXdHplf5v8Zha8t8QHEXyMz
SxGZz7FGBoV/wL+XGZnv0DudEc08BjT7IPx4CQ4HHHwQuJAmKoEsj+R+EL9B
7PdqZD5D1j1BFQck+2F8mPtgfJj7YXyo/5DNU0KzT8kBAHlvMuM=
      "], {{9.03490000963211, 8.}, {9.03490000963211, 3.}, {6.020900011062622,
       3.}, {5.718900203704834, 3.}, {5.46690034866333, 
      2.8330001831054688`}, {4.011899948120117, 1.864999771118164}, {
      4.011899948120117, 2.}, {4.011899948120117, 3.}, {3.011899948120117, 
      3.}, {2.0058999061584473`, 3.}, {2.0058999061584473`, 8.}, {
      9.03490000963211, 8.}}}]}},
  AspectRatio->Automatic,
  BaselinePosition->(Center -> Center),
  ImageSize->{13., 12.},
  PlotRange->{{-0.5, 11.54110050201416}, {-0.5, 11.5}}]
|>, 
name, $Failed]

inlineCloudChatbookIcon // endDefinition;

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
    insertStyleMenuItem[ chatbookIcon @ icon, style, shortcut ];

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
        chatbookExpression[ "AdvancedSettings" ]
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
