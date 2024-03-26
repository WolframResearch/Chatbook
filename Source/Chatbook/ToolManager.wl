(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ToolManager`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`CreateLLMToolManagerDialog;
`CreateLLMToolManagerPanel;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Dialogs`"           ];
Needs[ "Wolfram`Chatbook`Dynamics`"          ];
Needs[ "Wolfram`Chatbook`FrontEnd`"          ];
Needs[ "Wolfram`Chatbook`Models`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];
Needs[ "Wolfram`Chatbook`SendChat`"          ];
Needs[ "Wolfram`Chatbook`Settings`"          ];
Needs[ "Wolfram`Chatbook`Tools`"             ];
Needs[ "Wolfram`Chatbook`UI`"                ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$toolsWidth             = 240;
$personasWidth          = 30;
$rightColWidth          = 107;
$rowHeight              = 30;
$highlightCol           = GrayLevel[ 0.95 ];
$dividerCol             = GrayLevel[ 0.85 ];
$activeBlue             = Hue[ 0.59, 0.9, 0.93 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolManagerDialog*)
CreateLLMToolManagerDialog // beginDefinition;

CreateLLMToolManagerDialog[ args___ ] := createDialog[
    CreateLLMToolManagerPanel @ args,
    WindowTitle -> tr["ToolManagerTitle"]
];

CreateLLMToolManagerDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolManagerPanel*)
CreateLLMToolManagerPanel // beginDefinition;

CreateLLMToolManagerPanel[ ] := catchMine @
    With[ { inDialog = $inDialog },
        trackedDynamic[
            Block[ { $inDialog = inDialog },
                CreateLLMToolManagerPanel[ getFullToolList[ ], getFullPersonaList[ ] ]
            ],
            { "Tools", "Personas" }
        ]
    ];

CreateLLMToolManagerPanel[ tools0_List, personas_List ] :=
    catchMine @ cvExpand @ Catch @ Module[
        {
            globalTools, personaTools, personaToolNames, personaToolLookup, tools,
            preppedPersonas, preppedTools, personaNames, personaDisplayNames,
            toolNames, toolDefaultPersonas, gridOpts
        },

        globalTools = toolName @ tools0;
        personaTools = DeleteCases[
            DeleteCases[
                Association @ Cases[
                    personas,
                    KeyValuePattern @ { "Name" -> name_, "Tools" -> t_ } :>
                        name -> addPersonaSource[ Complement[ Flatten @ List @ t, globalTools ], name ]
                ],
                Except[ _LLMTool ],
                { 2 }
            ],
            { } | Automatic | Inherited | None
        ];

        personaToolNames = toolName /@ personaTools;
        personaToolLookup = Association @ KeyValueMap[ Thread[ #2 -> #1 ] &, personaToolNames ];

        tools = DeleteDuplicates @ Join[
            toolData @ tools0,
            toolData @ Flatten @ Values @ personaTools
        ];

        If[ TrueQ @ $cloudNotebooks, Throw @ cloudToolManager @ tools ];

        gridOpts = Sequence[
            Spacings -> { 0, 0 },
            ItemSize -> { 0, 0 },
            Dividers -> { None, { None, { GrayLevel[ 0.9 ] }, None } }
        ];

        DynamicModule[
            {
                sH           = 0,
                sV           = 0,
                w            = If[ TrueQ @ $inDialog, 167, UpTo[ 230 ] ],
                h            = If[ TrueQ @ $inDialog, 180, Automatic ],
                row          = None,
                column       = None,
                scopeMode    = $FrontEnd &,
                scope        = $FrontEnd,
                notInherited = None,
                notInheritedStyle,
                toolLookup   = Association @ MapThread[
                    Rule,
                    { tools[[ All, "CanonicalName" ]], Range @ Length @ tools }
                ]
            },

            preppedPersonas     = prepPersonas[ personas, Dynamic @ { row, column } ];
            preppedTools        = prepTools[ tools, Dynamic @ { row, column } ];
            personaNames        = personas[[ All, "Name" ]];
            personaDisplayNames = personas[[ All, "DisplayName" ]];
            toolNames           = toolName @ tools;

            (* Produce an association whose keys are tool names, and values are all the personas which list that tool in
               their default tools to use. *)
            toolDefaultPersonas =
                With[ { personaDefaults = (#[ "Name" ] -> Lookup[ #, "Tools", { } ] &) /@ personas },
                    Association @ Map[
                        Function[
                            name,
                            name -> First /@ Select[ personaDefaults, MemberQ[ Last @ #, name ] & ]
                        ],
                        toolNames
                    ]
                ];

            DynamicWrapper[
                Grid[
                    {
                        titleSection[ ],

                        (* ----- Install Tools ----- *)
                        installToolsSection[ ],

                        (* ----- Configure and Enable Tools ----- *)
                        manageAndEnableToolsSection @ Dynamic[ scopeMode ],

                        dialogBody[ EventHandler[
                            Grid[
                                {
                                    Append[
                                        Map[
                                            Function @ Item[
                                                EventHandler[
                                                    Pane[ #, FrameMargins -> { { 0, 0 }, { 2, 2 } } ],
                                                    { "MouseEntered" :> FEPrivate`Set[ { row, column }, { None, None } ] }
                                                ],
                                                Background -> GrayLevel[ 0.898 ]
                                            ],
                                            {
                                                Row @ { Spacer[ 4 ], tr["ToolManagerTool"] },
                                                Row @ {
                                                    Spacer[ 4 ],
                                                    tr["ToolManagerEnabledFor"],
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
                                                (*fitLastColumn @*) Table[
                                                    If[ And[
                                                            StringQ @ personaToolLookup @ tools[[ i, "CanonicalName" ]],
                                                            UnsameQ[
                                                                personaToolLookup @ tools[[ i, "CanonicalName" ]],
                                                                personas[[ j, "Name" ]]
                                                            ]
                                                        ],
                                                        disabledControl[
                                                            { i, Part[ tools, i ][ "CanonicalName" ] },
                                                            { j, personas[[ j ]] },
                                                            Dynamic @ { row, column },
                                                            Dynamic @ scope,
                                                            personaNames
                                                        ],
                                                        enabledControl[
                                                            { i, Part[ tools, i ][ "CanonicalName" ] },
                                                            { j, personas[[ j ]] },
                                                            Dynamic @ { row, column },
                                                            Dynamic @ scope,
                                                            personaNames
                                                        ]
                                                    ],
                                                    { i, Length @ tools    },
                                                    { j, Length @ personas }
                                                ],
                                                Background -> With[ { c = $highlightCol },
                                                    Dynamic @ { { column -> c }, { row -> c }, notInheritedStyle }
                                                ],
                                                gridOpts
                                            ],
                                            With[ { w1 = w-1, w2 = w, h1 = h-1, h2 = h },
                                                Dynamic[
                                                    { w, h },
                                                    Function[

                                                        FEPrivate`Set[
                                                            w,
                                                            FEPrivate`If[
                                                                FEPrivate`Greater[ FEPrivate`Part[ #, 1 ], w1 ],
                                                                FEPrivate`Part[ #, 1 ],
                                                                w2
                                                            ]
                                                        ];

                                                        FEPrivate`Set[
                                                            h,
                                                            FEPrivate`If[
                                                                FEPrivate`Greater[ FEPrivate`Part[ #, 2 ], h1 ],
                                                                FEPrivate`Part[ #, 2 ],
                                                                h2
                                                            ]
                                                        ]
                                                    ]
                                                ]
                                            ],
                                            Dynamic @ { sH, sV },
                                            Scrollbars -> { Automatic, False },
                                            AppearanceElements -> If[ TrueQ @ $inDialog, Automatic, None ]
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
                                Alignment  -> { Left, Top },
                                Background -> White,
                                BaseStyle  -> $baseStyle,
                                ItemSize   -> { 0, 0 },
                                Spacings   -> { 0, 0 },
                                Dividers   -> {
                                    { False, $dividerCol, $dividerCol, { False } },
                                    { False, False      , $dividerCol, { False } }
                                }
                            ],
                            { "MouseExited" :> FEPrivate`Set[ { row, column }, { None, None } ] },
                            PassEventsDown -> True
                        ], { { Automatic, 0 }, Automatic } ],

                        (* ----- Dialog Buttons ----- *)
                        dialogButtonSection[ ]
                    },
                    Alignment -> { Left, Top },
                    BaseStyle -> $baseStyle,
                    Dividers  -> {
                        False,
                        {
                            If[ TrueQ @ $inDialog, Sequence @@ { False, $dividerCol }, False ],
                            False,
                            $dividerCol,
                            False,
                            { False }
                        }
                    },
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
                                    DeleteCases[ Except[ KeyValuePattern @ { } ] ] @ {
                                        acv[ $FrontEnd, "ToolSelections" ],
                                        acv[ scope    , "ToolSelections" ]
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
                                    DeleteCases[ Except[ KeyValuePattern @ { } ] ] @ {
                                        acv[ ParentNotebook @ First @ scope, "ToolSelections" ],
                                        Splice @ acv[ scope, "ToolSelections" ]
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

                    (* Looking at $FrontEnd *)
                    _FrontEndObject, (
                        notInherited = toolLookup /@ Union[
                            Keys @ Replace[
                                cv[ $FrontEnd, "ToolSelections" ],
                                Except[ KeyValuePattern @ { } ] -> <| |>
                            ],
                            Keys @ Replace[
                                cv[ $FrontEnd, "ToolSelectionType" ],
                                Except[ KeyValuePattern @ { } ] -> <| |>
                            ]
                        ];

                        notInheritedStyle = ({ { #, # }, { 1, -1 } } -> Hue[ 0.59, 0.48, 1, 0.1 ] &) /@ notInherited
                    ),

                    (* Otherwise no selection if scope is {}. *)
                    _, (
                        notInherited = notInheritedStyle = None
                    )
                ]
            ],
            UnsavedVariables :> { sH, sV, w, h, row, column },
            Initialization   :> (scopeMode = $FrontEnd &)
        ]
    ];

CreateLLMToolManagerPanel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fitLastColumn*)
fitLastColumn // beginDefinition;

fitLastColumn[ grid_? MatrixQ ] :=
    MapAt[
        Item[ #, ItemSize -> { Fit, Automatic }, Alignment -> { Left, Automatic } ] &,
        grid,
        { All, -1 }
    ];

fitLastColumn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addPersonaSource*)
addPersonaSource // beginDefinition;

addPersonaSource[ tools_List, name_String ] :=
    addPersonaSource[ #, name ] & /@ tools;

addPersonaSource[ HoldPattern @ LLMTool[ as_Association, a___ ], name_String ] :=
    LLMTool[ Association[ "Origin" -> "Persona", "PersonaName" -> name, as ], a ];

addPersonaSource[ tool_, _ ] :=
    tool;

addPersonaSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFullToolList*)
getFullToolList // beginDefinition;
getFullToolList[ ] := DeleteDuplicates @ Join[ Values @ $DefaultTools, Values @ $InstalledTools ];
getFullToolList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFullPersonaList*)
getFullPersonaList // beginDefinition;

getFullPersonaList[ ] :=
    standardizePersonaData /@ Values @ KeyDrop[ GetCachedPersonaData[ "IncludeHidden" -> False ], "RawModel" ];

getFullPersonaList // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*standardizePersonaData*)
standardizePersonaData // beginDefinition;

standardizePersonaData[ persona_Association ] :=
    standardizePersonaData[ persona, Lookup[ persona, "Tools", { } ] ];

standardizePersonaData[ persona_Association, tools_List ] :=
    Append[ persona, "Tools" -> tools ];

standardizePersonaData[ persona_Association, tools: Automatic|Inherited ] :=
    standardizePersonaData[ persona, Keys @ $DefaultTools ];

standardizePersonaData[ persona_Association, None ] :=
    standardizePersonaData[ persona, { } ];

standardizePersonaData // endDefinition;

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
                    FrameMargins     -> 20,
                    FrameStyle       -> GrayLevel[ 0.85 ],
                    RoundingRadius   -> 8,
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
        { title, SpanFromLeft },
        { body , SpanFromLeft },
        {
            "",
            Row @ {
                Button[ label1, action1, BaseStyle -> $baseStyle, Appearance -> "Suppressed", Method -> "Queued" ],
                Spacer[ 10 ],
                Button[ label2, action2, BaseStyle -> $baseStyle, Appearance -> "Suppressed", Method -> "Queued" ]
            }
        }
    },
    Alignment -> { { Left, Right }, Baseline },
    ItemSize  -> { { Fit, { 0 } }, 0 },
    Spacings  -> { 0, 1 }
];

overlayGrid[ expr: Except[ _List ] ] := expr;

overlayGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toolModelWarning*)
toolModelWarning // beginDefinition;
toolModelWarning[ None | { } | HoldPattern @ SelectedCells @ None ] := "";
toolModelWarning[ { cell_CellObject, ___ } ] := toolModelWarning @ cell;
toolModelWarning[ scope_ ] := toolModelWarning[ scope, currentChatSettings[ scope, "ToolsEnabled" ] ];
toolModelWarning[ scope_, True ] := "";
toolModelWarning[ scope_, False ] := $toolsDisabledWarning;
toolModelWarning[ scope_, enabled_ ] := toolModelWarning[ scope, enabled, currentChatSettings[ scope, "Model" ] ];
toolModelWarning[ scope_, enabled_, KeyValuePattern[ "Name" -> Automatic ] ] := "";
toolModelWarning[ scope_, enabled_, model_? toolsEnabledQ ] := "";
toolModelWarning[ scope_, enabled_, model_ ] := toolModelWarning0[ scope, model ];
toolModelWarning // endDefinition;

(* FIXME: add a link to open the Notebooks preferences tab *)
toolModelWarning0 // beginDefinition;

toolModelWarning0[ scope_, model_String ] := Enclose[
    Module[ { name, template, message },
        name     = ConfirmBy[ modelDisplayName @ model, StringQ, "ModelName" ];
        template = ConfirmBy[ Chatbook::ModelToolSupport, StringQ, "Template" ];
        message  = ConfirmBy[ TemplateApply[ template, { name } ], StringQ, "Message" ];
        Grid[
            { {
                Spacer[ 5 ],
                Style[ "\[WarningSign]", FontWeight -> Bold, FontColor -> Gray, FontSize -> 18 ],
                Style[ message, FontColor -> Gray, FontSlant -> Italic ]
            } },
            Alignment -> { Left, Top }
        ]
    ],
    throwInternalFailure[ toolModelWarning0[ scope, model ], ## ] &
];

toolModelWarning0[ scope_, model: Except[ _String ] ] :=
    With[ { name = toModelName @ model },
        toolModelWarning0[ scope, name ] /; StringQ @ name
    ];

toolModelWarning0 // endDefinition;

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
                    configureButton[ #1, #2, Dynamic @ { row, column } ],
                    deleteButton[ #1, #2, Dynamic @ { row, column } ],
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
(* ::Subsubsection::Closed:: *)
(*configurableToolQ*)
configurableToolQ // beginDefinition;
configurableToolQ[ tool_Association ] := False; (* TODO *)
configurableToolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deletableToolQ*)
deletableToolQ // beginDefinition;
deletableToolQ[ KeyValuePattern[ "Origin" -> "BuiltIn" ] ] := False;
deletableToolQ[ KeyValuePattern[ "Origin" -> "Persona" ] ] := False;
deletableToolQ[ tool_ ] := True;
deletableToolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*configureButton*)
configureButton // beginDefinition;

configureButton[ tool_Association? configurableToolQ, index_Integer, Dynamic[ { row_, column_ } ] ] :=
    PaneSelector[
        MapThread[
            Function[
                { val, colCog, colDelimiter },
                val -> Pane @ Grid[
                    {
                        {
                            Spacer[ 5 ],
                            Pane[
                                inlineTemplateBoxes @ tool[ "Icon" ],
                                ImageSize       -> { 22, 20 },
                                ImageSizeAction -> "ShrinkToFit"
                            ],
                            Spacer[ 5 ],
                            tool[ "CanonicalName" ],
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
                { { False, False }, { True, False }  , { True, True }   },
                { Transparent     , GrayLevel[ 0.65 ], $activeBlue      },
                { Transparent     , GrayLevel[ 0.80 ], GrayLevel[ 0.8 ] }
            }
        ],
        Dynamic @ { FEPrivate`SameQ[ row, index ], FrontEnd`CurrentValue[ "MouseOver" ] },
        BaselinePosition -> Center -> Center,
        FrameMargins     -> None,
        ImageSize        -> { $toolsWidth, $rowHeight }
    ];

configureButton[ tool_Association, index_Integer, Dynamic[ { row_, column_ } ] ] :=
    PaneSelector[
        MapThread[
            Function[
                { val, colCog, colDelimiter },
                val -> Pane @ Grid[
                    {
                        {
                            Spacer[ 5 ],
                            Pane[
                                inlineTemplateBoxes @ tool[ "Icon" ],
                                ImageSize       -> { 22, 20 },
                                ImageSizeAction -> "ShrinkToFit"
                            ],
                            Spacer[ 5 ],
                            tool[ "CanonicalName" ],
                            Tooltip[ Dynamic @ iconData[ "Cog", colCog ], nonConfigurableTooltip @ tool ],
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
                { { False, False }, { True, False } , { True, True }   },
                { Transparent     , GrayLevel[ 0.8 ], GrayLevel[ 0.8 ] },
                { Transparent     , GrayLevel[ 0.8 ], GrayLevel[ 0.8 ] }
            }
        ],
        Dynamic @ { FEPrivate`SameQ[ row, index ], FrontEnd`CurrentValue[ "MouseOver" ] },
        BaselinePosition -> Center -> Center,
        FrameMargins     -> None,
        ImageSize        -> { $toolsWidth, $rowHeight }
    ];

configureButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deleteButton*)
deleteButton // beginDefinition;

deleteButton[ tool_Association? deletableToolQ, index_Integer, Dynamic[ { row_, column_ } ] ] :=
    PaneSelector[
        MapThread[
            Function[
                { val, colBin, colDelimiter },
                val -> Grid[
                    {
                        {
                            Spacer[ 5 ],
                            deleteButton0[ colBin, index, tool ],
                            Spacer[ 3 ],
                            Dynamic @ iconData[ "Delimiter", Transparent ]
                        }
                    },
                    ItemSize -> { 0, 0 },
                    Spacings -> { 0, 0 }
                ]
            ],
            {
                { { False, False }, { True, False }  , { True, True } },
                { Transparent     , GrayLevel[ 0.65 ], $activeBlue    },
                { Transparent     , Transparent      , Transparent    }
            }
        ],
        Dynamic @ { FEPrivate`SameQ[ row, index ], FrontEnd`CurrentValue[ "MouseOver" ] },
        BaselinePosition -> Center -> Center,
        FrameMargins     -> None,
        ImageSize        -> { Automatic, $rowHeight }
    ];

deleteButton[ tool_Association, index_Integer, Dynamic[ { row_, column_ } ] ] :=
    PaneSelector[
        MapThread[
            Function[
                { val, colBin, colDelimiter },
                val -> Grid[
                    {
                        {
                            Spacer[ 5 ],
                            Button[
                                Tooltip[ Dynamic @ iconData[ "Bin", colBin ], nonDeletableTooltip @ tool ],
                                Null,
                                Appearance       -> "Suppressed",
                                BaselinePosition -> Center -> Center,
                                ContentPadding   -> False,
                                FrameMargins     -> { { 0, 0 }, { 2, 0 } },
                                ImageSize        -> { Automatic, $rowHeight }
                            ],
                            Spacer[ 3 ],
                            Dynamic @ iconData[ "Delimiter", Transparent ]
                        }
                    },
                    ItemSize -> { 0, 0 },
                    Spacings -> { 0, 0 }
                ]
            ],
            {
                { { False, False }, { True, False } , { True, True }   },
                { Transparent     , GrayLevel[ 0.8 ], GrayLevel[ 0.8 ] },
                { Transparent     , Transparent     , Transparent      }
            }
        ],
        Dynamic @ { FEPrivate`SameQ[ row, index ], FrontEnd`CurrentValue[ "MouseOver" ] },
        BaselinePosition -> Center -> Center,
        FrameMargins     -> None,
        ImageSize        -> { Automatic, $rowHeight }
    ];

deleteButton // endDefinition;

deleteButton0 // beginDefinition;

deleteButton0[ colBin_, row_, tool_Association ] := Button[
    Dynamic @ iconData[ "Bin", colBin ],
    attachOverlay[
        {
            Style[ tr["ToolManagerDeleteTool"], "DialogHeader", FontSize -> 16, FontWeight -> "DemiBold" ],
            Row @ { inlineTemplateBox @ tool[ "Icon" ], Spacer[ 5 ], tool[ "CanonicalName" ] },
            {
                redDialogButtonLabel[ Row[{" ", tr["CancelButton"], " "}] ],
                Hold[ NotebookDelete @ EvaluationCell[ ] ],
                grayDialogButtonLabel[ Row[{" ", tr["DeleteButton"], " "}] ],
                Hold[ deleteTool @ tool; NotebookDelete @ EvaluationCell[ ] ]
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

deleteButton0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*nonDeletableTooltip*)
nonDeletableTooltip // beginDefinition;

nonDeletableTooltip[ KeyValuePattern @ { "CanonicalName" -> name_String, "Origin" -> "BuiltIn" } ] :=
    trStringTemplate["ToolManagerTooltipNonDeletable1"][<|"name" -> name|>];

nonDeletableTooltip[ KeyValuePattern @ {
    "CanonicalName" -> name_String,
    "Origin"        -> "Persona",
    "PersonaName"   -> persona_String
} ] := trStringTemplate["ToolManagerTooltipNonDeletable2"][<|"name" -> name, "persona" -> persona|>];

nonDeletableTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*nonConfigurableTooltip*)
nonConfigurableTooltip // beginDefinition;

nonConfigurableTooltip[ KeyValuePattern[ "CanonicalName" -> name_String ] ] :=
    trStringTemplate["ToolManagerTooltipNonConfigurable"][<|"name" -> name|>];

nonConfigurableTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteTool*)
deleteTool // beginDefinition;

deleteTool[ KeyValuePattern @ { "CanonicalName" -> cName_, "ResourceName" -> rName_String } ] :=
    deleteTool[ cName, rName ];

deleteTool[ cName_, rName_String ] := (
    unsetCV[ $FrontEnd, "ToolSelections"   , cName ];
    unsetCV[ $FrontEnd, "ToolSelectionType", cName ];
    ResourceUninstall[ "LLMTool", rName ]
);

deleteTool // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prepPersonas*)
prepPersonas // beginDefinition;

prepPersonas[ personas: { __Association }, Dynamic[ { row_, column_ } ] ] := MapThread[
    Function @ EventHandler[
        Framed[
            resizeMenuIcon @ getPersonaMenuIcon[ #1, "Full" ],
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
    { row_, nameOfTool_ },
    { column_, persona: KeyValuePattern @ { "Name" -> personaName_, "Tools" -> tools_List } },
    Dynamic[ { dRow_, dColumn_ } ],
    Dynamic[ scope_ ],
    allPersonas_
] := cvExpand @ With[ { defaultSelected = MemberQ[ toolName @ tools, nameOfTool ] },
    EventHandler[
        Framed[
            Checkbox[
                Dynamic[
                    Switch[
                        {
                            acv[ scope, "ToolSelectionType", nameOfTool ],
                            acv[ scope, "ToolSelections"   , nameOfTool, personaName ]
                        },
                        { All , _                             }, True,
                        { None, _                             }, False,
                        { _   , Inherited | { Inherited ... } }, defaultSelected,
                        { _   , True      | { True ..       } }, True,
                        { _   , False     | { False ..      } }, False,
                        { _   , _                             }, Undefined
                    ],
                    Function[
                        setCV[
                            scope, "ToolSelections", nameOfTool, personaName,
                            (* If the scope is $FrontEnd and the setting is default for the persona, set to Inherited *)
                            If[ ! Xor[ #, defaultSelected ] && MatchQ[ scope, _FrontEndObject ], Inherited, # ]
                        ];

                        (* Unset the "All" or "None" setting if it exists, since a checkbox was toggled manually: *)
                        unsetCV[ scope, "ToolSelectionType", nameOfTool ];

                        (* Cleanup empty tagging rules *)
                        If[ MatchQ[ cv[ scope, "ToolSelections", nameOfTool ], <| |> | { } ],
                            unsetCV[ scope, "ToolSelections", nameOfTool ];
                            If[ MatchQ[ cv[ scope, "ToolSelections" ], <| |> | { } ],
                                unsetCV[ scope, "ToolSelections" ];
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
    ]
];

enabledControl // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*disabledControl*)
disabledControl // beginDefinition;

disabledControl[
    { row_, nameOfTool_ },
    { column_, persona: KeyValuePattern @ { "Name" -> personaName_, "Tools" -> tools_List } },
    Dynamic[ { dRow_, dColumn_ } ],
    Dynamic[ scope_ ],
    allPersonas_
] := cvExpand @ With[ { defaultSelected = MemberQ[ toolName @ tools, nameOfTool ] },
    EventHandler[
        Framed[
            Checkbox[ defaultSelected, { False, True }, Enabled -> False ],
            Alignment    -> { Center, Center },
            Background   -> None,
            BaseStyle    -> { LineBreakWithin -> False },
            FrameMargins -> None,
            FrameStyle   -> None,
            ImageSize    -> { $personasWidth, $rowHeight }
        ],
        { "MouseEntered" :> FEPrivate`Set[ { dRow, dColumn }, { row, column } ] },
        PassEventsDown -> True
    ]
];

disabledControl // endDefinition;

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
] := cvExpand @ EventHandler[
    Pane[
        Grid[
            {
                {
                    PopupMenu[
                        Dynamic[
                            acv[ scope, "ToolSelectionType", toolName ],
                            setCV[ scope, "ToolSelectionType", toolName, # ] &
                        ],
                        {
                            Inherited -> tr["ToolManagerEnabledByPersona"],
                            Delimiter,
                            None      -> tr["ToolManagerEnabledNever"],
                            All       -> tr["ToolManagerEnabledAlways"]
                        },
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
                                            { tr["Always"], tr["Always"], tr["Never"], tr["Never"] }
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
                                ][
                                    FrontEnd`AbsoluteCurrentValue[
                                        scope,
                                        { TaggingRules, "ChatNotebookSettings", "ToolSelectionType", toolName }
                                    ]
                                ]
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
                                    unsetCV[ scope, "ToolSelections"   , toolName ];
                                    unsetCV[ scope, "ToolSelectionType", toolName ];
                                    ,
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
    grayDialogButtonLabel @ Row @ {
        PaneSelector[
            {
                ($FrontEnd &) -> tr["ScopeGlobal"],
                FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> tr["ScopeNotebook"],
                SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> tr["ScopeCells"]
            },
            Dynamic @ scopeMode,
            BaselinePosition -> Baseline,
            BaseStyle        -> $baseStyle,
            ImageSize        -> Automatic
        ],
        " \[DownPointer]"
    },
    {
        tr["ScopeGlobal"]   :> (scopeMode = $FrontEnd &),
        tr["ScopeNotebook"] :> (scopeMode = FE`Evaluate @* FEPrivate`LastActiveUserNotebook),
        tr["ScopeCells"]    :> (scopeMode = SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook)
    },
    Appearance       -> "Frameless",
    BaselinePosition -> Baseline
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
(*linkedPane*)
linkedPane // beginDefinition;
linkedPane[ expr_, size_, scrollPos_, opts___ ] := Pane[ expr, size, ScrollPosition -> scrollPos, opts ];
linkedPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Icons*)
iconData // beginDefinition;
iconData[ name_String, color_ ] := Insert[ chatbookIcon[ "ToolManager"<>name, False ], color, { 1, 1, 1 } ];
iconData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dialog Elements*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*titleSection*)
titleSection // beginDefinition;
titleSection[ ] := If[ TrueQ @ $inDialog, dialogHeader[ tr["ToolManagerTitle"] ], Nothing ];
titleSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*installToolsSection*)
installToolsSection // beginDefinition;

installToolsSection[ ] := Sequence[
    dialogSubHeader[ tr["ToolManagerInstallTools"] ],
    dialogBody[
        Grid @ {
            {
                tr["ToolManagerInstallFrom"],
                Button[
                    grayDialogButtonLabel[ tr["ToolManagerInstallFromLLMToolRepo"] ],
                    If[ $CloudEvaluation, SetOptions[ EvaluationNotebook[ ], DockedCells -> Inherited ] ];
                    ResourceInstallFromRepository[ "LLMTool" ],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Method           -> "Queued"
                ],
                Button[
                    grayDialogButtonLabel[ tr["URLButton"] ],
                    If[ $CloudEvaluation, SetOptions[ EvaluationNotebook[ ], DockedCells -> Inherited ] ];
                    Block[ { PrintTemporary }, ResourceInstallFromURL[ "LLMTool" ] ],
                    Appearance       -> "Suppressed",
                    BaselinePosition -> Baseline,
                    Method           -> "Queued"
                ]
            }
        }
    ]
];

installToolsSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*manageAndEnableToolsSection*)
manageAndEnableToolsSection // beginDefinition;

manageAndEnableToolsSection[ Dynamic[ scopeMode_ ] ] := Sequence[
    manageAndEnableToolsSection[ ],
    dialogBody[
        Grid @ {
            {
                tr["ToolManagerShowEnabledFor"],
                scopeSelector @ Dynamic @ scopeMode,
                Dynamic @ catchAlways @ toolModelWarning @ scopeMode[ ]
            }
        },
        { Automatic, { 5, Automatic } }
    ]
];

manageAndEnableToolsSection[ ] := dialogSubHeader[ tr["ToolManagerManageTools"] ];

manageAndEnableToolsSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dialogButtonSection*)
dialogButtonSection // beginDefinition;

dialogButtonSection[ ] :=
    If[ TrueQ @ $inDialog,
        {
            Item[
                Framed[
                    Button[
                        redDialogButtonLabel[ tr["OKButton"] ],
                        NotebookClose @ EvaluationNotebook[ ],
                        Appearance -> "Suppressed",
                        BaselinePosition -> Baseline,
                        Method -> "Queued"
                    ],
                    FrameStyle -> None,
                    ImageSize -> { 100, 50 },
                    Alignment -> { Center, Center }
                ],
                Alignment -> { Right, Automatic }
            ],
            SpanFromLeft
        },
        Nothing
    ];

dialogButtonSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudToolManager*)
cloudToolManager // beginDefinition;

cloudToolManager[ tools: { __Association } ] := Grid[
    {
        titleSection[ ],

        (* ----- Install Tools ----- *)
        installToolsSection[ ],

        (* ----- Configure and Enable Tools ----- *)
        manageAndEnableToolsSection[ ],

        (* ----- Tool Grid ----- *)
        dialogBody[ cloudToolGrid @ tools, { { Automatic, 0 }, Automatic } ],

        (* ----- Dialog Buttons ----- *)
        dialogButtonSection[ ]
    },
    Alignment -> { Left, Top },
    BaseStyle -> $baseStyle,
    Dividers  -> {
        False,
        {
            If[ TrueQ @ $inDialog, Sequence @@ { False, $dividerCol }, False ],
            False,
            $dividerCol,
            False,
            { False }
        }
    },
    ItemSize  -> { Automatic, 0 },
    Spacings  -> { 0, 0 }
];

cloudToolManager // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cloudToolGrid*)
cloudToolGrid // beginDefinition;

cloudToolGrid[ tools: { __Association } ] := Grid[
    Join[
        { {
            "Tool",
            "",
            "",
            "",
            "Enabled"
        } },
        cloudToolGridRow /@ tools
    ],
    Alignment  -> { Left, Center },
    Background -> { White, { GrayLevel[ 0.898 ], White } },
    BaseStyle  -> "Text",
    Dividers   -> { True, All },
    FrameStyle -> GrayLevel[ 0.898 ]
];

cloudToolGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudToolGridRow*)
cloudToolGridRow // beginDefinition;

cloudToolGridRow[ tool_Association ] := {
    Grid[
        { {
            Pane[
                tool[ "Icon" ],
                ImageSize       -> { 22, 20 },
                ImageSizeAction -> "ShrinkToFit"
            ],
            tool[ "CanonicalName" ]
        } },
        Alignment -> { { Center, Left }, Center },
        Spacings  -> 0.5
    ],
    Item[ "", ItemSize -> Fit ],
    cloudDeleteToolButton @ tool,
    cloudConfigureToolButton @ tool,
    Item[ cloudToolEnablePopup @ tool, Alignment -> Right ]
};

cloudToolGridRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudToolEnablePopup*)
cloudToolEnablePopup // beginDefinition;

cloudToolEnablePopup[ KeyValuePattern[ "CanonicalName" -> name_String ] ] :=
    cloudToolEnablePopup @ name;

cloudToolEnablePopup[ name_String ] :=
    PopupMenu[
        Dynamic[
            Replace[ CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ][ name ], Except[ None|All ] -> Inherited ],
            Function[
                CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ] =
                    DeleteCases[
                        Append[
                            Replace[
                                CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ],
                                Except[ _? AssociationQ ] -> <| |>
                            ],
                            name -> #1
                        ],
                        Inherited
                    ]
            ]
        ],
        {
            All       -> tr["EnabledAlways"],
            Inherited -> tr["EnabledByPersona"],
            None      -> tr["EnabledNever2"]
        }
    ];

cloudToolEnablePopup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudConfigureToolButton*)
cloudConfigureToolButton // beginDefinition;

(* TODO: needs a definition for configurable tools *)

cloudConfigureToolButton[ tool_Association ] :=
    Tooltip[
        Dynamic @ iconData[ "Cog", GrayLevel[ 0.8 ] ],
        nonConfigurableTooltip @ tool
    ];

cloudConfigureToolButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudDeleteToolButton*)
cloudDeleteToolButton // beginDefinition;

cloudDeleteToolButton[ tool_Association? deletableToolQ ] :=
    With[ { cName = tool[ "CanonicalName" ], rName = tool[ "ResourceName" ] },
        Button[
            $cloudDeleteToolButtonLabel,
            deleteTool[ cName, rName ],
            Appearance -> "Suppressed"
        ]
    ];

cloudDeleteToolButton[ tool_Association ] :=
    Tooltip[
        Dynamic @ iconData[ "Bin", GrayLevel[ 0.8 ] ],
        nonDeletableTooltip @ tool
    ];

cloudDeleteToolButton // endDefinition;

$cloudDeleteToolButtonLabel = Mouseover[
    Dynamic @ iconData[ "Bin", GrayLevel[ 0.65 ] ],
    Dynamic @ iconData[ "Bin", $activeBlue ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
