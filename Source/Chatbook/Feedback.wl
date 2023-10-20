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
$feedbackURL           = "https://www.wolframcloud.com/obj/chatbook-feedback/api/1.0/Feedback";
$feedbackClientVersion = 1;

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
    Module[ { b64, wxf, data, chatData, systemData, settings, image },

        b64        = ConfirmBy[ CurrentValue[ cell, { TaggingRules, "ChatData" } ], StringQ, "Base64" ];
        wxf        = ConfirmBy[ BaseDecode @ b64, ByteArrayQ, "WXF" ];
        data       = ConfirmBy[ BinaryDeserialize @ wxf, AssociationQ, "Data" ];
        chatData   = ConfirmBy[ Lookup[ data, "Data" ], AssociationQ, "ChatData" ];
        systemData = ConfirmBy[ $debugData, AssociationQ, "SystemData" ];
        settings   = ConfirmBy[ Association[ $settingsData,  KeyDrop[ data, "Data" ] ], AssociationQ, "SettingsData" ];
        image      = ConfirmBy[ cellImage @ cell, ImageQ, "Image" ];

        <|
            "ChatData"  -> chatData,
            "Image"     -> image,
            "Positive"  -> positive,
            "Settings"  -> settings,
            "System"    -> systemData,
            "Timestamp" -> StringTrim[ DateString[ "ISODateTime" ], "Z"|"z" ] <> "Z"
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
        (* cellImage[ cellObject ] = image *)
        image
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
        choices = <| "CellImage" -> False, "ChatHistory" -> True, "Messages" -> True, "SystemMessage" -> True |>;
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
                dialogBody[ "Included content:", { Automatic, { 0, Automatic } } ],
                dialogBody @ Grid[
                    {
                        {
                            Checkbox @ Dynamic[
                                choices[ "Messages" ],
                                Function[
                                    choices[ "SystemMessage" ] = choices[ "ChatHistory" ] = #;
                                    choices[ "Messages" ] = #
                                ]
                            ],
                            "Chat messages"
                        },
                        {
                            "",
                            Grid[
                                {
                                    {
                                        Checkbox[
                                            Dynamic @ choices[ "SystemMessage" ],
                                            Enabled -> Dynamic @ choices[ "Messages" ]
                                        ],
                                        "Include system message"
                                    },
                                    {
                                        Checkbox[
                                            Dynamic @ choices[ "ChatHistory" ],
                                            Enabled -> Dynamic @ choices[ "Messages" ]
                                        ],
                                        "Include chat history used to generate this output"
                                    }
                                },
                                Alignment -> { Left, Baseline }
                            ]
                        },
                        {
                            Checkbox[ Dynamic @ choices[ "CellImage" ] ],
                            Tooltip[
                                "Include image of chat output",
                                ImageResize[ data[ "Image" ], Scaled[ 1/2 ] ],
                                TooltipStyle -> {
                                    Background     -> White,
                                    CellFrame      -> 1,
                                    CellFrameColor -> GrayLevel[ 0.85 ]
                                }
                            ]
                        }
                    },
                    Alignment -> { Left, Baseline }
                ],
                dialogBody[
                    InputField[
                        Dynamic @ data[ "Comment" ],
                        String,
                        ContinuousAction -> True,
                        FieldHint        -> "Do you have additional feedback? (Optional)",
                        ImageSize        -> { 500, 60 }
                    ],
                    { Automatic, { 3, Automatic } }
                ],
                dialogBody[
                    Style[
                        "Your chat history and feedback may be used for training purposes.",
                        FontColor -> GrayLevel[ 0.75 ],
                        FontSize  -> 12
                    ],
                    { Automatic, { 15, 3 } }
                ],
                dialogBody @ OpenerView[
                    {
                        "Preview data to be sent",
                        Pane[
                            Dynamic @ generatePreviewData[ data, choices ],
                            BaseStyle  -> {
                                "Program",
                                Background        -> GrayLevel[ 0.975 ],
                                FontSize          -> 9,
                                LineBreakWithin   -> False,
                                PageWidth         -> 485,
                                Selectable        -> True,
                                TextClipboardType -> "PlainText"
                            },
                            ImageSize  -> { 485, UpTo[ 200 ] },
                            Scrollbars -> Automatic
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
                                        sendDialogFeedback[ EvaluationNotebook[ ], data, choices ],
                                        Appearance       -> "Suppressed",
                                        BaselinePosition -> Baseline,
                                        Method           -> "Queued"
                                    ]
                                } }
                            ],
                            FrameStyle   -> None,
                            FrameMargins -> { { 0, 30 }, { 13, 13 } },
                            Alignment    -> { Right, Center }
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
(* ::Subsection::Closed:: *)
(*sendDialogFeedback*)
sendDialogFeedback // beginDefinition;

sendDialogFeedback[ nbo_NotebookObject, data_Association, choices_Association ] := Enclose[
    Module[ { json, chosen, string, image, request, response },

        CurrentValue[ nbo, { TaggingRules, "Status" } ] = "Submitting";

        json   = ConfirmBy[ toJSON @ Evaluate @ KeyDrop[ data, { "Image" } ], AssociationQ, "JSONData" ];
        chosen = ConfirmBy[ filterChoices[ json, choices ], AssociationQ, "Filtered" ];

        string = ConfirmBy[
            Developer`WriteRawJSONString[
                KeySort @ KeyDrop[ <| chosen, "Choices" -> choices |>, "CellImage" ],
                "Compact" -> True
            ],
            StringQ,
            "JSONString"
        ];

        image = If[ TrueQ @ choices[ "CellImage" ],
                    ConfirmBy[ createImageFile @ data, FileFormatQ[ #1, "PNG" ] &, "Image" ],
                    None
                ];

        request  = ConfirmMatch[ makeFeedbackRequest[ image, string ], _HTTPRequest, "HTTPRequest" ];
        response = ConfirmMatch[ URLRead @ request, _HTTPResponse, "HTTPResponse" ];

        checkResponse[ nbo, response ] (* TODO *)
    ],
    throwInternalFailure[ sendDialogFeedback[ nbo, data, choices ], ## ] &
];

sendDialogFeedback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createImageFile*)
createImageFile // beginDefinition;
createImageFile[ data_Association ] := createImageFile @ data[ "Image" ];
createImageFile[ image_Image? ImageQ ] := Flatten @ File @ Export[ $temporaryImageFile, image, "PNG" ];
createImageFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$temporaryImageFile*)
$temporaryImageFile := FileNameJoin @ {
    $TemporaryDirectory,
    "chatbook-feedback-" <> IntegerString[ $SessionID, 16 ] <> ".png"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeFeedbackRequest*)
makeFeedbackRequest // beginDefinition;

makeFeedbackRequest[ image_File? FileExistsQ, data_String ] :=
    HTTPRequest[
        CloudObject @ $feedbackURL,
        <|
            "Body" -> {
                "CellImage" -> <| "Content" -> image, "MIMEType" -> "image/png", "FileName" -> FileNameTake @ image |>,
                "Data"      -> StringToByteArray @ data,
                "Version"   -> IntegerString @ $feedbackClientVersion
            },
            "Method" -> "POST"
        |>
    ];

makeFeedbackRequest[ None, data_String ] :=
    HTTPRequest[
        CloudObject @ $feedbackURL,
        <|
            "Body" -> {
                "Data"    -> StringToByteArray @ data,
                "Version" -> IntegerString @ $feedbackClientVersion
            },
            "Method" -> "POST"
        |>
    ];

makeFeedbackRequest // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generatePreviewData*)
generatePreviewData // beginDefinition;

generatePreviewData[ data_, choices_ ] := Enclose[
    Module[ { json, readable, chosen },
        json     = ConfirmBy[ toJSON @ Evaluate @ KeyDrop[ data, { "Image" } ], AssociationQ, "JSONData" ];
        readable = ConfirmBy[ makeObjectsReadable @ json, AssociationQ, "Readable" ];
        chosen   = ConfirmBy[ filterChoices[ readable, choices ], AssociationQ, "Filtered" ];
        ConfirmBy[ Developer`WriteRawJSONString @ KeySort @ chosen, StringQ, "JSONString" ]
    ],
    throwInternalFailure[ generatePreviewData[ data, choices ], ## ] &
];

generatePreviewData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*filterChoices*)
filterChoices // beginDefinition;

filterChoices[ data0_Association, choices_Association ] := Enclose[
    Module[ { data },
        data = data0;
        If[ choices[ "Messages" ]
            ,
            If[ ! choices[ "SystemMessage" ],
                data = ConfirmBy[ dropSystemMessage @ data, AssociationQ, "DropSystemMessage" ]
            ];
            If[ ! choices[ "ChatHistory" ],
                data = ConfirmBy[ dropChatHistory @ data, AssociationQ, "DropChatHistory" ]
            ];
            ,
            data = ConfirmBy[ dropMessages @ data, AssociationQ, "DropMessages" ]
        ];

        If[ data[ "Comment" ] === "", KeyDropFrom[ data, "Comment" ] ];

        If[ choices[ "CellImage" ],
            data[ "CellImage" ] = "(will be uploaded upon sending)",
            KeyDropFrom[ data, "CellImage" ]
        ];

        Replace[
            DeleteCases[ data, _Missing | <| |> | { } ],
            as_Association :> RuleCondition @ KeySort @ as,
            { 1 }
        ]
    ],
    throwInternalFailure[ filterChoices[ data0, choices ], ## ] &
];

filterChoices // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropSystemMessage*)
dropSystemMessage // beginDefinition;

dropSystemMessage[ data_Association ] :=
    dropSystemMessage[ data, data[ "ChatData", "Messages" ] ];

dropSystemMessage[ data0_Association, messages: { ___Association } ] :=
    Module[ { data },
        data = data0;

        data[ "ChatData", "Messages" ] =
            If[ MatchQ[ First[ messages, None ], KeyValuePattern[ "Role" -> "System" ] ],
                Rest @ messages,
                messages
            ];

        data
    ];

dropSystemMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropChatHistory*)
dropChatHistory // beginDefinition;

dropChatHistory[ data_Association ] :=
    dropChatHistory[ data, data[ "ChatData", "Messages" ] ];

dropChatHistory[
    data0_Association,
    { sys: KeyValuePattern[ "Role" -> "System" ], ___, in_Association, out_Association }
] :=
    Module[ { data },
        data = data0;
        data[ "ChatData", "Messages" ] = { sys, in, out };
        data
    ];

dropChatHistory[ data0_Association, { ___, in_Association, out_Association } ] :=
    Module[ { data },
        data = data0;
        data[ "ChatData", "Messages" ] = { in, out };
        data
    ];

dropChatHistory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*dropMessages*)
dropMessages // beginDefinition;

dropMessages[ data: KeyValuePattern[ "ChatData" -> as_Association ] ] :=
    <| data, "ChatData" -> KeyDrop[ as, "Messages" ] |>;

dropMessages // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeObjectsReadable*)
makeObjectsReadable // beginDefinition;

makeObjectsReadable[ as_Association ] :=
    ReplaceAll[
        as,
        {
            KeyValuePattern @ { "_Object" -> "Symbol"|"DefaultTool", "Data" -> name_ } :> name
        }
    ];

makeObjectsReadable // endDefinition;

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
