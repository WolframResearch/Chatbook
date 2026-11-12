(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* Patterns and helpers used by the tests below. Markdown images become an inline cell holding
       PaneBox[ TagBox[ TooltipBox[ content, alt ], "MarkdownImage", AutoDelete -> True, TaggingRules -> <| ... |> ] ]
   The "CellToStringData" tagging rule is the markdown that CellToString gives for the image, and the tooltip shows the
   alt text. Images without alt text have no tooltip. *)
VerificationTest[
    (* Serialization.wl reads the "CellToStringData" tagging rule and Explode.wl matches the PaneBox[ TagBox[ ... ] ]
       shape. Other options are allowed, since they would not change the appearance or serialization: *)
    imgTagged[ content_, md_ ] := TagBox[
        content,
        "MarkdownImage",
        OrderlessPatternSequence[ AutoDelete -> True, TaggingRules -> KeyValuePattern[ "CellToStringData" -> md ], ___ ]
    ];

    imgPane[ boxes_ ] := PaneBox[ boxes, OrderlessPatternSequence[ ImageMargins -> { { 0, 0 }, { 10, 10 } }, ___ ] ];

    imgBoxes[ content_, None, md_ ] := imgPane @ imgTagged[ content, md ];
    imgBoxes[ content_, alt_String, md_ ] :=
        imgPane @ imgTagged[ TooltipBox[ content, ToString[ alt, InputForm ], ___ ], md ];

    (* The options of the inline cell (currently Background -> None for attachments and nothing for imported images)
       are incidental: *)
    imgCell[ content_, alt_, md_ ] := Cell[ BoxData @ imgBoxes[ content, alt, md ], ___ ];

    (* Content patterns: a raster image (from a file or an Image value) and the "image not found" placeholder. Imported
       images currently get a second, inner tooltip with the same text, which these patterns allow: *)
    imgRasterQ[ boxes_ ] := ! FreeQ[ boxes, _RasterBox ];
    imgNotFoundQ[ boxes_ ] := ! FreeQ[ boxes, TemplateBox[ { }, "ImageNotFound" ] ];

    (* The boxes of { 1, 2, 3 }, which most attachment tests use as the attached expression: *)
    $imgList = RowBox @ { "{", RowBox @ { "1", ",", "2", ",", "3" }, "}" };

    (* When the URL contains a known attachment key, CellToStringData currently has the bare key instead of the URL the
       model wrote. Both forms are allowed, since either one can be read back by GetExpressionURI: *)
    imgKeyMD[ alt_String ] := imgKeyMD[ alt, "content-abc12" ];
    imgKeyMD[ alt_String, key_String ] := imgKeyMD[ alt, key, "attachment" ];
    imgKeyMD[ alt_String, key_String, scheme_String ] :=
        Alternatives[ "![" <> alt <> "](" <> scheme <> "://" <> key <> ")", "![" <> alt <> "](" <> key <> ")" ];

    $imgSmallImage = Image[ ConstantArray[ 0.5, { 10, 20 } ] ];

    $imgAttachments = <|
        "content-abc12" -> HoldComplete[ { 1, 2, 3 } ],
        "content-img01" -> HoldComplete @@ { $imgSmallImage }
    |>;

    (* Formats markdown with known attachments. The streaming result cell cache is reset so that each test is
       independent. $CloudBase is set because missing images currently issue URLParse::invuri when it is Automatic
       (see cloudURLQ): *)
    imgFormat[ md_String ] := imgFormat[ md, "Finished" ];
    imgFormat[ md_String, status_String ] := imgFormat[ md, status, $imgAttachments ];
    imgFormat[ md_String, status_String, attachments_Association ] :=
        Block[
            {
                Wolfram`Chatbook`Common`$attachments     = attachments,
                Wolfram`Chatbook`Common`$resultCellCache = <| |>,
                $CloudBase                               = "https://www.wolframcloud.com/"
            },
            FormatMarkdown[ md, status ]
        ];

    imgRoundTrip[ md_String ] := imgRoundTrip[ md, "Finished" ];
    imgRoundTrip[ md_String, status_String ] :=
        Block[
            {
                Wolfram`Chatbook`Common`$attachments     = $imgAttachments,
                Wolfram`Chatbook`Common`$resultCellCache = <| |>,
                $CloudBase                               = "https://www.wolframcloud.com/"
            },
            MarkdownRoundTrip[ md, status ]
        ];

    (* Runs f[ uri ] with a fresh attachment store, where uri is a real expression URI made by MakeExpressionURI: *)
    imgWithURI[ expr_, f_ ] :=
        Block[
            {
                Wolfram`Chatbook`Common`$attachments     = <| |>,
                Wolfram`Chatbook`Common`$resultCellCache = <| |>
            },
            f @ MakeExpressionURI @ expr
        ];

    imgKey[ uri_String ] := First @ StringCases[ uri, "content-" ~~ (LetterCharacter|DigitCharacter).. ];

    (* The serialized forms allowed for a formatted expression URI with alt text: the URI itself, or the same with the
       bare key (see imgKeyMD): *)
    imgURIMD[ uri_String ] := uri | StringReplace[ uri, "](" ~~ LetterCharacter.. ~~ "://" -> "](" ];

    (* The pixel dimensions { width, height } of the first raster and the first ImageSize setting in some boxes: *)
    imgDims[ boxes_ ] := FirstCase[ boxes, RasterBox[ data_, ___ ] :> Reverse @ Take[ Dimensions @ data, 2 ], Missing[ ], Infinity ];
    imgSize[ boxes_ ] := FirstCase[ boxes, HoldPattern[ ImageSize -> size_ ] :> size, Missing[ ], Infinity ];

    (* Image sizes that display the raster at its own size (currently ImageSize -> Automatic, from Show[ img,
       Options[ img, ImageSize ] ]; boxes without an ImageSize look the same), and sizes that display it at w x h: *)
    $imgNaturalSize = Automatic | _Missing;
    imgShownAt[ { w_Integer, h_Integer } ] := { UpTo[ w ], UpTo[ h ] } | { w, h };

    (* Image files on disk. The directory is unique, since imported images are cached by path for the session: *)
    $imgDir = CreateDirectory[ ];
    imgFile[ name_String, { w_Integer, h_Integer } ] :=
        Export[ FileNameJoin @ { $imgDir, name <> ".png" }, Image[ ConstantArray[ 0.5, { h, w } ] ] ];

    $imgSmallFile    = imgFile[ "small"   , { 20  , 10  } ];
    $imgMediumFile   = imgFile[ "medium"  , { 250 , 300 } ];
    $imgLargeFile    = imgFile[ "large"   , { 1000, 900 } ];
    $imgMaxFile      = imgFile[ "max"     , { 800 , 10  } ];
    $imgOverMaxFile  = imgFile[ "overmax" , { 801 , 10  } ];
    $imgMissingFile  = FileNameJoin @ { $imgDir, "missing.png" };

    FileExistsQ /@ { $imgSmallFile, $imgMediumFile, $imgLargeFile, $imgMaxFile, $imgOverMaxFile, $imgMissingFile },
    { True, True, True, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "Images-Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Attachments*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Basic*)

(* A markdown image whose URL refers to a key of $attachments shows the boxes of the attached expression, with the alt
   text as a tooltip: *)
VerificationTest[
    imgFormat[ "![alt](attachment://content-abc12)" ],
    { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Finished"
]

(* The streaming display is the same: *)
VerificationTest[
    imgFormat[ "![alt](attachment://content-abc12)", "Streaming" ],
    { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Streaming"
]

(* Attached Image values are shown as images: *)
VerificationTest[
    imgFormat[ "![pic](attachment://content-img01)" ],
    { imgCell[ _? imgRasterQ, "pic", imgKeyMD[ "pic", "content-img01" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Image-Value"
]

(* The attachment store normally holds HoldComplete[ expr ], but values that are not held work too: *)
VerificationTest[
    imgFormat[ "![alt](attachment://content-abc12)", "Finished", <| "content-abc12" -> { 1, 2, 3 } |> ],
    { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Unheld-Value"
]

(* An attachment is found by looking for any known key in the URL, ignoring case. So the scheme does not matter, a bare
   key works, and so do URLs that models mangle, e.g. by adding a file extension: *)
VerificationTest[
    imgFormat /@ {
        "![alt](expression://content-abc12)",
        "![alt](dynamic://content-abc12)",
        "![alt](attachment://CONTENT-ABC12)",
        "![alt](content-abc12)",
        "![alt](attachment://content-abc12.png)"
    },
    {
        { imgCell[ $imgList, "alt", imgKeyMD[ "alt", "content-abc12", "expression" ] ] },
        { imgCell[ $imgList, "alt", imgKeyMD[ "alt", "content-abc12", "dynamic" ] ] },
        { imgCell[ $imgList, "alt", imgKeyMD[ "alt", "CONTENT-ABC12" ] | imgKeyMD[ "alt" ] ] },
        { imgCell[ $imgList, "alt", "![alt](content-abc12)" ] },
        { imgCell[ $imgList, "alt", "![alt](attachment://content-abc12.png)" | "![alt](content-abc12)" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Key-Anywhere-In-URL"
]

(* Formatted attachments serialize back to the markdown image: *)
VerificationTest[
    {
        imgRoundTrip[ "![alt](attachment://content-abc12)" ],
        imgRoundTrip[ "![alt](attachment://content-abc12)", "Streaming" ],
        imgRoundTrip[ "![pic](attachment://content-img01)" ]
    },
    { imgKeyMD[ "alt" ], imgKeyMD[ "alt" ], imgKeyMD[ "pic", "content-img01" ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Round-Trip"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Empty Alt Text*)

(* An image without alt text has no tooltip, and it serializes as the canonical expression URI of the attached
   expression (with a generated label and the scheme for the type of expression): *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri, { uri, FormatMarkdown[ "![](attachment://" <> imgKey @ uri <> ")" ] } ]
    ],
    { uri_String, { imgCell[ $imgList, None, uri_ ] } } /; StringStartsQ[ uri, "![Data](expression://content-" ],
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Empty-Alt"
]

VerificationTest[
    imgWithURI[
        $imgSmallImage,
        Function[ uri, { uri, FormatMarkdown[ "![](expression://" <> imgKey @ uri <> ")" ] } ]
    ],
    { uri_String, { imgCell[ _? imgRasterQ, None, uri_ ] } } /; StringStartsQ[ uri, "![Image](attachment://content-" ],
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Empty-Alt-Image"
]

VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri, { uri, MarkdownRoundTrip[ "![](attachment://" <> imgKey @ uri <> ")" ] } ]
    ],
    { uri_String, uri_String },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Empty-Alt-Round-Trip"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Real Expression URIs*)

(* URIs made by MakeExpressionURI (as tool results are) are shown as the expression and serialize back to the same
   label and key: *)
VerificationTest[
    imgWithURI[ { 1, 2, 3 }, Function[ uri, { uri, FormatMarkdown @ uri, MarkdownRoundTrip @ uri } ] ],
    { uri_String, formatted_, rt_ } /; And[
        StringMatchQ[ uri, "![Data](expression://content-" ~~ Repeated[ LetterCharacter|DigitCharacter, { 5 } ] ~~ ")" ],
        MatchQ[ formatted, { imgCell[ $imgList, "Data", imgURIMD @ uri ] } ],
        MatchQ[ rt, imgURIMD @ uri ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Real-Expression-URI"
]

VerificationTest[
    imgWithURI[
        $imgSmallImage,
        Function[ uri, { uri, FormatMarkdown @ uri, FormatMarkdown[ uri, "Streaming" ], MarkdownRoundTrip @ uri } ]
    ],
    { uri_String, formatted_, streaming_, rt_ } /; And[
        StringStartsQ[ uri, "![Image](attachment://content-" ],
        MatchQ[ formatted, { imgCell[ _? imgRasterQ, "Image", imgURIMD @ uri ] } ],
        MatchQ[ streaming, { imgCell[ _? imgRasterQ, "Image", imgURIMD @ uri ] } ],
        MatchQ[ rt, imgURIMD @ uri ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Real-Image-URI"
]

(* Graphics (e.g. plots from the evaluator tool) are the most common attachments. They are shown as their own boxes,
   keeping their ImageSize, on a line between the surrounding paragraphs: *)
VerificationTest[
    imgWithURI[
        Graphics[ Disk[ ], ImageSize -> 50 ],
        Function[ uri,
            {
                uri,
                NormalizeTextData @ FormatMarkdown[ "Here is the plot:\n\n" <> uri <> "\n\nDone." ],
                MarkdownRoundTrip @ uri
            }
        ]
    ],
    { uri_String, formatted_, rt_ } /; And[
        StringStartsQ[ uri, "![Image](attachment://content-" ],
        MatchQ[
            formatted,
            {
                "Here is the plot:\n",
                imgCell[ GraphicsBox[ DiskBox[ { 0, 0 } ], ImageSize -> 50 ], "Image", imgURIMD @ uri ],
                "\nDone."
            }
        ],
        MatchQ[ rt, imgURIMD @ uri ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Real-Graphics-URI"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing Attachments*)

(* An attachment URI whose key is unknown (e.g. from a previous kernel session) shows the "image not found" placeholder
   with the alt text, and its tagging rules keep the original markdown. This only checks the image boxes: they are
   currently wrapped in a Wolfram Language code block frame, which looks and serializes wrong (reported as a quirk): *)
VerificationTest[
    FirstCase[
        imgFormat[ #1 ],
        imgTagged[ TooltipBox[ _? imgNotFoundQ, "\"alt\"" ], #2 ],
        $Failed,
        Infinity
    ] & @@@ {
        { "![alt](attachment://content-zzz99)", "![alt](attachment://content-zzz99)" },
        { "![alt](expression://content-zzz99)", "![alt](attachment://content-zzz99)" | "![alt](expression://content-zzz99)" }
    },
    { _TagBox, _TagBox },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Missing-Key"
]

VerificationTest[
    FirstCase[
        imgFormat[ "![alt](attachment://content-zzz99)", "Streaming" ],
        imgTagged[ TooltipBox[ _? imgNotFoundQ, "\"alt\"" ], "![alt](attachment://content-zzz99)" ],
        $Failed,
        Infinity
    ],
    _TagBox,
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Missing-Key-Streaming"
]

(* Other schemes are not looked up as attachments, so a missing key is treated like a missing file: *)
VerificationTest[
    imgFormat[ "![alt](dynamic://content-zzz99)" ],
    { imgCell[ _? imgNotFoundQ, "alt", "![alt](dynamic://content-zzz99)" ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Missing-Key-Other-Scheme"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Box Cache*)

(* The boxes of attached expressions are cached by the hash of the expression, so an expression that is shown again
   reuses its boxes: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| Hash[ { 1, 2, 3 } ] -> "CACHED" |> },
        imgFormat[ "![alt](attachment://content-abc12)" ]
    ],
    { imgCell[ "CACHED", "alt", imgKeyMD[ "alt" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Uses-Box-Cache"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| |> },
        imgFormat[ "![alt](attachment://content-abc12)" ];
        Wolfram`Chatbook`Formatting`Private`$boxCache
    ],
    <| Hash[ { 1, 2, 3 } ] -> $imgList |>,
    SameTest -> MatchQ,
    TestID   -> "Images-Attachment-Fills-Box-Cache"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Image Syntax*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Alt Text*)

(* Alt text can contain brackets that are not followed by a URL: *)
VerificationTest[
    {
        imgFormat[ "![a [b] c](attachment://content-abc12)" ],
        imgFormat[ "![[x]](attachment://content-abc12)" ]
    },
    {
        { imgCell[ $imgList, "a [b] c", imgKeyMD[ "a [b] c" ] ] },
        { imgCell[ $imgList, "[x]", imgKeyMD[ "[x]" ] ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Alt-With-Brackets"
]

(* The tooltip shows the alt text as a string box, so quotes are escaped there, while the serialized markdown keeps
   the alt text as written: *)
VerificationTest[
    imgFormat[ "![say \"hi\"](attachment://content-abc12)" ],
    {
        Cell[
            BoxData @ imgPane @ imgTagged[
                TooltipBox[ $imgList, "\"say \\\"hi\\\"\"", ___ ],
                imgKeyMD[ "say \"hi\"" ]
            ],
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Alt-With-Quotes"
]

VerificationTest[
    {
        imgFormat[ "![\[Pi] \[TildeTilde] 3.14 \[LongDash] \:0433\:0440\:0430\:0444\:0438\:043a\:0430](attachment://content-abc12)" ],
        imgRoundTrip[ "![\[Pi] \[TildeTilde] 3.14 \[LongDash] \:0433\:0440\:0430\:0444\:0438\:043a\:0430](attachment://content-abc12)" ]
    },
    {
        {
            imgCell[
                $imgList,
                "\[Pi] \[TildeTilde] 3.14 \[LongDash] \:0433\:0440\:0430\:0444\:0438\:043a\:0430",
                imgKeyMD[ "\[Pi] \[TildeTilde] 3.14 \[LongDash] \:0433\:0440\:0430\:0444\:0438\:043a\:0430" ]
            ]
        },
        imgKeyMD[ "\[Pi] \[TildeTilde] 3.14 \[LongDash] \:0433\:0440\:0430\:0444\:0438\:043a\:0430" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Alt-Unicode"
]

(* Markdown escapes in the alt text are removed, in both the tooltip and the serialized markdown: *)
VerificationTest[
    NormalizeTextData @ imgFormat[ "Some \\* text ![a\\_b](attachment://content-abc12)" ],
    { "Some * text ", imgCell[ $imgList, "a_b", imgKeyMD[ "a_b" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Alt-Markdown-Escapes"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)

(* Images can be inline in a sentence: *)
VerificationTest[
    NormalizeTextData @ imgFormat[ "Here is ![alt](attachment://content-abc12) inline." ],
    { "Here is ", imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ], " inline." },
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-In-Sentence"
]

VerificationTest[
    NormalizeTextData @ imgFormat[ "![a](attachment://content-abc12) ![b](attachment://content-abc12)" ],
    { imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], " ", imgCell[ $imgList, "b", imgKeyMD[ "b" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Two-On-One-Line"
]

(* An image on its own line between paragraphs is separated from them by single line breaks (the pane adds vertical
   margins): *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "Before\n\n![a](attachment://content-abc12)\n\nAfter" ],
        imgFormat[ "Before\n![a](attachment://content-abc12)\nAfter" ],
        imgFormat[ "Before\n\n![a](attachment://content-abc12)\n\nAfter", "Streaming" ]
    },
    {
        { "Before\n", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], "\nAfter" },
        { "Before\n", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], "\nAfter" },
        { "Before\n", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], "\nAfter" }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Own-Line-Between-Paragraphs"
]

(* The serialized image is on its own line. Any whitespace is allowed around it, since the blank lines are currently
   reduced to single line breaks (reported as a quirk): *)
VerificationTest[
    imgRoundTrip[ "Before\n\n![a](attachment://content-abc12)\n\nAfter" ],
    s_String /; StringMatchQ[
        s,
        StringExpression[
            "Before",
            " "...,
            "\n",
            WhitespaceCharacter...,
            "![a](",
            "attachment://"|"",
            "content-abc12)",
            " "...,
            "\n",
            WhitespaceCharacter...,
            "After"
        ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Own-Line-Round-Trip"
]

(* Images next to other blocks: *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "## Heading\n![a](attachment://content-abc12)" ],
        imgFormat[ "![a](attachment://content-abc12)\n## Heading\nText" ],
        imgFormat[ "![a](attachment://content-abc12)\n* one\n* two" ]
    },
    {
        {
            Cell[ BoxData @ PaneBox[ StyleBox[ "\"Heading\"", "Section", ___ ], ___ ], "InlineSection", ___ ],
            "\n",
            imgCell[ $imgList, "a", imgKeyMD[ "a" ] ]
        },
        {
            imgCell[ $imgList, "a", imgKeyMD[ "a" ] ],
            "\n",
            Cell[ BoxData @ PaneBox[ StyleBox[ "\"Heading\"", "Section", ___ ], ___ ], "InlineSection", ___ ],
            "\nText"
        },
        {
            imgCell[ $imgList, "a", imgKeyMD[ "a" ] ],
            "\n",
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " one" }, "InlineItem" ],
            "\n",
            Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " two" }, "InlineItem" ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Next-To-Blocks"
]

VerificationTest[
    NormalizeTextData @ imgFormat[ "```wl\n1+1\n```\n![a](attachment://content-abc12)" ],
    { Cell[ _, "ChatCodeBlock", ___ ], "\n", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ] },
    SameTest -> MatchQ,
    TestID   -> "Images-After-Code-Block"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Inside Other Constructs*)

(* Images inside list items, headings, table cells and block quotes (these are formatted by the inline formatting
   rules rather than the block level ones): *)
VerificationTest[
    NormalizeTextData @ imgFormat[ "* item ![alt](attachment://content-abc12)" ],
    {
        Cell[
            TextData @ { StyleBox[ "\[Bullet]", ___ ], " item ", imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] },
            "InlineItem"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-List-Item"
]

VerificationTest[
    NormalizeTextData @ imgFormat[ "* a\n  * ![alt](attachment://content-abc12)" ],
    {
        Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " a" }, "InlineItem" ],
        "\n",
        Cell[
            TextData @ { "  ", StyleBox[ "\[Bullet]", ___ ], " ", imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] },
            "InlineSubitem"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-List-Subitem"
]

VerificationTest[
    imgFormat[ "## Title ![a](attachment://content-abc12)" ],
    {
        Cell[
            BoxData @ PaneBox[
                StyleBox[
                    Cell[ TextData @ { "Title ", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ] }, ___ ],
                    "Section",
                    ___
                ],
                ___
            ],
            "InlineSection",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-Heading"
]

(* The image is the first entry of a two-column table row (the table structure itself is tested in
   FormattingTables.wlt): *)
VerificationTest[
    imgFormat[ "| a | b |\n|---|---|\n| ![x](attachment://content-abc12) | 2 |" ],
    {
        Cell[
            _? (! FreeQ[ #, { imgCell[ $imgList, "x", imgKeyMD[ "x" ] ] | imgBoxes[ $imgList, "x", imgKeyMD[ "x" ] ], _ } ] &),
            "TextTableForm",
            ___
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-Table-Cell"
]

VerificationTest[
    imgFormat[ "> ![x](attachment://content-abc12)" ],
    { Cell[ _? (! FreeQ[ #, imgBoxes[ $imgList, "x", imgKeyMD[ "x" ] ] ] &), "BlockQuote", ___ ] },
    SameTest -> MatchQ,
    TestID   -> "Images-In-Block-Quote"
]

(* Numbered list items are plain text, so the image is inline after the number: *)
VerificationTest[
    NormalizeTextData @ imgFormat[ "1. ![a](attachment://content-abc12)\n2. two" ],
    { "1. ", imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], "\n2. two" },
    SameTest -> MatchQ,
    TestID   -> "Images-In-Numbered-List"
]

(* Inside list items the image rule comes before the hyperlink rule, so an image next to a link in the same item is
   still an image, and the link is still a link: *)
VerificationTest[
    NormalizeTextData @ imgFormat[ "* see ![a](attachment://content-abc12) and [docs](https://example.com)" ],
    {
        Cell[
            TextData @ {
                StyleBox[ "\[Bullet]", ___ ],
                " see ",
                imgCell[ $imgList, "a", imgKeyMD[ "a" ] ],
                " and ",
                ButtonBox[ "docs", OrderlessPatternSequence[ ButtonData -> { URL[ "https://example.com" ], None }, ___ ] ]
            },
            "InlineItem"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-List-Item-With-Link"
]

(* Image syntax inside inline code is code, not an image: *)
VerificationTest[
    With[ { result = imgFormat[ "Use `![a](attachment://content-abc12)` to show it" ] },
        { FreeQ[ result, "MarkdownImage" ], NormalizeTextData @ result }
    ],
    {
        True,
        {
            "Use ",
            Cell[
                BoxData @ TemplateBox[ { Cell[ "![a](attachment://content-abc12)", ___ ] }, "ChatCodeInlineTemplate" ],
                ___
            ],
            " to show it"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-In-Inline-Code"
]

(* Images inside these constructs serialize back to the markdown image in place: *)
VerificationTest[
    {
        imgRoundTrip[ "* item ![alt](attachment://content-abc12)" ],
        imgRoundTrip[ "## Title ![a](attachment://content-abc12)" ],
        imgRoundTrip[ "> ![x](attachment://content-abc12)" ],
        imgRoundTrip[ "| a | b |\n|---|---|\n| ![x](attachment://content-abc12) | 2 |" ]
    },
    {
        ("* item " <> # &) /@ imgKeyMD[ "alt" ],
        ("## Title " <> # &) /@ imgKeyMD[ "a" ],
        ("> " <> # &) /@ imgKeyMD[ "x" ],
        s_String /; StringMatchQ[
            s,
            "| a" ~~ ___ ~~ "\n" ~~ ___ ~~ "\n| ![x](" ~~ ("attachment://"|"") ~~ "content-abc12) | 2 |"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Inside-Constructs-Round-Trip"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Incomplete Syntax*)

(* Incomplete image syntax stays as text, both while streaming and when finished: *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "Look ![alt](attachment://content-abc1", "Streaming" ],
        imgFormat[ "Look ![alt](attachment://content-abc1", "Finished" ],
        imgFormat[ "Look ![al", "Streaming" ],
        imgFormat[ "Look ![alt]", "Streaming" ]
    },
    {
        { "Look ![alt](attachment://content-abc1" },
        { "Look ![alt](attachment://content-abc1" },
        { "Look ![al" },
        { "Look ![alt]" }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Incomplete-Syntax"
]

(* The same for an inline URI that is not closed yet, even when its key is known: *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "See <!attachment://content-ab", "Streaming" ],
        imgFormat[ "See <!attachment://content-abc12", "Streaming" ],
        imgFormat[ "See <!attachment://content-abc12!", "Streaming" ]
    },
    {
        { "See <!attachment://content-ab" },
        { "See <!attachment://content-abc12" },
        { "See <!attachment://content-abc12!" }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Incomplete-Inline-URI"
]

(* An image that is not complete yet inside a list item or heading also stays as text while streaming: *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "* item ![alt](attachment://cont", "Streaming" ],
        imgFormat[ "## Title ![alt](att", "Streaming" ]
    },
    {
        { Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " item ![alt](attachment://cont" }, "InlineItem" ] },
        { Cell[ BoxData @ PaneBox[ StyleBox[ "\"Title ![alt](att\"", "Section", ___ ], ___ ], "InlineSection", ___ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Incomplete-Syntax-In-Constructs"
]

(* A complete image is shown while a later one is still incomplete: *)
VerificationTest[
    NormalizeTextData @ imgFormat[
        "![a](attachment://content-abc12)\n\nMore ![b](attach",
        "Streaming"
    ],
    { imgCell[ $imgList, "a", imgKeyMD[ "a" ] ], "\nMore ![b](attach" },
    SameTest -> MatchQ,
    TestID   -> "Images-Streaming-Complete-Then-Incomplete"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Image Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Local Files*)

(* A local file path is imported as an image. "file://" and "attachment://" URLs of existing local files work too: *)
VerificationTest[
    imgFormat /@ { "![small](" <> $imgSmallFile <> ")", "![small](file://" <> $imgSmallFile <> ")" },
    {
        { imgCell[ _? imgRasterQ, "small", "![small](" <> $imgSmallFile <> ")" ] },
        { imgCell[ _? imgRasterQ, "small", "![small](" <> $imgSmallFile <> ")" | "![small](file://" <> $imgSmallFile <> ")" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File"
]

VerificationTest[
    imgFormat[ "![small](attachment://" <> $imgSmallFile <> ")" ],
    {
        imgCell[
            _? imgRasterQ,
            "small",
            "![small](" <> $imgSmallFile <> ")" | "![small](attachment://" <> $imgSmallFile <> ")"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Attachment-Scheme"
]

VerificationTest[
    imgFormat[ "![small](" <> $imgSmallFile <> ")", "Streaming" ],
    { imgCell[ _? imgRasterQ, "small", "![small](" <> $imgSmallFile <> ")" ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Streaming"
]

(* Surrounding whitespace in the alt text is trimmed: *)
VerificationTest[
    imgFormat[ "![  spaced alt  ](" <> $imgSmallFile <> ")" ],
    { imgCell[ _? imgRasterQ, "spaced alt", "![spaced alt](" <> $imgSmallFile <> ")" ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Alt-Trimmed"
]

(* Without alt text there is no tooltip (the serialized form is not checked here, since it is currently wrong for
   files; reported as a quirk): *)
VerificationTest[
    imgFormat[ "![](" <> $imgSmallFile <> ")" ],
    { Cell[ BoxData @ imgPane @ TagBox[ _? imgRasterQ, "MarkdownImage", ___ ], ___ ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Empty-Alt"
]

VerificationTest[
    FreeQ[ imgFormat[ "![](" <> $imgSmallFile <> ")" ], _TooltipBox ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Empty-Alt-No-Tooltip"
]

VerificationTest[
    {
        imgRoundTrip[ "![small](" <> $imgSmallFile <> ")" ],
        imgRoundTrip[ "Text ![small](" <> $imgSmallFile <> ") more." ],
        imgRoundTrip[ "![small](file://" <> $imgSmallFile <> ")" ]
    },
    {
        "![small](" <> $imgSmallFile <> ")",
        "Text ![small](" <> $imgSmallFile <> ") more.",
        "![small](" <> $imgSmallFile <> ")" | "![small](file://" <> $imgSmallFile <> ")"
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Local-File-Round-Trip"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Missing Files*)

(* Images that can't be found are shown as the "image not found" placeholder, with the alt text as a tooltip, and they
   still serialize as the original markdown: *)
VerificationTest[
    imgFormat /@ {
        "![alt](" <> $imgMissingFile <> ")",
        "![alt](file://" <> $imgMissingFile <> ")",
        "![alt](attachment://" <> $imgMissingFile <> ")",
        "![alt](nonexistent-image.png)"
    },
    {
        { imgCell[ _? imgNotFoundQ, "alt", "![alt](" <> $imgMissingFile <> ")" ] },
        { imgCell[ _? imgNotFoundQ, "alt", "![alt](file://" <> $imgMissingFile <> ")" ] },
        { imgCell[ _? imgNotFoundQ, "alt", "![alt](attachment://" <> $imgMissingFile <> ")" ] },
        { imgCell[ _? imgNotFoundQ, "alt", "![alt](nonexistent-image.png)" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Missing-File"
]

VerificationTest[
    imgFormat[ "![alt](" <> $imgMissingFile <> ")", "Streaming" ],
    { imgCell[ _? imgNotFoundQ, "alt", "![alt](" <> $imgMissingFile <> ")" ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Missing-File-Streaming"
]

VerificationTest[
    {
        imgRoundTrip[ "![alt](" <> $imgMissingFile <> ")" ],
        imgRoundTrip[ "See ![alt](nonexistent-image.png) here" ]
    },
    { "![alt](" <> $imgMissingFile <> ")", "See ![alt](nonexistent-image.png) here" },
    SameTest -> MatchQ,
    TestID   -> "Images-Missing-File-Round-Trip"
]

VerificationTest[
    imgFormat[ "![](" <> $imgMissingFile <> ")" ],
    { Cell[ BoxData @ imgPane @ TagBox[ TemplateBox[ { }, "ImageNotFound" ], "MarkdownImage", ___ ], ___ ] },
    SameTest -> MatchQ,
    TestID   -> "Images-Missing-File-Empty-Alt"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Resizing*)

(* Images up to $maxImageSize (800) pixels are shown at their own size (the streaming case is the small image, which
   is under the streaming limit too): *)
VerificationTest[
    { imgDims @ #, imgSize @ # } & /@ {
        imgFormat[ "![a](" <> $imgSmallFile <> ")", "Finished" ],
        imgFormat[ "![a](" <> $imgSmallFile <> ")", "Streaming" ],
        imgFormat[ "![a](" <> $imgMediumFile <> ")", "Finished" ],
        imgFormat[ "![a](" <> $imgMaxFile <> ")", "Finished" ]
    },
    {
        { { 20, 10 }, $imgNaturalSize },
        { { 20, 10 }, $imgNaturalSize },
        { { 250, 300 }, $imgNaturalSize },
        { { 800, 10 }, $imgNaturalSize }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Resize-Small-Unchanged"
]

(* Larger images are downsampled to fit in 800 pixels and shown at half that size (so an 801 pixel wide image is shown
   400 pixels wide, while an 800 pixel wide one is shown at its own size): *)
VerificationTest[
    { imgDims @ #, imgSize @ # } & /@ {
        imgFormat[ "![a](" <> $imgLargeFile <> ")", "Finished" ],
        imgFormat[ "![a](" <> $imgOverMaxFile <> ")", "Finished" ]
    },
    {
        { { 800, 720 }, imgShownAt @ { 400, 360 } },
        { { 800, 10 }, imgShownAt @ { 400, 5 } }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Resize-Large"
]

(* While streaming, images are downsampled to fit in $maxDynamicImageSize (200, a quarter of $maxImageSize) pixels,
   which is cheaper to display. Large images are shown at the same size as when finished: *)
VerificationTest[
    { imgDims @ #, imgSize @ # } & @ imgFormat[ "![a](" <> $imgLargeFile <> ")", "Streaming" ],
    { { 200, 180 }, imgShownAt @ { 400, 360 } },
    SameTest -> MatchQ,
    TestID   -> "Images-Resize-Large-Streaming"
]

(* Only the streaming resolution is checked for medium sized images, since the size they are shown at while streaming
   currently differs from the finished size (reported as a quirk): *)
VerificationTest[
    imgDims @ imgFormat[ "![a](" <> $imgMediumFile <> ")", "Streaming" ],
    { w_, h_ } /; Max[ w, h ] <= 200,
    SameTest -> MatchQ,
    TestID   -> "Images-Resize-Medium-Streaming-Resolution"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Code Fences*)

(* A code fence whose whole content is a markdown image is shown as the image instead of a code block: *)
VerificationTest[
    imgFormat /@ {
        "```\n![alt](attachment://content-abc12)\n```",
        "```wl\n![alt](attachment://content-abc12)\n```",
        "```markdown\n![alt](attachment://content-abc12)\n```",
        "```\n\n![alt](attachment://content-abc12)\n\n```"
    },
    ConstantArray[ { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] }, 4 ],
    SameTest -> MatchQ,
    TestID   -> "Images-Code-Fence-Image"
]

(* Also while streaming, including a fence that is not closed yet: *)
VerificationTest[
    {
        imgFormat[ "```\n![alt](attachment://content-abc12)\n```", "Streaming" ],
        imgFormat[ "```\n![alt](attachment://content-abc12)", "Streaming" ]
    },
    ConstantArray[ { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ] }, 2 ],
    SameTest -> MatchQ,
    TestID   -> "Images-Code-Fence-Image-Streaming"
]

VerificationTest[
    {
        NormalizeTextData @ imgFormat[ "```\n![alt](attachment://content-abc12)\n```\nAfter" ],
        imgFormat[ "```\n![alt](" <> $imgSmallFile <> ")\n```" ]
    },
    {
        { imgCell[ $imgList, "alt", imgKeyMD[ "alt" ] ], "\nAfter" },
        { imgCell[ _? imgRasterQ, "alt", "![alt](" <> $imgSmallFile <> ")" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Code-Fence-Image-Variants"
]

(* It serializes as the image rather than as a code block: *)
VerificationTest[
    imgRoundTrip[ "```\n![alt](attachment://content-abc12)\n```" ],
    imgKeyMD[ "alt" ],
    SameTest -> MatchQ,
    TestID   -> "Images-Code-Fence-Image-Round-Trip"
]

(* Code with other content around an image is an ordinary code block: *)
VerificationTest[
    imgFormat[ "```\nx = 1\n![a](attachment://content-abc12)\n```" ],
    {
        Cell[
            BoxData @ TemplateBox[
                { Cell[ "x = 1\n![a](attachment://content-abc12)", "ChatPreformatted", ___ ], "" },
                "ChatCodeBlockTemplate"
            ],
            "ChatCodeBlock"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Code-Fence-Not-Only-Image"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Expression URIs*)

(* "<!scheme://content-xxxxx!>" shows an attachment inline. It has no alt text, so it has no tooltip and serializes as
   the canonical expression URI: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            {
                uri,
                NormalizeTextData @ FormatMarkdown[ "See <!attachment://" <> imgKey @ uri <> "!> here" ],
                NormalizeTextData @ FormatMarkdown[ "See <!attachment://" <> imgKey @ uri <> "!> here", "Streaming" ]
            }
        ]
    ],
    {
        uri_String,
        { "See ", imgCell[ $imgList, None, uri_ ], " here" },
        { "See ", imgCell[ $imgList, None, uri_ ], " here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI"
]

VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri, { uri, MarkdownRoundTrip[ "See <!attachment://" <> imgKey @ uri <> "!> here" ] } ]
    ],
    { uri_String, rt_String } /; rt === "See " <> uri <> " here",
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI-Round-Trip"
]

(* Any scheme of up to 20 letters is accepted: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            {
                uri,
                NormalizeTextData @ FormatMarkdown[ "<!expression://" <> imgKey @ uri <> "!>" ],
                NormalizeTextData @ FormatMarkdown[ "<!dynamic://" <> imgKey @ uri <> "!>" ],
                NormalizeTextData @ FormatMarkdown[ "<!attachment://" <> imgKey @ uri <> "!><!expression://" <> imgKey @ uri <> "!>" ]
            }
        ]
    ],
    {
        uri_String,
        { imgCell[ $imgList, None, uri_ ] },
        { imgCell[ $imgList, None, uri_ ] },
        { imgCell[ $imgList, None, uri_ ], imgCell[ $imgList, None, uri_ ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI-Schemes"
]

(* The key can have at most five characters after "content-" (the length of keys made by MakeExpressionURI), otherwise
   the text is left as is. Shorter keys are matched too, but keys made by MakeExpressionURI are never shorter, so they
   are unknown and hit the missing key failure reported as a quirk: *)
VerificationTest[
    NormalizeTextData /@ {
        imgFormat[ "See <!attachment://content-abc123!> here" ],
        imgFormat[ "See <!attachment://content-abc12x!> here", "Streaming" ]
    },
    {
        { "See <!attachment://content-abc123!> here" },
        { "See <!attachment://content-abc12x!> here" }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI-Key-Length"
]

(* Inline URIs inside list items and headings: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            {
                uri,
                NormalizeTextData @ FormatMarkdown[ "* see <!attachment://" <> imgKey @ uri <> "!>" ],
                FormatMarkdown[ "# see <!attachment://" <> imgKey @ uri <> "!>" ]
            }
        ]
    ],
    {
        uri_String,
        { Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " see ", imgCell[ $imgList, None, uri_ ] }, "InlineItem" ] },
        {
            Cell[
                BoxData @ PaneBox[
                    StyleBox[ Cell[ TextData @ { "see ", imgCell[ $imgList, None, uri_ ] }, ___ ], "Title", ___ ],
                    ___
                ],
                "InlineSection",
                ___
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI-In-List-And-Heading"
]

(* Some malformed variants that models write are corrected to the inline URI syntax before formatting, and the
   MarkdownImageBox escape that CellToString writes for images in input cells is replaced by the markdown image: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            {
                uri,
                NormalizeTextData @ FormatMarkdown[ "See <attachment://" <> imgKey @ uri <> "> here" ],
                NormalizeTextData @ FormatMarkdown[ "See !<attachment://" <> imgKey @ uri <> "!> here" ],
                NormalizeTextData @ FormatMarkdown[ "See \\!\\(\\*MarkdownImageBox[\"" <> uri <> "\"]\\) here" ]
            }
        ]
    ],
    { uri_String, a_, b_, c_ } /; And[
        MatchQ[ a, { "See ", imgCell[ $imgList, None, uri ], " here" } ],
        MatchQ[ b, { "See ", imgCell[ $imgList, None, uri ], " here" } ],
        MatchQ[ c, { "See ", imgCell[ $imgList, "Data", imgURIMD @ uri ], " here" } ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Inline-URI-Auto-Corrected"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Expression Links*)

(* A markdown link to an expression URI becomes a TextExpressionLink template (a button that opens the expression in a
   new notebook). The second argument is the base64 encoded BinarySerialize of the expression: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri, NormalizeTextData @ FormatMarkdown[ "Click [this](expression://" <> imgKey @ uri <> ") now" ] ]
    ],
    {
        "Click ",
        Cell[ BoxData @ TemplateBox[ { "\"this\"" | "this", _String }, "TextExpressionLink" ], ___ ],
        " now"
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Expression-Link"
]

VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            FirstCase[
                FormatMarkdown[ "Click [this](expression://" <> imgKey @ uri <> ") now" ],
                TemplateBox[ { _, b64_String }, "TextExpressionLink" ] :> BinaryDeserialize @ BaseDecode @ b64,
                $Failed,
                Infinity
            ]
        ]
    ],
    { 1, 2, 3 },
    SameTest -> MatchQ,
    TestID   -> "Images-Expression-Link-Data"
]

(* While streaming, the link is only styled as a hyperlink: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri, NormalizeTextData @ FormatMarkdown[ "Click [this](expression://" <> imgKey @ uri <> ") now", "Streaming" ] ]
    ],
    { "Click ", StyleBox[ "this", "Hyperlink" ], " now" },
    SameTest -> MatchQ,
    TestID   -> "Images-Expression-Link-Streaming"
]

(* Any scheme, or a bare key, makes an expression link, and they work in list items: *)
VerificationTest[
    imgWithURI[
        { 1, 2, 3 },
        Function[ uri,
            {
                FormatMarkdown[ "[this](attachment://" <> imgKey @ uri <> ")" ],
                FormatMarkdown[ "[this](" <> imgKey @ uri <> ")" ],
                NormalizeTextData @ FormatMarkdown[ "* Click [this](expression://" <> imgKey @ uri <> ")" ]
            }
        ]
    ],
    {
        { Cell[ BoxData @ TemplateBox[ { "\"this\"" | "this", _String }, "TextExpressionLink" ], ___ ] },
        { Cell[ BoxData @ TemplateBox[ { "\"this\"" | "this", _String }, "TextExpressionLink" ], ___ ] },
        {
            Cell[
                TextData @ {
                    StyleBox[ "\[Bullet]", ___ ],
                    " Click ",
                    Cell[ BoxData @ TemplateBox[ { "\"this\"" | "this", _String }, "TextExpressionLink" ], ___ ]
                },
                "InlineItem"
            ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Expression-Link-Variants"
]

(* A URI that is not shaped like an expression URI is an ordinary hyperlink: *)
VerificationTest[
    FormatMarkdown[ "[this](expression://content-abc123)" ],
    {
        ButtonBox[
            "this",
            OrderlessPatternSequence[
                BaseStyle  -> "Hyperlink",
                ButtonData -> { URL[ "expression://content-abc123" ], None },
                ___
            ]
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Expression-Link-Not-A-Key"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CachedBoxes*)

(* CachedBoxes gives the boxes of an expression, cached by the hash of the expression: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| |> },
        { CachedBoxes[ { 1, 2, 3 } ], Values @ Wolfram`Chatbook`Formatting`Private`$boxCache }
    ],
    { $imgList, { $imgList } },
    SameTest -> MatchQ,
    TestID   -> "Images-CachedBoxes"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| Hash[ { 1, 2, 3 } ] -> "CACHED" |> },
        CachedBoxes[ { 1, 2, 3 } ]
    ],
    "CACHED",
    SameTest -> MatchQ,
    TestID   -> "Images-CachedBoxes-Hit"
]

(* Dynamic content is never cached, so that each use gets its own dynamic identity (Manipulate is checked in
   Formatting.wlt): *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Formatting`Private`$boxCache = <| |> },
        {
            CachedBoxes @ Dynamic @ imgDynamicVariable,
            CachedBoxes @ DynamicModule[ { y = 1 }, y ],
            Wolfram`Chatbook`Formatting`Private`$boxCache
        }
    ],
    { _DynamicBox, _DynamicModuleBox, <| |> },
    SameTest -> MatchQ,
    TestID   -> "Images-CachedBoxes-Dynamic-Not-Cached"
]

VerificationTest[
    CachedBoxes[ ],
    _Failure,
    { CachedBoxes::InvalidArguments },
    SameTest -> MatchQ,
    TestID   -> "Images-CachedBoxes-Invalid-Arguments"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cloud*)

(* In the cloud ($CloudEvaluation), boxes that contain rasters are replaced by a DynamicModule that loads them later
   as embedded HTML. The boxes are queued under an ID until the dynamic content asks for them. Other boxes are not
   changed: *)
VerificationTest[
    Block[
        {
            $CloudEvaluation                                  = True,
            Wolfram`Chatbook`Formatting`Private`$boxCache      = <| |>,
            Wolfram`Chatbook`Formatting`Private`$boxQueueCache = <| |>
        },
        {
            CachedBoxes @ $imgSmallImage,
            Length @ Wolfram`Chatbook`Formatting`Private`$boxQueueCache,
            CachedBoxes[ { 1, 2, 3 } ]
        }
    ],
    { TagBox[ _DynamicModuleBox, "DynamicEmbeddedHTMLBoxes" ], 1, $imgList },
    SameTest -> MatchQ,
    TestID   -> "Images-Cloud-Raster-Boxes"
]

(* Formatted images keep their serialization data in the cloud: *)
VerificationTest[
    Block[
        {
            $CloudEvaluation                                  = True,
            Wolfram`Chatbook`Formatting`Private`$boxCache      = <| |>,
            Wolfram`Chatbook`Formatting`Private`$boxQueueCache = <| |>
        },
        With[ { formatted = imgFormat[ "![pic](attachment://content-img01)" ] },
            { formatted, CellToString @ Cell[ TextData @ formatted, "ChatOutput" ] }
        ]
    ],
    {
        { imgCell[ TagBox[ _DynamicModuleBox, "DynamicEmbeddedHTMLBoxes" ], "pic", imgKeyMD[ "pic", "content-img01" ] ] },
        imgKeyMD[ "pic", "content-img01" ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Cloud-Formatted-Image"
]

(* The queued boxes are given as base64 encoded data once, and DisplayBase64Boxes turns that data back into boxes: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Formatting`Private`$boxQueueCache = <| 1 -> RowBox @ { "imgTestBoxes1" } |>,
            Wolfram`Chatbook`Formatting`Private`$base64Cache   = <| |>
        },
        With[ { b64 = Wolfram`Chatbook`Formatting`Private`getBase64[ 1 ] },
            {
                StringQ @ b64,
                DisplayBase64Boxes @ b64,
                Wolfram`Chatbook`Formatting`Private`$boxQueueCache,
                Wolfram`Chatbook`Formatting`Private`getBase64[ 1 ] === b64,
                Wolfram`Chatbook`Formatting`Private`getBase64[ 2 ]
            }
        ]
    ],
    { True, RawBoxes @ RowBox @ { "imgTestBoxes1" }, <| |>, True, _Missing },
    SameTest -> MatchQ,
    TestID   -> "Images-Cloud-Base64-Boxes"
]

(* Without data, or while streaming, a progress indicator is shown instead: *)
VerificationTest[
    {
        Wolfram`Chatbook`Formatting`Private`displayBase64Boxes @ Missing[ "NotAvailable" ],
        Block[ { Wolfram`Chatbook`Common`$dynamicText = True }, DisplayBase64Boxes[ "abc" ] ]
    },
    { RawBoxes[ p_PanelBox ], RawBoxes[ p_PanelBox ] } /; ! FreeQ[ p, ProgressIndicator ],
    SameTest -> MatchQ,
    TestID   -> "Images-Cloud-Base64-Waiting"
]

(* In the cloud, the decoded boxes are rasterized and shown as an embedded HTML image: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Formatting`Private`$boxQueueCache = <| 1 -> ToBoxes @ Graphics[ Disk[ ], ImageSize -> 50 ] |>,
            Wolfram`Chatbook`Formatting`Private`$base64Cache   = <| |>
        },
        With[ { b64 = Wolfram`Chatbook`Formatting`Private`getBase64[ 1 ] },
            Block[ { $CloudEvaluation = True }, DisplayBase64Boxes @ b64 ]
        ]
    ],
    RawBoxes @ TagBox[ boxes_, "CloudEmbeddedHTMLImage" ] /; MatchQ[
        FirstCase[ boxes, EmbeddedHTML[ html_String, ___ ] :> html, $Failed, Infinity ],
        html_String /; StringMatchQ[
            html,
            StringExpression[
                "<div style=\"margin: -8px;\"><img src=\"data:image/jpeg;base64,",
                __,
                "\" width=\"",
                DigitCharacter..,
                "\" height=\"",
                DigitCharacter..,
                "\"></div>"
            ]
        ]
    ],
    SameTest -> MatchQ,
    TestID   -> "Images-Cloud-Embedded-HTML"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*attachment*)

(* The private attachment function is only reached from FormatChatOutput for URIs whose key is not in $attachments (see
   Images-Attachment-Missing-Key), since keys that exist are handled before it. These tests call it directly with keys
   that exist. If the rewrite removes it, these tests can go too. *)

(* Image values are resized and shown in a pane with margins: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$attachments = <| "content-img02" -> HoldComplete @@ { Image @ ConstantArray[ 0.5, { 900, 1000 } ] } |> },
        With[ { result = Wolfram`Chatbook`Formatting`Private`attachment[ "pic", "content-img02" ] },
            { result, imgDims @ result, imgSize @ result }
        ]
    ],
    {
        Cell[
            BoxData @ PaneBox[ imgBoxes[ _? imgRasterQ, "pic", "![pic](attachment://content-img02)" ], ImageMargins -> 10 ],
            ___
        ],
        { 800, 720 },
        { UpTo[ 400 ], UpTo[ 360 ] }
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Private-Attachment-Image"
]

(* Other expressions are shown unevaluated in a Wolfram Language code block, and in an active code cell while
   streaming: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$attachments = <| "content-abc12" -> HoldComplete[ { 1, 2, 3 } ] |> },
        {
            Wolfram`Chatbook`Formatting`Private`attachment[ "data", "content-abc12" ],
            Block[ { Wolfram`Chatbook`Common`$dynamicText = True },
                Wolfram`Chatbook`Formatting`Private`attachment[ "data", "content-abc12" ]
            ]
        }
    ],
    {
        Cell[
            BoxData @ TemplateBox[
                {
                    Cell @ BoxData @ Cell[
                        BoxData @ imgBoxes[ $imgList, "data", "![data](attachment://content-abc12)" ],
                        "ChatCode",
                        "Input",
                        ___
                    ],
                    "Wolfram"
                },
                "ChatCodeBlockTemplate"
            ],
            "ChatCodeBlock"
        ],
        Cell[
            BoxData @ TemplateBox[
                {
                    Cell[ BoxData @ imgBoxes[ $imgList, "data", "![data](attachment://content-abc12)" ], "ChatCodeActive" ],
                    "Wolfram"
                },
                "ChatCodeBlockTemplate"
            ],
            "ChatCodeBlock"
        ]
    },
    SameTest -> MatchQ,
    TestID   -> "Images-Private-Attachment-Expression"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    DeleteDirectory[ $imgDir, DeleteContents -> True ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "Images-Cleanup"
]

(* :!CodeAnalysis::EndBlock:: *)
