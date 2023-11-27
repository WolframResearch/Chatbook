(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Feedback`" ];

(* :!CodeAnalysis::BeginBlock:: *)

HoldComplete[
    `sendFeedback;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"               ];
Needs[ "Wolfram`Chatbook`ChatMessages`"  ];
Needs[ "Wolfram`Chatbook`Common`"        ];
Needs[ "Wolfram`Chatbook`Dialogs`"       ];
Needs[ "Wolfram`Chatbook`FrontEnd`"      ];
Needs[ "Wolfram`Chatbook`SendChat`"      ];
Needs[ "Wolfram`Chatbook`Serialization`" ];
Needs[ "Wolfram`Chatbook`Utils`"         ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$feedbackURL           = "https://www.wolframcloud.com/obj/chatbook-feedback/api/1.0/Feedback";
$feedbackClientVersion = 1;
$maxJSONObjectSize     = 10000;
$simpleDisplayObjects  = { "DefaultTool", "Symbol", "Tokenizer" };
$$simpleDisplayObject  = Alternatives @@ $simpleDisplayObjects;

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
        ConfirmMatch[ createFeedbackDialog[ cell, data ], _NotebookObject, "FeedbackDialog" ]
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
            "ContentID" -> contentID @ { chatData, settings, systemData }
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

createFeedbackDialog[ cell_CellObject, data0_Association ] := createDialog[
    DynamicModule[ { data = data0, choices },
        choices = <| "CellImage" -> False, "ChatHistory" -> True, "Messages" -> True, "SystemMessage" -> True |>;
        createFeedbackDialogContent[ cell, Dynamic @ data, Dynamic @ choices ]
    ],
    WindowTitle -> "Send Wolfram AI Chat Feedback"
];

createFeedbackDialog // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createFeedbackDialogContent*)
createFeedbackDialogContent // beginDefinition;

createFeedbackDialogContent[ cell_CellObject, Dynamic[ data_ ], Dynamic[ choices_ ] ] := Enclose[
    cvExpand @ Module[ { content },
        content = Grid[
            {
                dialogHeader[ "Send Wolfram AI Chat Feedback" ],
                dialogBody[
                    Grid[
                        {
                            {
                                SetterBar[
                                    Dynamic @ data[ "Positive" ],
                                    {
                                        True  -> chatbookIcon[ "ThumbsUpActive"  , False ],
                                        False -> chatbookIcon[ "ThumbsDownActive", False ]
                                    }
                                ],
                                "Sending feedback helps us improve our AI features."
                            }
                        },
                        Alignment -> { Left, Baseline }
                    ],
                    { Automatic, { 0, 15 } }
                ],
                dialogBody[
                    includedContentGrid[ Dynamic @ data, Dynamic @ choices ],
                    { Automatic, { Automatic, 10 } }
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
                        topRightOverlay[
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
                            ],
                            Framed[
                                clickToCopy[
                                    chatbookIcon[ "AssistantCopyClipboard", False ],
                                    Unevaluated @ Developer`ReadRawJSONString @ generatePreviewData[ data, choices ]
                                ],
                                Background     -> GrayLevel[ 0.975 ],
                                ContentPadding -> False,
                                FrameMargins   -> 0,
                                FrameStyle     -> None
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
                                        sendDialogFeedback[ cell, EvaluationNotebook[ ], data, choices ],
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
                    GrayLevel[ 0.85 ],
                    False,
                    { False }
                }
            },
            ItemSize  -> { Automatic, 0 },
            Spacings  -> { 0, 0 }
        ];

        PaneSelector[
            {
                "None"       -> content,
                "Submitting" -> ProgressIndicator[ Appearance -> "Necklace" ],
                "Done"       -> Style[ "Thanks for your feedback!", $baseStyle ],
                "Error"      -> Style[
                    Dynamic[ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ErrorText" } ] ],
                    $baseStyle
                ]
            },
            Dynamic @ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "Status" }, "None" ],
            Alignment -> { Center, Center }
        ]
    ],
    throwInternalFailure[ createFeedbackDialogContent @ data, ## ] &
];

createFeedbackDialogContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*topRightOverlay*)
topRightOverlay // beginDefinition;

topRightOverlay[ pane_, attached_ ] :=
    DynamicWrapper[
        pane,
        AttachCell[
            EvaluationBox[ ],
            attached,
            { Right, Top },
            Offset[ { -20, -5 }, { 0, 0 } ],
            { Right, Top }
        ],
        SingleEvaluation -> True
    ];

topRightOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includedContentGrid*)
includedContentGrid // beginDefinition;

includedContentGrid[ Dynamic[ data_ ], Dynamic[ choices_ ] ] := Enclose[
    Module[ { image, cropped, resized },
        image = ConfirmBy[ data[ "Image" ], ImageQ, "Image" ];
        cropped = ConfirmBy[ cropImage @ image, ImageQ, "Cropped" ];
        resized = ConfirmBy[ ImageResize[ image, { UpTo[ 1440 ], UpTo[ 810 ] } ], ImageQ, "Resized" ];
        Grid[
            {
                {
                    "Included content:",
                    PaneSelector[
                        {
                            True -> Style[ "Output image", FontColor -> GrayLevel[ 0.75 ] ],
                            False -> ""
                        },
                        Dynamic @ choices[ "CellImage" ]
                    ]
                },
                {
                    includedContentCheckboxes[ Dynamic @ data, Dynamic @ choices ],
                    Item[
                        PaneSelector[
                            {
                                True -> Tooltip[
                                    Pane[
                                        cropped,
                                        ImageSize       -> { 240, UpTo[ 90 ] },
                                        ImageSizeAction -> "ShrinkToFit",
                                        Alignment       -> { Right, Top }
                                    ],
                                    resized,
                                    TooltipStyle -> {
                                        Background     -> White,
                                        CellFrame      -> 1,
                                        CellFrameColor -> GrayLevel[ 0.85 ]
                                    }
                                ],
                                False -> ""
                            },
                            Dynamic @ choices[ "CellImage" ]
                        ],
                        Alignment -> { Right, Top }
                    ]
                }
            },
            Alignment -> { { Left, Right }, Top }
        ]
    ],
    throwInternalFailure[ includedContentGrid[ Dynamic @ data, Dynamic @ choices ], ## ] &
];

includedContentGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*infoTooltip*)
infoTooltip // beginDefinition;
infoTooltip[ content_, tooltip_ ] := Row @ { content, Spacer[ 5 ], infoTooltip @ tooltip };
infoTooltip[ tooltip_ ] := Tooltip[ chatbookIcon[ "InformationTooltip", False ], tooltip ];
infoTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cropImage*)
cropImage // beginDefinition;

cropImage[ img_? ImageQ ] := Enclose[
    Module[ { w, h, hh },
        { w, h } = ConfirmMatch[ ImageDimensions @ img, { _? Positive, _? Positive }, "ImageDimensions" ];
        hh = ConfirmBy[ Round[ 0.4 * w ], IntegerQ, "Height" ];
        If[ TrueQ[ h > hh ],
            ConfirmBy[ ImageCrop[ img, { w, hh }, Bottom ], ImageQ, "ImageCrop" ],
            img
        ]
    ],
    throwInternalFailure[ cropImage @ img, ##1 ] &
];

cropImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*includedContentCheckboxes*)
includedContentCheckboxes // beginDefinition;

includedContentCheckboxes[ Dynamic[ data_ ], Dynamic[ choices_ ] ] :=
    Grid[
        {
            {
                Checkbox @ Dynamic[
                    choices[ "Messages" ],
                    Function[ choices[ "SystemMessage" ] = choices[ "ChatHistory" ] = #1; choices[ "Messages" ] = #1 ]
                ],
                infoTooltip[ "Chat messages", "Chat messages involved in creating this chat output." ]
            },
            {
                "",
                Grid[
                    {
                        {
                            Checkbox[ Dynamic @ choices[ "SystemMessage" ], Enabled -> Dynamic @ choices[ "Messages" ] ],
                            infoTooltip[
                                "System message",
                                "The underlying system message used for giving instructions to the AI."
                            ]
                        },
                        {
                            Checkbox[ Dynamic @ choices[ "ChatHistory" ], Enabled -> Dynamic @ choices[ "Messages" ] ],
                            infoTooltip[
                                "Chat history used to generate this output",
                                "Additional messages that were used as conversation history to generate this output."
                            ]
                        }
                    },
                    Alignment -> { Left, Baseline },
                    Spacings  -> { 0.5, 0.75 }
                ]
            },
            {
                Checkbox @ Dynamic @ choices[ "CellImage" ],
                infoTooltip[
                    "Image of chat output",
                    "A screenshot of the chat output, which can be used if feedback is related to the output's appearance."
                ]
            }
        },
        Alignment -> { Left, Baseline },
        Spacings  -> { 0.5, 0.75 }
    ];

includedContentCheckboxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*sendDialogFeedback*)
sendDialogFeedback // beginDefinition;

sendDialogFeedback[ cell_CellObject, nbo_NotebookObject, data_Association, choices_Association ] := Enclose[
    Module[ { uuid, json, chosen, string, image, request, response },
        CurrentValue[ nbo, { TaggingRules, "Status" } ] = "Submitting";

        uuid = Replace[ CurrentValue[ cell, { TaggingRules, "FeedbackUUID" } ], Except[ _? StringQ ] :> Null ];

        json   = ConfirmBy[ toJSON @ Evaluate @ KeyDrop[ data, { "Image" } ], AssociationQ, "JSONData" ];
        chosen = ConfirmBy[ filterChoices[ json, choices ], AssociationQ, "Filtered" ];

        string = ConfirmBy[
            Developer`WriteRawJSONString[
                KeySort @ KeyDrop[
                    <|
                        chosen,
                        "Choices"   -> choices,
                        "Overwrite" -> uuid
                    |>,
                    "CellImage"
                ],
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

        checkResponse[ cell, nbo, response ]
    ],
    throwInternalFailure[ sendDialogFeedback[ nbo, data, choices ], ## ] &
];

sendDialogFeedback // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*contentID*)
contentID // beginDefinition;
contentID[ data_ ] := Hash[ data, Automatic, "HexString" ];
contentID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkResponse*)
checkResponse // beginDefinition;

checkResponse[ cell_CellObject, nbo_NotebookObject, response_HTTPResponse ] := Enclose[
    Module[ { bytes, string, data, code, uuid },
        bytes  = ConfirmBy[ response[ "BodyByteArray" ], ByteArrayQ, "Bytes" ];
        string = ConfirmBy[ ByteArrayToString @ bytes, StringQ, "String" ];
        data   = ConfirmBy[ Developer`ReadRawJSONString @ string, AssociationQ, "Data" ];
        code   = ConfirmBy[ response[ "StatusCode" ], IntegerQ, "StatusCode" ];
        checkResponse[ cell, nbo, data, code ]
    ],
    throwInternalFailure[ checkResponse[ cell, nbo, response ], ## ] &
];

checkResponse[ cell_CellObject, nbo_NotebookObject, data_Association, 200 ] := Enclose[
    Module[ { uuid },
        uuid = ConfirmBy[ data[ "RequestUUID" ], StringQ, "UUID" ];
        CurrentValue[ cell, { TaggingRules, "FeedbackUUID" } ] = uuid;
        CurrentValue[ nbo , { TaggingRules, "Status"       } ] = "Done";

        SessionSubmit @ ScheduledTask[ NotebookClose @ nbo, { 3 } ]
    ],
    throwInternalFailure[ checkResponse[ cell, nbo, data, 200 ], ## ] &
];

checkResponse[ cell_, nbo_, data_, code_ ] := Enclose[
    Module[ { text },
        text = ConfirmBy[ getErrorText[ data, code ], StringQ, "ErrorText" ];
        CurrentValue[ nbo, { TaggingRules, "ErrorText" } ] = text;
        CurrentValue[ nbo, { TaggingRules, "Status"    } ] = "Error";
    ],
    throwInternalFailure[ checkResponse[ cell, nbo, data, code ], ## ] &
];

checkResponse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayError*)
displayError // beginDefinition;

displayError[ nbo_NotebookObject ] :=
    CurrentValue[ nbo, { TaggingRules, "ErrorText" } ];

displayError // endDefinition;

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
                "Data"      -> StringToByteArray @ data
            },
            "Query"  -> <| "Version" -> IntegerString @ $feedbackClientVersion |>,
            "Method" -> "POST"
        |>
    ];

makeFeedbackRequest[ None, data_String ] :=
    HTTPRequest[
        CloudObject @ $feedbackURL,
        <|
            "Body"   -> { "Data" -> StringToByteArray @ data },
            "Query"  -> <| "Version" -> IntegerString @ $feedbackClientVersion |>,
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
            KeyValuePattern @ { "_Object" -> $$simpleDisplayObject, "Data" -> name_ } :> name
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

toJSON[ image_? graphicsQ ] :=
    imageJSON @ image;

toJSON[ RawBoxes @ TemplateBox[ { }, name_String ] ] :=
    <| "_Object" -> "NamedTemplateBox", "Data" -> name |>;

toJSON[ File[ file_String ] ] :=
    <| "_Object" -> "File", "Data" -> file |>;

toJSON[ URL[ uri_String ] ] /; StringStartsQ[ uri, "data:" ] :=
    With[ { expr = Quiet @ catchAlways @ importDataURI @ uri },
        toJSON @ expr /; ! FailureQ @ expr
    ];

toJSON[ URL[ url_String ] ] :=
    <| "_Object" -> "URL", "Data" -> url |>;

toJSON[ tokenizer_ ] :=
    With[ { name = tokenizerToName @ tokenizer },
        <| "_Object" -> "Tokenizer", "Data" -> name |> /; StringQ @ name
    ];

toJSON[ other_ ] := <|
    "_Object" -> "Expression",
    "Data"    -> toJSONObjectString @ Unevaluated @ other
|>;

toJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*imageJSON*)
imageJSON // beginDefinition;

imageJSON[ image_ ] := Enclose[
    Module[ { uri, raster, resized },
        uri = ConfirmBy[ toImageURI @ image, StringQ, "URI" ];
        If[ TrueQ[ StringLength @ uri < $maxJSONObjectSize ],
            <| "_Object" -> "Image", "Data" -> uri |>,
            raster  = ConfirmBy[ If[ image2DQ @ image, image, Rasterize @ image ], ImageQ, "Rasterize" ];
            resized = ConfirmBy[ ImageResize[ raster, Scaled[ 1/2 ] ], ImageQ, "Resize" ];
            imageJSON[ image ] = <|
                ConfirmMatch[
                    imageJSON @ Evaluate @ resized,
                    KeyValuePattern[ "_Object" -> "Image"|"ThumbnailImage" ],
                    "ResizedJSON"
                ],
                "_Object"            -> "ThumbnailImage",
                "OriginalDimensions" -> ImageDimensions @ raster
            |>
        ]
    ],
    throwInternalFailure[ imageJSON @ image, ## ] &
];

imageJSON // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toJSONObjectString*)
toJSONObjectString // beginDefinition;
toJSONObjectString[ expr_ ] := truncateString[ ToString[ Unevaluated @ expr, InputForm ], $maxJSONObjectSize ];
toJSONObjectString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenizerToName*)
tokenizerToName // beginDefinition;
tokenizerToName[ tokenizer_ ] := tokenizerToName[ tokenizer, cachedTokenizer @ All ];
tokenizerToName[ tokenizer_, KeyValuePattern[ name_String -> tokenizer_ ] ] := name;
tokenizerToName[ tokenizer_, _Association ] := Missing[ "NotFound" ];
tokenizerToName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolJSON*)
toolJSON // beginDefinition;

toolJSON[ tool: HoldPattern[ _LLMTool ] ] :=
    Module[ { names, name },
        names = AssociationMap[ Reverse, $DefaultTools ];
        name  = Lookup[ names, tool ];
        If[ StringQ @ name,
            <| "_Object" -> "DefaultTool", "Data" -> name |>,
            <| "_Object" -> "Expression" , "Data" -> toJSONObjectString @ tool |>
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
