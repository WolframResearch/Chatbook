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
            NotebookWrite[ EvaluationNotebook[ ], Cell[ "", "ChatDelimiter", CellFrameLabels -> None ] ]
        ],
        Button[ "Clear", NotebookDelete @ Cells @ EvaluationNotebook[ ] ],
        Item[ "", ItemSize -> Fit ],
        Button[ "Pop Out", popOutChatNB @ EvaluationNotebook[ ], Method -> "Queued" ]
    }
};

makeWorkspaceChatDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Convert to Normal Chat Notebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*popOutChatNB*)
popOutChatNB // beginDefinition;

popOutChatNB[ nbo_NotebookObject ] :=
    popOutChatNB @ NotebookGet @ nbo;

popOutChatNB[ Notebook[ cells_, ___ ] ] :=
    NotebookPut @ Notebook[ cells /. $fromWorkspaceChatConversionRules, StyleDefinitions -> "Chatbook.nb" ];

popOutChatNB // endDefinition;


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
                                    Dynamic @ CurrentValue[
                                        EvaluationNotebook[ ],
                                        { TaggingRules, "ChatInputString" }
                                    ],
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
                        "EvaluateWorkspaceChat",
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
(*Package Footer*)
addToMXInitialization[
    $fromWorkspaceChatConversionRules
];

End[ ];
EndPackage[ ];
