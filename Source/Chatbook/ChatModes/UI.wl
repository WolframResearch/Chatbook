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
$initialInlineChatWidth      = Scaled[ 0.85 ];
$initialInlineChatHeight     = UpTo[ 300 ];
$inputFieldBox               = None;
$inlineChatScrollPosition    = 0.0;
$lastScrollPosition          = 0.0;
$maxHistoryItems             = 25;
$messageAuthorImagePadding   = { { 0, 0 }, { 0, 6 } };

$toolbarLabelStyle = "WorkspaceChatToolbarButtonLabel";

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

$useGravatarImages := useGravatarImagesQ[ ];

$userImageParams = <| "size" -> 40, "default" -> "404", "rating" -> "G" |>;

$defaultUserImage := $defaultUserImage =
    inlineTemplateBoxes @ RawBoxes @ TemplateBox[ { }, "WorkspaceDefaultUserIcon" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWorkspaceChatDockedCell*)
makeWorkspaceChatDockedCell // beginDefinition;

makeWorkspaceChatDockedCell[ ] := Framed[
    DynamicModule[ { nbo },
        Grid[
            { {
                LogChatTiming @ historyButton @ Dynamic @ nbo,
                Item[ Spacer[ 0 ], ItemSize -> Fit ],
                LogChatTiming @ sourcesButton @ Dynamic @ nbo,
                LogChatTiming @ newChatButton @ Dynamic @ nbo
            } },
            Alignment -> { Automatic, Center },
            Spacings  -> 0.5
        ],
        Initialization :> (nbo = EvaluationNotebook[ ])
    ],
    Background   -> RGBColor[ "#66ADD2" ],
    FrameStyle   -> RGBColor[ "#A3C9F2" ],
    FrameMargins -> { { 2, 8 }, { 0, 0 } },
    ImageMargins -> 0
];

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyButton*)
historyButton // beginDefinition;

historyButton[ Dynamic[ nbo_ ] ] :=
    Module[ { label },

        label = Pane[
            Style[
                Dynamic @ FEPrivate`If[
                    CurrentValue[ nbo, { WindowSize, 1 } ] > 250,
                    FEPrivate`TruncateStringToWidth[
                        CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ],
                        "WorkspaceChatToolbarTitle",
                        CurrentValue[ nbo, { WindowSize, 1 } ] - 170,
                        Right
                    ],
                    ""
                ],
                "WorkspaceChatToolbarTitle"
            ]
        ];

        Button[
            toolbarButtonLabel[ "History", label, "History" ],
            toggleOverlayMenu[ nbo, "History" ],
            Appearance -> "Suppressed"
        ]
    ];

historyButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sourcesButton*)
sourcesButton // beginDefinition;

sourcesButton[ Dynamic[ nbo_ ] ] := Button[
    toolbarButtonLabel[ "Sources" ],
    toggleOverlayMenu[ nbo, "Sources" ],
    Appearance -> "Suppressed"
];

sourcesButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*newChatButton*)
newChatButton // beginDefinition;

newChatButton[ Dynamic[ nbo_ ] ] := Button[
    toolbarButtonLabel[ "New" ],
    clearOverlayMenus @ nbo;
    NotebookDelete @ Cells @ nbo;
    CurrentChatSettings[ nbo, "ConversationUUID" ] = CreateUUID[ ];
    CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] = "";
    moveChatInputToTop @ nbo;
    ,
    Appearance -> "Suppressed"
];

newChatButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolbarButtonLabel*)
toolbarButtonLabel // beginDefinition;

toolbarButtonLabel[ name_String, opts: OptionsPattern[ ] ] :=
    toolbarButtonLabel[ name, name, opts ];

toolbarButtonLabel[ iconName_String, label_, opts: OptionsPattern[ ] ] :=
    toolbarButtonLabel[ iconName, label, iconName, opts ];

toolbarButtonLabel[ iconName_String, label_, tooltipName: _String | None, opts: OptionsPattern[ ] ] :=
    toolbarButtonLabel[ iconName, label, tooltipName, opts ] =
    With[ { lbl = toolbarButtonLabel0[ iconName, label ] },
        buttonTooltip[
            NotebookTools`Mousedown[
                Framed[ lbl, opts, $toolbarButtonCommon, $toolbarButtonDefault ],
                Framed[ lbl, opts, $toolbarButtonCommon, $toolbarButtonHover   ],
                Framed[ lbl, opts, $toolbarButtonCommon, $toolbarButtonActive  ]
            ],
            tooltipName
        ]
    ];

toolbarButtonLabel // endDefinition;


toolbarButtonLabel0 // beginDefinition;

toolbarButtonLabel0[ iconName_String, labelName_String ] :=
    toolbarButtonLabel0[ iconName, tr[ "WorkspaceToolbarButtonLabel"<>labelName ] ];

toolbarButtonLabel0[ iconName_String, None ] :=
    Grid[
        { { RawBoxes @ TemplateBox[ { }, "WorkspaceToolbarIcon"<>iconName ] } },
        Spacings  -> 0.5,
        Alignment -> { Automatic, Center }
    ];

toolbarButtonLabel0[ iconName_String, label_ ] :=
    Grid[
        { {
            RawBoxes @ TemplateBox[ { }, "WorkspaceToolbarIcon"<>iconName ],
            Style[ label, $toolbarLabelStyle ]
        } },
        Spacings  -> 0.5,
        Alignment -> { Automatic, Center }
    ];

toolbarButtonLabel0 // endDefinition;

$toolbarButtonCommon = Sequence[
    FrameMargins   -> { { 1, 3 }, { 1, 1 } },
    ImageSize      -> { Automatic, 22 },
    RoundingRadius -> 3
];

$toolbarButtonDefault = Sequence[ Background -> RGBColor[ "#66ADD2" ], FrameStyle -> RGBColor[ "#66ADD2" ] ];
$toolbarButtonHover   = Sequence[ Background -> RGBColor[ "#87C3E3" ], FrameStyle -> RGBColor[ "#9ACAE4" ] ];
$toolbarButtonActive  = Sequence[ Background -> RGBColor[ "#3689B5" ], FrameStyle -> RGBColor[ "#3689B5" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*buttonTooltip*)
buttonTooltip // beginDefinition;
buttonTooltip[ label_, None ] := label;
buttonTooltip[ label_, name_String ] := Tooltip[ label, tr[ "WorkspaceToolbarButtonTooltip"<>name ] ];
buttonTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachWorkspaceChatInput*)
attachWorkspaceChatInput // beginDefinition;

attachWorkspaceChatInput[ nbo_NotebookObject ] := attachWorkspaceChatInput[ nbo, Bottom ]

attachWorkspaceChatInput[ nbo_NotebookObject, location : Top|Bottom ] := Enclose[
    Module[ { attached },
        attached = ConfirmMatch[
            AttachCell[
                nbo,
                attachedWorkspaceChatInputCell[ If[ location === Top, "Top", "Bottom" ] ],
                location,
                0,
                location
            ],
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
(*attachedWorkspaceChatInputCell*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)
attachedWorkspaceChatInputCell[ location_String ] := Cell[
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
                            workspaceChatInitializer @ RawBoxes @ TemplateBox[
                                { RGBColor[ "#a3c9f2" ], RGBColor[ "#f1f7fd" ], 27, thisNB },
                                "WorkspaceSendChatButton"
                            ]
                        }
                    },
                    BaseStyle -> { Magnification -> $inputFieldGridMagnification }
                ],
                FrameMargins -> $inputFieldPaneMargins,
                ImageSize ->
                    If[ location === "Top",
                        Dynamic @ {
                            Automatic,
                            AbsoluteCurrentValue[ thisNB, { WindowSize, 2 } ] /
                                AbsoluteCurrentValue[ thisNB, Magnification ]
                        },
                        Automatic
                    ]
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
    CellTags      -> location,
    Magnification :> AbsoluteCurrentValue[ EvaluationNotebook[ ], Magnification ],
    Selectable    -> True
];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*workspaceChatInitializer*)
workspaceChatInitializer // beginDefinition;

workspaceChatInitializer[ expr_ ] :=
    DynamicWrapper[
        expr,
        initializeWorkspaceChat[ ],
        SingleEvaluation    -> True,
        SynchronousUpdating -> False
    ];

workspaceChatInitializer // endDefinition;

$workspaceChatInitialized = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*initializeWorkspaceChat*)
initializeWorkspaceChat // beginDefinition;

initializeWorkspaceChat[ ] := initializeWorkspaceChat[ ] = LogChatTiming[
    LogChatTiming[ getEmbeddings[ { "Hello" } ], "InitializeEmbeddings" ];
    LogChatTiming[ cachedTokenizer[ "gpt-4o-text" ], "InitializeTokenizer" ];
    LogChatTiming[ $llmKitService, "InitializeLLMKitService" ];
    $workspaceChatInitialized = True,
    "InitializeWorkspaceChat"
];

initializeWorkspaceChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Moving input field between bottom/top of window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveChatInputToTop*)
moveChatInputToTop // beginDefinition;

moveChatInputToTop[ nbo_NotebookObject ] :=
    Catch @ Module[ { attached },
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> "Bottom" ];
        If[ attached === { }, Throw @ Null ];
        NotebookDelete @ attached;
        ChatbookAction[ "AttachWorkspaceChatInput", nbo, Top ]
    ];

moveChatInputToTop // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*moveChatInputToBottom*)
moveChatInputToBottom // beginDefinition;

moveChatInputToBottom[ nbo_NotebookObject ] :=
    Catch @ Module[ { attached },
        attached = Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> "Top" ];
        If[ attached === { }, Throw @ Null ];
        NotebookDelete @ attached;
        ChatbookAction[ "AttachWorkspaceChatInput", nbo, Bottom ]
    ];

moveChatInputToBottom // endDefinition;

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
                    ClearAll @ evaluateAttachedInlineChat;
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
    evaluateAttachedInlineChat[ ] := ChatbookAction[
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
                BaseStyle -> { Magnification -> $inputFieldGridMagnification*0.8 }
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

assistantMessageLabel[ ] := Enclose[
    Catch @ Module[ { cell, persona, icon, name },
        cell = topParentCell @ EvaluationCell[ ];
        persona = If[ MatchQ[ cell, _CellObject ], CurrentChatSettings[ cell, "LLMEvaluator" ], "NotebookAssistant" ];
        icon = ConfirmMatch[ getPersonaMenuIcon @ persona, Except[ _getPersonaMenuIcon | _? FailureQ ], "Icon" ];
        name = ConfirmMatch[ personaDisplayName @ persona, Except[ _personaDisplayName | _? FailureQ ], "Name" ];
        Grid[ { { icon, name } }, Alignment -> { Automatic, Center } ]
    ],
    throwInternalFailure
];

assistantMessageLabel // endDefinition;

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

userName[ ] := FirstCase[
    Unevaluated @ { $CloudAccountName, CurrentValue[ "WolframCloudFullUserName" ], $Username },
    expr_ :> With[ { user = expr }, user /; StringQ @ user ],
    "You"
];

userName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*userImage*)
userImage // beginDefinition;

userImage[ ] :=
    If[ TrueQ @ $useGravatarImages,
        userImage @ FirstCase[
            Unevaluated @ { $CloudUserID, CurrentValue[ "WolframCloudUserName" ] },
            expr_ :> With[ { user = expr }, user /; StringQ @ user ]
        ],
        $defaultUserImage
    ];

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
(* ::Subsubsection::Closed:: *)
(*useGravatarImagesQ*)
useGravatarImagesQ // beginDefinition;
useGravatarImagesQ[ ] := useGravatarImagesQ[ ] = TrueQ @ CurrentChatSettings[ $FrontEnd, "UseGravatarImages" ];
useGravatarImagesQ // endDefinition;

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
popOutChatNB[ chat_Association ] := popOutChatNB0 @ chat;
popOutChatNB // endDefinition;


popOutChatNB0 // beginDefinition;

popOutChatNB0[ id_ ] := Enclose[
    Module[ { loaded, uuid, title, messages, cells },
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell @ messages, { __Cell }, "Cells" ];
        ConfirmMatch[ CreateChatNotebook @ cells, _NotebookObject, "Notebook" ]
    ],
    throwInternalFailure
];

popOutChatNB0 // endDefinition;

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
(*Overlay Menus*)
$notebookIcon = RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][
    GrayLevel[ 0.651 ],
    RGBColor[ 0.86667, 0.066667, 0. ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*clearOverlayMenus*)
clearOverlayMenus // beginDefinition;

clearOverlayMenus[ nbo_NotebookObject ] := (
    restoreVerticalScrollbar @ nbo;
    NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ]
);

clearOverlayMenus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toggleOverlayMenu*)
toggleOverlayMenu // beginDefinition;

toggleOverlayMenu[ nbo_NotebookObject, name_String ] :=
    Module[ { cell },
        cell = First[
            Cells[ nbo, AttachedCell -> True, CellStyle -> "AttachedOverlayMenu", CellTags -> name ],
            Missing[ "NotAttached" ]
        ];

        If[ MissingQ @ cell,
            attachOverlayMenu[ nbo, name ],
            restoreVerticalScrollbar @ nbo;
            NotebookDelete @ cell
        ]
    ];

toggleOverlayMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*overlayMenu*)
overlayMenu // beginDefinition;
overlayMenu[ nbo_, "Sources" ] := sourcesOverlay @ nbo;
overlayMenu[ nbo_, "History" ] := historyOverlay @ nbo;
overlayMenu[ nbo_, "Loading" ] := loadingOverlay @ nbo;
overlayMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachOverlayMenu*)
attachOverlayMenu // beginDefinition;

attachOverlayMenu[ nbo_NotebookObject, name_String ] := Enclose[
    hideVerticalScrollbar @ nbo;
    NotebookDelete @ Cells[ nbo, CellStyle -> "AttachedOverlayMenu", AttachedCell -> True ];
    AttachCell[
        nbo,
        Cell[
            BoxData @ ToBoxes @ Framed[
                ConfirmMatch[ overlayMenu[ nbo, name ], Except[ _overlayMenu ], "OverlayMenu" ],
                Alignment    -> { Center, Top },
                Background   -> White,
                FrameMargins -> { { 5, 5 }, { 2000, 5 } },
                FrameStyle   -> White,
                ImageSize    -> { Scaled[ 1 ], Automatic }
            ],
            "AttachedOverlayMenu",
            CellTags -> name,
            Magnification -> Dynamic @ AbsoluteCurrentValue[ nbo, Magnification ]
        ],
        { Center, Top },
        0,
        { Center, Top }
    ],
    throwInternalFailure
];

attachOverlayMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withLoadingOverlay*)
withLoadingOverlay // beginDefinition;

withLoadingOverlay // Attributes = { HoldRest };

withLoadingOverlay[ nbo_NotebookObject ] :=
    Function[ eval, withLoadingOverlay[ nbo, eval ], HoldFirst ];

withLoadingOverlay[ nbo_NotebookObject, eval_ ] :=
    Module[ { attached },
        WithCleanup[
            attached = attachOverlayMenu[ nbo, "Loading" ],
            eval,
            NotebookDelete @ attached
        ]
    ];

withLoadingOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*loadingOverlay*)
loadingOverlay // beginDefinition;

loadingOverlay[ _NotebookObject ] := Pane[
    ProgressIndicator[ Appearance -> "Necklace" ],
    ImageMargins -> 50
];

loadingOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*restoreVerticalScrollbar*)
restoreVerticalScrollbar // beginDefinition;
restoreVerticalScrollbar[ nbo_NotebookObject ] := CurrentValue[ nbo, WindowElements ] = Inherited;
restoreVerticalScrollbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*hideVerticalScrollbar*)
hideVerticalScrollbar // beginDefinition;

hideVerticalScrollbar[ nbo_NotebookObject ] := CurrentValue[ nbo, WindowElements ] =
    DeleteCases[ AbsoluteCurrentValue[ nbo, WindowElements ], "VerticalScrollBar" ];

hideVerticalScrollbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sourcesOverlay*)
sourcesOverlay // beginDefinition;
sourcesOverlay[ nbo_NotebookObject ] := notebookSources[ ]; (* TODO: combined menu that includes files etc. *)
sourcesOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*notebookSources*)
notebookSources // beginDefinition;

(* FIXME: the sources overlay ends up too thin if there are no notebooks open *)
notebookSources[ ] := Framed[
    Column[
        {
            Pane[
                Style[
                    tr[ "WorkspaceSourcesOpenNotebooks" ],
                    "Text",
                    FontSize   -> 14,
                    FontColor  -> RGBColor[ "#333333" ],
                    FontWeight -> Bold
                ],
                FrameMargins -> { { 5, 5 }, { 3, 3 } }
            ],
            Pane[
                Dynamic @ Grid[
                    Cases[
                        SortBy[ SourceNotebookObjectInformation[ ], #[ "WindowTitle" ] & ],
                        KeyValuePattern @ { "NotebookObject" -> nbo_NotebookObject, "WindowTitle" -> title_ } :> {
                            Spacer[ 3 ],
                            inclusionCheckbox @ nbo,
                            Item[
                                Button[
                                    MouseAppearance[
                                        Grid[
                                            { { $notebookIcon, formatNotebookTitle @ title } },
                                            Alignment -> { Left, Baseline }
                                        ],
                                        "LinkHand"
                                    ],
                                    ToggleChatInclusion @ nbo,
                                    Alignment  -> Left,
                                    Appearance -> "Suppressed",
                                    BaseStyle  -> { "Text", FontSize -> 14, LineBreakWithin -> False }
                                ],
                                ItemSize -> Fit
                            ],
                            Button[
                                MouseAppearance[
                                    Mouseover[
                                        Style[ "   \[RightGuillemet]   ", FontColor -> GrayLevel[ 0.6 ] ],
                                        Style[ "   \[RightGuillemet]   ", FontColor -> GrayLevel[ 0.2 ] ]
                                    ],
                                    "LinkHand"
                                ],
                                SetSelectedNotebook @ nbo,
                                Alignment  -> Right,
                                Appearance -> "Suppressed",
                                BaseStyle  -> { "Text", FontSize -> 16 }
                            ]
                        }
                    ],
                    Alignment -> { Left, Center },
                    Dividers  -> { False, { False, { RGBColor[ "#D1D1D1" ] }, False } },
                    Spacings  -> { Automatic, { 0, { 1 }, 0 } }
                ],
                FrameMargins -> { { 0, 0 }, { 5, 5 } }
            ]
        },
        Alignment -> Left,
        Background -> { RGBColor[ "#F5F5F5" ], White },
        Dividers -> { None, { 2 -> RGBColor[ "#D1D1D1" ] } }
    ],
    RoundingRadius -> 3,
    FrameMargins   -> 0,
    FrameStyle     -> RGBColor[ "#D1D1D1" ]
];

notebookSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNotebookTitle*)
formatNotebookTitle // beginDefinition;
formatNotebookTitle[ title_String ] := title;
formatNotebookTitle[ None ] := Style[ "Unnamed Notebook", FontColor -> GrayLevel[ 0.6 ], FontSlant -> Italic ];
formatNotebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inclusionCheckbox*)
inclusionCheckbox // beginDefinition;

inclusionCheckbox[ nbo_NotebookObject ] :=
    Checkbox @ Dynamic[
        ! TrueQ @ CurrentChatSettings[ nbo, "ExcludeFromChat" ],
        ToggleChatInclusion[ nbo, #1 ] &
    ];

inclusionCheckbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*History*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyOverlay*)
historyOverlay // beginDefinition;

historyOverlay[ nbo_NotebookObject ] :=
    DynamicModule[ { searching = False },
        PaneSelector[
            {
                True  -> historySearchView[ nbo, Dynamic @ searching ],
                False -> historyDefaultView[ nbo, Dynamic @ searching ]
            },
            Dynamic @ searching,
            ImageSize -> Automatic
        ]
    ];

historyOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historyDefaultView*)
historyDefaultView // beginDefinition;

historyDefaultView[ nbo_NotebookObject, Dynamic[ searching_ ] ] := Enclose[
    Catch @ Module[ { header, view },
        header = ConfirmMatch[ makeHistoryHeader @ historySearchButton @ Dynamic @ searching, _Pane, "Header" ];
        view = ConfirmMatch[ makeDefaultHistoryView @ nbo, _RawBoxes, "View" ];

        Framed[
            Column[
                { header, view },
                Alignment  -> Left,
                Background -> { RGBColor[ "#F5F5F5" ], White },
                Dividers   -> { None, { 2 -> RGBColor[ "#D1D1D1" ] } }
            ],
            RoundingRadius -> 3,
            FrameMargins   -> 0,
            FrameStyle     -> RGBColor[ "#D1D1D1" ]
        ]
    ],
    throwInternalFailure
];

historyDefaultView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDefaultHistoryView*)
makeDefaultHistoryView // beginDefinition;

makeDefaultHistoryView[ nbo_NotebookObject ] := Enclose[
    RawBoxes @ ToBoxes @ DynamicModule[ { display },
        display = Pane[ ProgressIndicator[ Appearance -> "Percolate" ], ImageMargins -> 25 ];

        Pane[
            Dynamic[ display, TrackedSymbols :> { display } ],
            Alignment          -> { Center, Top },
            AppearanceElements -> { },
            FrameMargins       -> { { 0, 0 }, { 5, 5 } },
            ImageSize          -> Dynamic @ { Scaled[ 1 ], AbsoluteCurrentValue[ nbo, { WindowSize, 2 } ] },
            Scrollbars         -> Automatic
        ],

        Initialization            :> (display = catchAlways @ makeDefaultHistoryView0 @ nbo),
        SynchronousInitialization -> False
    ],
    throwInternalFailure
];

makeDefaultHistoryView // endDefinition;


makeDefaultHistoryView0 // beginDefinition;

makeDefaultHistoryView0[ nbo_NotebookObject ] := Enclose[
    DynamicModule[ { appName, chats, rows },
        appName = ConfirmBy[ CurrentChatSettings[ nbo, "AppName" ], StringQ, "AppName" ];
        chats = ConfirmMatch[ ListSavedChats @ appName, { ___Association }, "Chats" ];
        rows = makeHistoryMenuItem[ Dynamic @ rows, nbo ] /@ chats;
        Dynamic[
            Grid[
                rows,
                Alignment -> { Left, Center },
                Dividers  -> { False, { False, { RGBColor[ "#D1D1D1" ] }, False } },
                Spacings  -> { Automatic, { 0, { 1 }, 0 } }
            ],
            TrackedSymbols :> { rows }
        ]
    ],
    throwInternalFailure
];

makeDefaultHistoryView0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistoryHeader*)
makeHistoryHeader // beginDefinition;

makeHistoryHeader[ extraContent_ ] := Pane[
    Grid[
        {
            {
                (* FIXME: move "History" to text resources *)
                Style[ "History", "Text", FontSize -> 14, FontColor -> RGBColor[ "#333333" ], FontWeight -> Bold ],
                extraContent
            }
        },
        Alignment -> { { Left, Right }, Baseline },
        ItemSize  -> Fit
    ],
    FrameMargins -> { { 5, 5 }, { 3, 3 } }
];

makeHistoryHeader // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*historySearchButton*)
historySearchButton // beginDefinition;

historySearchButton[ Dynamic[ searching_ ] ] :=
    PaneSelector[
        {
            False -> searchButton @ Dynamic @ searching,
            True -> searchField @ Dynamic @ searching
        },
        Dynamic @ searching,
        ImageSize -> Automatic
    ];

historySearchButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*searchButton*)
searchButton // beginDefinition;
searchButton[ Dynamic[ searching_ ] ] := Button[ $searchButtonLabel, searching = True, Appearance -> "Suppressed" ];
searchButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeHistoryMenuItem*)
makeHistoryMenuItem // beginDefinition;

makeHistoryMenuItem[ rows_Dynamic, nbo_NotebookObject ] :=
    makeHistoryMenuItem[ rows, nbo, # ] &;

makeHistoryMenuItem[ Dynamic[ rows_ ], nbo_NotebookObject, chat_Association ] := Enclose[
    Module[ { title, date, timeString, default, hover },
        title = ConfirmBy[ chat[ "ConversationTitle" ], StringQ, "Title" ];
        date = DateObject[ ConfirmBy[ chat[ "Date" ], NumericQ, "Date" ], TimeZone -> 0 ];
        timeString = ConfirmBy[ relativeTimeString @ date, StringQ, "TimeString" ];

        default = Grid[
            { {
                title,
                Style[ timeString, FontColor -> RGBColor[ "#A6A6A6" ] ]
            } },
            Alignment -> { { Left, Right }, Baseline },
            BaseStyle -> { "Text", FontSize -> 14, LineBreakWithin -> False },
            ItemSize  -> Fit
        ];

        hover = Grid[
            { {
                Button[
                    title,
                    loadConversation[ nbo, chat ],
                    Alignment  -> Left,
                    Appearance -> "Suppressed",
                    BaseStyle  -> { "Text", FontSize -> 14, LineBreakWithin -> False },
                    Method     -> "Queued"
                ],
                Grid[
                    { {
                        Button[
                            $popOutButtonLabel,
                            popOutChatNB @ chat,
                            Appearance -> "Suppressed"
                        ],
                        Button[
                            $trashButtonLabel,
                            DeleteChat @ chat;
                            removeChatFromRows[ Dynamic @ rows, chat ],
                            Appearance -> "Suppressed"
                        ]
                    } }
                ]
            } },
            Alignment  -> { { Left, Right }, Baseline },
            Background -> RGBColor[ "#EDF7FC" ],
            ItemSize   -> Fit
        ];

        {
            Style[ Spacer[ 3 ], TaggingRules -> <| "ConversationUUID" -> chat[ "ConversationUUID" ] |> ],
            Mouseover[ default, hover ],
            Spacer[ 3 ]
        }
    ],
    throwInternalFailure
];

makeHistoryMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*removeChatFromRows*)
removeChatFromRows // beginDefinition;

removeChatFromRows[ Dynamic[ rows_ ], KeyValuePattern[ "ConversationUUID" -> uuid_String ] ] :=
    rows = DeleteCases[
        rows,
        {
            Style[
                __,
                TaggingRules -> KeyValuePattern[ "ConversationUUID" -> uuid ],
                ___
            ],
            ___
        }
    ];

removeChatFromRows // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*loadConversation*)
loadConversation // beginDefinition;

loadConversation[ nbo_NotebookObject, id_ ] := Enclose[
    Module[ { loaded, uuid, title, messages, cells, cellObjects },
        loaded = ConfirmBy[ LoadChat @ id, AssociationQ, "Loaded" ];
        uuid = ConfirmBy[ loaded[ "ConversationUUID" ], StringQ, "UUID" ];
        title = ConfirmBy[ loaded[ "ConversationTitle" ], StringQ, "Title" ];
        messages = ConfirmBy[ loaded[ "Messages" ], ListQ, "Messages" ];
        cells = ConfirmMatch[ ChatMessageToCell[ messages, "Workspace" ], { __Cell }, "Cells" ];
        cellObjects = ConfirmMatch[ Cells @ nbo, { ___CellObject }, "CellObjects" ];
        ConfirmMatch[ NotebookDelete @ cellObjects, { Null... }, "Delete" ];
        NotebookDelete @ First[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ], $Failed ];
        SelectionMove[ nbo, Before, Notebook, AutoScroll -> True ];
        ConfirmMatch[ NotebookWrite[ nbo, cells, AutoScroll -> False ], Null, "Write" ];
        If[ Cells @ nbo === { }, NotebookWrite[ nbo, cells, AutoScroll -> False ] ];
        ChatbookAction[ "AttachWorkspaceChatInput", nbo ];
        CurrentChatSettings[ nbo, "ConversationUUID" ] = uuid;
        CurrentValue[ nbo, { TaggingRules, "ConversationTitle" } ] = title;
        restoreVerticalScrollbar @ nbo;
        moveToChatInputField[ nbo, True ]
    ] // withLoadingOverlay @ nbo,
    throwInternalFailure
];

loadConversation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Icons*)
(* FIXME: Move these to FE resources *)

$searchButtonLabel := $searchButtonLabel = RawBoxes @ ToBoxes @ Mouseover[ $searchIconDefault, $searchIconActive ];

$searchIconDefault = Graphics[
    {
        Thickness[ 0.055556 ],
        Style[
            {
                FilledCurve[
                    {
                        { { 1, 4, 3 }, { 1, 3, 3 }, { 1, 3, 3 }, { 1, 3, 3 } },
                        {
                            { 0, 2, 0 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 0, 1, 0 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 }
                        }
                    },
                    {
                        {
                            { 7.5, 6.0 },
                            { 5.019, 6.0 },
                            { 3.0, 8.019 },
                            { 3.0, 10.5 },
                            { 3.0, 12.981 },
                            { 5.019, 15.0 },
                            { 7.5, 15.0 },
                            { 9.981, 15.0 },
                            { 12.0, 12.981 },
                            { 12.0, 10.5 },
                            { 12.0, 8.019 },
                            { 9.981, 6.0 },
                            { 7.5, 6.0 }
                        },
                        {
                            { 15.03, 3.03 },
                            { 11.416, 6.645 },
                            { 12.394, 7.638 },
                            { 13.0, 8.999 },
                            { 13.0, 10.5 },
                            { 13.0, 13.533 },
                            { 10.533, 16.0 },
                            { 7.5, 16.0 },
                            { 4.467, 16.0 },
                            { 2.0, 13.533 },
                            { 2.0, 10.5 },
                            { 2.0, 7.467 },
                            { 4.467, 5.0 },
                            { 7.5, 5.0 },
                            { 8.495, 5.0 },
                            { 9.426, 5.27 },
                            { 10.232, 5.733 },
                            { 10.251, 5.709 },
                            { 10.26, 5.68 },
                            { 10.282, 5.657 },
                            { 13.97, 1.97 },
                            { 14.116, 1.823 },
                            { 14.308, 1.75 },
                            { 14.5, 1.75 },
                            { 14.692, 1.75 },
                            { 14.884, 1.823 },
                            { 15.03, 1.97 },
                            { 15.323, 2.263 },
                            { 15.323, 2.737 },
                            { 15.03, 3.03 }
                        }
                    }
                ]
            },
            FaceForm @ RGBColor[ 0.2, 0.2, 0.2, 1.0 ]
        ]
    },
    ImageSize -> { 18.0, 18.0 }/0.85,
    PlotRange -> { { 0.0, 18.0 }, { 0.0, 18.0 } },
    AspectRatio -> Automatic
];

$searchIconActive = Graphics[
    {
        Thickness[ 0.055556 ],
        Style[
            {
                FilledCurve[
                    {
                        { { 1, 4, 3 }, { 1, 3, 3 }, { 1, 3, 3 }, { 1, 3, 3 } },
                        {
                            { 1, 4, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 0, 1, 0 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 1, 3, 3 },
                            { 0, 1, 0 }
                        }
                    },
                    {
                        {
                            { 3.5, 10.5 },
                            { 3.5, 12.981 },
                            { 5.519, 15.0 },
                            { 8.0, 15.0 },
                            { 10.481, 15.0 },
                            { 12.5, 12.981 },
                            { 12.5, 10.5 },
                            { 12.5, 8.019 },
                            { 10.481, 6.0 },
                            { 8.0, 6.0 },
                            { 5.519, 6.0 },
                            { 3.5, 8.019 },
                            { 3.5, 10.5 }
                        },
                        {
                            { 11.916, 6.645 },
                            { 12.894, 7.638 },
                            { 13.5, 8.999 },
                            { 13.5, 10.5 },
                            { 13.5, 13.533 },
                            { 11.033, 16.0 },
                            { 8.0, 16.0 },
                            { 4.967, 16.0 },
                            { 2.5, 13.533 },
                            { 2.5, 10.5 },
                            { 2.5, 7.467 },
                            { 4.967, 5.0 },
                            { 8.0, 5.0 },
                            { 8.995, 5.0 },
                            { 9.926, 5.27 },
                            { 10.732, 5.733 },
                            { 10.751, 5.709 },
                            { 10.76, 5.68 },
                            { 10.782, 5.657 },
                            { 14.47, 1.97 },
                            { 14.616, 1.823 },
                            { 14.808, 1.75 },
                            { 15.0, 1.75 },
                            { 15.192, 1.75 },
                            { 15.384, 1.823 },
                            { 15.53, 1.97 },
                            { 15.823, 2.263 },
                            { 15.823, 2.737 },
                            { 15.53, 3.03 },
                            { 11.916, 6.645 }
                        }
                    }
                ]
            },
            FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1.0 ]
        ]
    },
    ImageSize -> { 18.0, 18.0 }/0.85,
    PlotRange -> { { 0.0, 18.0 }, { 0.0, 18.0 } },
    AspectRatio -> Automatic
];


$popOutButtonLabel := $popOutButtonLabel = RawBoxes @ ToBoxes @ Mouseover[
    Graphics[
        {
            Thickness[ 0.11111 ],
            Style[
                {
                    FilledCurve[
                        {
                            {
                                { 0, 2, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 1, 3, 3 },
                                { 1, 3, 3 },
                                { 1, 3, 3 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 }
                            },
                            {
                                { 0, 2, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 }
                            }
                        },
                        {
                            {
                                { 5.0, 9.0 },
                                { 5.0, 8.0 },
                                { 7.293, 8.0 },
                                { 4.145, 4.856 },
                                { 3.949, 4.66 },
                                { 3.949, 4.344 },
                                { 4.145, 4.149 },
                                { 4.242, 4.051 },
                                { 4.371, 4.0 },
                                { 4.5, 4.0 },
                                { 4.629, 4.0 },
                                { 4.758, 4.051 },
                                { 4.855, 4.145 },
                                { 8.0, 7.293 },
                                { 8.0, 5.0 },
                                { 9.0, 5.0 },
                                { 9.0, 9.0 },
                                { 5.0, 9.0 }
                            },
                            {
                                { 9.0, 0.0 },
                                { 0.0, 0.0 },
                                { 0.0, 9.0 },
                                { 3.0, 9.0 },
                                { 3.0, 8.0 },
                                { 1.0, 8.0 },
                                { 1.0, 1.0 },
                                { 8.0, 1.0 },
                                { 8.0, 3.0 },
                                { 9.0, 3.0 },
                                { 9.0, 0.0 }
                            }
                        }
                    ]
                },
                FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1.0 ]
            ]
        },
        ImageSize -> { 10.0, 10.0 }/0.85,
        PlotRange -> { { -0.5, 9.5 }, { -0.5, 9.5 } },
        AspectRatio -> Automatic
    ],
    Graphics[
        {
            Thickness[ 0.11111 ],
            Style[
                {
                    FilledCurve[
                        {
                            {
                                { 0, 2, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 1, 3, 3 },
                                { 1, 3, 3 },
                                { 1, 3, 3 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 }
                            },
                            {
                                { 0, 2, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 },
                                { 0, 1, 0 }
                            }
                        },
                        {
                            {
                                { 5.0, 9.0 },
                                { 5.0, 8.0 },
                                { 7.293, 8.0 },
                                { 4.145, 4.856 },
                                { 3.949, 4.66 },
                                { 3.949, 4.344 },
                                { 4.145, 4.149 },
                                { 4.242, 4.051 },
                                { 4.371, 4.0 },
                                { 4.5, 4.0 },
                                { 4.629, 4.0 },
                                { 4.758, 4.051 },
                                { 4.855, 4.145 },
                                { 8.0, 7.293 },
                                { 8.0, 5.0 },
                                { 9.0, 5.0 },
                                { 9.0, 9.0 },
                                { 5.0, 9.0 }
                            },
                            {
                                { 9.0, 0.0 },
                                { 0.0, 0.0 },
                                { 0.0, 9.0 },
                                { 3.0, 9.0 },
                                { 3.0, 8.0 },
                                { 1.0, 8.0 },
                                { 1.0, 1.0 },
                                { 8.0, 1.0 },
                                { 8.0, 3.0 },
                                { 9.0, 3.0 },
                                { 9.0, 0.0 }
                            }
                        }
                    ]
                },
                FaceForm @ GrayLevel[ 0.2 ]
            ]
        },
        ImageSize -> { 10.0, 10.0 }/0.85,
        PlotRange -> { { -0.5, 9.5 }, { -0.5, 9.5 } },
        AspectRatio -> Automatic
    ]
];


$trashButtonLabel := $trashButtonLabel = RawBoxes @ ToBoxes @ Mouseover[
    Graphics[
        {
            Thickness[ 0.090909 ],
            Style[
                {
                    FilledCurve[
                        {
                            { { 0, 2, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 } }
                        },
                        {
                            {
                                { 9.0156, 9.1667 },
                                { 8.8026, 1.2497 },
                                { 8.8026, 1.0197 },
                                { 8.6186, 0.8337 },
                                { 8.3936, 0.8337 },
                                { 2.6056, 0.8337 },
                                { 2.3796, 0.8337 },
                                { 2.1966, 1.0197 },
                                { 2.1966, 1.2497 },
                                { 1.9966, 9.1667 },
                                { 9.0156, 9.1667 }
                            },
                            {
                                { 9.8336, 9.9997 },
                                { 1.1786, 9.9997 },
                                { 1.3786, 1.2497 },
                                { 1.3786, 0.5597 },
                                { 1.9286, -0.00030041 },
                                { 2.6056, -0.00030041 },
                                { 8.3936, -0.00030041 },
                                { 9.0706, -0.00030041 },
                                { 9.6206, 0.5597 },
                                { 9.6206, 1.2497 },
                                { 9.8336, 9.9997 }
                            }
                        }
                    ]
                },
                FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1. ]
            ],
            Style[
                {
                    FilledCurve[
                        {
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } }
                        },
                        {
                            { { 6.8513, 2.0213 }, { 7.5433, 2.0213 }, { 7.7573, 8.0133 }, { 7.0643, 8.0133 }, { 6.8513, 2.0213 } },
                            { { 5.1543, 2.0213 }, { 5.8463, 2.0213 }, { 5.8463, 8.0133 }, { 5.1543, 8.0133 }, { 5.1543, 2.0213 } },
                            { { 3.4553, 2.0213 }, { 4.1473, 2.0213 }, { 3.9483, 8.0133 }, { 3.2553, 8.0133 }, { 3.4553, 2.0213 } }
                        }
                    ]
                },
                FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1. ]
            ],
            Style[
                {
                    FilledCurve[
                        { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
                        { { { 0.517, 9. }, { 10.498, 9. }, { 10.498, 10. }, { 0.517, 10. }, { 0.517, 9. } } }
                    ]
                },
                FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1. ]
            ],
            Style[
                {
                    FilledCurve[
                        { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
                        { { { 4.515, 10. }, { 6.528, 10. }, { 6.528, 11. }, { 4.515, 11. }, { 4.515, 10. } } }
                    ]
                },
                FaceForm @ RGBColor[ 0.4, 0.67843, 0.82353, 1. ]
            ]
        },
        ImageSize -> { 12., 12. }/0.85,
        PlotRange -> { { -0.5, 11.5 }, { -0.5, 11.5 } },
        AspectRatio -> Automatic
    ],
    Graphics[
        {
            Thickness[ 0.090909 ],
            Style[
                {
                    FilledCurve[
                        {
                            { { 0, 2, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 }, { 1, 3, 3 }, { 0, 1, 0 } }
                        },
                        {
                            {
                                { 9.0156, 9.1667 },
                                { 8.8026, 1.2497 },
                                { 8.8026, 1.0197 },
                                { 8.6186, 0.8337 },
                                { 8.3936, 0.8337 },
                                { 2.6056, 0.8337 },
                                { 2.3796, 0.8337 },
                                { 2.1966, 1.0197 },
                                { 2.1966, 1.2497 },
                                { 1.9966, 9.1667 },
                                { 9.0156, 9.1667 }
                            },
                            {
                                { 9.8336, 9.9997 },
                                { 1.1786, 9.9997 },
                                { 1.3786, 1.2497 },
                                { 1.3786, 0.5597 },
                                { 1.9286, -0.00030041 },
                                { 2.6056, -0.00030041 },
                                { 8.3936, -0.00030041 },
                                { 9.0706, -0.00030041 },
                                { 9.6206, 0.5597 },
                                { 9.6206, 1.2497 },
                                { 9.8336, 9.9997 }
                            }
                        }
                    ]
                },
                FaceForm @ GrayLevel[ 0.2 ]
            ],
            Style[
                {
                    FilledCurve[
                        {
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } },
                            { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } }
                        },
                        {
                            { { 6.8513, 2.0213 }, { 7.5433, 2.0213 }, { 7.7573, 8.0133 }, { 7.0643, 8.0133 }, { 6.8513, 2.0213 } },
                            { { 5.1543, 2.0213 }, { 5.8463, 2.0213 }, { 5.8463, 8.0133 }, { 5.1543, 8.0133 }, { 5.1543, 2.0213 } },
                            { { 3.4553, 2.0213 }, { 4.1473, 2.0213 }, { 3.9483, 8.0133 }, { 3.2553, 8.0133 }, { 3.4553, 2.0213 } }
                        }
                    ]
                },
                FaceForm @ GrayLevel[ 0.2 ]
            ],
            Style[
                {
                    FilledCurve[
                        { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
                        { { { 0.517, 9. }, { 10.498, 9. }, { 10.498, 10. }, { 0.517, 10. }, { 0.517, 9. } } }
                    ]
                },
                FaceForm @ GrayLevel[ 0.2 ]
            ],
            Style[
                {
                    FilledCurve[
                        { { { 0, 2, 0 }, { 0, 1, 0 }, { 0, 1, 0 }, { 0, 1, 0 } } },
                        { { { 4.515, 10. }, { 6.528, 10. }, { 6.528, 11. }, { 4.515, 11. }, { 4.515, 10. } } }
                    ]
                },
                FaceForm @ GrayLevel[ 0.2 ]
            ]
        },
        ImageSize -> { 12., 12. }/0.85,
        PlotRange -> { { -0.5, 11.5 }, { -0.5, 11.5 } },
        AspectRatio -> Automatic
    ]
];


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $fromWorkspaceChatConversionRules;
    $inlineToWorkspaceConversionRules;
    $defaultUserImage;
];

End[ ];
EndPackage[ ];
