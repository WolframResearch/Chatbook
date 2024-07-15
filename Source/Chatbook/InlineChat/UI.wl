(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineChat`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inputFieldPaneMargins       = 5;
$inputFieldGridMagnification = 0.75;
$inputFieldOuterBackground   = None;

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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attached Chat Input*)

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
(* ::Subsection::Closed:: *)
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
    Background    -> $inputFieldOuterBackground,
    Selectable    -> True,
    Magnification -> 0.8
];

inlineChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
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
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
