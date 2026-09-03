(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

$readFileEnabled := $readFileEnabled = sufficientVersionQ[15.1];


(* ::Subsection::Closed:: *)
(*Icon*)
(* $readFileIcon =  *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$readFiletDescription = "Read a file or directory from the local filesystem and return an \
association describing it: type, format, size, a bounded \
(line-numbered, clipped) text/data preview, and media metadata. \
Binary/media content is summarized, not returned raw. Hard errors \
(missing file, unknown or unsupported format) return a Failure whose \
message says how to fix it.
If the result from the tool contains 'NextDataOffset' equal to a \
numeric value, then the file content is clipped. To get the next \
chunk of data use the 'DataOffset' option with the value equal to \
'NextDataOffset'.
'IncludePageImage' option is valid only for PDF files. Use \
'IncludePageImage' -> True only if the page image is needed.
If the result from the tool contains 'NextElementIndex' equal to a \
numeric value, then use the 'ElementIndex' option with the value \
equal to 'NextElementIndex' to get the next item. 'Hints' is internal \
guidance for you (Wolfram Import elements and functions to analyze \
the file further if needed) - not file content, and not to be shown \
to the user."

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "FileReader" ] = <|
    toolDefaultData[ "FileReader" ],
    "Description"        -> $readFiletDescription,
    "Enabled"            :> $readFileEnabled,
    "Function"           -> readFile,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "Path" ->
            <|
                "Interpreter" -> "String",
                "Required" -> True,
                "Help" ->"Path to a file or directory on the local filesystem resolved by FindFile."
            |>,
        "IncludePageImage" ->
            <|
                "Interpreter" -> "Boolean",
                "Default" -> False,
                "Required" -> False,
                "Help" ->"PDF only. If True, also return the current page rendered as an \
Image object. Use only when the page must be seen visually."
            |>,
        "DataOffset" -> <|
                "Interpreter" -> "Integer",
                "Default" -> 1,
                "Required" -> False,
                 "Help" -> "1-based offset for paging clipped content (text lines, rows, \
frames) within one item. Set to a prior result's 'NextDataOffset' to \
get the next chunk."
            |>,
        "ElementIndex" -> <|
            "Interpreter" -> "Integer",
            "Default" -> 1,
            "Required" -> False,
            "Help" -> "1-based index selecting one item in a multi-item file (page, \
frame, dataset). Set to a prior result's 'NextElementIndex' to get \
the next item."
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
    Confirm @ Quiet @ FormatUtilities`LLM`ReadFile[
        as[ "Path" ],
        "IncludePageImage" -> as[ "IncludePageImage" ],
        "DataOffset" -> as[ "DataOffset" ],
        "ElementIndex" -> as[ "ElementIndex" ]
    ]
];

readFile // endDefinition;


(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
