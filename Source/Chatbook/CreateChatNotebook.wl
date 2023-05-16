(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CreateChatNotebook`" ];

ClearAll[ "`*"         ];
ClearAll[ "`Private`*" ];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
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
    "ChatHistoryLength"                 -> 25,
    "DynamicAutoFormat"                 -> Automatic,
    "FrequencyPenalty"                  -> 0.1,
    "IncludeHistory"                    -> Automatic,
    "MaxTokens"                         -> Automatic,
    "MergeMessages"                     -> True,
    "LLMEvaluator"                      -> "Helper",
    "Model"                             -> "gpt-3.5-turbo",
    "OpenAIKey"                         -> Automatic,
    "PresencePenalty"                   -> 0.1,
    "ShowMinimized"                     -> Automatic,
    "Temperature"                       -> 0.7,
    "TopP"                              -> 1
};

CreateChatNotebook[ opts: OptionsPattern[ ] ] := createChatNotebook @ opts;

CreateChatNotebook[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    Enclose @ Module[ { settings, options },
        settings = makeChatNotebookSettings @ Association @ opts;
        options  = makeChatNotebookOptions @ settings;
        SetOptions[ nbo, options ];
        nbo
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createChatNotebook*)
createChatNotebook // SetFallthroughError;
createChatNotebook[ opts___ ] /; CloudSystem`$CloudNotebooks := createCloudChatNotebook @ opts;
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
                SetOptions[ nbo, Visible -> True ];
                SetSelectedNotebook @ nbo
            ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookSettings*)
makeChatNotebookSettings // SetFallthroughError;

makeChatNotebookSettings[ ] := makeChatNotebookSettings @ <| |>;

makeChatNotebookSettings[ as_Association? AssociationQ, opts: OptionsPattern[ CreateChatNotebook ] ] :=
    With[ { bcOpts = Options @ CreateChatNotebook },
        KeyMap[ ToString, Association[ bcOpts, FilterRules[ { opts }, bcOpts ], as ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookOptions*)
makeChatNotebookOptions // SetFallthroughError;

makeChatNotebookOptions[ settings_Association ] := Sequence[
    StyleDefinitions -> $chatbookStylesheet,
    TaggingRules     -> <| "ChatNotebookSettings" -> settings |>
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatbookStylesheet*)
$chatbookStylesheet := If[ TrueQ @ CloudSystem`$CloudNotebooks, $inlinedStylesheet, "Chatbook.nb" ];

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
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $inlinedStylesheet;
];

End[ ];
EndPackage[ ];
