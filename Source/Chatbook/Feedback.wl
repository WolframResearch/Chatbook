(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Feedback`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `sendFeedback;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`Dialogs`"  ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$feedbackURL = "https://www.wolframcloud.com/obj/rhennigan/Chatbook/api/1.0/Feedback"; (* FIXME: deploy real endpoint *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Send Feedback*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendFeedback*)
sendFeedback // beginDefinition;

sendFeedback[ cell_CellObject, positive: True|False ] := Enclose[
    Module[ { data },
        data = ConfirmBy[ createFeedbackData[ cell, positive ], AssociationQ, "FeedbackData" ];
        Global`$data = data;
        ConfirmMatch[ createFeedbackDialog @ data, _NotebookObject, "FeedbackDialog" ]
    ],
    throwInternalFailure[ sendFeedback[ cell, positive ], ## ] &
];

sendFeedback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createFeedbackData*)
createFeedbackData // beginDefinition;

createFeedbackData[ cell_CellObject, positive: True|False ] := Enclose[
    Module[ { b64, wxf, data, chatData, debugData, settings, image },

        b64       = ConfirmBy[ CurrentValue[ cell, { TaggingRules, "ChatData" } ], StringQ, "Base64" ];
        wxf       = ConfirmBy[ BaseDecode @ b64, ByteArrayQ, "WXF" ];
        data      = ConfirmBy[ BinaryDeserialize @ wxf, AssociationQ, "Data" ];
        chatData  = ConfirmBy[ Lookup[ data, "Data" ], AssociationQ, "ChatData" ];
        debugData = ConfirmBy[ $debugData, AssociationQ, "DebugData" ];
        settings  = ConfirmBy[ Association[ $settingsData,  KeyDrop[ data, "Data" ] ], AssociationQ, "SettingsData" ];
        image     = ConfirmBy[ cellImage @ cell, ImageQ, "Image" ];

        <|
            "ChatData"  -> chatData,
            "DebugData" -> debugData,
            "Image"     -> image,
            "Positive"  -> positive,
            "Settings"  -> settings,
            "Timestamp" -> DateString[ "ISODateTime" ]
        |>
    ],
    throwInternalFailure[ createFeedbackData[ cell, positive ], ##1 ] &
];

createFeedbackData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellImage*)
cellImage // beginDefinition;

cellImage[ cellObject_CellObject ] := Enclose[
    Module[ { cell, nbo, opts, nb, image },
        cell  = ConfirmMatch[ NotebookRead @ cellObject, _Cell, "Cell" ];
        nbo   = ConfirmMatch[ parentNotebook @ cellObject, _NotebookObject, "NotebookObject" ];
        opts  = ConfirmMatch[ Options @ nbo, KeyValuePattern @ { }, "Options" ];
        nb    = Notebook[ { $blankCell, cell, $blankCell }, Sequence @@ opts ];
        image = ConfirmBy[ Rasterize @ nb, ImageQ, "Rasterize" ];
        cellImage[ cellObject ] = image
    ],
    throwInternalFailure[ cellImage @ cellObject, ## ] &
];

cellImage // endDefinition;


$blankCell = Cell[ "", CellElementSpacings -> { "CellMinHeight" -> 0, "ClosedCellHeight" -> 0 }, CellOpen -> False ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createFeedbackDialog*)
createFeedbackDialog // beginDefinition;

createFeedbackDialog[ data0_Association ] := createDialog[
    DynamicModule[ { data = data0, choices },
        choices = <| "CellImage" -> True, "ChatHistory" -> True, "LastChat" -> True |>;
        createFeedbackDialogContent[ Dynamic @ data, Dynamic @ choices ]
    ],
    WindowTitle -> "Send Wolfram AI Chat Feedback"
];

createFeedbackDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createFeedbackDialogContent*)
createFeedbackDialogContent // beginDefinition;

createFeedbackDialogContent[ Dynamic[ data_ ], Dynamic[ choices_ ] ] := Enclose[
    cvExpand @ Module[ { content },
        content = Grid[
            {
                dialogHeader[ "Send Wolfram AI Chat Feedback" ],
                dialogBody[ "Sending feedback helps us improve our AI features.", { Automatic, { 0, 10 } } ],
                dialogBody @ Grid[
                    {
                        {
                            RadioButton[ Dynamic @ data[ "Positive" ], True ],
                            chatbookIcon[ "ThumbsUpActive", False ]
                        },
                        {
                            RadioButton[ Dynamic @ data[ "Positive" ], False ],
                            chatbookIcon[ "ThumbsDownActive", False ]
                        }
                    },
                    Alignment -> { Automatic, Center }
                ],
                dialogBody[ "Content to be sent:", { Automatic, { 0, Automatic } } ],
                dialogBody @ Grid[
                    {
                        {
                            Checkbox @ Dynamic[
                                choices[ "LastChat" ],
                                Function[
                                    If[ ! #, choices[ "ChatHistory" ] = False ];
                                    choices[ "LastChat" ] = #
                                ]
                            ],
                            "Chat input and output"
                        },
                        {
                            Checkbox[
                                Dynamic @ choices[ "ChatHistory" ],
                                Enabled -> Dynamic @ choices[ "LastChat" ]
                            ],
                            "Include chat history used to generate this output"
                        },
                        {
                            Checkbox[ Dynamic @ choices[ "CellImage" ] ],
                            "Include image of chat output"
                        }
                    },
                    Alignment -> { Left, Baseline }
                ],
                dialogBody[
                    InputField[
                        Dynamic @ data[ "Comment" ],
                        String,
                        FieldHint -> "Do you have additional feedback? (Optional)",
                        ImageSize -> { 500, 60 }
                    ]
                ],
                dialogBody @ OpenerView[
                    {
                        "Preview",
                        Dynamic[
                            Column[
                                {
                                    Pane[
                                        Developer`WriteRawJSONString[
                                            toJSON @ Evaluate @ KeyDrop[ data, { "Image" } ]
                                        ],
                                        BaseStyle  -> {
                                            "Program",
                                            Background      -> GrayLevel[ 0.975 ],
                                            FontSize        -> 9,
                                            LineBreakWithin -> False,
                                            PageWidth       -> 500,
                                            Selectable      -> True
                                        },
                                        ImageSize  -> { UpTo[ 500 ], UpTo[ 200 ] },
                                        Scrollbars -> Automatic
                                    ],
                                    If[ False && TrueQ @ choices[ "CellImage" ],
                                        Pane[
                                            data[ "Image" ],
                                            ImageSize       -> { UpTo[ 500 ], UpTo[ 200 ] },
                                            ImageSizeAction -> "ShrinkToFit"
                                        ],
                                        Nothing
                                    ]
                                }
                            ]
                        ]
                    },
                    Method -> "Active"
                ],
                {
                    Item[
                        Framed[
                            Grid[
                                { {
                                    Button[
                                        grayDialogButtonLabel[ "Cancel" ],
                                        NotebookClose @ EvaluationNotebook[ ],
                                        Appearance       -> "Suppressed",
                                        BaselinePosition -> Baseline,
                                        Method           -> "Queued"
                                    ],
                                    Button[
                                        redDialogButtonLabel[ "Send" ],
                                        sendDialogFeedback[ data, choices ],
                                        Appearance       -> "Suppressed",
                                        BaselinePosition -> Baseline,
                                        Method           -> "Queued"
                                    ]
                                } }
                            ],
                            FrameStyle -> None,
                            ImageSize  -> { 150, 50 },
                            Alignment  -> { Center, Center }
                        ],
                        Alignment -> { Right, Automatic }
                    ],
                    SpanFromLeft
                }
            },
            Alignment -> { Left, Top },
            BaseStyle -> $baseStyle,
            Dividers  -> {
                False,
                {
                    False,
                    GrayLevel[ 0.85 ],
                    False,
                    False,
                    False,
                    False,
                    False,
                    GrayLevel[ 0.85 ],
                    False,
                    { False }
                }
            },
            ItemSize  -> { Automatic, 0 },
            Spacings  -> { 0, 0 }
        ];

        content
    ],
    throwInternalFailure[ createFeedbackDialogContent @ data, ## ] &
];

createFeedbackDialogContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*JSON Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toJSON*)
toJSON // beginDefinition;
toJSON // Attributes = { HoldFirst };

toJSON[ as0: KeyValuePattern[ key_ :> val_ ] ] /; AssociationQ @ Unevaluated @ as0 :=
    Block[ { as = Association @ as0 },
        as[ key ] = toJSON @ val;
        toJSON @ Evaluate @ as
    ];

toJSON[ as_Association ] /; AssociationQ @ Unevaluated @ as :=
    KeyMap[ toJSON, toJSON /@ as ];

toJSON[ list_List ] :=
    toJSON /@ Unevaluated @ list;

toJSON[ sym: True|False|Null ] :=
    sym;

toJSON[ number_ /; NumberQ @ Unevaluated @ number ] :=
    number;

toJSON[ string_String /; StringQ @ Unevaluated @ string ] :=
    ToString @ string;

toJSON[ sym_Symbol /; AtomQ @ Unevaluated @ sym ] :=
    With[ { ctx = Context @ Unevaluated @ sym, name = SymbolName @ Unevaluated @ sym },
        If[ ctx === "System`",
            <| "_Object" -> "Symbol", "Data" -> name |>,
            <| "_Object" -> "Symbol", "Data" -> ctx<>name |>
        ]
    ];

toJSON[ tool: HoldPattern[ _LLMTool ] ] :=
    toolJSON @ tool;

toJSON[ RawBoxes @ TemplateBox[ { }, name_String ] ] :=
    <| "_Object" -> "NamedTemplateBox", "Data" -> name |>;

toJSON[ other_ ] :=
    <| "_Object" -> "Expression", "Data" -> ToString[ Unevaluated @ other, InputForm ] |>;

toJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolJSON*)
toolJSON // beginDefinition;

toolJSON[ tool: HoldPattern[ _LLMTool ] ] :=
    Module[ { names, name },
        names = AssociationMap[ Reverse, $DefaultTools ];
        name = Lookup[ names, tool ];
        If[ StringQ @ name,
            <| "_Object" -> "DefaultTool", "Data" -> name |>,
            <| "_Object" -> "Expression", "Data" -> ToString[ Unevaluated @ tool, InputForm ] |>
        ]
    ];

toolJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

(* :!CodeAnalysis::EndBlock:: *)

End[ ];
EndPackage[ ];
