(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`InlineChat`" ];

HoldComplete[
    `$inlineChat;
    `$attachedInlineChat;
    `attachInlineChat;
    `attachInlineChatOutput;
    `evaluateInlineChat;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Actions`"  ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];
Needs[ "Wolfram`Chatbook`Settings`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$inlineChat         = False;
$attachedInlineChat = None;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Chat*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachInlineChat*)
attachInlineChat // beginDefinition;

attachInlineChat[ ] :=
    attachInlineChat @ InputNotebook[ ];

attachInlineChat[ nbo_NotebookObject ] :=
    attachInlineChat[ nbo, SelectedCells @ nbo ];


attachInlineChat[ nbo_NotebookObject, { ___, cell_CellObject } ] := (
    NotebookDelete @ $attachedInlineChat;
    $attachedInlineChat = AttachCell[ cell, $inlineChatInputCell, "Inline", RemovalConditions -> { "SelectionExit" } ];
    SelectionMove[ $attachedInlineChat, All, CellContents ];
    FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ]
);


attachInlineChat[ nbo_NotebookObject, { } ] :=
    FirstCase[
        cellInformation @ Cells @ nbo,
        KeyValuePattern @ {
            "CursorPosition" -> "BelowCell"|"AboveCell",
            "CellObject"     -> cell_CellObject
        } :> attachInlineChat[ nbo, { cell } ],
        attachInlineChat[ nbo, None ]
    ];


attachInlineChat[ nbo_NotebookObject, _ ] := (
    NotebookDelete @ $attachedInlineChat;

    $attachedInlineChat = AttachCell[
        nbo,
        $inlineChatInputCell,
        { Left, Bottom },
        0,
        { Left, Bottom },
        RemovalConditions -> { "SelectionExit" }
    ];

    SelectionMove[ $attachedInlineChat, All, CellContents ];
    FrontEndExecute @ FrontEnd`FrontEndToken[ "MoveNextPlaceHolder" ]
);

attachInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateInlineChat*)
evaluateInlineChat // beginDefinition;

evaluateInlineChat[ cell_CellObject ] :=
    Block[ { $inlineChat = True, $attachedInlineChat = cell },
        EvaluateChatInput[ cell, parentNotebook @ cell, currentChatSettings @ parentCell @ cell ]
    ];

evaluateInlineChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*attachInlineChatOutput*)
attachInlineChatOutput // beginDefinition;

attachInlineChatOutput[ settings_, evalCell_CellObject, cell_Cell ] :=
    With[ { attached = AttachCell[ evalCell, cell, "Inline", RemovalConditions -> { "SelectionExit" } ] },
        ensureChatOutputCell[ attached ] = True;
        attached
    ];

attachInlineChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*UI Elements*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$inlineChatInputCell*)
$inlineChatInputCell := $inlineChatInputCell = Cell[
    BoxData @ ToBoxes @ Grid[
        {
            {
                RawBoxes @ TemplateBox[ { }, "ChatInputActiveCellDingbat" ],
                Framed[
                    Grid[
                        {
                            {
                                EventHandler[
                                    InputField[
                                        Dynamic @ CurrentValue[
                                            EvaluationCell[ ],
                                            { TaggingRules, "InlineChatInput" }
                                        ],
                                        String,
                                        Appearance       -> "Frameless",
                                        BaseStyle        -> { "Text", FontWeight -> Plain },
                                        ContinuousAction -> True,
                                        FieldHint        -> "Ask me anything",
                                        FrameMargins     -> 0,
                                        ImageSize        -> { Scaled[ 1 ], Automatic }
                                    ],
                                    {
                                        "ReturnKeyDown" :> With[ { $CellContext`cell = EvaluationCell[ ] },
                                            Needs[ "Wolfram`Chatbook`" -> None ];
                                            Catch[
                                                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                                                    "EvaluateInlineChat",
                                                    $CellContext`cell
                                                ],
                                                _
                                            ]
                                        ]
                                    },
                                    Method -> "Queued"
                                ],
                                $sendButtonLabel
                            }
                        },
                        Alignment -> { Left, Center }
                    ],
                    FrameMargins -> { { 8, 2 }, { 1, 1 } },
                    FrameStyle   -> Directive[ AbsoluteThickness[ 2 ], RGBColor[ 0.63922, 0.78824, 0.94902 ] ],
                    ImageMargins -> 0
                ]
            }
        },
        Alignment -> { Left, Baseline }
    ],
    "AttachedChatInput",
    CellMargins -> { { 66, 66 }, { 0, 10 } }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$sendButtonLabel*)
$sendButtonLabel := $sendButtonLabel =
    Module[ { icon },

        icon = Graphics[
            {
                EdgeForm @ Darker @ RGBColor[ 0.63922, 0.78824, 0.94902 ],
                FaceForm @ RGBColor[ 0.63922, 0.78824, 0.94902 ],
                Polygon @ CirclePoints[ { 1, 120 * Degree }, 3 ]
            },
            ImageSize -> 15
        ];

        MouseAppearance[
            Mouseover[
                Framed[
                    icon,
                    RoundingRadius -> 3,
                    FrameStyle     -> None,
                    FrameMargins   -> { { Automatic, 2 }, { Automatic, Automatic } }
                ],
                Framed[
                    icon,
                    RoundingRadius -> 3,
                    FrameStyle     -> GrayLevel[ 0.9 ],
                    FrameMargins   -> { { Automatic, 2 }, { Automatic, Automatic } },
                    Background     -> GrayLevel[ 0.95 ]
                ]
            ],
            "LinkHand"
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
