(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`AIAssistant`" ];
Begin[ "`Private`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$assetLocation = PacletObject[ "Wolfram/LLMTools" ][ "AssetLocation", "AIAssistant" ];

$iconDirectory         = FileNameJoin @ { $assetLocation, "Icons"                      };
$curveDirectory        = FileNameJoin @ { $assetLocation, "GraphicsComponents"         };
$promptDirectory       = FileNameJoin @ { $assetLocation, "Prompts"                    };
$styleDataFile         = FileNameJoin @ { $assetLocation, "Styles.wl"                  };
$dialogDescriptionFile = FileNameJoin @ { $assetLocation, "APIKeyDialogDescription.wl" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Resources*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$icons*)
$icons := $icons = Association @ Map[
    FileBaseName @ # -> Developer`ReadWXFFile @ # &,
    FileNames[ "*.wxf", $iconDirectory ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$curves*)
$curves := $curves = Association @ Map[
    FileBaseName @ # -> Developer`ReadWXFFile @ # &,
    FileNames[ "*.wxf", $curveDirectory ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$promptStrings*)
$promptStrings := $promptStrings = Association @ Map[
    Function[
        StringDelete[
            StringReplace[ ResourceFunction[ "RelativePath" ][ $promptDirectory, # ], "\\" -> "/" ],
            ".md"~~EndOfString
        ] -> ByteArrayToString @ ReadByteArray @ #
    ],
    FileNames[ "*.md", $promptDirectory, Infinity ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$styleDataCells*)
$styleDataCells := $styleDataCells = Association @ Cases[
    ReadList @ $styleDataFile,
    cell: Cell[ StyleData[ name_String, ___ ], ___ ] :> name -> cell
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$apiKeyDialogDescription*)
$apiKeyDialogDescription := $apiKeyDialogDescription = Get @ $dialogDescriptionFile;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];