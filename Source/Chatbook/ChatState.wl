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
            $absoluteCurrentSettingsCache = <| |>,
            $AutomaticAssistance          = False,
            $chatState                    = True,
            $currentSettingsCache         = <| |>,
            $enableLLMServices            = Automatic,
            $WorkspaceChat                = False,
            withChatState                 = # &,

            (* Values used for token budgets during cell serialization: *)
            $cellStringBudget             = $cellStringBudget,
            $conversionRules              = $conversionRules,
            $initialCellStringBudget      = $initialCellStringBudget,
            $multimodalMessages           = $multimodalMessages,
            $tokenBudget                  = $tokenBudget,
            $tokenPressure                = $tokenPressure
        },
        $ChatHandlerData = <| |>;
        $tokenBudgetLog = Internal`Bag[ ];
        (* cSpell: ignore multser *)
        Internal`InheritedBlock[ { $evaluationCell, $evaluationNotebook },
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

(* Operator forms: *)
withChatStateAndFEObjects[ cell_CellObject ] :=
    withChatStateAndFEObjects[ { cell, None } ];

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
        $ChatEvaluationCell = cell,
        withEvaluationCell[
            cell,
            (* Initialize settings cache: *)
            AbsoluteCurrentChatSettings @ cell;
            eval
        ],
        $ChatEvaluationCell = None
    ];

withChatEvaluationCell // endDefinition;

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
withEvaluationNotebook[ nbo_NotebookObject, eval_ ] := Block[ { $evaluationNotebook = nbo }, eval ];
withEvaluationNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
