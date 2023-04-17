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
    "Assistance"                        -> Automatic, (* TODO: use this to determine if assistance should run as epilog *)
    "AutoFormat"                        -> True,
    "ChatContextCellProcessingFunction" -> Automatic,
    "ChatContextPostEvaluationFunction" -> Automatic,
    "ChatContextPreprompt"              -> Automatic,
    "ChatHistoryLength"                 -> 25,
    "DynamicAutoFormat"                 -> Automatic,
    "FrequencyPenalty"                  -> 0.1,
    "MaxTokens"                         -> Automatic,
    "MergeMessages"                     -> True,
    "Model"                             -> "gpt-3.5-turbo",
    "OpenAIKey"                         -> Automatic,
    "PresencePenalty"                   -> 0.1,
    "ShowMinimized"                     -> Automatic,
    "Temperature"                       -> 0.7,
    "TopP"                              -> 1
};

CreateChatNotebook[ opts: OptionsPattern[ ] ] :=
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

CreateChatNotebook[ nbo_NotebookObject, opts: OptionsPattern[ ] ] :=
    Enclose @ Module[ { settings, options },
        settings = makeChatNotebookSettings @ opts;
        options  = makeChatNotebookOptions @ settings;
        SetOptions[ nbo, options ];
        nbo
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
    StyleDefinitions -> "Chatbook.nb",
    TaggingRules     -> <| "ChatNotebookSettings" -> settings |>
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
