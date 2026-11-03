(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*image*)
image // beginDefinition;

image[ str_String ] := First @ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> image[ alt, url ] ];

image[ alt_, url_String ] := Enclose[
    Module[ { keys, key },
        keys = ConfirmMatch[ Keys @ $attachments, { ___String? StringQ }, "Keys" ];
        key  = SelectFirst[ keys, StringContainsQ[ url, #1, IgnoreCase -> True ] & ];
        If[ StringQ @ key,
            Cell[
                BoxData @ markdownImageBoxes[
                    alt,
                    key,
                    Replace[ $attachments[ key ], HoldComplete[ expr_ ] :> expr ]
                ],
                Background -> None
            ],
            image[ alt, url, urlParse @ url ]
        ]
    ],
    throwInternalFailure
];

image[ alt_, url_, KeyValuePattern @ { "Scheme" -> "attachment"|"expression", "Domain" -> key_String } ] :=
    attachment[ alt, key ];

image[ alt_, url_, KeyValuePattern @ { "Scheme" -> "file", "Path" -> path_String } ] :=
    importedImage[ alt, path ];

image[ alt_, url_, _ ] :=
    importedImage[ alt, url ];

image // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*urlParse*)
urlParse // beginDefinition;
urlParse[ url_String ] := With[ { parsed = localParse @ url }, parsed /; AssociationQ @ parsed ];
urlParse[ url_String ] := URLParse @ url;
urlParse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*localParse*)
localParse // beginDefinition;

localParse[ uri_String ] /; StringStartsQ[ uri, ("attachment"|"file")~~"://" ] :=
    With[ { path = StringDelete[ uri, StartOfString ~~ ("attachment"|"file") ~~ "://" ] },
        <| "Scheme" -> "file", "Path" -> path |> /; FileExistsQ @ path
    ];

localParse[ uri_String ] :=
    Missing[ "NotAvailable" ];

localParse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachment*)
attachment // beginDefinition;
attachment[ alt_String, key_String ] := attachment[ alt, key, $attachments[ key ] ];
attachment[ alt_String, key_String, HoldComplete[ expr_ ] ] := attachment[ alt, key, Defer @ expr ];
attachment[ alt_String, key_String, _Missing ] := attachment[ alt, key, $missingImage ];

attachment[ alt_String, key_String, Defer[ img_Image ] ] /; ImageQ @ Unevaluated @ img :=
    Cell[ BoxData @ PaneBox[ attachmentBoxes[ alt, key, resizeImage @ img ], ImageMargins -> 10 ], Background -> None ];

attachment[ alt_String, key_String, expr_ ] /; $dynamicText :=
    codeBlockFrame[ Cell[ BoxData @ attachmentBoxes[ alt, key, expr ], "ChatCodeActive" ], expr ];

attachment[ alt_String, key_String, expr_ ] :=
    Module[ { boxes, display, handler },
        boxes = attachmentBoxes[ alt, key, expr ];
        display = RawBoxes @ Cell[
            BoxData @ boxes,
            "ChatCode",
            "Input",
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            TranslationOptions   -> {
                "Enabled" -> Dynamic @ AbsoluteCurrentValue[ $FrontEnd, { TranslationOptions, "Enabled" } ]
            }
        ];
        handler = inlineInteractiveCodeCell[ display, Cell[ BoxData @ cachedBoxes @ expr, "Input" ] ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, expr ]
    ];

attachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachmentBoxes*)
attachmentBoxes // beginDefinition;
attachmentBoxes[ alt_, key_String, expr_ ] := markdownImageBoxes[ StringTrim @ alt, "attachment://" <> key, expr ];
attachmentBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownImageBoxes*)
markdownImageBoxes // beginDefinition;

markdownImageBoxes[ ""|None, url_String, expr_ ] := PaneBox[
    TagBox[
        cachedBoxes @ expr,
        "MarkdownImage",
        AutoDelete   -> True,
        TaggingRules -> <| "CellToStringData" -> toMIBoxURI @ url |>
    ],
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

markdownImageBoxes[ alt_String, url_String, expr_ ] := PaneBox[
    TagBox[
        TooltipBox[ cachedBoxes @ expr, ToString[ alt, InputForm ] ],
        "MarkdownImage",
        AutoDelete   -> True,
        TaggingRules -> <| "CellToStringData" -> "![" <> alt <> "](" <> url <> ")" |>
    ],
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

markdownImageBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toMIBoxURI*)
toMIBoxURI // beginDefinition;

toMIBoxURI[ uri_String ] := Enclose[
    Catch @ Module[ { expr },

        expr = ConfirmMatch[
            catchAlways @ Quiet @ GetExpressionURI[ uri, HoldComplete ],
            HoldComplete[ _ ] | _Failure,
            "GetExpression"
        ];

        Replace[
            expr,
            {
                HoldComplete[ e_ ] :> ConfirmBy[ MakeExpressionURI @ Unevaluated @ e, StringQ, "URI" ],
                _Failure :> If[ StringQ @ URLParse[ uri, "Scheme" ], uri, "expression://"<>uri ]
            }
        ]
    ],
    throwInternalFailure
];

toMIBoxURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*importedImage*)
importedImage // beginDefinition;

importedImage[ alt_String, url_String ] :=
    importedImage[ alt, url, importImage @ url ];

importedImage[ alt_String, url_String, _? FailureQ | _String ] :=
    importedImage[ alt, url, $missingImage ];

importedImage[ alt_String, url_String, i_ ] :=
    Cell @ BoxData @ markdownImageBoxes[ StringTrim @ alt, url, tooltip[ resizeImage @ i, alt ] ];

importedImage // endDefinition;

$missingImage = RawBoxes @ TemplateBox[ { }, "ImageNotFound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importImage*)
importImage // beginDefinition;
importImage[ url_String ] := Lookup[
    $importedImageCache,
    url,
    addToCache[ $importedImageCache, $maxImportedImageCacheSize, url, importImage0 @ url ]
];
importImage // endDefinition;

$importedImageCache        = <| |>;
$maxImportedImageCacheSize = 50;

importImage0 // beginDefinition;
importImage0[ url_String ] := importImage0[ url, Quiet @ Import[ url, "Image" ] ];
importImage0[ url_, image: $$image ] := image;
importImage0[ url_String? cloudURLQ, _? FailureQ ] := Quiet @ Import[ CloudObject @ url, "Image" ];
importImage0[ _, failed_ ] := failed;
importImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cloudURLQ*)
cloudURLQ // beginDefinition;
cloudURLQ[ url_String ] := URLParse[ url, "Domain" ] === URLParse[ $CloudBase, "Domain" ];
cloudURLQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tooltip*)
tooltip // beginDefinition;
tooltip[ expr_, ""|"result" ] := expr;
tooltip[ expr_, text_ ] := Tooltip[ expr, text ];
tooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeImage*)
resizeImage // beginDefinition;
resizeImage[ img_ ] := resizeImage[ img, $dynamicText ];
resizeImage[ img_, dynamic_ ] := Lookup[
    $resizedImageCache,
    Key @ { img, dynamic },
    addToCache[ $resizedImageCache, $maxResizedImageCacheSize, { img, dynamic }, resizeImage0 @ img ]
];
resizeImage // endDefinition;

(* Twice as many entries as $importedImageCache, since each image can be shown both while streaming and after: *)
$resizedImageCache        = <| |>;
$maxResizedImageCacheSize = 100;


resizeImage0 // beginDefinition;

resizeImage0[ img: $$image ] :=
    resizeImage0[ img, ImageDimensions @ img ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] /; $dynamicText && Max @ dims > $maxDynamicImageSize :=
    showResized @ ImageResize[ img, { UpTo[ $maxDynamicImageSize ], UpTo[ $maxDynamicImageSize ] } ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] /; Max @ dims > $maxImageSize :=
    showResized @ ImageResize[ img, { UpTo @ $maxImageSize, UpTo @ $maxImageSize } ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] :=
    Show[ img, Options[ img, ImageSize ] ];

resizeImage0[ other_ ] :=
    other;

resizeImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showResized*)
showResized // beginDefinition;
showResized[ img: $$image ] := showResized[ img, targetImageSize @ img ];
showResized[ img_, { w_Integer, h_Integer } ] := Show[ img, ImageSize -> { UpTo @ w, UpTo @ h } ];
showResized[ img_ ] := img;
showResized // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*targetImageSize*)
targetImageSize // beginDefinition;
targetImageSize[ img: $$image ] /; $dynamicText := Ceiling[ (ImageDimensions @ img / 2) / $dynamicImageScale ];
targetImageSize[ img: $$image ] := Ceiling[ ImageDimensions @ img / 2 ];
targetImageSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedBoxes*)
cachedBoxes // beginDefinition;

cachedBoxes[ e: _Manipulate|_DynamicModule|_Dynamic ] :=
    checkBoxes @ MakeBoxes @ e;

cachedBoxes[ e_ ] :=
    With[ { h = Hash @ Unevaluated @ e },
        Lookup[ $boxCache, h, addToCache[ $boxCache, $maxBoxCacheSize, h, checkBoxes @ MakeBoxes @ e ] ]
    ];

cachedBoxes // endDefinition;

$boxCache        = <| |>;
$maxBoxCacheSize = 100;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBoxes*)
checkBoxes // beginDefinition;
checkBoxes[ e_ ] /; $CloudEvaluation && ! FreeQ[ e, _RasterBox ] := embeddedHTMLBoxes @ e;
checkBoxes[ e_ ] := e;
checkBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*embeddedHTMLBoxes*)
embeddedHTMLBoxes // beginDefinition;

embeddedHTMLBoxes[ boxes_ ] := Enclose[
    Module[ { id, dynamic },
        id = ConfirmBy[ createBoxCacheReference @ boxes, IntegerQ, "ID" ];

        dynamic = With[ { id = id, missing = $missingImage, waiting = $waiting },
            DynamicModule[ { b64, display },
                Dynamic @ Replace[ display, Except[ _RawBoxes ] -> waiting ],
                Initialization :> (
                    If[ TrueQ @ $dynamicText,
                        Null,
                        If[ ! StringQ @ b64, b64 = getBase64 @ id ];
                        display = Replace[ displayBase64Boxes @ b64, Except[ _RawBoxes ] :> missing ]
                    ]
                ),
                SynchronousInitialization -> False,
                UnsavedVariables :> { display }
            ]
        ];

        TagBox[ ToBoxes @ dynamic, "DynamicEmbeddedHTMLBoxes" ]
    ],
    throwInternalFailure
];

embeddedHTMLBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createBoxCacheReference*)
createBoxCacheReference // beginDefinition;
createBoxCacheReference[ boxes_ ] := With[ { id = Hash @ boxes }, $boxQueueCache[ id ] = boxes; id ];
createBoxCacheReference // endDefinition;

$boxQueueCache      = <| |>;
$base64Cache        = <| |>;
$maxBase64CacheSize = 100;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getBase64*)
getBase64 // beginDefinition;

getBase64[ id_ ] := getBase64[ id, $base64Cache[ id ] ];
getBase64[ id_, b64_String ] := b64;
getBase64[ id_, m_Missing ] := getBase64[ id, m, $boxQueueCache[ id ] ];
getBase64[ id_, _, _Missing ] := Missing[ "NotAvailable" ];

getBase64[ id_, _, boxes_ ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ RawBoxes @ boxes, PerformanceGoal -> "Size" ] },
        addToCache[ $base64Cache, $maxBase64CacheSize, id, b64 ];
        KeyDropFrom[ $boxQueueCache, id ];
        b64
    ];

getBase64 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayBase64Boxes*)
displayBase64Boxes // beginDefinition;

(* Boxes that were already decoded are shown even while streaming: *)
displayBase64Boxes[ b64_String ] /; $dynamicText && ! KeyExistsQ[ $decodedBase64Cache, b64 ] := $waiting;

displayBase64Boxes[ b64_String ] := Lookup[
    $decodedBase64Cache,
    b64,
    Enclose[
        Module[ { bytes, boxes, display },
            bytes = ConfirmBy[ BaseDecode @ b64, ByteArrayQ, "Bytes" ];
            boxes = ConfirmMatch[ BinaryDeserialize @ bytes, _RawBoxes, "Boxes" ];
            display = If[ TrueQ @ $CloudEvaluation, cloudEmbeddedHTMLImage @ boxes, boxes ];
            addToCache[
                $decodedBase64Cache,
                $maxDecodedBase64CacheSize,
                b64,
                ConfirmMatch[ display, _RawBoxes, "Display" ]
            ]
        ],
        throwInternalFailure
    ]
];

displayBase64Boxes[ _ ] := $waiting;

displayBase64Boxes // endDefinition;

$decodedBase64Cache        = <| |>;
$maxDecodedBase64CacheSize = 100;


$waiting := $waiting = RawBoxes @ ToBoxes @ Panel[
    ProgressIndicator[ Appearance -> "Necklace" ],
    ImageSize -> { 150, 150 },
    Alignment -> { Center, Center }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudEmbeddedHTMLImage*)
cloudEmbeddedHTMLImage // beginDefinition;

cloudEmbeddedHTMLImage[ expr_ ] := Enclose[
    usingFrontEnd @ Module[ { raster, size, resized, b64, width, height, embedSize, html, boxes },

        raster = ConfirmBy[ rasterize[ expr, ImageResolution -> 144 ], image2DQ, "Raster" ];
        size = Max @ ConfirmMatch[ ImageDimensions @ raster, { _, _ }, "OriginalDimensions" ];
        resized = If[ size > 1000, ImageResize[ raster, { UpTo[ 1000 ], UpTo[ 1000 ] } ], raster ];
        b64 = ConfirmBy[ exportDataURI[ resized, "JPEG" ], StringQ, "Base64" ];
        { width, height } = Round[ ConfirmMatch[ ImageDimensions @ resized, { _, _ }, "Dimensions" ] / 2 ];
        embedSize = { width, height + 12 };

        html = ConfirmBy[
            TemplateApply[ $embeddedImageTemplate, { b64, width, height } ],
            StringQ,
            "HTML"
        ];

        boxes = ToBoxes @ EmbeddedHTML[ html, ImageSize -> embedSize ];
        RawBoxes @ TagBox[ boxes, "CloudEmbeddedHTMLImage" ]
    ],
    throwInternalFailure
];

cloudEmbeddedHTMLImage // endDefinition;


$embeddedImageTemplate = "<div style=\"margin: -8px;\"><img src=\"`1`\" width=\"`2`\" height=\"`3`\"></div>";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
