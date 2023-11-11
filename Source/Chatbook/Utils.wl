(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Utils`" ];

HoldComplete[
    `associationKeyDeflatten;
    `convertUTF8;
    `fastFileHash;
    `fixLineEndings;
    `getPinkBoxErrors;
    `graphicsQ;
    `image2DQ;
    `makeFailureString;
    `readString;
    `stringTrimMiddle;
    `validGraphicsQ;
];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* cSpell: ignore deflatten *)
(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AssociationKeyDeflatten*)
(* https://resources.wolframcloud.com/FunctionRepository/resources/AssociationKeyDeflatten *)
importResourceFunction[ associationKeyDeflatten, "AssociationKeyDeflatten" ];

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
readString[ file_, string_? StringQ   ] := fixLineEndings @ string;
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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*graphicsQ*)
graphicsQ[ $$graphics              ] := True;
graphicsQ[ $$definitelyNotGraphics ] := False;
graphicsQ[ g_                      ] := MatchQ[ Quiet @ Show @ Unevaluated @ g, $$graphics ];
graphicsQ[ ___                     ] := False;

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
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
