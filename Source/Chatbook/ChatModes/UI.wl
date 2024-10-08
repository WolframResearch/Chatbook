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
$inputFieldGridMagnification = Inherited;
$inputFieldOuterBackground   = GrayLevel[ 0.95 ];
$initialInlineChatWidth      = Scaled[ 1 ];
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

$userImageParams = <| "size" -> 40, "default" -> "404", "rating" -> "G" |>;

$defaultUserImage = Graphics[
    {
        EdgeForm @ None,
        FaceForm @ GrayLevel[ 0.8 ],
        Disk[ { 0, 0.2 }, 2.35 ],
        FaceForm @ White,
        Disk[ { 0, 1 }, 1 ],
        Disk[ { 0, -1.8 }, { 1.65, 2 } ]
    },
    ImageSize -> 20,
    PlotRange -> { { -2.4, 2.4 }, { -2.0, 2.8 } }
];

$messageAuthorImagePadding = { { 0, 0 }, { 0, 6 } };

$inputFieldBox = None;
$inlineChatScrollPosition = 0.0;
$lastScrollPosition       = 0.0;

$maxHistoryItems = 25;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] :=
    DynamicModule[ { nbo },
        Grid @ {
            {
                Tooltip[
                    Button[
                        "New Chat",
                        NotebookDelete @ Cells @ nbo;
                        CurrentChatSettings[ nbo, "ConversationUUID" ] = CreateUUID[ ]
                    ],
                    "Start a new conversation"
                ],
                trackedDynamic[ createHistoryMenu @ nbo, "SavedChats" ],
                Tooltip[
                    Button[
                        "Delete",
                        DeleteChat[
                            CurrentChatSettings[ nbo, "AppName" ],
                            CurrentChatSettings[ nbo, "ConversationUUID" ]
                        ];
                        NotebookDelete @ Cells @ nbo;
                        CurrentChatSettings[ nbo, "ConversationUUID" ] = CreateUUID[ ]
                    ],
                    "Remove the current chat from the history menu"
                ]
                ,
                Item[ "", ItemSize -> Fit ],
                Tooltip[
                    Button[ "Pop Out", popOutChatNB @ nbo, Method -> "Queued" ],
                    "View the chat as a normal chat notebook"
                ]
            }
        },
        Initialization :> (nbo = EvaluationNotebook[ ])
    ];

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
                            RawBoxes @ TemplateBox[
                                { RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ], 27, thisNB },
                                "WorkspaceSendChatButton"
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
    Background    -> $inputFieldOuterBackground,
    Magnification :> AbsoluteCurrentValue[ EvaluationNotebook[ ], Magnification ],
    Selectable    -> True
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachInlineChatInput*)
attachInlineChatInput // beginDefinition;

attachInlineChatInput[ nbo_NotebookObject ] :=
    attachInlineChatInput[ nbo, <| |> ];

attachInlineChatInput[ nbo_NotebookObject, settings_Association ] :=
    If[ TrueQ @ userNotebookQ @ nbo,
        attachInlineChatInput[ nbo, settings, SelectedCells @ nbo ],
        Null
    ];

attachInlineChatInput[ nbo_NotebookObject, settings_Association, { root_CellObject } ] := Enclose[
    Module[ { selectionInfo, attached },

        NotebookDelete @ $lastAttachedInlineChat;
        NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedChatInput" ];

        selectionInfo = ConfirmMatch[
            getSelectionInfo @ root,
            None | KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
            "SelectionInfo"
        ];

        $lastScrollPosition       = 0.0;
        $inlineChatScrollPosition = 0.0;

        (* TODO: Watch the root cell for changes and remove (or disable) the attached chat if cell changed *)
        attached = ConfirmMatch[
            AttachCell[
                NotebookSelection @ nbo,
                inlineChatInputCell[ root, selectionInfo, settings ],
                { "WindowCenter", Bottom },
                0,
                { Center, Top },
                RemovalConditions -> { "EvaluatorQuit" }
            ],
            _CellObject,
            "Attach"
        ];

        SelectionMove[ attached, Before, CellContents ];
        FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ];

        $lastAttachedInlineChat = attached
    ],
    throwInternalFailure
];

(* TODO: moving the selection probably isn't ideal: *)
attachInlineChatInput[ nbo_NotebookObject, settings_, { } ] := Enclose[
    Module[ { root },
        SelectionMove[ nbo, Previous, Cell ];
        root = Replace[ SelectedCells @ nbo, { cell_CellObject } :> cell ];
        If[ MatchQ[ root, _CellObject ],
            attachInlineChatInput[ nbo, settings, { root } ],
            Null
        ]
    ],
    throwInternalFailure
];

(* FIXME: Need to handle multiple cell selections *)
attachInlineChatInput[ nbo_NotebookObject, settings_, { ___ } ] := Null;

attachInlineChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSelectionInfo*)
getSelectionInfo // beginDefinition;

getSelectionInfo[ cell_CellObject ] :=
    getSelectionInfo[ cell, cellInformation[ cell, { "ContentData", "CursorPosition" } ] ];

getSelectionInfo[ cell_, KeyValuePattern[ "CursorPosition" -> Except[ { _Integer, _Integer } ] ] ] :=
    None;

getSelectionInfo[ cell_, info_ ] :=
    getSelectionInfo[ cell, info, cellHash @ cell ];

getSelectionInfo[
    cell_CellObject,
    as: KeyValuePattern[ "CursorPosition" -> { _Integer, _Integer } ],
    hash_String
] := <|
    as,
    "CellObject" -> cell,
    "Hash"       -> hash
|>;

getSelectionInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellHash*)
cellHash // beginDefinition;
cellHash[ cell_CellObject ] := cellHash[ cell, FrontEndExecute @ FrontEnd`CryptoHash @ cell ];
cellHash[ cell_CellObject, KeyValuePattern @ { "DirtiableContentsHash" -> hash_String } ] := hash;
cellHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatInputCell*)
inlineChatInputCell // beginDefinition;

inlineChatInputCell[ root_CellObject, selectionInfo_, settings_ ] := Cell[
    BoxData @ inlineTemplateBox @ TemplateBox[
        {
            ToBoxes @ DynamicModule[ { messageCells = { }, cell },
                Dynamic[
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "DisplayInlineChat",
                        cell,
                        root,
                        selectionInfo,
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
                    attachInlineChatButtons[ EvaluationCell[ ], Dynamic @ messageCells ]
                ),

                Deinitialization :> Quiet[
                    $inputFieldBox = None;
                    Unset @ parentCell @ cell;
                    Unset @ parentNotebook @ cell;
                    ClearAll @ evaluateCurrentInlineChat;
                ]
            ]
        },
        "DropShadowPaneBox"
    ],
    "AttachedChatInput",
    Background    -> None,
    Magnification :> AbsoluteCurrentValue[ EvaluationNotebook[ ], Magnification ],
    Selectable    -> True,
    TaggingRules  -> <| "ChatNotebookSettings" -> settings |>
];

inlineChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachInlineChatButtons*)
attachInlineChatButtons // beginDefinition;

attachInlineChatButtons[ cell_CellObject, messageCells_Dynamic ] := AttachCell[
    cell,
    inlineChatButtonsCell[ cell, messageCells ],
    { Right, Top },
    Offset[ { -57, -7 }, 0 ],
    { Left, Top }
];

attachInlineChatButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineChatButtonsCell*)
inlineChatButtonsCell // beginDefinition;

(* TODO: define a template box for this in the stylesheet *)
inlineChatButtonsCell[ cell_CellObject, messageCells_Dynamic ] :=
    Cell @ BoxData @ GridBox[
        { { closeButton @ cell }, { popOutButton[ cell, messageCells ] } },
        AutoDelete      -> False,
        GridBoxItemSize -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } },
        GridBoxSpacings -> { "Columns" -> { { 0 } }, "Rows" -> { { 0 } } }
    ];

inlineChatButtonsCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*closeButton*)
closeButton // beginDefinition;

closeButton[ cell_CellObject ] := ToBoxes @ Button[
    RawBoxes @ FrameBox[
        GraphicsBox[
            {
                GrayLevel[ 0.3 ],
                AbsoluteThickness[ 1 ],
                CapForm[ "Round" ],
                LineBox @ { { { -1, -1 }, { 1, 1 } }, { { 1, -1 }, { -1, 1 } } }
            },
            ImagePadding -> { { 0, 1 }, { 1, 0 } },
            ImageSize    -> { 6, 6 },
            PlotRange    -> 1
        ],
        Alignment      -> { Center, Center },
        Background     -> GrayLevel[ 0.96 ],
        ContentPadding -> False,
        FrameMargins   -> None,
        FrameStyle     -> GrayLevel[ 0.85 ],
        ImageSize      -> { 16, 16 },
        RoundingRadius -> 2,
        StripOnInput   -> False
    ],
    NotebookDelete @ cell,
    Appearance -> "Suppressed",
    Tooltip    -> "Close"
];

closeButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*popOutButton*)
popOutButton // beginDefinition;

popOutButton[ cell_CellObject, messageCells_Dynamic ] := ToBoxes @ Button[
    RawBoxes @ FrameBox[
        GraphicsBox[
            {
                GrayLevel[ 0.3 ],
                AbsoluteThickness[ 1 ],
                CapForm[ "Round" ],
                LineBox @ {
                    { { -0.4, 0.8 }, { -0.8, 0.8 }, { -0.8, -0.8 }, { 0.8, -0.8 }, { 0.8, -0.4 } },
                    { { -0.1, -0.1 }, { 1, 1 } },
                    { { 0.2, 1 }, { 1, 1 }, { 1, 0.2 } }
                }
            },
            ImagePadding -> { { 0, 1 }, { 1, 0 } },
            ImageSize    -> { 10, 10 },
            PlotRange    -> 1
        ],
        Alignment      -> { Center, Center },
        Background     -> GrayLevel[ 0.96 ],
        ContentPadding -> False,
        FrameMargins   -> None,
        FrameStyle     -> GrayLevel[ 0.85 ],
        ImageSize      -> { 16, 16 },
        RoundingRadius -> 2,
        StripOnInput   -> False
    ],
    NotebookDelete @ cell;
    popOutWorkspaceChatNB @ messageCells,
    Appearance -> "Suppressed",
    Tooltip    -> "View in Code Assistance Chat"
];

popOutButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*displayInlineChat*)
displayInlineChat // beginDefinition;

displayInlineChat[ cell_CellObject, root_CellObject, selectionInfo_, Dynamic[ messageCells_Symbol ] ] :=
    Module[ { inputField },

        inputField = inlineChatInputField[
            cell,
            root,
            selectionInfo,
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

inlineChatInputField[
    cell_CellObject,
    root_CellObject,
    selectionInfo_,
    Dynamic[ currentInput_ ],
    Dynamic[ messageCells_ ]
] := (
    evaluateCurrentInlineChat[ ] := ChatbookAction[
        "EvaluateInlineChat",
        cell,
        root,
        selectionInfo,
        Dynamic @ currentInput,
        Dynamic @ messageCells
    ];
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
                        RawBoxes @ inlineTemplateBox @ TemplateBox[
                            { RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ], 27 },
                            "SendChatButton"
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
                    selectionInfo,
                    Dynamic @ currentInput,
                    Dynamic @ messageCells
                ]
            )
        },
        Method -> "Queued"
    ]
);

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

moveToInlineChatInputField[ None ] := Null;

moveToInlineChatInputField // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayInlineChatMessages*)
displayInlineChatMessages // beginDefinition;

displayInlineChatMessages[ { }, inputField_ ] :=
    Pane[ inputField, ImageSize -> { $initialInlineChatWidth, Automatic } ];

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
                        BaseStyle  -> { Magnification -> 0.8 * Inherited },
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
                    RawBoxes @ InputFieldBox[
                        Append[ DeleteCases[ cell, Background -> _ ], Background -> None ],
                        Appearance -> None,
                        ImageSize  -> { Scaled[ 1 ], Automatic }
                    ]
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
(*Chat Message Decorations*)

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
        hash  = Hash[ ToLowerCase @ StringTrim @ user, "MD5", "HexString" ];
        url   = ConfirmBy[ URLBuild[ { "https://www.gravatar.com/avatar/", hash }, $userImageParams ], StringQ, "URL" ];
        image = ConfirmBy[ Quiet @ Import @ url, ImageQ, "Image" ];
        userImage[ user ] = Show[ image, ImageSize -> 20 ]
    ],
    (userImage[ user ] = $defaultUserImage) &
];

userImage[ other_ ] :=
    $defaultUserImage;

userImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachAssistantMessageButtons*)
attachAssistantMessageButtons // beginDefinition;

attachAssistantMessageButtons[ cell_ ] /; $dynamicText || MatchQ[ $ChatEvaluationCell, _CellObject ] := Null;

attachAssistantMessageButtons[ cell_CellObject ] :=
    attachAssistantMessageButtons[ cell, CurrentChatSettings[ cell, "WorkspaceChat" ] ];

attachAssistantMessageButtons[ cell0_CellObject, True ] := Enclose[
    Catch @ Module[ { cell, attached },

        cell = topParentCell @ cell0;
        If[ ! MatchQ[ cell, _CellObject ], Throw @ Null ];

        (* If chat has been reloaded from history, it no longer has the necessary metadata for feedback: *)
        If[ ! StringQ @ CurrentValue[ cell, { TaggingRules, "ChatData" } ], Throw @ Null ];

        (* Remove existing attached cell, if any: *)
        NotebookDelete @ Cells[ cell, AttachedCell -> True, CellStyle -> "ChatOutputTrayButtons" ];

        (* Attach new cell: *)
        attached = AttachCell[
            cell,
            Cell[
                BoxData @ TemplateBox[ { }, "FeedbackButtonsHorizontal" ],
                "ChatOutputTrayButtons",
                Magnification -> AbsoluteCurrentValue[ cell, Magnification ]
            ],
            { Left, Bottom },
            0,
            { Left, Top },
            RemovalConditions -> "MouseExit"
        ]
    ],
    throwInternalFailure
];

attachAssistantMessageButtons[ cell_CellObject, _ ] :=
    Null;

attachAssistantMessageButtons // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Notebook Conversion*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutWorkspaceChatNB*)
popOutWorkspaceChatNB // beginDefinition;

popOutWorkspaceChatNB[ Dynamic[ cells_ ] ] :=
    popOutWorkspaceChatNB @ cells;

popOutWorkspaceChatNB[ cells0: { ___Cell } ] := Enclose[
    Module[ { cells, settings, nbo },
        NotebookClose @ findCurrentWorkspaceChat[ ];

        cells = cells0 //. $inlineToWorkspaceConversionRules;

        nbo = ConfirmMatch[
            createWorkspaceChat[ EvaluationNotebook[ ], cells ],
            _NotebookObject,
            "Notebook"
        ];

        moveToChatInputField @ nbo;

        settings = ConfirmBy[ AbsoluteCurrentChatSettings @ nbo, AssociationQ, "Settings" ];
        If[ TrueQ @ settings[ "AutoSaveConversations" ], SaveChat[ nbo, settings ] ];

        nbo
    ],
    throwInternalFailure
];

popOutWorkspaceChatNB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$inlineToWorkspaceConversionRules*)
$inlineToWorkspaceConversionRules := $inlineToWorkspaceConversionRules = Dispatch @ {
    Cell[ BoxData @ TemplateBox[ { Cell[ text_ ] }, "UserMessageBox", __ ], "ChatInput", ___ ] :>
        Cell[
            BoxData @ TemplateBox[
                { Cell[ Flatten @ TextData @ text, Background -> None, Selectable -> True, Editable -> True ] },
                "UserMessageBox"
            ],
            "ChatInput"
        ]
    ,
    Cell[
        TextData @ { Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ], ___ ] },
        "ChatOutput",
        ___,
        TaggingRules -> tags_,
        ___
    ] :>
        Cell[
            TextData @ Cell[
                BoxData @ TemplateBox[
                    { Cell[ Flatten @ TextData @ text, Background -> None, Editable -> True, Selectable -> True ] },
                    "AssistantMessageBox"
                ],
                Background -> None
            ],
            "ChatOutput",
            TaggingRules      -> tags,
            GeneratedCell     -> True,
            CellAutoOverwrite -> True
        ]
};

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
    Cell[ BoxData @ TemplateBox[ { Cell[ TextData[ text_ ], ___ ] }, "UserMessageBox", ___ ], "ChatInput", ___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput" ]
    ,
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
(*History*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*createHistoryMenu*)
createHistoryMenu // beginDefinition;

createHistoryMenu[ nbo_NotebookObject ] :=
    createHistoryMenu[ nbo, ListSavedChats @ CurrentChatSettings[ nbo, "AppName" ] ];

createHistoryMenu[ nbo_NotebookObject ] := Enclose[
    Catch @ Module[ { appName, chats },
        appName = ConfirmBy[ CurrentChatSettings[ nbo, "AppName" ], StringQ, "AppName" ];
        chats = ConfirmMatch[ ListSavedChats @ appName, { ___Association }, "Chats" ];
        If[ chats === { }, Throw @ ActionMenu[ "History", { "Nothing here yet" :> Null } ] ];
        ActionMenu[
            "History",
            makeHistoryMenuItem[ nbo ] /@ Take[ chats, UpTo @ $maxHistoryItems ],
            Method -> "Queued"
        ]
    ],
    throwInternalFailure
];

createHistoryMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistoryMenuItem*)
makeHistoryMenuItem // beginDefinition;

makeHistoryMenuItem[ nbo_NotebookObject ] :=
    makeHistoryMenuItem[ nbo, # ] &;

makeHistoryMenuItem[ nbo_NotebookObject, chat_Association ] := Enclose[
    Module[ { title, date, timeString, label },
        title = ConfirmBy[ chat[ "ConversationTitle" ], StringQ, "Title" ];
        date = DateObject[ ConfirmBy[ chat[ "Date" ], NumericQ, "Date" ], TimeZone -> 0 ];
        timeString = ConfirmBy[ relativeTimeString @ date, StringQ, "TimeString" ];
        label = Row @ { title, " ", Style[ timeString, FontOpacity -> 0.75, FontSize -> Inherited * 0.9 ] };
        label :> loadConversation[ nbo, chat ]
    ],
    throwInternalFailure
];

makeHistoryMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadConversation*)
loadConversation // beginDefinition;

loadConversation[ nbo_NotebookObject, id_ ] := Enclose[
    Module[ { loaded, uuid, messages, cells, cellObjects },
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell[ messages, "Workspace" ], { __Cell }, "Cells" ];
        cellObjects = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "CellObjects" ];
        ConfirmMatch[ NotebookDelete @ cellObjects, { Null... }, "Delete" ];

        WithCleanup[
            NotebookDelete @ First[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], $Failed ],
            SelectionMove[ nbo, Before, Notebook, AutoScroll -> True ];
            ConfirmMatch[
                NotebookWrite[ nbo, cells, AutoScroll -> False ],
                Null,
                "Write"
            ],
            ChatbookAction[ "AttachWorkspaceChatInput", nbo ]
        ];

        CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid;
        moveToChatInputField[ nbo, True ]
    ],
    throwInternalFailure
];

loadConversation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $fromWorkspaceChatConversionRules;
    $inlineToWorkspaceConversionRules;
];

End[ ];
EndPackage[ ];
