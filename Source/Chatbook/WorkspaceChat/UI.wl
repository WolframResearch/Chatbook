(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`WorkspaceChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inputFieldPaneMargins       = 5;
$inputFieldGridMagnification = 0.75;
$inputFieldOuterBackground   = GrayLevel[ 0.95 ];

$inputFieldOptions = Sequence[
    BoxID      -> "AttachedChatInputField",
    ImageSize  -> { Scaled[ 1 ], 25 },
    FieldHint  -> tr[ "FloatingChatFieldHint" ],
    BaseStyle  -> "ChatInput",
    Appearance -> "Frameless"
];

$inputFieldFrameOptions = Sequence[
    Background   -> White,
    FrameMargins -> { { 5, 5 }, { 2, 2 } },
    FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#a3c9f2" ] ]
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Docked Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] := Grid @ {
    {
        Button[
            "New",
            SelectionMove[ EvaluationNotebook[ ], After, Notebook ];
            NotebookWrite[ EvaluationNotebook[ ], Cell[ "", "ChatDelimiter" ] ]
        ],
        Button[ "Clear", NotebookDelete @ Cells @ EvaluationNotebook[ ] ],
        Item[ "", ItemSize -> Fit ],
        Button[
            "Pop Out",
            NotebookPut @ Notebook[ First @ NotebookGet @ EvaluationNotebook[ ], StyleDefinitions -> "Chatbook.nb" ]
        ]
    }
};

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attached Chat Input*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachChatInputField*)
attachWorkspaceChatInput // beginDefinition;

attachWorkspaceChatInput[ nbo_NotebookObject ] := Enclose[
    Module[ { attached },
        attached = ConfirmMatch[ AttachCell[ nbo, $attachedChatInputCell, Bottom, 0, Bottom ], _CellObject, "Attach" ];
        attached
    ],
    throwInternalFailure
];

attachWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$attachedChatInputCell*)
$attachedChatInputCell = ExpressionCell[
    DynamicModule[ { thisNB },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                            Framed[
                                InputField[
                                    Dynamic @ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatInputString" } ],
                                    String,
                                    $inputFieldOptions
                                ],
                                $inputFieldFrameOptions
                            ]
                        }
                    },
                    BaseStyle -> { Magnification -> $inputFieldGridMagnification }
                ],
                FrameMargins -> $inputFieldPaneMargins
            ],
            {
                "ReturnKeyDown" :> (
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "EvaluateFloatingChat",
                        thisNB,
                        Dynamic @ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ChatInputString" } ]
                    ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ])
    ],
    "ChatInputField",
    Background -> $inputFieldOuterBackground,
    Selectable -> True
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Field Movement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*moveToChatInputField*)
moveToChatInputField // beginDefinition;

moveToChatInputField[ nbo_ ] :=
    moveToChatInputField[ nbo, $WorkspaceChat ];

moveToChatInputField[ nbo_NotebookObject, True ] := (
    moveToChatInputField0 @ nbo; (* TODO: Need to investigate why this is needed twice *)
    moveToChatInputField0 @ nbo;
);

moveToChatInputField[ nbo_NotebookObject, False ] :=
    Null;

moveToChatInputField // endDefinition;


moveToChatInputField0 // beginDefinition;

moveToChatInputField0[ nbo_NotebookObject ] := (
    SelectionMove[
        First[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], $Failed ],
        After,
        CellContents
    ];
    FrontEndExecute @ FrontEndToken[ nbo, "MovePrevious" ]
);

moveToChatInputField0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
