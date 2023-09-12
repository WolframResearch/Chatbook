(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ToolSelectorUI`" ];

(* :!CodeAnalysis::BeginBlock:: *)

`CreateLLMToolManagerPanel;
`CreateLLMToolManagerDialog;

(* TODO: create a Dialogs.wl file containing definitions to share between this and the persona dialog *)

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                   ];
Needs[ "Wolfram`Chatbook`Common`"            ];
Needs[ "Wolfram`Chatbook`Personas`"          ];
Needs[ "Wolfram`Chatbook`UI`"                ];
Needs[ "Wolfram`Chatbook`Tools`"             ];
Needs[ "Wolfram`Chatbook`ResourceInstaller`" ];

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
$dialogHeaderMargins    = { { 30, 30 }, { 13, 9 } };
$dialogSubHeaderMargins = { { 30, 30 }, {  0, 9 } };
$dialogBodyMargins      = { { 30, 30 }, { 13, 5 } };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolManagerDialog*)
CreateLLMToolManagerDialog // beginDefinition;
CreateLLMToolManagerDialog[ args___ ] := Block[ { $inWindow = True }, inWindow @ CreateLLMToolManagerPanel @ args ];
CreateLLMToolManagerDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateLLMToolManagerPanel*)
CreateLLMToolManagerPanel // beginDefinition;

CreateLLMToolManagerPanel[ ] := catchMine @ Dynamic[
    $installedResourceTrigger;
    CreateLLMToolManagerPanel[ getFullToolList[ ], getFullPersonaList[ ] ],
    TrackedSymbols :> { $installedResourceTrigger }
];

CreateLLMToolManagerPanel[ tools0_List, personas_List ] :=
    catchMine @ cvExpand @ Module[
        {
            globalTools, personaTools, personaToolNames, personaToolLookup, tools,
            preppedPersonas, preppedTools, personaNames, personaDisplayNames,
            toolNames, toolDefaultPersonas,
            gridOpts, $sectionSpacer, sectionHeading, indent
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

        DynamicModule[
            {
                sH           = 0,
                sV           = 0,
                w            = 167,
                h            = 180,
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
                        (* ----- Install Tools ----- *)
                        dialogHeader[ "Add & Manage LLM Tools" ],
                        dialogSubHeader[ "Install Tools" ],
                        dialogBody[
                            Grid @ {
                                {
                                    "Install from",
                                    Button[
                                        grayDialogButtonLabel[ "LLM Tool Repository \[UpperRightArrow]" ],
                                        ResourceInstallFromRepository[ "LLMTool" ],
                                        Appearance       -> "Suppressed",
                                        BaselinePosition -> Baseline,
                                        Method           -> "Queued"
                                    ],
                                    Button[
                                        grayDialogButtonLabel[ "URL" ],
                                        Block[ { PrintTemporary }, ResourceInstallFromURL[ ] ],
                                        Appearance       -> "Suppressed",
                                        BaselinePosition -> Baseline,
                                        Method           -> "Queued"
                                    ]
                                }
                            }
                        ],

                        (* ----- Configure and Enable Tools ----- *)


                        dialogSubHeader[ "Manage and Enable Tools" ],
                        dialogBody[
                            Grid @ {
                                {
                                    "Show enabled tools for:",
                                    scopeSelector @ Dynamic @ scopeMode
                                }
                            },
                            { Automatic, { 5, Automatic } }
                        ],

                        dialogBody[ EventHandler[
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
                        ], { { Automatic, 0 }, Automatic } ],

                        If[ TrueQ @ $inWindow,
                            {
                                Item[
                                    Framed[
                                        Button[
                                            redDialogButtonLabel[ "OK" ],
                                            NotebookClose @ EvaluationNotebook[ ],
                                            Appearance       -> "Suppressed",
                                            BaselinePosition -> Baseline,
                                            Method           -> "Queued"
                                        ],
                                        FrameStyle -> None,
                                        ImageSize  -> { 100, 50 },
                                        Alignment  -> { Center, Center }
                                    ],
                                    Alignment -> { Right, Automatic }
                                ],
                                SpanFromLeft
                            },
                            Nothing
                        ]
                    },
                    Alignment -> { Left, Top },
                    BaseStyle -> $baseStyle,
                    Dividers  -> { False, { False, $dividerCol, False, $dividerCol, False, { False } } },
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
(*addPersonaSource*)
addPersonaSource // beginDefinition;

addPersonaSource[ tools_List, name_String ] :=
    addPersonaSource[ #, name ] & /@ tools;

addPersonaSource[ HoldPattern @ LLMTool[ as_Association, a___ ], name_String ] :=
    LLMTool[ Association[ "Source" -> "Persona", "PersonaName" -> name, as ], a ];

addPersonaSource[ tool_, _ ] :=
    tool;

addPersonaSource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*grayDialogButtonLabel*)
grayDialogButtonLabel // beginDefinition;

grayDialogButtonLabel[ { normal_, hover_, pressed_ } ] :=
    NotebookTools`Mousedown[
        Framed[ normal , BaseStyle -> "ButtonGray1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , BaseStyle -> "ButtonGray1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, BaseStyle -> "ButtonGray1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

grayDialogButtonLabel[ { normal_, hover_ } ] := grayDialogButtonLabel[ { normal, hover, hover } ];

grayDialogButtonLabel[ label_ ] := grayDialogButtonLabel[ { label, label, label } ];

grayDialogButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*redDialogButtonLabel*)
redDialogButtonLabel // beginDefinition;

redDialogButtonLabel[ { normal_, hover_, pressed_ } ] :=
    NotebookTools`Mousedown[
        Framed[ normal , BaseStyle -> "ButtonRed1Normal" , BaselinePosition -> Baseline ],
        Framed[ hover  , BaseStyle -> "ButtonRed1Hover"  , BaselinePosition -> Baseline ],
        Framed[ pressed, BaseStyle -> "ButtonRed1Pressed", BaselinePosition -> Baseline ],
        BaseStyle -> "DialogTextBasic"
    ];

redDialogButtonLabel[ { normal_, hover_ } ] := redDialogButtonLabel[ { normal, hover, hover } ];

redDialogButtonLabel[ label_ ] := redDialogButtonLabel[ { label, label, label } ];

redDialogButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*spanAcross*)
spanAcross // beginDefinition;
spanAcross[ expr_ ] := { expr, SpanFromLeft };
spanAcross // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogHeader*)
dialogHeader // beginDefinition;

dialogHeader[ expr_ ] :=
    dialogHeader[ expr, Automatic ];

dialogHeader[ expr_, margins_ ] :=
    spanAcross @ Pane[ expr, BaseStyle -> "DialogHeader", FrameMargins -> dialogHeaderMargins @ margins ];

dialogHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogSubHeader*)
dialogSubHeader // beginDefinition;

dialogSubHeader[ expr_ ] :=
    dialogSubHeader[ expr, Automatic ];

dialogSubHeader[ expr_, margins_ ] :=
    spanAcross @ Pane[
        expr,
        BaseStyle -> { FontSize -> 14, FontWeight -> "DemiBold" },
        FrameMargins -> dialogSubHeaderMargins @ margins
    ];

dialogSubHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogBody*)
dialogBody // beginDefinition;

dialogBody[ expr_ ] :=
    dialogBody[ expr, Automatic ];

dialogBody[ expr_, margins_ ] :=
    spanAcross @ Pane[ expr, BaseStyle -> "DialogBody", FrameMargins -> dialogBodyMargins @ margins ];

dialogBody // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogBodyMargins*)
dialogBodyMargins // beginDefinition;
dialogBodyMargins[ margins_ ] := dialogBodyMargins[ margins ] = autoMargins[ margins, $dialogBodyMargins ];
dialogBodyMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogHeaderMargins*)
dialogHeaderMargins // beginDefinition;
dialogHeaderMargins[ margins_ ] := dialogHeaderMargins[ margins ] = autoMargins[ margins, $dialogHeaderMargins ];
dialogHeaderMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*dialogSubHeaderMargins*)
dialogSubHeaderMargins // beginDefinition;
dialogSubHeaderMargins[ margins_ ] := dialogSubHeaderMargins[ margins ] = autoMargins[ margins, $dialogSubHeaderMargins ];
dialogSubHeaderMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*autoMargins*)
autoMargins // beginDefinition;
autoMargins[ Automatic, defaults_ ] := autoMargins[ ConstantArray[ Automatic, { 2, 2 } ], defaults ];
autoMargins[ { w: Automatic|_Integer, h_ }, defaults_ ] := autoMargins[ { { w, w }, h }, defaults ];
autoMargins[ { w_, h: Automatic|_Integer }, defaults_ ] := autoMargins[ { w, { h, h } }, defaults ]
autoMargins[ spec: { { _, _ }, { _, _ } }, default: { { _, _ }, { _, _ } } ] := autoMargins0[ spec, default ];
autoMargins // endDefinition;

autoMargins0 // beginDefinition;
autoMargins0 // Attributes = { Listable };
autoMargins0[ Automatic, m: Automatic|_Integer ] := m;
autoMargins0[ m_Integer, _ ] := m;
autoMargins0 // endDefinition;

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
getFullPersonaList[ ] := standardizePersonaData /@ Values @ KeyDrop[ GetCachedPersonaData[ ], "RawModel" ];
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
(*Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$baseStyle*)
$baseStyle = { FontFamily -> "Source Sans Pro", FontSize -> 14 };

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
deletableToolQ[ KeyValuePattern[ "Source" -> "BuiltIn" ] ] := False;
deletableToolQ[ KeyValuePattern[ "Source" -> "Persona" ] ] := False;
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
                { { False, False } , { True, False }  , { True, True }   },
                { LineColor -> None, GrayLevel[ 0.65 ], $activeBlue      },
                { LineColor -> None, GrayLevel[ 0.80 ], GrayLevel[ 0.8 ] }
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
                { { False, False } , { True, False } , { True, True }   },
                { LineColor -> None, GrayLevel[ 0.8 ], GrayLevel[ 0.8 ] },
                { LineColor -> None, GrayLevel[ 0.8 ], GrayLevel[ 0.8 ] }
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
                            Dynamic @ iconData[ "Delimiter", LineColor -> None ]
                        }
                    },
                    ItemSize -> { 0, 0 },
                    Spacings -> { 0, 0 }
                ]
            ],
            {
                { { False, False } , { True, False }  , { True, True }    },
                { LineColor -> None, GrayLevel[ 0.8 ] , GrayLevel[ 0.8 ]  },
                { LineColor -> None, LineColor -> None, LineColor -> None }
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
            Style[ "Delete Tool", "DialogHeader", FontSize -> 16, FontWeight -> "DemiBold" ],
            Row @ { inlineTemplateBox @ tool[ "Icon" ], Spacer[ 5 ], tool[ "CanonicalName" ] },
            {
                redDialogButtonLabel[ " Cancel " ],
                Hold[ NotebookDelete @ EvaluationCell[ ] ],
                grayDialogButtonLabel[ " Delete " ],
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

nonDeletableTooltip[ KeyValuePattern @ { "CanonicalName" -> name_String, "Source" -> "BuiltIn" } ] :=
    name<>" is a built-in tool and cannot be deleted.";

nonDeletableTooltip[ KeyValuePattern @ {
    "CanonicalName" -> name_String,
    "Source"        -> "Persona",
    "PersonaName"   -> persona_String
} ] := name<>" is provided by the persona "<>persona<>" and cannot be deleted separately.";

nonDeletableTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*nonConfigurableTooltip*)
nonConfigurableTooltip // beginDefinition;

nonConfigurableTooltip[ KeyValuePattern[ "CanonicalName" -> name_String ] ] :=
    name<>" does not have any configurable parameters.";

nonConfigurableTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*deleteTool*)
deleteTool // beginDefinition;

deleteTool[ KeyValuePattern @ { "CanonicalName" -> cName_, "ResourceName" -> rName_String } ] := (
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
                            Inherited -> "Enabled by persona",
                            Delimiter,
                            None      -> "Never enabled",
                            All       -> "Always enabled"
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
                ($FrontEnd &) -> "Global",
                FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Notebook",
                SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook -> "Selected Cells"
            },
            Dynamic @ scopeMode,
            BaselinePosition -> Baseline,
            BaseStyle        -> $baseStyle,
            ImageSize        -> Automatic
        ],
        " \[DownPointer]"
    },
    {
        "Global"            :> (scopeMode = $FrontEnd &),
        "Selected Notebook" :> (scopeMode = FE`Evaluate @* FEPrivate`LastActiveUserNotebook),
        "Selected Cells"    :> (scopeMode = SelectedCells @* FE`Evaluate @* FEPrivate`LastActiveUserNotebook)
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
(*inWindow*)
inWindow // beginDefinition;

inWindow[ expr_ ] := CreateDialog[
    ExpressionCell[ expr, CellMargins -> 0 ],
    Background             -> White,
    CellInsertionPointCell -> None,
    StyleDefinitions       -> $toolDialogStyles,
    WindowFrameElements    -> { "CloseBox" },
    WindowTitle            -> "Add & Manage LLM Tools",
    NotebookEventActions -> {
        "EscapeKeyDown"                        :> (findAndClickCancel[ ]; channelCleanup[ ]; DialogReturn @ $Canceled),
        "WindowClose"                          :> (findAndClickCancel[ ]; channelCleanup[ ]; DialogReturn @ $Canceled),
        "ReturnKeyDown"                        :> findAndClickDefault[ ],
        { "MenuCommand", "EvaluateCells"     } :> findAndClickDefault[ ],
        { "MenuCommand", "EvaluateNextCell"  } :> findAndClickDefault[ ],
        { "MenuCommand", "HandleShiftReturn" } :> findAndClickDefault[ ]
    }
];

inWindow // endDefinition;

findAndClickDefault[ ] := FE`Evaluate @ FEPrivate`FindAndClickDefaultButton[ ];
findAndClickCancel[ ] := FE`Evaluate @ FEPrivate`FindAndClickCancelButton[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$toolDialogStyles*)
$toolDialogStyles = Notebook[
    {
        Cell @ StyleData[ StyleDefinitions -> "Dialog.nb" ],
        Cell[ StyleData[ "HyperlinkActive" ], FontColor -> RGBColor[ 0.2392, 0.7960, 1.0000 ] ],
        Cell[ StyleData[ "Hyperlink"       ], FontColor -> RGBColor[ 0.0862, 0.6196, 0.8156 ] ]
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
iconData[ name_String, color_ ] := Insert[ chatbookIcon[ "ToolSelectorUI"<>name, False ], color, { 1, 1, 1 } ];
iconData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentValue Tools*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cvExpand*)
cvExpand // beginDefinition;
cvExpand // Attributes = { HoldFirst };
cvExpand[ expr_ ] := expr /. $cvRules;
cvExpand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$cvRules*)
$cvRules := $cvRules = Dispatch @ Flatten @ {
    DownValues @ acv,
    DownValues @ cv,
    DownValues @ setCV,
    DownValues @ unsetCV
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acv*)
acv // beginDefinition;
acv[ scope_, keys___ ] := AbsoluteCurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ];
acv // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cv*)
cv // beginDefinition;
cv[ scope_, keys___ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ];
cv // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setCV*)
setCV // beginDefinition;
setCV[ scope_, keys___, value_ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ] = value;
setCV // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unsetCV*)
unsetCV // beginDefinition;
unsetCV[ scope_, keys___ ] := CurrentValue[ scope, { TaggingRules, "ChatNotebookSettings", keys } ] = Inherited;
unsetCV // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $cvRules;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
