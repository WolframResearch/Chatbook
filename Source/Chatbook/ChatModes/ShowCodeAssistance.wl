(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`ShowCodeAssistance`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$workspaceChatWidth = 325;

$codeAssistanceSettings = <|
    "AppName"           -> "CodeAssistance",
    "PromptGenerators"  -> { "RelatedDocumentation" },
    "ServiceCaller"     -> "CodeAssistance",
    "Tools"             -> { "NotebookEditor" },
    "ToolSelectionType" -> <| "DocumentationLookup" -> None, "DocumentationSearcher" -> None |>
|>;

$workspaceChatNotebookOptions = Sequence[
    DefaultNewCellStyle -> "AutoMoveToChatInputField",
    StyleDefinitions    -> FrontEnd`FileName[ { "Wolfram" }, "WorkspaceChat.nb", CharacterEncoding -> "UTF-8" ],
    TaggingRules        -> <| "ChatNotebookSettings" -> $codeAssistanceSettings |>
];

(* TODO: set $serviceCaller from chat settings *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*EnableCodeAssistance*)
EnableCodeAssistance // beginDefinition;
EnableCodeAssistance[ ] := catchMine @ (enableCodeAssistance[ ]; Null);
EnableCodeAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*enableCodeAssistance*)
enableCodeAssistance // beginDefinition;

enableCodeAssistance[ ] := Once[
    FrontEndExecute @ {
        FrontEnd`AddMenuCommands[
            "OpenHelpLink",
            {
                MenuItem[
                    "Code Assistance Chat\[Ellipsis]",
                    FrontEnd`KernelExecute[
                        Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Window" ]
                    ],
                    FrontEnd`MenuEvaluator -> Automatic,
                    Evaluate[
                        If[ $OperatingSystem === "MacOSX",
                            FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { FrontEnd`Control } ],
                            FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { FrontEnd`Command } ]
                        ]
                    ]
                ],
                MenuItem[
                    "Code Assistance for Selection",
                    FrontEnd`KernelExecute[
                        Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ShowCodeAssistance" ][ "Inline" ]
                    ],
                    FrontEnd`MenuEvaluator -> Automatic,
                    FrontEnd`MenuKey[ "'", FrontEnd`Modifiers -> { FrontEnd`Control, FrontEnd`Shift } ]
                ]
            }
        ],
        FrontEnd`AddMenuCommands[
            "DuplicatePreviousOutput",
            {
                MenuItem[
                    "AI Content Suggestion",
                    FrontEnd`KernelExecute[
                        Needs[ "Wolfram`Chatbook`" -> None ];
                        Symbol[ "Wolfram`Chatbook`ShowContentSuggestions" ][ ]
                    ],
                    FrontEnd`MenuEvaluator -> Automatic,
                    Evaluate[
                        If[ $OperatingSystem === "MacOSX",
                            FrontEnd`MenuKey[ "k", FrontEnd`Modifiers -> { FrontEnd`Control } ],
                            FrontEnd`MenuKey[ "k", FrontEnd`Modifiers -> { FrontEnd`Command } ]
                        ]
                    ],
                    Method -> "Queued"
                ]
            }
        ]
    },
    "FrontEndSession"
];

enableCodeAssistance // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ShowCodeAssistance*)
ShowCodeAssistance // beginDefinition;
ShowCodeAssistance[ ] := catchMine @ ShowCodeAssistance[ "Window" ];
ShowCodeAssistance[ nbo_NotebookObject ] := catchMine @ showCodeAssistanceWindow @ nbo;
ShowCodeAssistance[ "Window" ] := catchMine @ ShowCodeAssistance[ getUserNotebook[ ], "Window" ];
ShowCodeAssistance[ "Inline" ] := catchMine @ ShowCodeAssistance[ InputNotebook[ ], "Inline" ];
ShowCodeAssistance[ nbo_NotebookObject, "Window" ] := catchMine @ showCodeAssistanceWindow @ nbo;
ShowCodeAssistance[ nbo_NotebookObject, "Inline" ] := catchMine @ showCodeAssistanceInline @ nbo;
ShowCodeAssistance // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Code Assistance*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showCodeAssistanceInline*)
showCodeAssistanceInline // beginDefinition;
showCodeAssistanceInline[ nbo_NotebookObject ] := attachInlineChatInput[ nbo, $codeAssistanceSettings ];
showCodeAssistanceInline[ _ ] := MessageDialog[ "No notebook selected." ];
showCodeAssistanceInline // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Assistance Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showCodeAssistanceWindow*)
showCodeAssistanceWindow // beginDefinition;

showCodeAssistanceWindow[ source_NotebookObject ] := Enclose[
    Module[ { current },
        current = ConfirmMatch[ findCurrentWorkspaceChat[ ], _NotebookObject | Missing[ "NotFound" ], "Existing" ];
        If[ MissingQ @ current,
            ConfirmMatch[ createWorkspaceChat @ source, _NotebookObject, "New" ],
            ConfirmMatch[ attachToLeft[ source, current ], _NotebookObject, "Attached" ]
        ]
    ],
    throwInternalFailure
];

showCodeAssistanceWindow[ None ] := Enclose[
    Module[ { current },
        current = ConfirmMatch[ findCurrentWorkspaceChat[ ], _NotebookObject | Missing[ "NotFound" ], "Existing" ];
        If[ MissingQ @ current,
            ConfirmMatch[ createWorkspaceChat[ ], _NotebookObject, "New" ],
            current
        ]
    ],
    throwInternalFailure
];

showCodeAssistanceWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachToLeft*)
attachToLeft // beginDefinition;

attachToLeft[ source_NotebookObject, current_NotebookObject ] := Enclose[
    Module[ { margins, left, bottom, top },

        margins = ConfirmMatch[ windowMargins @ source, { { _, _ }, { _, _ } }, "Margins" ];

        left   = margins[[ 1, 1 ]];
        bottom = margins[[ 2, 1 ]];
        top    = margins[[ 2, 2 ]];

        If[ NonPositive[ left - $workspaceChatWidth ],
            left   = $workspaceChatWidth;
            bottom = 0;
            top    = 0;
        ];

        SetOptions[
            current,
            WindowMargins -> { { left - $workspaceChatWidth, Automatic }, { bottom, top } },
            WindowSize    -> { $workspaceChatWidth, Automatic }
        ];

        SetSelectedNotebook @ current
    ],
    throwInternalFailure
];

attachToLeft // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*windowMargins*)
windowMargins // beginDefinition;
windowMargins[ nbo_NotebookObject ] := windowMargins[ nbo, AbsoluteCurrentValue[ nbo, WindowMargins ] ];
windowMargins[ nbo_, margins: { { _, _ }, { _, _ } } ] := margins;
windowMargins[ nbo_, margins_? NumberQ ] := { { margins, margins }, { margins, margins } };
windowMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findCurrentWorkspaceChat*)
findCurrentWorkspaceChat // beginDefinition;

findCurrentWorkspaceChat[ ] := FirstCase[
    selectByCurrentValue[ Notebooks[ ], { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" }, "Absolute" -> True ],
    _NotebookObject,
    Missing[ "NotFound" ]
];

findCurrentWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateWorkspaceChat*)
CreateWorkspaceChat // beginDefinition;
CreateWorkspaceChat[ ] := catchMine @ createWorkspaceChat[ ];
CreateWorkspaceChat[ nbo_NotebookObject ] := catchMine @ createWorkspaceChat @ nbo;
CreateWorkspaceChat // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createWorkspaceChat*)
createWorkspaceChat // beginDefinition;

createWorkspaceChat[ ] :=
    createWorkspaceChat[ { } ];

createWorkspaceChat[ cells: { ___Cell } ] := Enclose[
    Module[ { nbo },
        nbo = ConfirmMatch[
            NotebookPut @ Notebook[ cells, $workspaceChatNotebookOptions ],
            _NotebookObject,
            "Notebook"
        ];
        (* Do we need to move to input field here? *)
        SetOptions[
            nbo,
            WindowMargins -> { { 0, Automatic }, { 0, 0 } },
            WindowSize    -> { $workspaceChatWidth, Automatic }
        ];

        nbo
    ],
    throwInternalFailure
];

createWorkspaceChat[ source_NotebookObject ] :=
    createWorkspaceChat[ source, { } ];

createWorkspaceChat[ source_NotebookObject, cells: { ___Cell } ] := Enclose[
    Module[ { nbo },

        nbo = ConfirmMatch[
            NotebookPut @ Notebook[ cells, $workspaceChatNotebookOptions ],
            _NotebookObject,
            "Notebook"
        ];

        (* Do we need to move to input field here? *)
        ConfirmMatch[ attachToLeft[ source, nbo ], _NotebookObject, "Attached" ]
    ],
    throwInternalFailure
];

createWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
