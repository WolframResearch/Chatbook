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
        SelectionMove[ attached, All, Cell ]; (* FIXME: this isn't working *)
        attached
    ],
    throwInternalFailure
];

attachWorkspaceChatInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$attachedChatInputCell*)
$attachedChatInputCell = ExpressionCell[
    DynamicModule[ { input = Null, thisNB },
        EventHandler[
            Pane[
                Grid[
                    {
                        {
                            RawBoxes @ TemplateBox[ { }, "ChatIconUser" ],
                            Framed[
                                InputField[ Dynamic @ input, String, $inputFieldOptions ],
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
                    Global`thisNB = thisNB;
                    Global`dInput = Dynamic @ input;
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "EvaluateFloatingChat", thisNB, Dynamic @ input ]
                )
            },
            Method -> "Queued"
        ],
        Initialization :> (thisNB = EvaluationNotebook[ ])
    ],
    "ChatInputField",
    Background -> $inputFieldOuterBackground
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
