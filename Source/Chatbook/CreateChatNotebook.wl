(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`CreateChatNotebook`" ];

HoldComplete[
    System`ChatObject
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];
Needs[ "Wolfram`Chatbook`UI`"     ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$unsavedSettings = { "InitialChatCell", "TargetCloudObject" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Argument Patterns*)
$$createChatOptions = OptionsPattern[ { CreateChatNotebook, Notebook } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CreateChatNotebook*)
Needs[ "Wolfram`Chatbook`Settings`" ]; (* Needed for $defaultChatSettings *)
CreateChatNotebook // Options = Normal[ $defaultChatSettings, Association ];


CreateChatNotebook[ opts: $$createChatOptions ] :=
    catchMine @ createChatNotebook @ opts;

CreateChatNotebook[ nbo_NotebookObject, opts: $$createChatOptions ] :=
    catchMine @ Enclose @ Module[ { settings, options },
        settings = makeChatNotebookSettings @ Association @ FilterRules[ { opts }, Options @ CreateChatNotebook ];
        options  = makeChatNotebookOptions[ settings, opts ];
        SetOptions[ nbo, options ];
        nbo
    ];

CreateChatNotebook[ cell_Cell, opts: $$createChatOptions ] :=
    catchMine @ CreateChatNotebook[ { cell }, opts ];

CreateChatNotebook[ cells: { ___Cell }, opts: $$createChatOptions ] :=
    catchMine @ Block[ { initialChatCells = cells & }, CreateChatNotebook @ opts ];

CreateChatNotebook[ chat: HoldPattern[ _ChatObject ], opts: $$createChatOptions ] :=
    catchMine @ createNotebookFromChatObject[ chat, opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*initialChatCells*)
initialChatCells // beginDefinition;

initialChatCells[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    If[ TrueQ @ OptionValue[
            CreateChatNotebook,
            FilterRules[ { opts }, Options @ CreateChatNotebook ],
            "InitialChatCell"
        ],
        $initialChatCells,
        { }
    ];

initialChatCells // endDefinition;

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

createCloudChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] := Enclose[
    Module[ { validOpts, settings, options, notebook, location, deployed },
        validOpts = FilterRules[ { opts }, Options @ CreateChatNotebook ];
        settings  = makeChatNotebookSettings @ Association @ validOpts;
        options   = makeChatNotebookOptions[ settings, opts ];
        notebook  = Notebook[ ConfirmMatch[ Flatten @ { initialChatCells @ opts }, { ___Cell }, "Cells" ], options ];
        location  = OptionValue[ CreateChatNotebook, validOpts, "TargetCloudObject" ];
        deployed  = ConfirmMatch[ deployCloudNotebook[ notebook, location ], _CloudObject, "Deploy" ];
        SystemOpen @ deployed;
        deployed
    ],
    throwInternalFailure
];

createCloudChatNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*deployCloudNotebook*)
deployCloudNotebook // beginDefinition;
deployCloudNotebook[ nb_Notebook, obj_CloudObject ] := CloudDeploy[ nb, obj, CloudObjectURLType -> "Environment" ];
deployCloudNotebook[ nb_Notebook, _ ] := CloudDeploy[ nb, CloudObjectURLType -> "Environment" ];
deployCloudNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createLocalChatNotebook*)
createLocalChatNotebook // beginDefinition;

createLocalChatNotebook[ opts: OptionsPattern[ CreateChatNotebook ] ] :=
    Module[ { nbo, result },
        WithCleanup[
            nbo = NotebookPut[ Notebook @ Flatten @ { initialChatCells @ opts }, Visible -> False ],
            result = CreateChatNotebook[ nbo, opts ],
            If[ FailureQ @ result
                ,
                NotebookClose @ nbo
                ,
                Replace[ Cells @ nbo, { cell_CellObject, ___ } :> SelectionMove[ cell, Before, CellContents ] ];
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
CreateChatDrivenNotebook[ opts: $$createChatOptions ] :=
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

makeChatNotebookSettings[ as_Association? AssociationQ ] := KeyDrop[
    KeySort @ KeyMap[ ToString, as ],
    $unsavedSettings
];

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
        Block[ { initialChatCells = Evaluate @ cells & }, createChatNotebook[ "LLMEvaluator" -> "PlainChat", opts ] ]
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
    Module[ { role, content, string },
        role = ToLowerCase @ ConfirmBy[ msg[ "role" ], StringQ, "Role" ];
        content = ConfirmMatch[ msg[ "content" ], _String|_Association, "Content" ];
        string = ConfirmBy[ If[ StringQ @ content, content, content[ "Data" ] ], StringQ, "String" ];
        createMessageCell0[ as, role, string ]
    ],
    throwInternalFailure
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
