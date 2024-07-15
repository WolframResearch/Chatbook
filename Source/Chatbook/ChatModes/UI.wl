(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ChatModes`UI`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inputFieldPaneMargins       = 5;
$inputFieldGridMagnification = 0.8;
$inputFieldOuterBackground   = GrayLevel[ 0.95 ];
$initialInlineChatWidth      = Scaled[ 0.5 ];
$initialInlineChatHeight     = UpTo[ 200 ];

$inputFieldOptions = Sequence[
    BoxID      -> "AttachedChatInputField",
    ImageSize  -> { Scaled[ 1 ], { 25, Automatic } },
    FieldHint  -> tr[ "AttachedChatFieldHint" ],
    BaseStyle  -> { "Text" },
    Appearance -> "Frameless"
];

$inputFieldFrameOptions = Sequence[
    Background   -> White,
    FrameMargins -> { { 5, 5 }, { 2, 2 } },
    FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ "#a3c9f2" ] ]
];

$userImageParams = <| "size" -> 50, "default" -> "identicon", "rating" -> "G" |>;

$defaultUserImage = Graphics[
    {
        EdgeForm @ None,
        FaceForm @ GrayLevel[ 0.8 ],
        Disk[ { 0, 0.2 }, 2.35 ],
        FaceForm @ White,
        Disk[ { 0, 1 }, 1 ],
        Disk[ { 0, -1.8 }, { 1.65, 2 } ]
    },
    ImageSize -> 25,
    PlotRange -> { { -2.4, 2.4 }, { -2.0, 2.8 } }
];

$messageAuthorImagePadding = { { 0, 0 }, { 0, 6 } };

$inputFieldBox = None;
$inlineChatScrollPosition = 0.0;
$lastScrollPosition       = 0.0;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] := Grid @ {
    {
        Button[
            "New",
            SelectionMove[ EvaluationNotebook[ ], After, Notebook ];
            NotebookWrite[ EvaluationNotebook[ ], Cell[ "", "ChatDelimiter", CellFrameLabels -> None ] ]
        ],
        Button[ "Clear", NotebookDelete @ Cells @ EvaluationNotebook[ ] ],
        Item[ "", ItemSize -> Fit ],
        Button[ "Pop Out", popOutChatNB @ EvaluationNotebook[ ], Method -> "Queued" ]
    }
};

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachWorkspaceChatInput*)
attachWorkspaceChatInput // beginDefinition;

attachWorkspaceChatInput[ nbo_NotebookObject ] := Enclose[
    Module[ { attached },
        attached = ConfirmMatch[
            AttachCell[ nbo, $attachedWorkspaceChatInputCell, Bottom, 0, Bottom ],
            _CellObject,
            "Attach"
        ];

        attached
    ],
    throwInternalFailure
];

attachWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$attachedWorkspaceChatInputCell*)
$attachedWorkspaceChatInputCell := $attachedWorkspaceChatInputCell = Cell[
    BoxData @ ToBoxes @ DynamicModule[ { thisNB },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                            Framed[
                                InputField[
                                    Dynamic @ CurrentValue[
                                        EvaluationNotebook[ ],
                                        { TaggingRules, "ChatInputString" }
                                    ],
                                    String,
                                    $inputFieldOptions
                                ],
                                $inputFieldFrameOptions
                            ],
                            RawBoxes @ TemplateBox[ { RGBColor[ "#a3c9f2" ], 27, thisNB }, "WorkspaceSendChatButton" ]
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
                        "EvaluateWorkspaceChat",
                        thisNB,
                        Dynamic @ CurrentValue[ thisNB, { TaggingRules, "ChatInputString" } ]
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
(*Inline Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachInlineChatInput*)
attachInlineChatInput // beginDefinition;

attachInlineChatInput[ nbo_NotebookObject ] :=
    If[ TrueQ @ userNotebookQ @ nbo,
        attachInlineChatInput[ nbo, SelectedCells @ nbo ],
        Null
    ];

(* FIXME: need to determine selection info and store it before attaching the cell, since the selection will move *)
attachInlineChatInput[ nbo_NotebookObject, { root_CellObject } ] := Enclose[
    Module[ { attached },

        $lastScrollPosition = 0.0;
        $inlineChatScrollPosition = 0.0;

        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedChatInput" ];

        attached = ConfirmMatch[
            AttachCell[
                NotebookSelection @ nbo,
                inlineChatInputCell @ root,
                { Left, Top },
                0,
                { Left, Bottom },
                RemovalConditions -> { "EvaluatorQuit" }
            ],
            _CellObject,
            "Attach"
        ];

        SelectionMove[ attached, Before, CellContents ];
        FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ];

        attached
    ],
    throwInternalFailure
];

attachInlineChatInput[ nbo_NotebookObject, { ___ } ] := Null;

attachInlineChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatInputCell*)
inlineChatInputCell // beginDefinition;

inlineChatInputCell[ root_CellObject ] := Cell[
    BoxData @ inlineTemplateBox @ TemplateBox[
        {
            ToBoxes @ DynamicModule[ { messageCells = { }, cell },
                Dynamic[
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "DisplayInlineChat",
                        cell,
                        root,
                        Dynamic[ messageCells ]
                    ]
                ],

                UnsavedVariables :> { cell },

                (* ParentCell and ParentNotebook do not work for cells attached to NotebookSelection[ ],
                   so we create temporary overrides here. *)
                Initialization :> (
                    cell = EvaluationCell[ ];
                    parentCell[ cell ] = root;
                    parentNotebook[ cell ] = parentNotebook @ root;
                ),

                Deinitialization :> Quiet[
                    $inputFieldBox = None;
                    Unset @ parentCell @ cell;
                    Unset @ parentNotebook @ cell;
                ]
            ]
        },
        "DropShadowPaneBox"
    ],
    "AttachedChatInput",
    Background -> None,
    Selectable -> True
];

inlineChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*displayInlineChat*)
displayInlineChat // beginDefinition;

displayInlineChat[ cell_CellObject, root_CellObject, Dynamic[ messageCells_Symbol ] ] :=
    Module[ { inputField },

        inputField = inlineChatInputField[
            cell,
            root,
            Dynamic @ CurrentValue[ cell, { TaggingRules, "ChatInputString" } ],
            Dynamic @ messageCells
        ];

        displayInlineChatMessages[ messageCells, inputField ]
    ];

displayInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatInputField*)
inlineChatInputField // beginDefinition;

inlineChatInputField[ cell_CellObject, root_CellObject, Dynamic[ currentInput_ ], Dynamic[ messageCells_ ] ] :=
    EventHandler[
        Pane[
            Grid[
                {
                    {
                        RawBoxes @ inlineTemplateBox @ TemplateBox[ { }, "ChatIconUser" ],
                        Framed[
                            DynamicWrapper[
                                InputField[ Dynamic @ currentInput, String, $inputFieldOptions ],
                                $inputFieldBox = EvaluationBox[ ]
                            ],
                            $inputFieldFrameOptions
                        ],
                        (* FIXME: this needs a custom button *)
                        RawBoxes @ inlineTemplateBox @ TemplateBox[ { RGBColor[ "#a3c9f2" ], 27 }, "SendChatButton" ],
                        Style[
                            ActionMenu[
                                "More",
                                {
                                    "Close"        :> NotebookDelete @ EvaluationCell[ ],
                                    "View in Chat" :> (
                                        NotebookDelete @ EvaluationCell[ ];
                                        popOutWorkspaceChatNB @ messageCells
                                    )
                                },
                                ImageSize -> { Automatic, 25 }
                            ],
                            Magnification -> 1
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
                    "EvaluateInlineChat",
                    cell,
                    root,
                    Dynamic @ currentInput,
                    Dynamic @ messageCells
                ]
            )
        },
        Method -> "Queued"
    ];

inlineChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveToInlineChatInputField*)
moveToInlineChatInputField // beginDefinition;

moveToInlineChatInputField[ ] :=
    moveToInlineChatInputField @ $inputFieldBox;

moveToInlineChatInputField[ box_BoxObject ] := Quiet @ Catch[
    SelectionMove[ box, Before, Expression ];
    FrontEnd`MoveCursorToInputField[ parentNotebook @ box, "AttachedChatInputField" ],
    _
];

moveToInlineChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayInlineChatMessages*)
displayInlineChatMessages // beginDefinition;

displayInlineChatMessages[ { }, inputField_ ] :=
    Pane[ inputField, ImageSize -> { Scaled[ 0.5 ], Automatic } ];

displayInlineChatMessages[ cells: { __Cell }, inputField_ ] :=
    DynamicModule[ { w, h, size },

        (* TODO: use cell tagging rules instead so it remembers the size when refreshing *)
        w = $initialInlineChatWidth;
        h = $initialInlineChatHeight;
        size = { w, h };

        Column[
            {
                Pane[
                    Column[
                        formatInlineMessageCells /@ cells,
                        Alignment  -> Left,
                        BaseStyle  -> { Magnification -> 0.8 },
                        ItemSize   -> { Fit, Automatic },
                        Spacings   -> 0.5
                    ],
                    FrameMargins       -> 5,
                    ImageSize          -> Dynamic[ size, Function[ { w, h } = size = # ] ],
                    Scrollbars         -> Automatic,
                    AppearanceElements -> { "ResizeArea" },
                    ScrollPosition     -> Dynamic[
                        { 0, $inlineChatScrollPosition },
                        Function[ $lastScrollPosition = $inlineChatScrollPosition = Last[ # ] ]
                    ]
                ],
                Pane[ inputField, ImageSize -> Dynamic[ { w, Automatic } ] ]
            },
            Alignment -> Left
        ],
        Initialization :> ($inlineChatScrollPosition = $lastScrollPosition)
    ];

displayInlineChatMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*scrollInlineChat*)
scrollInlineChat // beginDefinition;
scrollInlineChat[ ] := scrollInlineChat[ 500 ];
scrollInlineChat[ amount_ ] := (scrollInlineChat0[ amount ]; updateDynamics[ "InlineChatScrollPane" ]);
scrollInlineChat // endDefinition;

scrollInlineChat0 // beginDefinition;
scrollInlineChat0[ amount_ ] := scrollInlineChat0[ amount, $lastScrollPosition ];
scrollInlineChat0[ amount_? NumberQ, current_? NumberQ ] := $lastScrollPosition = current + amount;
scrollInlineChat0[ amount_? NumberQ, _  ] := $lastScrollPosition = amount;
scrollInlineChat0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatInlineMessageCells*)
formatInlineMessageCells // beginDefinition;

formatInlineMessageCells[ cell: Cell[ __, "ChatInput", ___ ] ] :=
    Item[
        Grid[
            { { RawBoxes @ cell, Pane[ userImage[ ], ImageMargins -> $messageAuthorImagePadding ] } },
            Alignment -> { Right, Top }
        ],
        Alignment -> Right
    ];

formatInlineMessageCells[ cell: Cell[ __, "ChatOutput", ___ ] ] :=
    Block[ { $InlineChat = True },
        Grid[
            {
                {
                    Pane[ assistantImage[ ], ImageMargins -> $messageAuthorImagePadding ],
                    RawBoxes @ Append[ DeleteCases[ cell, Background -> _ ], Background -> None ]
                }
            },
            Alignment -> { Left, Top }
        ]
    ];

formatInlineMessageCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Field Movement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*moveToChatInputField*)
moveToChatInputField // beginDefinition;

(* TODO: support inline chat cells too *)
moveToChatInputField[ nbo_ ] :=
    moveToChatInputField[ nbo, $WorkspaceChat ];

moveToChatInputField[ nbo_NotebookObject, True ] := (
    moveToChatInputField0 @ nbo; (* TODO: Need to investigate why this is needed twice *)
    (* FIXME: Maybe this should use `FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ]`? *)
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
(*Chat Message Labels*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageLabel*)
assistantMessageLabel // beginDefinition;
assistantMessageLabel[ ] := Grid[ { { assistantImage[ ], assistantName[ ] } }, Alignment -> { Automatic, Center } ];
assistantMessageLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assistantName*)
assistantName // beginDefinition;
assistantName[ ] := "Code Assistant"; (* TODO *)
assistantName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assistantImage*)
assistantImage // beginDefinition;
assistantImage[      ] := assistantImage @ $InlineChat;
assistantImage[ True ] := inlineTemplateBox @ assistantImage0[ ];
assistantImage[ _    ] := assistantImage0[ ];
assistantImage // endDefinition;


assistantImage0 // beginDefinition;
assistantImage0[ ] := RawBoxes @ TemplateBox[ { }, "ChatIconCodeAssistant" ]; (* TODO *)
assistantImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*userMessageLabel*)
userMessageLabel // beginDefinition;
userMessageLabel[ ] := Grid[ { { userName[ ], userImage[ ] } }, Alignment -> { Automatic, Center } ];
userMessageLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userName*)
userName // beginDefinition;
userName[ ] := SelectFirst[ { $CloudAccountName, $Username }, StringQ, "You" ];
userName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userImage*)
userImage // beginDefinition;

userImage[ ] := userImage[ $CloudUserID ];

userImage[ user_String ] := Enclose[
    Module[ { hash, url, image },
        hash = Hash[ ToLowerCase @ StringTrim @ user, "MD5", "HexString" ];
        url = ConfirmBy[ URLBuild[ { "https://www.gravatar.com/avatar/", hash }, $userImageParams ], StringQ, "URL" ];
        image = ConfirmBy[ Import @ url, ImageQ, "Image" ];
        userImage[ user ] = Show[ image, ImageSize -> 25 ]
    ],
    $defaultUserImage &
];

userImage[ other_ ] :=
    $defaultUserImage;

userImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Notebook Conversion*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutWorkspaceChatNB*)
popOutWorkspaceChatNB // beginDefinition;

popOutWorkspaceChatNB[ cells: { ___Cell } ] := Enclose[
    Module[ { nbo },
        NotebookClose @ findCurrentWorkspaceChat[ ];

        nbo = ConfirmMatch[
            createWorkspaceChat[ EvaluationNotebook[ ], DeleteCases[ cells, CellDingbat -> _, { 2 } ] ],
            _NotebookObject,
            "Notebook"
        ];

        moveToChatInputField @ nbo
    ],
    throwInternalFailure
];

popOutWorkspaceChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutChatNB*)
popOutChatNB // beginDefinition;
popOutChatNB[ nbo_NotebookObject ] := popOutChatNB @ NotebookGet @ nbo;
popOutChatNB[ Notebook[ cells_, ___ ] ] := popOutChatNB @ cells;
popOutChatNB[ Dynamic[ messageList_ ] ] := popOutChatNB @ messageList;
popOutChatNB[ cells: { ___Cell } ] := NotebookPut @ cellsToChatNB @ cells;
popOutChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellsToChatNB*)
cellsToChatNB // beginDefinition;

cellsToChatNB[ cells: { ___Cell } ] :=
    Notebook[ cells /. $fromWorkspaceChatConversionRules, StyleDefinitions -> "Chatbook.nb" ];

cellsToChatNB // endDefinition;


$fromWorkspaceChatConversionRules := $fromWorkspaceChatConversionRules = Dispatch @ {
    Cell[ BoxData @ TemplateBox[ { text_ }, "UserMessageBox", ___ ], "ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
    Cell[
        TextData @ Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ], ___ ],
        "ChatOutput",
        ___
    ] :> Cell[ Flatten @ TextData @ text, "ChatOutput" ]
    ,
    Cell[
        TextData @ { Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ], ___ ] },
        "ChatOutput",
        ___
    ] :> Cell[ Flatten @ TextData @ text, "ChatOutput" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $fromWorkspaceChatConversionRules
];

End[ ];
EndPackage[ ];
