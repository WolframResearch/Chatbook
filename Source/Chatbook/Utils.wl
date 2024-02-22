(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Utils`" ];

HoldComplete[
    `associationKeyDeflatten;
    `clickToCopy;
    `contextBlock;
    `convertUTF8;
    `exportDataURI;
    `fastFileHash;
    `fileFormatQ;
    `fixLineEndings;
    `formatToMIMEType;
    `getPinkBoxErrors;
    `graphicsQ;
    `image2DQ;
    `importDataURI;
    `makeFailureString;
    `mimeTypeToFormat;
    `readString;
    `stringTrimMiddle;
    `tinyHash;
    `validGraphicsQ;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$tinyHashLength = 5;

(* cSpell: ignore deflatten *)
(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AssociationKeyDeflatten*)
(* https://resources.wolframcloud.com/FunctionRepository/resources/AssociationKeyDeflatten *)
importResourceFunction[ associationKeyDeflatten, "AssociationKeyDeflatten" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ClickToCopy*)
(* https://resources.wolframcloud.com/FunctionRepository/resources/ClickToCopy *)
importResourceFunction[ clickToCopy, "ClickToCopy" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fixLineEndings*)
fixLineEndings // beginDefinition;
fixLineEndings[ string_String? StringQ ] := StringReplace[ string, "\r\n" -> "\n" ];
fixLineEndings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*convertUTF8*)
convertUTF8 // beginDefinition;
convertUTF8[ string_String ] := convertUTF8[ string, True ];
convertUTF8[ string_String, True  ] := FromCharacterCode[ ToCharacterCode @ string, "UTF-8" ];
convertUTF8[ string_String, False ] := FromCharacterCode @ ToCharacterCode[ string, "UTF-8" ];
convertUTF8 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringTrimMiddle*)
stringTrimMiddle // beginDefinition;
stringTrimMiddle[ str_String, Infinity ] := str;
stringTrimMiddle[ str_String, max_Integer? Positive ] := stringTrimMiddle[ str, Ceiling[ max / 2 ], Floor[ max / 2 ] ];
stringTrimMiddle[ str_String, l_Integer, r_Integer ] /; StringLength @ str <= l + r + 5 := str;
stringTrimMiddle[ str_String, l_Integer, r_Integer ] := StringTake[ str, l ] <> " ... " <> StringTake[ str, -r ];
stringTrimMiddle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeFailureString*)
makeFailureString // beginDefinition;

makeFailureString[ failure: Failure[ tag_, as_Association ] ] := Enclose[
    Module[ { message },
        message = ToString @ ConfirmBy[ failure[ "Message" ], StringQ, "Message" ];
        StringJoin[
            "Failure[",
                ToString[ tag, InputForm ],
                ", ",
                StringReplace[
                    ToString[ as, InputForm ],
                    StartOfString~~"<|" -> "<|" <> ToString[ "Message" -> message, InputForm ] <> ", "
                ],
            "]"
        ]
    ],
    throwInternalFailure[ makeFailureString @ failure, ##1 ] &
];

makeFailureString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Files*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*readString*)
readString // beginDefinition;

readString[ file_ ] := Quiet[ readString[ file, ReadByteArray @ file ], $CharacterEncoding::utf8 ];

readString[ file_, bytes_? ByteArrayQ ] := readString[ file, ByteArrayToString @ bytes ];
readString[ file_, string_? StringQ   ] := replaceSpecialCharacters @ fixLineEndings @ string;
readString[ file_, failure_Failure    ] := failure;

readString[ file_, $Failed ] :=
    Module[ { exists, tag, template },
        exists   = TrueQ @ FileExistsQ @ file;
        tag      = If[ exists, "FileUnreadable", "FileNotFound" ];
        template = If[ exists, "Cannot read content from `1`.", "The file `1` does not exist." ];
        Failure[ tag, <| "MessageTemplate" -> template, "MessageParameters" -> { file } |> ]
    ];

readString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*replaceSpecialCharacters*)
replaceSpecialCharacters // beginDefinition;

replaceSpecialCharacters[ string_String? StringQ ] := StringReplace[
    string,
    special: ("\\[" ~~ LetterCharacter.. ~~ "]") :> ToExpression[ "\""<>special<>"\"" ]
];

replaceSpecialCharacters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unreadableFileFailure*)
unreadableFileFailure // beginDefinition;

unreadableFileFailure[ file_ ] :=
    Failure[
        "FileUnreadable",
        <|
            "MessageTemplate" -> "Cannot read content from `1`.",
            "MessageParameters" -> { file }
        |>
    ];

unreadableFileFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fastFileHash*)
fastFileHash // beginDefinition;
fastFileHash[ file_ ] := fastFileHash[ file, ReadByteArray @ file ];
fastFileHash[ file_, bytes_ByteArray ] := Hash @ bytes;
fastFileHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Graphics*)
$$graphics = HoldPattern @ Alternatives[
    _System`AstroGraphics,
    _GeoGraphics,
    _Graphics,
    _Graphics3D,
    _Image,
    _Image3D,
    _Legended
];

$$definitelyNotGraphics = HoldPattern @ Alternatives[
    _Association,
    _CloudObject,
    _File,
    _List,
    _String,
    _URL,
    Null,
    True|False
];

$$graphicsBoxIgnoredHead = HoldPattern @ Alternatives[
    BoxData,
    Cell,
    FormBox,
    PaneBox,
    StyleBox,
    TagBox
];

$$graphicsBoxIgnoredTemplates = Alternatives[
    "Labeled",
    "Legended"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*graphicsQ*)
graphicsQ[ $$graphics              ] := True;
graphicsQ[ $$definitelyNotGraphics ] := False;
graphicsQ[ RawBoxes[ boxes_ ]      ] := graphicsBoxQ @ Unevaluated @ boxes;
graphicsQ[ g_                      ] := MatchQ[ Quiet @ Show @ Unevaluated @ g, $$graphics ];
graphicsQ[ ___                     ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*graphicsBoxQ*)
graphicsBoxQ[ _GraphicsBox|_Graphics3DBox ] := True;
graphicsBoxQ[ $$graphicsBoxIgnoredHead[ box_, ___ ] ] := graphicsBoxQ @ Unevaluated @ box;
graphicsBoxQ[ TemplateBox[ { box_, ___ }, $$graphicsBoxIgnoredTemplates, ___ ] ] := graphicsBoxQ @ Unevaluated @ box;
graphicsBoxQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validGraphicsQ*)
validGraphicsQ[ g_? graphicsQ ] := getPinkBoxErrors @ Unevaluated @ g === { };
validGraphicsQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getPinkBoxErrors*)
getPinkBoxErrors // beginDefinition;
(* TODO: hook this up to evaluator outputs and CellToString to give feedback about pink boxes *)

getPinkBoxErrors[ { } ] :=
    { };

getPinkBoxErrors[ cells: _CellObject | { __CellObject } ] :=
    getPinkBoxErrors @ NotebookRead @ cells;

getPinkBoxErrors[ cells: _Cell | { __Cell } ] :=
    Module[ { nbo },
        UsingFrontEnd @ WithCleanup[
            nbo = NotebookPut[ Notebook @ Flatten @ { cells }, Visible -> False ],
            SelectionMove[ nbo, All, Notebook ];
            MathLink`CallFrontEnd @ FrontEnd`GetErrorsInSelectionPacket @ nbo,
            NotebookClose @ nbo
        ]
    ];

getPinkBoxErrors[ data: _TextData | _BoxData | { __BoxData } ] :=
    getPinkBoxErrors @ Cell @ data;

getPinkBoxErrors[ exprs_List ] :=
    getPinkBoxErrors[ Cell @* BoxData /@ MakeBoxes /@ Unevaluated @ exprs ];

getPinkBoxErrors[ expr_ ] :=
    getPinkBoxErrors @ { Cell @ BoxData @ MakeBoxes @ expr };

getPinkBoxErrors // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*image2DQ*)
(* Matches against the head in addition to checking ImageQ to avoid passing Image3D when a 2D image is expected: *)
image2DQ // beginDefinition;
image2DQ[ _Image? ImageQ ] := True;
image2DQ[ _              ] := False;
image2DQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Format Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$fileFormats*)
$fileFormats := ToLowerCase @ Union[ $ImportFormats, $ExportFormats ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*fileFormatQ*)
fileFormatQ // beginDefinition;
fileFormatQ[ fmt_String ] := fileFormatQ[ fmt ] = MemberQ[ $fileFormats, ToLowerCase @ fmt ];
fileFormatQ[ _ ] := False
fileFormatQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatToMIMEType*)
formatToMIMEType // beginDefinition;
formatToMIMEType[ Automatic ] := "application/octet-stream";
formatToMIMEType[ mime_String ] /; StringContainsQ[ mime, "/" ] := ToLowerCase @ mime;
formatToMIMEType[ fmt_String ] := formatToMIMEType[ fmt, FileFormatProperties[ fmt, "MIMETypes" ] ];
formatToMIMEType[ fmt_, _? FailureQ | { } | _FileFormatProperties ] := "application/octet-stream";
formatToMIMEType[ fmt_, { mimeType_String, ___ } ] := mimeType;
formatToMIMEType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mimeTypeToFormat*)
mimeTypeToFormat // beginDefinition;
mimeTypeToFormat[ fmt_String ] /; StringFreeQ[ fmt, "/" ] := fmt;
mimeTypeToFormat[ mime_String ] := mimeTypeToFormat @ MIMETypeToFormatList @ mime;
mimeTypeToFormat[ { fmt_String, ___ } ] := fmt;
mimeTypeToFormat[ { } ] := "Binary";
mimeTypeToFormat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importDataURI*)
importDataURI // beginDefinition;

importDataURI[ uri_ ] :=
    importDataURI[ uri, Automatic ];

importDataURI[ URL[ uri_String ], fmt_ ] :=
    importDataURI[ uri, fmt ];

importDataURI[ uri_String, fmt0_ ] := Enclose[
    Module[ { info, bytes, fmt, fmts, result, $failed },

        info  = ConfirmBy[ uriData @ uri, AssociationQ, "URIData" ];
        bytes = ConfirmBy[ info[ "Data" ], ByteArrayQ, "Data" ];
        fmt   = If[ StringQ @ fmt0, fmt0, Nothing ];

        fmts = ConfirmMatch[
            DeleteDuplicates @ Flatten @ { fmt, info[ "Formats" ], Automatic },
            { (Automatic|_String).. },
            "Formats"
        ];

        result = FirstCase[
            fmts,
            f_ :> With[ { res = ImportByteArray[ bytes, f ] },
                res /; MatchQ[ res, Except[ _ImportByteArray | _? FailureQ ] ]
            ],
            $failed
        ];

        ConfirmMatch[ result, Except[ $failed ], "Result" ]
    ],
    throwInternalFailure[ importDataURI[ uri, fmt0 ], ## ] &
];

importDataURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*uriData*)
uriData // beginDefinition;

uriData[ uri_String ] /; StringMatchQ[ uri, "data:" ~~ ___ ~~ "," ~~ __ ] :=
    uriData @ StringSplit[ StringDelete[ uri, StartOfString~~"data:" ], "," ];

uriData[ { contentType_String, data_String } ] :=
    uriData[ StringSplit[ ToLowerCase @ contentType, ";" ], data ];

uriData[ { data_String } ] :=
    uriData @ { "text/plain;charset=US-ASCII", data };

uriData[ { mimeType_String, "base64" }, data_String ] := <|
    "Formats" -> MIMETypeToFormatList @ mimeType,
    "Data"    -> BaseDecode @ data
|>;

uriData[ { mimeType_String, rule_String, rest___ }, data_String ] /; StringContainsQ[ rule, "=" ] :=
    uriData[ { mimeType <> ";" <> rule, rest }, data ];

uriData[ { mimeType_String }, data_String ] := <|
    "Formats" -> MIMETypeToFormatList @ mimeType,
    "Data"    -> StringToByteArray @ URLDecode @ data
|>;

uriData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exportDataURI*)
exportDataURI // beginDefinition;

exportDataURI[ data_ ] :=
    With[ { mime = guessExpressionMimeType @ data },
        exportDataURI[ data, mimeTypeToFormat @ mime, mime ]
    ];

exportDataURI[ data_, fmt_String ] :=
    exportDataURI[ data, fmt, formatToMIMEType @ fmt ];

exportDataURI[ data_, fmt_String, mime_String ] := Enclose[
    Module[ { base64 },
        base64 = ConfirmBy[ ExportString[ data, { "Base64", fmt } ], StringQ, "Base64" ];
        "data:" <> mime <> ";base64," <> StringDelete[ base64, "\n" ]
    ],
    throwInternalFailure
];

exportDataURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*guessExpressionMimeType*)
guessExpressionMimeType // beginDefinition;
guessExpressionMimeType[ _? image2DQ            ] := "image/jpeg";
guessExpressionMimeType[ _? graphicsQ           ] := "image/png";
guessExpressionMimeType[ _String? StringQ       ] := "text/plain";
guessExpressionMimeType[ _ByteArray? ByteArrayQ ] := "application/octet-stream";
guessExpressionMimeType[ ___                    ] := "application/vnd.wolfram.wl";
guessExpressionMimeType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*contextBlock*)
contextBlock // beginDefinition;
contextBlock // Attributes = { HoldFirst };
contextBlock[ eval_ ] := Block[ { $Context = "Global`", $ContextPath = { "Global`", "System`" } }, eval ];
contextBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*tinyHash*)
tinyHash // beginDefinition;
tinyHash[ e_ ] := tinyHash[ Unevaluated @ e, $tinyHashLength ];
tinyHash[ e_, n_ ] := StringTake[ IntegerString[ Hash @ Unevaluated @ e, 36 ], -n ];
tinyHash // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Scan[ fileFormatQ, $fileFormats ];
];

End[ ];
EndPackage[ ];
