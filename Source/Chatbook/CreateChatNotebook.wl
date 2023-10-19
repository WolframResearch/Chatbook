(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CreateChatNotebook`" ];

HoldComplete[
    System`ChatObject
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`Formatting`" ];
Needs[ "Wolfram`Chatbook`SendChat`"   ];
Needs[ "Wolfram`Chatbook`UI`"         ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatNotebook*)
CreateChatNotebook // Options = {
    "Assistance"               -> Automatic,
    "AutoFormat"               -> True,
    "BasePrompt"               -> Automatic,
    "CellToMessageFunction"    -> CellToChatMessage,
    "ChatContextPreprompt"     -> Automatic,
    "ChatDrivenNotebook"       -> False,
    "ChatFormattingFunction"   -> FormatChatOutput,
    "ChatHistoryLength"        -> 25,
    "DynamicAutoFormat"        -> Automatic,
    "EnableChatGroupSettings"  -> False,
    "EnableLLMServices"        -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "FrequencyPenalty"         -> 0.1,
    "HandlerFunctions"         :> $DefaultChatHandlerFunctions,
    "HandlerFunctionsKeys"     -> Automatic,
    "IncludeHistory"           -> Automatic,
    "LLMEvaluator"             -> "CodeAssistant",
    "MaxTokens"                -> Automatic,
    "MergeMessages"            -> True,
    "Model"                    :> $DefaultModel,
    "NotebookWriteMethod"      -> Automatic,
    "OpenAIKey"                -> Automatic, (* TODO: remove this once LLMServices is widely available *)
    "PresencePenalty"          -> 0.1,
    "RecordChatStream"         -> False,
    "ShowMinimized"            -> Automatic,
    "StreamingOutputMethod"    -> Automatic,
    "Temperature"              -> 0.7,
    "ToolOptions"              :> $DefaultToolOptions,
    "Tools"                    -> Automatic,
    "ToolsEnabled"             -> Automatic,
    "TopP"                     -> 1,
    "TrackScrollingWhenPlaced" -> Automatic
};


CreateChatNotebook[ opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] :=
    catchMine @ createChatNotebook @ opts;

CreateChatNotebook[ nbo_NotebookObject, opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] :=
    catchMine @ Enclose @ Module[ { settings, options },
        settings = makeChatNotebookSettings @ Association @ FilterRules[ { opts }, Options @ CreateChatNotebook ];
        options  = makeChatNotebookOptions[ settings, opts ];
        SetOptions[ nbo, options ];
        nbo
    ];

CreateChatNotebook[ chat: HoldPattern[ _ChatObject ], opts: OptionsPattern[ { CreateChatNotebook, Notebook } ] ] :=
    catchMine @ createNotebookFromChatObject[ chat, opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$initialChatCells*)
$initialChatCells :=
    If[ TrueQ @ $cloudNotebooks,
        { Cell[ "", "ChatInput" ], $cloudSelectionMover },
        { Cell[ "", "ChatInput" ] }
    ];

$cloudSelectionMover = Cell @ BoxData @ ToBoxes @ Dynamic[
    SelectionMove[ First @ Cells @ EvaluationNotebook[ ], Before, CellContents ];
    NotebookDelete @ EvaluationCell[ ];
    ""
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createChatNotebook*)
createChatNotebook // beginDefinition;
createChatNotebook[ opts___ ] /; $cloudNotebooks := createCloudChatNotebook @ opts;
createChatNotebook[ opts___ ] := createLocalChatNotebook @ opts;
createChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createCloudChatNotebook*)
createCloudChatNotebook // beginDefinition;

createCloudChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    Module[ { settings, options, notebook, deployed },
        settings = makeChatNotebookSettings @ Association @ FilterRules[ { opts }, Options @ CreateChatNotebook ];
        options  = makeChatNotebookOptions[ settings, opts ];
        notebook = Notebook[ Flatten @ { $initialChatCells }, options ];
        deployed = CloudDeploy[ notebook, CloudObjectURLType -> "Environment" ];
        SystemOpen @ deployed;
        deployed
    ];

createCloudChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createLocalChatNotebook*)
createLocalChatNotebook // beginDefinition;

createLocalChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    Module[ { nbo, result },
        WithCleanup[
            nbo = NotebookPut[ Notebook @ Flatten @ { $initialChatCells }, Visible -> False ],
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

createLocalChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$chatbookStylesheet*)
$chatbookStylesheet := If[ TrueQ @ $cloudNotebooks, $cloudStylesheet, "Chatbook.nb" ];

$cloudStylesheet :=
    With[ { dir = PacletObject[ "Wolfram/Chatbook" ][ "Location" ] },
        If[ StringQ @ dir && StringStartsQ[ dir, $BasePacletsDirectory ],
            "Chatbook.nb",
            ReplaceAll[
                $inlinedStylesheet,
                Cell @ StyleData[ StyleDefinitions -> "Default.nb" ] :>
                    Sequence[
                        Cell @ StyleData[ StyleDefinitions -> "Default.nb" ],
                        Cell[
                            StyleData[ All, "Working" ],
                            DockedCells -> Dynamic @ If[
                                $CloudEvaluation,
                                {
                                    Cell[
                                        BoxData @ DynamicBox @ ToBoxes @ MakeChatCloudDockedCellContents[ ],
                                        Background -> None
                                    ]
                                },
                                { }
                            ]
                        ]
                    ]
            ]
        ]
    ];

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
    catchMine @ CreateChatNotebook[
        "ChatDrivenNotebook" -> True,
        "LLMEvaluator"       -> "PlainChat",
        DefaultNewCellStyle  -> "ChatInput",
        opts
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Functions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookSettings*)
makeChatNotebookSettings // beginDefinition;
makeChatNotebookSettings[ as_Association? AssociationQ ] := KeySort @ KeyMap[ ToString, as ];
makeChatNotebookSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeChatNotebookOptions*)
makeChatNotebookOptions // beginDefinition;

makeChatNotebookOptions[ settings_Association, opts: OptionsPattern[ ] ] := Sequence @@ DeleteDuplicatesBy[
    Flatten @ {
        FilterRules[ { opts }, $notebookOptions ],
        StyleDefinitions -> $chatbookStylesheet,
        If[ settings === <| |>,
            Nothing,
            TaggingRules -> <| "ChatNotebookSettings" -> settings |>
        ]
    },
    ToString @* First
];

makeChatNotebookOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$notebookOptions*)
$notebookOptions := $notebookOptions = UsingFrontEnd @ Block[ { $Context = "FrontEnd`" }, Options @ Notebook ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createNotebookFromChatObject*)
createNotebookFromChatObject // beginDefinition;

createNotebookFromChatObject[ HoldPattern @ ChatObject[ args___ ], opts: OptionsPattern[ ] ] :=
    createNotebookFromChatObject[ { args }, opts ];

createNotebookFromChatObject[ { as_Association, a___ }, opts: OptionsPattern[ ] ] := Enclose[
    Module[ { messages, cells },
        messages = ConfirmMatch[ as[ "Messages" ], { ___Association }, "Messages" ];
        cells = ConfirmMatch[ createMessageCell[ as, #1 ] & /@ messages, { ___Cell }, "Cells" ];
        Block[ { $initialChatCells = cells }, createChatNotebook[ "LLMEvaluator" -> "PlainChat", opts ] ]
    ],
    throwInternalFailure[ createNotebookFromChatObject[ { as, a }, opts ], ##1 ] &
];

createNotebookFromChatObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createMessageCell*)
createMessageCell // beginDefinition;
createMessageCell[ as_Association, msg_Association ] := createMessageCell0[ as, KeyMap[ ToLowerCase@*ToString, msg ] ];
createMessageCell // endDefinition;

createMessageCell0 // beginDefinition;

createMessageCell0[ as_Association, msg_Association ] := Enclose[
    Module[ { role, content },
        role = ToLowerCase @ ConfirmBy[ msg[ "role" ], StringQ, "Role" ];
        content = ConfirmBy[ msg[ "content" ], StringQ, "Content" ];
        createMessageCell0[ as, role, content ]
    ],
    throwInternalFailure[ createMessageCell0[ as, msg ], ## ] &
];

createMessageCell0[ as_Association, "assistant", content_String ] :=
    Cell[ TextData @ reformatTextData @ content, "ChatOutput", CellDingbat -> makeOutputDingbat @ as ];

createMessageCell0[ as_Association, "system", content_String ] :=
    Cell[ content, "ChatSystemInput" ];

createMessageCell0[ as_Association, "user", content_String ] :=
    Cell[ content,
          "ChatInput",
          CellDingbat -> Cell[ BoxData @ TemplateBox[ { }, "ChatInputCellDingbat" ], Background -> None ]
    ];

createMessageCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
