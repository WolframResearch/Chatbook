(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatState`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat State Evaluation Wrappers*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withChatState*)
withChatState // beginDefinition;
withChatState // Attributes = { HoldFirst };

withChatState[ eval_ ] :=
    Block[
        {
            $ChatNotebookEvaluation       = True,
            $absoluteCurrentSettingsCache = <| |>,
            $AutomaticAssistance          = False,
            $chatState                    = True,
            $currentSettingsCache         = <| |>,
            $enableLLMServices            = Automatic,
            $WorkspaceChat                = False,
            withChatState                 = # &,
            $contextPrompt                = None,
            $selectionPrompt              = None,
            $toolCallCount                = 0,
            $openToolCallBoxes            = Automatic,
            $progressContainer            = None,
            $showProgressText             = $showProgressText,
            $receivedToolCall             = False,
            $thinkingStart                = None,
            $thinkingEnd                  = None,
            $useRasterCache               = True,
            $includeStackTrace            = True,

            (* Values used for token budgets during cell serialization: *)
            $cellStringBudget             = $cellStringBudget,
            $conversionRules              = $conversionRules,
            $initialCellStringBudget      = $initialCellStringBudget,
            $multimodalMessages           = $multimodalMessages,
            $tokenBudget                  = $tokenBudget,
            $tokenPressure                = $tokenPressure,

            (* Experimental features: *)
            $experimentalFeatures         = $experimentalFeatures
        },

        (* These are not locally scoped for debugging purposes: *)
        $ChatHandlerData = <| |>;
        $tokenBudgetLog  = Internal`Bag[ ];
        $lastTask        = None;
        $lastCellObject  = None;

        Internal`InheritedBlock[ { $evaluationCell, $evaluationNotebook, $llmKit, $llmKitService },
            Quiet[ withToolBox @ withBasePromptBuilder @ eval, ServiceExecute::multser ]
        ]
    ];

withChatState // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withChatStateAndFEObjects*)
withChatStateAndFEObjects // beginDefinition;
withChatStateAndFEObjects // Attributes = { HoldRest };

withChatStateAndFEObjects[ { cell_CellObject, nbo_NotebookObject }, eval_ ] :=
    withChatState @ withEvaluationNotebook[ nbo, withChatEvaluationCell[ cell, eval ] ];

withChatStateAndFEObjects[ { cell_CellObject, None }, eval_ ] :=
    withChatState @ withChatEvaluationCell[ cell, eval ];

withChatStateAndFEObjects[ { None, nbo_NotebookObject }, eval_ ] :=
    withChatState @ withAppNameCaller[ nbo, withEvaluationNotebook[ nbo, eval ] ];

(* Operator forms: *)
withChatStateAndFEObjects[ cell_CellObject ] :=
    withChatStateAndFEObjects[ { cell, None } ];

withChatStateAndFEObjects[ nbo_NotebookObject ] :=
    withChatStateAndFEObjects[ { None, nbo } ];

withChatStateAndFEObjects[ { cell_, nbo_ } ] :=
    Function[ eval,
              withChatStateAndFEObjects[ { cell, nbo }, eval ],
              HoldFirst
    ];

withChatStateAndFEObjects // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withChatEvaluationCell*)
withChatEvaluationCell // beginDefinition;
withChatEvaluationCell // Attributes = { HoldRest };

withChatEvaluationCell[ cell_CellObject, eval_ ] :=
    withChatState @ WithCleanup[
        $ChatEvaluationCell = cell
        ,
        withEvaluationCell[
            cell,
            (* Initialize settings cache: *)
            AbsoluteCurrentChatSettings @ cell;
            withAppNameCaller[ cell, eval ]
        ]
        ,
        (* CompoundExpression cannot be used here due to bug(450686): *)
        {
            $ChatEvaluationCell = None,
            If[ $CloudEvaluation,
                (* Workaround for dynamic in send/stop button not updating in cloud: *)
                NotebookWrite[ cell, NotebookRead @ cell, None, AutoScroll -> False ]
            ]
        }
    ];

withChatEvaluationCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*forceRedrawCellFrameLabels*)
forceRedrawCellFrameLabels // beginDefinition;

(* Workaround for dynamic in send/stop button not updating in cloud: *)
forceRedrawCellFrameLabels[ cell_CellObject ] /; $CloudEvaluation && chatInputCellQ @ cell :=
    Module[ { labels },
        labels = Replace[
            CurrentValue[ cell, CellFrameLabels ],
            Except[ { { _, _ }, { _, _ } } ] :> $defaultCellFrameLabels
        ];
        SetOptions[ cell, CellFrameLabels -> None ];
        SetOptions[ cell, CellFrameLabels -> labels ];
    ];

forceRedrawCellFrameLabels[ cell_ ] := Null;

forceRedrawCellFrameLabels // endDefinition;


$defaultCellFrameLabels = {
    {
        None,
        Cell[
            BoxData[ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "SendChatButton" ][ #1, #2, 20 ] ]&[ RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ] ] ],
            Background -> None
        ]
    },
    { None, None }
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withEvaluationCell*)
withEvaluationCell // beginDefinition;
withEvaluationCell // Attributes = { HoldRest };
withEvaluationCell[ cell_CellObject, eval_ ] := Block[ { $evaluationCell = cell }, eval ]
withEvaluationCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withEvaluationNotebook*)
withEvaluationNotebook // beginDefinition;
withEvaluationNotebook // Attributes = { HoldRest };

withEvaluationNotebook[ nbo_NotebookObject, eval_ ] :=
    Block[ { $evaluationNotebook = nbo },
        If[ TrueQ @ CurrentChatSettings[ nbo, "WorkspaceChat" ],
            withWorkspaceGlobalProgress[ nbo, eval ],
            eval
        ]
    ];

withEvaluationNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withAppNameCaller*)
withAppNameCaller // beginDefinition;
withAppNameCaller // Attributes = { HoldRest };

withAppNameCaller[ obj_, eval_ ] := Enclose[
    Module[ { appName },
        appName = CurrentChatSettings[ obj, "AppName" ];
        If[ StringQ @ appName && appName =!= $defaultAppName,
            setServiceCaller[ eval, appName ],
            eval
        ]
    ],
    throwInternalFailure
];

withAppNameCaller // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
