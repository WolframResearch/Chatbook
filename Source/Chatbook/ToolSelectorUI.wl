(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ToolSelectorUI`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`CreateLLMToolPalette;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$toolsWidth    = 240;
$personasWidth = 30;
$rightColWidth = 107;
$rowHeight     = 30;
$highlightCol  = GrayLevel[ 0.95 ];
$dividerCol    = GrayLevel[ 0.85 ];
$activeBlue    = Hue[ 0.59, 0.9, 0.93 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolPalette*)
CreateLLMToolPalette // beginDefinition;

CreateLLMToolPalette[ tools_List, personas_List ] :=
    Module[
        {
            preppedPersonas, preppedTools, personaNames, personaDisplayNames,
            toolNames, toolDefaultPersonas,
            gridOpts, $sectionSpacer, sectionHeading, indent
        },

        gridOpts = Sequence[
            Spacings -> { 0, 0 },
            ItemSize -> { 0, 0 },
            Dividers -> { None, { None, { GrayLevel[ 0.9 ] }, None } }
        ];

        $sectionSpacer = { Spacer @ { 0, 15 }, SpanFromLeft };

        sectionHeading[ heading_, pad_: { 5, 10 } ] := {
            Pane[ headerStyle @ heading, FrameMargins -> { { 0, 0 }, pad } ],
            SpanFromLeft
        };

        indent[ expr: Except[ _Integer ] ] := { Spacer @ { 10, 0 }, expr };

        indent[ i_Integer ] := { Spacer @ { i, 0 }, #1 } &;

        inWindow @ DynamicModule[
            {
                sH           = 0,
                sV           = 0,
                w            = 167,
                h            = 258,
                row          = None,
                column       = None,
                scopeMode    = $FrontEnd &,
                scope        = $FrontEnd,
                notInherited = None,
                notInheritedStyle,
                toolLookup   = Association @ MapThread[
                    Rule,
                    { Through @ tools[ "CanonicalName" ], Range @ Length @ tools }
                ]
            },

            preppedPersonas     = prepPersonas[ personas, Dynamic @ { row, column } ];
            preppedTools        = prepTools[ tools, Dynamic @ { row, column } ];
            personaNames        = Through @ personas[ "Name" ];
            personaDisplayNames = Through @ personas[ "DisplayName" ];
            toolNames           = Through @ tools[ "CanonicalName" ];

            (* Produce an association whose keys are tool names, and values are all the personas which list that tool in
               their default tools to use. *)
            toolDefaultPersonas =
                With[ { personaDefaults = (#[ "Name" ] -> Lookup[ #, "Tools", { } ] &) /@ personas },
                    Association @ Map[
                        Function[
                            toolName,
                            toolName -> First /@ Select[ personaDefaults, MemberQ[ Last @ #, toolName ] & ]
                        ],
                        toolNames
                    ]
                ];

            DynamicWrapper[
                Grid[
                    {
                        (* ----- Install Tools ----- *)
                        sectionHeading[ "Install Tools", { 5, 0 } ],
                        indent @ Grid[
                            {
                                {
                                    Button[ "LLM Tool Repository \[UpperRightArrow]", Null, BaseStyle -> $baseStyle ],
                                    Spacer[ 5 ],
                                    Button[ "Install From File...", Null, BaseStyle -> $baseStyle ]
                                }
                            },
                            Spacings -> { 0, 0 }
                        ],
                        $sectionSpacer,

                        (* ----- Configure and Enable Tools ----- *)
                        sectionHeading[ "Manage and Enable Tools", { 8, 15 } ],
                        indent @ Row @ {
                            "Scope for enable/disable checkboxes:",
                            Spacer[ 5 ],
                            scopeSelector @ Dynamic @ scopeMode
                        },
                        indent @ Spacer @ { 0, 17 },

                        indent @ EventHandler[
                            Grid[
                                {
                                    Append[
                                        Map[
                                            Function @ EventHandler[
                                                Pane[ #, FrameMargins -> { { 0, 0 }, { 2, 2 } } ],
                                                { "MouseEntered" :> FEPrivate`Set[ { row, column }, { None, None } ] }
                                            ],
                                            {
                                                "Tool",
                                                Row @ {
                                                    Spacer[ 4 ],
                                                    "Enabled for\[VeryThinSpace]:",
                                                    Spacer[ 5 ],
                                                    personaNameDisp[ personaDisplayNames, Dynamic @ column ]
                                                }
                                            }
                                        ],
                                        SpanFromLeft
                                    ],
                                    {
                                        "",
                                        (* Row of persona icons: *)
                                        linkedPane[
                                            Grid[
                                                { preppedPersonas },
                                                Background -> With[ { c = $highlightCol },
                                                    Dynamic @ { { column -> c }, { } }
                                                ],
                                                Alignment -> { Center, Center },
                                                gridOpts
                                            ],
                                            Dynamic[ { w, Automatic } ],
                                            Dynamic[ { sH, 0 }, FEPrivate`Set[ sH, FEPrivate`Part[ #, 1 ] ] & ],
                                            FrameMargins -> { { 0, 0 }, { 0, 0 } }
                                        ],
                                        ""
                                    },
                                    {
                                        (* Tools column: *)
                                        linkedPane[
                                            Grid[
                                                List /@ preppedTools,
                                                Background -> With[ { c = $highlightCol },
                                                    Dynamic @ { None, { row -> c }, notInheritedStyle }
                                                ],
                                                Alignment -> Left,
                                                gridOpts
                                            ],
                                            Dynamic[ { Automatic, h } ],
                                            Dynamic[ { 0, sV }, FEPrivate`Set[ sV, FEPrivate`Part[ #, 2 ] ] & ],
                                            FrameMargins -> { { 0, 0 }, { 15, 0 } }
                                        ],

                                        (* Checkbox grid: *)
                                        linkedPane[
                                            Grid[
                                                Table[
                                                    enabledControl[
                                                        { i, tools[[ i ]][ "CanonicalName" ] },
                                                        { j, personas[[ j ]][ "Name" ] },
                                                        Dynamic @ { row, column },
                                                        Dynamic @ scope,
                                                        personaNames
                                                    ],
                                                    { i, Length @ tools    },
                                                    { j, Length @ personas }
                                                ],
                                                Background -> With[ { c = $highlightCol },
                                                    Dynamic @ { { column -> c }, { row -> c }, notInheritedStyle }
                                                ],
                                                gridOpts
                                            ],
                                            Dynamic[
                                                { w, h },
                                                Function[

                                                    FEPrivate`Set[
                                                        w,
                                                        FEPrivate`If[
                                                            FEPrivate`Greater[ FEPrivate`Part[ #, 1 ], 166 ],
                                                            FEPrivate`Part[ #, 1 ],
                                                            167
                                                        ]
                                                    ];

                                                    FEPrivate`Set[
                                                        h,
                                                        FEPrivate`If[
                                                            FEPrivate`Greater[ FEPrivate`Part[ #, 2 ], 257 ],
                                                            FEPrivate`Part[ #, 2 ],
                                                            258
                                                        ]
                                                    ]
                                                ]
                                            ],
                                            Dynamic @ { sH, sV },
                                            Scrollbars -> { Automatic, False }
                                        ],

                                        (* All/None and clear column: *)
                                        linkedPane[
                                            Grid[
                                                MapThread[
                                                    Function @ {
                                                        rightColControl[
                                                            { #1, #2 },
                                                            Dynamic @ { row, column },
                                                            Dynamic @ scope,
                                                            Dynamic @ notInherited,
                                                            toolDefaultPersonas[ #2 ]
                                                        ]
                                                    },
                                                    { Range @ Length @ tools, toolNames }
                                                ],
                                                Background -> With[ { c = $highlightCol },
                                                    Dynamic @ { None, { row -> c }, notInheritedStyle }
                                                ],
                                                gridOpts
                                            ],
                                            Dynamic @ { Automatic, h },
                                            Dynamic[ { 0, sV }, FEPrivate`Set[ sV, FEPrivate`Part[ #, 2 ] ] & ],
                                            AppearanceElements -> None,
                                            FrameMargins       -> { { 0, 10 }, { 15, 0 } },
                                            Scrollbars         -> { False, Automatic }
                                        ]
                                    }
                                },
                                Alignment -> { Left, Top },
                                BaseStyle -> $baseStyle,
                                ItemSize  -> { 0, 0 },
                                Spacings  -> { 0, 0 },
                                Dividers  -> {
                                    { False, $dividerCol, $dividerCol, { False } },
                                    { False, False      , $dividerCol, { False } }
                                }
                            ],
                            { "MouseExited" :> FEPrivate`Set[ { row, column }, { None, None } ] },
                            PassEventsDown -> True
                        ]
                    },
                    Alignment -> { Left, Top },
                    BaseStyle -> $baseStyle,
                    Dividers  -> { False, { False, False, False, $dividerCol, { False } } },
                    ItemSize  -> { Automatic, 0 },
                    Spacings  -> { 0, 0 }
                ],

                (* Resolve scope to $FrontEnd, a notebook object, or list of cell objects. *)
                scope = scopeMode[ ];

                (* Determine which tools have a value set at the current scope. This logic is too involved to do in the
                   front end, but the code doesn't fire often so there's no significant disadvantage to running it in
                   the kernel. *)
                Switch[
                    scope,

                    (* Compare notebook to $FrontEnd. *)
                    _NotebookObject, (
                        notInherited = Map[
                            toolLookup,
                            Keys @ DeleteCases[
                                Merge[
                                    {
                                        AbsoluteCurrentValue[ $FrontEnd, { TaggingRules, "ToolsTest" } ],
                                        AbsoluteCurrentValue[ scope, { TaggingRules, "ToolsTest" } ]
                                    },
                                    (* Inheriting if there are exactly two identical copies of a value. *)
                                    Length @ # === 2 && SameQ @@ # &
                                ],
                                True
                            ]
                        ];

                        notInheritedStyle = ({ { #, # }, { 1, -1 } } -> Hue[ 0.59, 0.48, 1, 0.1 ] &) /@ notInherited
                    ),

                    (* Compare cell to parent notebook. *)
                    { __CellObject }, (
                        notInherited = Map[
                            toolLookup,
                            Keys @ DeleteCases[
                                Merge[
                                    {
                                        AbsoluteCurrentValue[
                                            ParentNotebook @ First @ scope,
                                            { TaggingRules, "ToolsTest" }
                                        ],
                                        Splice @ AbsoluteCurrentValue[ scope, { TaggingRules, "ToolsTest" } ]
                                    },
                                    (* Inheriting if there are exactly as many identical copies of a value as there are
                                       selected cells plus the parent scope. *)
                                    Length @ # === 1 + Length @ scope && SameQ @@ # &
                                ],
                                True
                            ]
                        ];

                        notInheritedStyle = ({ { #, # }, { 1, -1 } } -> Hue[ 0.59, 0.48, 1, 0.1 ] &) /@ notInherited
                    ),

                    (* Otherwise we're looking at $FrontEnd (or no selection if scope is {}). *)
                    _, (
                        notInherited = notInheritedStyle = None
                    )
                ]
            ],
            UnsavedVariables :> { sH, sV, w, h, row, column },
            Initialization   :> (scopeMode = $FrontEnd &)
        ]
    ];

CreateLLMToolPalette // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$baseStyle*)
$baseStyle = { FontFamily -> "Source Sans Pro", FontSize -> 14, FontColor -> GrayLevel[ 0.3 ] };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*headerStyle*)
headerStyle // beginDefinition;
headerStyle[ expr_, opts___ ] := Style[ expr, FontWeight -> Bold, opts ];
headerStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Overlays*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachOverlay*)

(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
attachOverlay // beginDefinition;

attachOverlay[ expr_, opts___ ] := AttachCell[
    EvaluationNotebook[ ],
    DynamicModule[ { },
        Overlay[
            {
                Framed[
                    "",
                    Background -> GrayLevel[ 0.97, 0.85 ],
                    FrameStyle -> None,
                    ImageSize  -> { Full, Last @ AbsoluteCurrentValue[ EvaluationNotebook[ ], WindowSize ] }
                ],
                Framed[
                    overlayGrid @ expr,
                    Background       -> White,
                    DefaultBaseStyle -> $baseStyle,
                    FrameStyle       -> GrayLevel[ 0.85 ],
                    RoundingRadius   -> 4,
                    opts
                ]
            },
            { 1, 2 },
            2,
            Alignment -> { Center, Center }
        ],
        InheritScope -> True
    ],
    { Center, Center },
    Automatic,
    { Center, Center },
    RemovalConditions -> { }
];

attachOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*overlayGrid*)
overlayGrid // beginDefinition;

overlayGrid[ { title_, body_, { label1_, Hold[ action1_ ], label2_, Hold[ action2_ ] } } ] := Grid[
    {
        { headerStyle @ title, SpanFromLeft },
        { body               , SpanFromLeft },
        {
            "",
            Button[ label1, action1, BaseStyle -> $baseStyle ],
            Spacer[ 5 ],
            Button[ label2, action2, BaseStyle -> $baseStyle ]
        }
    },
    Alignment -> Left,
    ItemSize  -> { { Fit, { 0 } }, 0 },
    Spacings  -> { 0, 0.4 }
];

overlayGrid[ expr: Except[ _List ] ] := expr;

overlayGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepTools*)

(* :!CodeAnalysis::Disable::DuplicateKeys::ListOfRules:: *)
prepTools // beginDefinition;

prepTools[ tools: { __Association }, Dynamic[ { row_, column_ } ] ] :=
    MapThread[
        Function[
            EventHandler[
                Row @ {
                    PaneSelector[
                        MapThread[
                            Function[
                                { val, colCog, colDelimiter },
                                val -> Pane @ Grid[
                                    {
                                        {
                                            Spacer[ 5 ],
                                            #[ "Icon" ],
                                            Spacer[ 5 ],
                                            #[ "CanonicalName" ],
                                            Dynamic @ iconData[ "Cog", colCog ],
                                            Spacer[ 5 ],
                                            Dynamic @ iconData[ "Delimiter", colDelimiter ]
                                        }
                                    },
                                    Alignment -> Left,
                                    ItemSize  -> { { { 0 }, Fit, 0, 0, 0 }, 0 },
                                    Spacings  -> { 0, 0 }
                                ]
                            ],
                            {
                                { { False, False } , { True, False }  , { True, True }   },
                                { LineColor -> None, GrayLevel[ 0.65 ], $activeBlue      },
                                { LineColor -> None, GrayLevel[ 0.80 ], GrayLevel[ 0.8 ] }
                            }
                        ],
                        Dynamic @ { FEPrivate`SameQ[ row, #2 ], FrontEnd`CurrentValue[ "MouseOver" ] },
                        BaselinePosition -> Center -> Center,
                        FrameMargins     -> None,
                        ImageSize        -> { $toolsWidth, $rowHeight }
                    ],
                    PaneSelector[
                        MapThread[
                            Function[
                                { val, colBin, colDelimiter },
                                val -> Grid[
                                    {
                                        {
                                            Spacer[ 5 ],
                                            deleteButton[ colBin, #2, #1 ],
                                            Spacer[ 3 ],
                                            Dynamic @ iconData[ "Delimiter", LineColor -> None ]
                                        }
                                    },
                                    ItemSize -> { 0, 0 },
                                    Spacings -> { 0, 0 }
                                ]
                            ],
                            {
                                { { False, False } , { True, False }  , { True, True }    },
                                { LineColor -> None, GrayLevel[ 0.65 ], $activeBlue       },
                                { LineColor -> None, LineColor -> None, LineColor -> None }
                            }
                        ],
                        Dynamic @ { FEPrivate`SameQ[ row, #2 ], FrontEnd`CurrentValue[ "MouseOver" ] },
                        BaselinePosition -> Center -> Center,
                        FrameMargins     -> None,
                        ImageSize        -> { Automatic, $rowHeight }
                    ],
                    Spacer[ 2 ]
                },
                { "MouseEntered" :> FEPrivate`Set[ { row, column }, { #2, None } ] },
                PassEventsDown -> True
            ]
        ],
        { tools, Range @ Length @ tools }
    ];

prepTools // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteButton*)
deleteButton // beginDefinition;

deleteButton[ colBin_, row_, tool_Association ] := Button[
    Dynamic @ iconData[ "Bin", colBin ],
    attachOverlay[
        {
            Style[ "Delete Tool", Bold ],
            Row @ { tool[ "Icon" ], Spacer[ 3 ], tool[ "CanonicalName" ] },
            {
                "Cancel",
                Hold @ NotebookDelete @ EvaluationCell[ ],
                Style[ "Delete", Red ],
                Hold @ NotebookDelete @ EvaluationCell[ ]
            }
        },
        FrameMargins -> { 13 * { 1, 1 }, 10 * { 1, 1 } },
        ImageSize    -> { 300, Automatic }
    ],
    Appearance       -> "Suppressed",
    BaselinePosition -> Center -> Center,
    ContentPadding   -> False,
    FrameMargins     -> { { 0, 0 }, { 2, 0 } },
    ImageSize        -> { Automatic, $rowHeight }
];

deleteButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepPersonas*)
prepPersonas // beginDefinition;

prepPersonas[ personas: { __Association }, Dynamic[ { row_, column_ } ] ] := MapThread[
    Function @ EventHandler[
        Framed[
            #1[ "Icon" ],
            Alignment    -> { Center, Center },
            BaseStyle    -> { LineBreakWithin -> False },
            FrameMargins -> None,
            FrameStyle   -> None,
            ImageSize    -> { $personasWidth, $personasWidth }
        ],
        { "MouseEntered" :> FEPrivate`Set[ { column, row } = { #2, None } ] },
        PassEventsDown -> True
    ],
    { personas, Range @ Length @ personas }
];

prepPersonas // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*enabledControl*)
enabledControl // beginDefinition;

enabledControl[
    { row_, toolName_ },
    { column_, personaName_ },
    Dynamic[ { dRow_, dColumn_ } ],
    Dynamic[ scope_ ],
    allPersonas_
] := EventHandler[
    Framed[
        Checkbox[
            Dynamic[
                Function[
                    FEPrivate`If[
                        FEPrivate`SameQ[ FEPrivate`Head @ scope, List ]
                        ,
                        FEPrivate`Which[
                            (* No cells selected. *)
                            FEPrivate`SameQ[ #, { } ],
                                False
                            ,
                            (* All cells have the same setting. *)
                            FEPrivate`SameQ @@ #,
                                FEPrivate`Or[
                                    FEPrivate`SameQ[ FEPrivate`Part[ #, 1 ], All ],
                                    FEPrivate`MemberQ[ FEPrivate`Part[ #, 1 ], personaName ]
                                ]
                            ,
                            (* Cells have different settings. *)
                            True,
                                { }
                        ],
                        FEPrivate`Or[ FEPrivate`SameQ[ #, All ], FEPrivate`MemberQ[ #, personaName ] ]
                    ]
                ][ FrontEnd`AbsoluteCurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ] ],
                Function[
                    CurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ] = With[
                        {
                            list = Replace[
                                AbsoluteCurrentValue[
                                    (* If multiple cells are selected, take the settings of the first one to modify. *)
                                    If[ Head @ scope === List,
                                        First[ scope, { } ],
                                        scope
                                    ],
                                    { TaggingRules, "ToolsTest", toolName }
                                ],
                                { None -> { }, All -> allPersonas, Except[ _List ] -> { } }
                            ]
                        },
                        If[ #,
                            DeleteDuplicates @ Append[ list, personaName ],
                            DeleteCases[ list, personaName ]
                        ]
                    ]
                ]
            ],
            { False, True }
        ],
        Alignment    -> { Center, Center },
        Background   -> None,
        BaseStyle    -> { LineBreakWithin -> False },
        FrameMargins -> None,
        FrameStyle   -> None,
        ImageSize    -> { $personasWidth, $rowHeight }
    ],
    { "MouseEntered" :> FEPrivate`Set[ { dRow, dColumn }, { row, column } ] },
    PassEventsDown -> True
];

enabledControl // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*rightColControl*)
rightColControl // beginDefinition;

rightColControl[
    { row_, toolName_ },
    Dynamic[ { dRow_, dColumn_ } ],
    Dynamic[ scope_ ],
    Dynamic[ notInherited_ ],
    defaultPersonas_
] := EventHandler[
    Pane[
        Grid[
            {
                {
                    PopupMenu[
                        Dynamic[
                            Function[
                                FEPrivate`Which[
                                    FEPrivate`SameQ[ #, None ]                 , None,
                                    FEPrivate`SameQ[ #, All ]                  , All,
                                    FEPrivate`SameQ[ FEPrivate`Head @ #, List ], List,
                                    True                                       , List
                                ]
                            ][ FrontEnd`AbsoluteCurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ] ],

                            FEPrivate`Which[
                                (* If the new setting is All or None, then set the enabled personas to All or None. *)
                                FEPrivate`MemberQ[ { All, None }, # ], (
                                    FEPrivate`Set[
                                        FrontEnd`CurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ],
                                        #
                                    ]
                                ),

                                (* If the new setting is a list (and the current setting is not a list), then set the
                                   enabled personas to the default set. In this sense, choosing "Enabled by persona"
                                   from the dropdown is equivalent to resetting how a tool is enabled, rather than just
                                   replacing None with {} or All with a list of all personas. *)
                                FEPrivate`UnsameQ[
                                    FEPrivate`Head @ FrontEnd`AbsoluteCurrentValue[
                                        scope,
                                        { TaggingRules, "ToolsTest", toolName }
                                    ],
                                    List
                                ], (
                                    FEPrivate`Set[
                                        FrontEnd`CurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ],
                                        defaultPersonas
                                    ]
                                )
                            ] &
                        ],
                        { List -> "Enabled by persona", Delimiter, None -> "Never enabled", All -> "Always enabled" },
                        "",
                        PaneSelector[
                            MapThread[
                                Function[
                                    { val, label, col },
                                    val -> Grid[
                                        {
                                            {
                                                Dynamic @ iconData[ "AllChecked", col ],
                                                Spacer[ 3 ],
                                                label,
                                                Dynamic @ iconData[ "DownChevron", col ]
                                            }
                                        },
                                        ItemSize -> { 0, 0 },
                                        Spacings -> { 0, 0 }
                                    ]
                                ],
                                {
                                    {
                                        { All , False },
                                        { All , True  },
                                        { None, False },
                                        { None, True  },
                                        { True, False },
                                        { True, True  }
                                    },
                                    Join[
                                        Map[
                                            Nest[ Unevaluated, Splice @ { #, Spacer[ 5 ] }, 2 ] &,
                                            { "Always", "Always", "Never", "Never" }
                                        ],
                                        { "", "" }
                                    ],
                                    {
                                        GrayLevel[ 0.65 ],
                                        $activeBlue,
                                        GrayLevel[ 0.65 ],
                                        $activeBlue,
                                        GrayLevel[ 0.65 ],
                                        $activeBlue
                                    }
                                }
                            ],
                            Dynamic[
                                Function[
                                    {
                                        FEPrivate`If[
                                            (* If there are cells selected, then check if they have the same settings *)
                                            FEPrivate`And[
                                                FEPrivate`SameQ[ FEPrivate`Head @ scope, List ],
                                                FEPrivate`SameQ @@ #
                                            ],
                                            (* If the setting is All or None, return the setting (and display an
                                               "Always" or "Never" label next to the icon).
                                               Otherwise check if the row is currently hovered over (and just display
                                               the icon with no label if so). *)
                                            FEPrivate`If[
                                                FEPrivate`MemberQ[ { All, None }, FEPrivate`Part[ #, 1 ] ],
                                                FEPrivate`Part[ #, 1 ],
                                                FEPrivate`SameQ[ dRow, row ]
                                            ],
                                            FEPrivate`If[
                                                FEPrivate`MemberQ[ { All, None }, # ],
                                                #,
                                                FEPrivate`SameQ[ dRow, row ]
                                            ]
                                        ],
                                        FrontEnd`CurrentValue[ "MouseOver" ]
                                    }
                                ][ FrontEnd`AbsoluteCurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ] ]
                            ],
                            "",
                            Alignment        -> { Left, Center },
                            BaselinePosition -> Center -> Center,
                            BaseStyle        -> Append[ $baseStyle, LineBreakWithin -> False ],
                            FrameMargins     -> { { 5, 3 }, { 2, 0 } },
                            ImageSize        -> { Automatic, $rowHeight }
                        ],
                        Appearance       -> "Frameless",
                        BaselinePosition -> Center -> Center,
                        BaseStyle        -> $baseStyle,
                        ContentPadding   -> False,
                        FrameMargins     -> { { 2, 0 }, { 0, 0 } }
                    ],
                    PaneSelector[
                        MapThread[
                            Function[
                                { val, col },
                                val -> Button[
                                    Dynamic @ iconData[ "Clear", col ],
                                    CurrentValue[ scope, { TaggingRules, "ToolsTest", toolName } ] = Inherited,
                                    Appearance -> "Suppressed",
                                    ImageSize  -> { 20, $rowHeight }
                                ]
                            ],
                            {
                                { { True, False } , { True, True } },
                                { GrayLevel[ 0.5 ], $activeBlue    }
                            }
                        ],
                        Dynamic @ { FEPrivate`MemberQ[ notInherited, row ], FrontEnd`CurrentValue[ "MouseOver" ] },
                        "",
                        BaselinePosition -> Center -> Center,
                        ImageSize        -> { 20, $rowHeight }
                    ]
                }
            },
            Alignment -> Left,
            ItemSize  -> { { Fit, { 0 } }, 0 },
            Spacings  -> { 0, 0 }
        ],
        { $rightColWidth, $rowHeight },
        FrameMargins -> None
    ],
    { "MouseEntered" :> FEPrivate`Set[ { dRow, dColumn } = { row, None } ] }
];

rightColControl // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scopeSelector*)
scopeSelector // beginDefinition;

scopeSelector[ Dynamic[ scopeMode_ ] ] := ActionMenu[
    Framed[
        Row @ {
            PaneSelector[
                {
                    ($FrontEnd &) -> "Global",
                    FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Notebook",
                    SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Cells"
                },
                Dynamic @ scopeMode,
                ImageSize -> Automatic,
                BaseStyle -> $baseStyle
            ],
            " \[DownPointer]"
        },
        FrameMargins   -> { { Automatic, Automatic }, { 2, 2 } },
        FrameStyle     -> GrayLevel[ 0.85 ],
        RoundingRadius -> 2
    ],
    {
        "Global"            :> (scopeMode = $FrontEnd &),
        "Selected Notebook" :> (scopeMode = FE`Evaluate @* FEPrivate`LastActiveUserNotebook),
        "Selected Cells"    :> (scopeMode = SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook)
    },
    Appearance -> "Frameless"
];

scopeSelector // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*personaNameDisp*)
personaNameDisp // beginDefinition;

personaNameDisp[ personaNames_, Dynamic[ column_ ] ] :=
    With[ { allowedIndices = Range @ Length @ personaNames },
        PaneSelector[
            { True -> Dynamic @ FEPrivate`Part[ personaNames, column ], False -> "" },
            Dynamic @ FEPrivate`MemberQ[ allowedIndices, column ],
            BaseStyle -> { FontColor -> GrayLevel[ 0.5 ], $baseStyle },
            ImageSize -> Automatic
        ]
    ];

personaNameDisp // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inWindow*)
inWindow // beginDefinition;

inWindow[ expr_ ] := CreateDialog[
    Cell[
        BoxData @ ToBoxes @ expr,
        CellFrame        -> { { False, 1 }, { 1, False } },
        CellFrameMargins -> { { 0, -10 }, { -2, 0 } },
        CellFrameStyle   -> White
    ],
    Background          -> White,
    Saveable            -> False,
    StyleDefinitions    -> $toolDialogStyles,
    WindowClickSelect   -> False,
    WindowFrameElements -> { "CloseBox", "ResizeArea" },
    WindowTitle         -> "LLM Tools"
];

inWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$toolDialogStyles*)
$toolDialogStyles = Notebook[
    {
        Cell @ StyleData[ StyleDefinitions -> "Dialog.nb"   ],
        Cell @ StyleData[ StyleDefinitions -> "Chatbook.nb" ]
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*linkedPane*)
linkedPane // beginDefinition;
linkedPane[ expr_, size_, scrollPos_, opts___ ] := Pane[ expr, size, ScrollPosition -> scrollPos, opts ];
linkedPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Icons*)
iconData // beginDefinition;
iconData[ name_String, color_ ] := Insert[ chatbookIcon[ "ToolSelectorUI"<>name ], color, { 1, 1, 1 } ];
iconData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
