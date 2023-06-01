(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CreateChatNotebook`" ];

ClearAll[ "`*"         ];
ClearAll[ "`Private`*" ];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatNotebook*)
CreateChatNotebook // Options = {
    "Assistance"                        -> Automatic,
    "AutoFormat"                        -> True,
    "BasePrompt"                        -> Automatic,
    "ChatContextCellProcessingFunction" -> Automatic,
    "ChatContextPostEvaluationFunction" -> Automatic,
    "ChatContextPreprompt"              -> Automatic,
    "ChatDrivenNotebook"                -> False,
    "ChatHistoryLength"                 -> 25,
    "DynamicAutoFormat"                 -> Automatic,
    "FrequencyPenalty"                  -> 0.1,
    "IncludeHistory"                    -> Automatic,
    "LLMEvaluator"                      -> "CodeAssistant",
    "MaxTokens"                         -> Automatic,
    "MergeMessages"                     -> True,
    "Model"                             -> "gpt-3.5-turbo",
    "OpenAIKey"                         -> Automatic,
    "PresencePenalty"                   -> 0.1,
    "ShowMinimized"                     -> Automatic,
    "Temperature"                       -> 0.7,
    "ToolsEnabled"                      -> False,
    "TopP"                              -> 1
};


CreateChatNotebook[ opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] := createChatNotebook @ opts;

CreateChatNotebook[ nbo_NotebookObject, opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] :=
    Enclose @ Module[ { settings, options },
        settings = makeChatNotebookSettings @ Association @ FilterRules[ { opts }, Options @ CreateChatNotebook ];
        options  = makeChatNotebookOptions[ settings, opts ];
        SetOptions[ nbo, options ];
        nbo
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createChatNotebook*)
createChatNotebook // SetFallthroughError;
createChatNotebook[ opts___ ] /; $cloudNotebooks := createCloudChatNotebook @ opts;
createChatNotebook[ opts___ ] := createLocalChatNotebook @ opts;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createCloudChatNotebook*)
createCloudChatNotebook // SetFallthroughError;
createCloudChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    Module[ { settings, options, notebook, deployed },
        settings = makeChatNotebookSettings @ Association @ opts;
        options  = makeChatNotebookOptions @ settings;
        notebook = Notebook[ { Cell[ "", "ChatInput" ], $cloudSelectionMover }, options ];
        deployed = CloudDeploy[ notebook, CloudObjectURLType -> "Environment" ];
        SystemOpen @ deployed;
        deployed
    ];

$cloudSelectionMover = Cell @ BoxData @ ToBoxes @ Dynamic[
    SelectionMove[ First @ Cells @ EvaluationNotebook[ ], Before, CellContents ];
    NotebookDelete @ EvaluationCell[ ];
    ""
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createLocalChatNotebook*)
createLocalChatNotebook // SetFallthroughError;
createLocalChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    Module[ { nbo, result },
        WithCleanup[
            nbo = NotebookPut[ Notebook @ { Cell[ "", "ChatInput" ] }, Visible -> False ],
            result = CreateChatNotebook[ nbo, opts ],
            If[ FailureQ @ result
                ,
                NotebookClose @ nbo
                ,
                SelectionMove[ First @ Cells @ nbo, Before, CellContents ];
                CurrentValue[ nbo, Visible ] = Inherited;
                SetSelectedNotebook @ nbo
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookSettings*)
makeChatNotebookSettings // SetFallthroughError;
makeChatNotebookSettings[ as_Association? AssociationQ ] := KeySort @ KeyMap[ ToString, as ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookOptions*)
makeChatNotebookOptions // SetFallthroughError;

makeChatNotebookOptions[ settings_Association, opts: OptionsPattern[ ] ] := Sequence @@ DeleteDuplicatesBy[
    Flatten @ {
        FilterRules[ { opts }, Options @ Notebook ],
        StyleDefinitions -> $chatbookStylesheet,
        If[ settings === <| |>,
            Nothing,
            TaggingRules -> <| "ChatNotebookSettings" -> settings |>
        ]
    },
    ToString @* First
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatbookStylesheet*)
$chatbookStylesheet := If[ TrueQ @ $cloudNotebooks, $inlinedStylesheet, "Chatbook.nb" ];

$inlinedStylesheet := $inlinedStylesheet = Import[
    FileNameJoin @ {
        PacletObject[ "Wolfram/Chatbook" ][ "Location" ],
        "FrontEnd",
        "StyleSheets",
        "Chatbook.nb"
    },
    "NB"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatDrivenNotebook*)
CreateChatDrivenNotebook[ opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] :=
    CreateChatNotebook[
        "ChatDrivenNotebook" -> True,
        "LLMEvaluator"       -> "Default",
        DefaultNewCellStyle  -> "ChatInput",
        opts
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $inlinedStylesheet;
];

End[ ];
EndPackage[ ];
