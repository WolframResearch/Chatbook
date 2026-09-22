(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
(* Not memoized: the MX is built on 15.0, so a cached value would be baked into the build. *)
$readFileEnabled := sufficientVersionQ[ 15.1 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$readFileDescription = "\
Read a file or directory from the local filesystem and return content and metadata describing it. \
Binary/media content is summarized, not returned raw. \
Hard errors (missing file, unknown or unsupported format) return a Failure whose message says how to fix it.
If the result from the tool contains 'NextDataOffset' equal to a numeric value, then the file content is clipped. \
To get the next chunk of data use the 'DataOffset' option with the value equal to 'NextDataOffset'.
'IncludePageImage' option is valid only for PDF files. Use only if the page image is needed.
If the result from the tool contains 'NextElementIndex' equal to a numeric value, then use the 'ElementIndex' option \
with the value equal to 'NextElementIndex' to get the next item. \
'Hints' is internal guidance for you (Wolfram Import elements and functions to analyze the file further if needed) - \
not file content, and not to be shown to the user.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "FileReader" ] = <|
    toolDefaultData[ "FileReader" ],
    "ShortName"          -> "read",
    "Description"        -> $readFileDescription,
    "Enabled"            :> $readFileEnabled,
    "Hidden"             :> ! $readFileEnabled,
    "Function"           -> readFile,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "Path" -> <|
            "Interpreter" -> "String",
            "Required"    -> True,
            "Help"        -> "Path to a file or directory on the local filesystem."
        |>,
        "IncludePageImage" -> <|
            "Interpreter" -> "Boolean",
            "Default"     -> False,
            "Required"    -> False,
            "Help"        -> "PDF only. If True, also return the current page rendered as an image. Use only when the page must be seen visually."
        |>,
        "DataOffset" -> <|
            "Interpreter" -> "Integer",
            "Default"     -> 1,
            "Required"    -> False,
            "Help"        -> "1-based offset for paging clipped content (text lines, rows, frames) within one item. Set to a prior result's 'NextDataOffset' to get the next chunk."
        |>,
        "ElementIndex" -> <|
            "Interpreter" -> "Integer",
            "Default"     -> 1,
            "Required"    -> False,
            "Help"        -> "1-based index selecting one item in a multi-item file (page, frame, dataset). Set to a prior result's 'NextElementIndex' to get the next item."
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readFile*)
readFile // beginDefinition;

readFile[ as_Association ] := Enclose[
    Module[ { path, options, readFileResult },
        path    = ConfirmBy[ as[ "Path" ], StringQ, "Path" ];
        options = ConfirmMatch[ readFileOptions @ as, { (_String -> _)... }, "Options" ];

        readFileResult = ConfirmMatch[
            FormatUtilities`LLM`ReadFile[ path, Sequence @@ options ],
            _Association|_Failure,
            "ReadFileResult"
        ];

        ConfirmMatch[
            readFilePost[ path, readFileResult ],
            KeyValuePattern @ { "String" -> _String, "Result" -> _ },
            "Result"
        ]
    ],
    throwInternalFailure
];

readFile // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readFileOptions*)
readFileOptions // beginDefinition;

readFileOptions[ as_Association ] := {
    "IncludePageImage" -> readFileParameter[ as, "IncludePageImage" ],
    "DataOffset"       -> readFileParameter[ as, "DataOffset"       ],
    "ElementIndex"     -> readFileParameter[ as, "ElementIndex"     ],
    readFileBudgetOption @ Ceiling[ $toolResultStringLength/2 ]
};

readFileOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*readFileParameter*)
readFileParameter // beginDefinition;

(* Optional parameters can arrive as Missing or empty strings when the LLM omits them (e.g. with the "Simple" tool
   method), and ReadFile issues messages for invalid option values, so fall back to the defaults declared in the spec: *)
readFileParameter[ as_Association, key: "IncludePageImage" ] :=
    Replace[ as[ key ], Except[ True|False ] -> False ];

readFileParameter[ as_Association, key: "DataOffset"|"ElementIndex" ] :=
    Replace[ as[ key ], Except[ _Integer? Positive ] -> 1 ];

readFileParameter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*readFileBudgetOption*)
readFileBudgetOption // beginDefinition;

(* ReadFile only accepts a positive integer byte budget, so when the cell string budget is Infinity (or otherwise
   unusable) the option is omitted and ReadFile applies its own default limit instead: *)
readFileBudgetOption[ budget_Integer? Positive ] := "MaxTextByteBudget" -> budget;
readFileBudgetOption[ _ ] := Nothing;

readFileBudgetOption // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readFilePost*)
readFilePost // beginDefinition;

readFilePost[ path_String, result0_Association ] := Enclose[
    Module[ { metaInformation, result, content, frontMatter, frontMatterString, contentString, string },

        metaInformation = ConfirmMatch[
            getMetaInformation[ path, result0[ "MetaInformation" ] ],
            _Association|_Missing|_String,
            "MetaInformation"
        ];

        result = DeleteMissing @ <| result0, "MetaInformation" -> metaInformation |>;

        content = <| Select[ result, probablyContentQ ], KeyTake[ result, $contentKeys ] |>;
        frontMatter = KeyDrop[ result, Keys @ content ];

        If[ content === <| |>,
            content = ConfirmBy[ findUsableContent[ path, result ], AssociationQ, "Content" ];
        ];

        frontMatterString = ConfirmBy[
            createYAMLFrontMatter @ frontMatter,
            StringQ,
            "FrontMatterString"
        ];

        contentString = StringTrim @ StringRiffle[
            ConfirmMatch[
                Block[ { $singleContentItem = Length @ content === 1 },
                    DeleteMissing @ KeyValueMap[ readFileTextItem, content ]
                ],
                { ___String },
                "ContentString"
            ],
            "\n"
        ];

        string = StringTrim @ ConfirmBy[
            If[ contentString === "",
                frontMatterString,
                TemplateApply[
                    $readFileResultTemplate,
                    <| "FrontMatter" -> frontMatterString, "Content" -> contentString |>
                ]
            ],
            StringQ,
            "Formatted"
        ];

        <| "Result" -> result, "String" -> string |>
    ],
    throwInternalFailure
];

readFilePost[ path_String, failure_Failure ] :=
    <| "Result" -> failure, "String" -> makeFailureString @ failure |>;

readFilePost // endDefinition;


$contentKeys = {
    "Content",
    "CurrentPageImage",
    "CurrentPageTextAndImages",
    "CurrentFrame",
    "Image"
};

$readFileResultTemplate = StringTemplate[ "---\n`FrontMatter`\n---\n\n`Content`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*probablyContentQ*)
probablyContentQ // beginDefinition;
probablyContentQ[ _? graphicsQ ] := True;
probablyContentQ[ _Audio ] := True;
probablyContentQ[ _Video ] := True;
probablyContentQ[ content_String ] := StringContainsQ[ content, "\n" ];
probablyContentQ[ list_List ] := AnyTrue[ list, probablyContentQ ];
probablyContentQ[ _ ] := False;
probablyContentQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*findUsableContent*)
findUsableContent // beginDefinition;

findUsableContent[ path_, as_Association ] := Enclose[
    Catch @ Module[ { format, default, formatElements, element, imported },

        format = ConfirmBy[ as[ "Format" ], StringQ, "Format" ];

        default        = FileFormatProperties[ format, "DefaultImportElement" ];
        formatElements = FileFormatProperties[ format, "ImportElements"       ];

        element = If[ MemberQ[ $usableContentElements, default ],
                      default,
                      ConfirmAssert[ ListQ @ formatElements, "ImportElements" ];
                      SelectFirst[ $usableContentElements, MemberQ[ formatElements, # ] & ]
                  ];

        If[ MissingQ @ element, Throw @ <| |> ];

        ConfirmAssert[ StringQ @ element, "UsableContentElement" ];

        imported = Confirm[ Quiet @ Import[ path, { format, element } ], "ImportedContent" ];

        <| "Content" -> imported |>
    ],
    <| |> &
];

findUsableContent // endDefinition;


$usableContentElements = {
    "MeshRegion",
    "BoundaryMeshRegion",
    "Region",
    "Graphics3D",
    "Graphics",
    "GraphicsComplex",
    "Image",
    "Audio"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createYAMLFrontMatter*)
createYAMLFrontMatter // beginDefinition;

createYAMLFrontMatter[ frontMatter_Association ] := Enclose[
    Module[ { yaml, niceKeys, lines },
        yaml = ConfirmBy[
            ExportString[
                DeleteCases[ frontMatter, _ByteArray|_NumericArray|_SparseArray, Infinity ],
                "YAML",
                "ExpressionFormattingFunction" -> TextString,
                "TerseListFormatting"          -> True
            ],
            StringQ,
            "YAML"
        ];

        niceKeys = StringReplace[
            yaml,
            StartOfLine ~~ ws: WhitespaceCharacter... ~~ "\"" ~~ s: Except[ "\"" ].. ~~ "\":" :> ws<>s<>":"
        ];

        lines = ConfirmMatch[
            stringTrimMiddle[ #, 250 ] & /@ StringSplit[ niceKeys, "\n" ],
            { ___String },
            "FrontMatterLines"
        ];

        StringRiffle[ lines, "\n" ]
    ],
    throwInternalFailure
];

createYAMLFrontMatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMetaInformation*)
getMetaInformation // beginDefinition;

getMetaInformation[ path_, meta_Association ] := meta;
getMetaInformation[ path_, missing_Missing ] := missing;

getMetaInformation[ path_, string_String ] :=
    With[ { meta = Quiet @ Import[ path, "MetaInformation" ] },
        If[ AssociationQ @ meta,
            meta,
            string
        ]
    ];

getMetaInformation // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*readFileTextItem*)
readFileTextItem // beginDefinition;

readFileTextItem[ key_String, value_String ] /; $singleContentItem :=
    value;

readFileTextItem[ key_String, value_String ] :=
    If[ StringFreeQ[ value, "\n" ],
        "<"<>key<>">"<>value<>"</"<>key<>">",
        "\n<"<>key<>">\n"<>value<>"\n</"<>key<>">\n"
    ];

readFileTextItem[ key_String, expr: _? graphicsQ | _Audio | _Video ] :=
    readFileTextItem[ key, MakeExpressionURI @ expr ];

readFileTextItem[ key_String, content: { (_String | _? graphicsQ)... } ] :=
    With[ { strings = Replace[ content, i: Except[ _String ] :> MakeExpressionURI @ i, { 1 } ] },
        readFileTextItem[ key, StringJoin @ strings ]
    ];

readFileTextItem[ key_String, value_Missing ] :=
    value;

readFileTextItem[ key_String, value_ ] :=
    readFileTextItem[ key, stringTrimMiddle[ TextString @ value, 100 ] ];

readFileTextItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
