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
$inputFieldGridMagnification = 0.75;
$inputFieldOuterBackground   = GrayLevel[ 0.95 ];

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
    attachInlineChatInput[ nbo, SelectedCells @ nbo ];

attachInlineChatInput[ nbo_NotebookObject, { root_CellObject } ] := Enclose[
    Module[ { attached },

        attached = ConfirmMatch[
            AttachCell[
                NotebookSelection @ nbo,
                inlineChatInputCell @ root,
                { Left, Bottom },
                0,
                { Left, Top },
                RemovalConditions -> { "MouseClickOutside" }
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
                Initialization :> ( cell = EvaluationCell[ ] ),
                UnsavedVariables :> { cell }
            ]
        },
        "DropShadowPaneBox"
    ],
    "ChatInputField",
    Background    -> None,
    Selectable    -> True,
    Magnification -> 0.8
];

inlineChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*displayInlineChat*)
displayInlineChat // beginDefinition;

displayInlineChat[ cell_CellObject, root_CellObject, Dynamic[ messageCells_ ] ] :=
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
                            InputField[ Dynamic @ currentInput, String, $inputFieldOptions ],
                            $inputFieldFrameOptions
                        ],
                        RawBoxes @ inlineTemplateBox @ TemplateBox[ { RGBColor[ "#a3c9f2" ], 27 }, "SendChatButton" ]
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
(*displayInlineChatMessages*)
displayInlineChatMessages // beginDefinition;

displayInlineChatMessages[ { }, inputField_ ] :=
    Pane[ inputField, ImageSize -> { Scaled[ 0.5 ], Automatic } ];

displayInlineChatMessages[ cells: { __Cell }, inputField_ ] :=
    Column[
        {
            Pane[
                Column[
                    RawBoxes /@ cells,
                    Background -> White,
                    Alignment -> Left,
                    Spacings  -> 0
                ],
                ImageSize -> { Scaled[ 0.5 ], UpTo[ 400 ] },
                Scrollbars -> Automatic,
                AppearanceElements -> { }
            ],
            Pane[ inputField, ImageSize -> { Scaled[ 0.5 ], Automatic } ]
        },
        Alignment -> Left
    ];

displayInlineChatMessages // endDefinition;

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
assistantImage[ ] := RawBoxes @ TemplateBox[ { }, "ChatIconCodeAssistant" ]; (* TODO *)
assistantImage // endDefinition;

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
(*Normal Chat Notebook Conversion*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutChatNB*)
popOutChatNB // beginDefinition;
popOutChatNB[ nbo_NotebookObject ] := popOutChatNB @ NotebookGet @ nbo;
popOutChatNB[ Notebook[ cells_, ___ ] ] := popOutChatNB @ cells;
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
    Cell[ BoxData @ TemplateBox[ { text_ }, "UserMessageBox" ], "ChatInput", opts___ ] :>
        Cell[ Flatten @ TextData @ text, "ChatInput", opts ]
    ,
    Cell[
        TextData @ Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox" ], ___ ],
        "ChatOutput",
        opts___
    ] :> Cell[ Flatten @ TextData @ text, "ChatOutput", opts ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $fromWorkspaceChatConversionRules
];

End[ ];
EndPackage[ ];
