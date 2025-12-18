(* ::Package:: *)

(* ::Section:: *)
(*Package Header*)


Begin[ "Wolfram`ChatbookStylesheetBuilder`Private`" ];


(* ::Section:: *)
(*Path setup*)


workspacePath = $darkFloatStyleSheetTarget (* 15.0+ stylesheet *)
corePath      = FileNameJoin[ { $InstallationDirectory, "SystemFiles", "FrontEnd", "StyleSheets", "Core.nb" } ]

ssName = "WorkspaceChat.nb";


prependRoot[ { path__ }, filename_ ] := FrontEnd`FileName[ { $RootDirectory, path }, filename ]


(* ::Section:: *)
(*Styles assuming current inheritance (WorkspaceChat.nb > Chatbook.nb > Default.nb > Core.nb)*)


(* Get all styles and environments from the original notebook before any changes were made: *)

env = CreateUUID[ ];

nbExpr = Get[ workspacePath ];
environments = Append[ Union @ Flatten @ Cases[ nbExpr, Cell[ sd : StyleData[ Except[ _Rule ], env_String, ___ ], ___ ] :> env, Infinity ], env ];
styles = Union[ Flatten[ Cases[ nbExpr, Cell[ sd : StyleData[ style : All | "All" | _String, ___ ], ___ ] :> style, Infinity ] ] ] /. All -> "All";

beforeTempPath = FileNameJoin[ { $TemporaryDirectory, "OLD" } ];

CreateDirectory[ beforeTempPath, CreateIntermediateDirectories -> True ];
CopyFile[ workspacePath, FileNameJoin[ { beforeTempPath, ssName } ], OverwriteTarget -> True ]

(* Calculate the options for all combinations of styles and environments: *)
WithCleanup[
    nb = CreateDocument[ { }, StyleDefinitions -> prependRoot[ FileNameSplit[ beforeTempPath ], ssName ] ];
    before = Table[ e -> Table[ s -> AbsoluteCurrentValue[ nb, { StyleDefinitions, { s, e } } ], { s, styles } ], { e, environments } ];
    ,
    NotebookClose @ nb ]


(* ::Section:: *)
(*Styles assuming only Core.nb*)


afterTempPath = FileNameJoin[ { $TemporaryDirectory, "NEW" } ];
CreateDirectory[ afterTempPath, CreateIntermediateDirectories -> True ];
CopyFile[ corePath, FileNameJoin[ { afterTempPath, ssName } ], OverwriteTarget -> True ];

(* Re-calculate the same set of styles and environments: *)
WithCleanup[
    nb = CreateDocument[ { }, StyleDefinitions -> prependRoot[ FileNameSplit[ afterTempPath ], ssName ] ];
    after = Table[ e -> Table[ s -> AbsoluteCurrentValue[ nb, { StyleDefinitions, { s, e } } ], { s, styles } ], { e, environments } ];
    ,
    NotebookClose @ nb ]


(* ::Section:: *)
(*Find style differences*)


(* Steps: *)
(* 1. Extract any cases where the previous data disagrees with the data pulled from the updated stylesheet: *)
(* 2. Remove specific styles that cannot be applied at the notebook scope in the side bar. *)

fails = Cases[ Table[ { e, s } -> Lookup[ Lookup[ before, e ], s ] === Lookup[ Lookup[ after, e ], s ], { s, styles }, { e, environments } ] // Flatten, HoldPattern[ val_ -> False ] :> val ]
fails = DeleteCases[ fails, { _, "Notebook" | "PrintTemporary" | "CellExpression" | "AttachedCell" | "DockedCell" } ];

(* 3. Only include styles that aren't included in, or are modified from, CoreExtensions.nb. Directly inherit within CoreExtensions.nb. *)
(* 4. CellFrameLabels is not supported by inline cells so use AttachCell instead *)

SidebarCoreExtensionCells[ ] :=
MapThread[
    Module[ { b, a, optionsList },
        b = Lookup[ Lookup[ before, #1 ], #2 ];
        a = Lookup[ Lookup[ after,  #1 ], #2 ];
        optionsList = DeleteCases[ SortBy[ Complement[ b, a ], First ], _[ System`MenuCommandKey | System`MenuSortingValue, _ ] ];
        Switch[ #2,
            "ChatInput",
                optionsList = Flatten @
                    Replace[ optionsList,
                        {
                            _[ CellFrameLabelMargins, _ ] :> None,
                            _[ CellFrameLabels, { { _, c_Cell }, _ } ] :> { CellFrameLabels -> None } },
                        1],
            "ChatOutput",
                optionsList = Flatten @
                    Replace[ optionsList,
                        {
                            _[ CellFrameLabelMargins, _ ] :> None,
                            _[ CellFrameLabels, { { c_Cell, _ }, _ } ] :> { CellFrameLabels -> None } },
                        1],
            "WorkspaceChatToolbarTitle",
                optionsList = { FontColor -> color @ "NA_ToolbarTitleFont", FontSize  -> 12 },
            _,
                Null];
        
        Switch[ #2,
            "AssistantMessageBox",  (* the FrameBox is effecively the same as in WorkspaceChat.nb, with added ImageMargins because we use an Overlay to add the icon *)
                Cell[
                    StyleData[ "NotebookAssistant`Sidebar`AssistantMessageBox" ], (* no need to inherit StyleData as this only defines the DisplayFunction *)
                    TemplateBoxOptions -> {
                        DisplayFunction -> Function @ Evaluate @ OverlayBox[
                            {
                                TagBox[
                                    FrameBox[
                                        #,
                                        BaseStyle      -> { "Text", Editable -> False, Selectable -> False },
                                        Background     -> color @ "NA_AssistantMessageBoxBackground",
                                        FrameMargins   -> 8,
                                        FrameStyle     -> Directive[ AbsoluteThickness[ 2 ], color @ "NA_AssistantMessageBoxFrame" ],
                                        ImageMargins   -> { { 15, 15 }, { 30, 12 } }, (* TWEAK: workaround for an inline cell, WorkspaceChat.nb's CellOutput style's CellMargins *)
                                        ImageSize      -> { Scaled[ 1 ], Automatic },
                                        RoundingRadius -> 8,
                                        StripOnInput   -> False
                                    ],
                                    EventHandlerTag @ {
                                        "MouseEntered" :>
                                            If[ TrueQ @ $CloudEvaluation,
                                                Null,
                                                With[ { cell = EvaluationCell[ ] },
                                                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                                                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AttachAssistantMessageButtons", cell, True (* forces attachment! *) ]
                                                ]
                                            ],
                                        Method         -> "Preemptive",
                                        PassEventsDown -> Automatic,
                                        PassEventsUp   -> True
                                    }
                                ],
                                (* This used to be a CellFrameLabel within the ChatOutput style, but that option isn't supported in inline cells in the side bar *)
                                PaneBox[
                                    DynamicBox[
                                        ToBoxes[
                                            Needs[ "Wolfram`Chatbook`" -> None ];
                                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "AssistantMessageLabel" ],
                                            StandardForm
                                        ],
                                        SingleEvaluation -> True
                                    ],
                                    FrameMargins -> { { 5, 0 }, { 0, 23 } }  (* TWEAK: push down the icon to align in the overlay *)
                                ]
                            },
                            All,
                            1,
                            Alignment -> { Left, Top }
                        ]
                    }
                ],

            "UserMessageBox",
                Cell[
                    StyleData[ "NotebookAssistant`Sidebar`UserMessageBox" ], (* no need to inherit StyleData as this only defines the DisplayFunction *)
                    TemplateBoxOptions -> {
                        DisplayFunction -> Function @ Evaluate @ OverlayBox[
                            {
                                PaneBox[
                                    FrameBox[
                                        #,
                                        BaseStyle      -> { "Text", Editable -> False, Selectable -> False },
                                        Background     -> color @ "UserMessageBoxBackground",
                                        FrameMargins   -> { { 8, 15 }, { 8, 8 } },
                                        FrameStyle     -> color @ "UserMessageBoxFrame",
                                        RoundingRadius -> 8,
                                        StripOnInput   -> False
                                    ],
                                    Alignment    -> Right,
                                    ImageMargins -> { { 15, 15 }, { 5, 10 } }, (* TWEAK: workaround for an inline cell, WorkspaceChat.nb's CellInput style's CellMargins *)
                                    ImageSize    -> { Full, Automatic }
                                ],
                                PaneBox[
                                    DynamicBox[
                                        ToBoxes[
                                            Needs[ "Wolfram`Chatbook`" -> None ];
                                            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "UserMessageLabel" ],
                                            StandardForm
                                        ],
                                        SingleEvaluation -> True
                                    ],
                                    FrameMargins -> { { 0, 5 }, { 0, 20 } }
                                ]
                            },
                            All,
                            1,
                            Alignment -> { Right, Top }
                        ]
                    }
                ],

            _,
                Cell[
                    StyleData[
                        "NotebookAssistant`Sidebar`" <> StringReplace[ #2, StartOfString ~~ "WorkspaceChat" -> "" ],
                        Which[
                            #2 === "WorkspaceChatToolbarTitle", StyleDefinitions -> StyleData[ "NotebookAssistant`Sidebar`ToolbarButtonLabel" ],
                            a === { }, Sequence @@ { },
                            True, StyleDefinitions -> StyleData[ #2 ] ] ],
                    Sequence @@ optionsList ]
        ]
    ]&,
    (Transpose @ fails) ]


(* ::Section:: *)
(*Package Footer*)


End[ ];
