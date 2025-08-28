#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "CodeParser`"         -> "cp`"   ];
Needs[ "GeneralUtilities`"   -> "gu`"   ];
Needs[ "PacletTools`"        -> "pt`"   ];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

$assertions = getBooleanArgument[ { "a", "assertions" }, True ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$mxFile = cStr @ FileNameJoin @ {
    $pacletDir,
    "Source",
    "Chatbook",
    ToString @ $SystemWordLength <> "Bit",
    "Chatbook.mx"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeParse*)
codeParse[ file_ ] := codeParse[ file ] =
    cp`CodeParse @ Flatten @ File @ file;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeParseIndexed*)
codeParseIndexed[ file_ ] := codeParseIndexed[ file ] =
    cp`CodeParse[ Flatten @ File @ file, "SourceConvention" -> "SourceCharacterIndex" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*copyTemporary*)
copyTemporary[ dir_ ] :=
    Enclose @ Module[ { tmp, extFiles },
        tmp = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] };
        extFiles = ConfirmMatch[ pacletFiles @ dir, { _String, __String }, "Files" ];
        ConfirmMatch[ (copyTemporary0[ dir, tmp, #1 ] &) /@ extFiles, { _String, __String }, "Copied" ];
        tmp
    ];

copyTemporary0[ dir_, tmp_, file_ ] :=
    With[ { rel = StringReplace[ ResourceFunction[ "RelativePath" ][ dir, file ], "\\" -> "/" ] },
        CopyFile[ file, ResourceFunction[ "EnsureFilePath" ][ FileNameJoin @ { tmp, rel } ] ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pacletFiles*)
pacletFiles[ dir_ ] := Flatten @ {
    FileNameJoin @ { dir, "PacletInfo.wl" },
    Values @ pt`PacletExtensionFiles @ File @ dir
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*expandTags*)
expandTags[ root_ ] :=
    Enclose @ Map[
        Confirm[ expandTags[ root, #1 ], "Expand" ] &,
        ConfirmMatch[ FileNames[ "*.wl", root, Infinity ], { __String }, "Files" ]
    ];

expandTags[ root_, file_ ] :=
    Enclose @ Catch @ Module[ { tags, pos, string, newString },
        tags = ConfirmMatch[ getNewTags[ root, file ], { ___String }, "Tags" ];
        If[ tags === { }, Throw @ file ];
        cicd`ConsoleLog[ "\t" <> ToString @ file ];
        pos = ConfirmMatch[ getTagPos @ file, { { _Integer, _Integer }.. }, "Positions" ];
        ConfirmAssert[ Length @ tags == Length @ pos, "LengthCheck" ];
        string = ConfirmBy[ ReadString @ file, StringQ, "FileContent" ];
        newString = ConfirmBy[ StringReplacePart[ string, tags, pos ], StringQ, "NewFileContent" ];
        ConfirmBy[ Export[ file, newString, "String" ], FileExistsQ, "ExportFile" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNewTags*)
getNewTags[ root_, file_ ] :=
    Module[ { relativeFile },

        relativeFile = StringReplace[ ResourceFunction[ "RelativePath" ][ root, file ], "\\" -> "/" ];

        Cases[
            codeParse @ file,
            ResourceFunction[ "ASTPattern" ][
                HoldPattern @ Alternatives[
                    (Confirm|ConfirmAssert)[ _, $tag1_String ],
                    (ConfirmBy|ConfirmMatch|ConfirmQuiet)[ _, _, $tag2_String ]
                ],
                KeyValuePattern[ cp`Source -> { { $l1_, $c1_ }, { $l2_, $c2_ } } ]
            ] :>
                With[ { tag = First @ { $tag1, $tag2 } },
                    TemplateApply[
                        $tagTemplate,
                        <|
                            "File"    -> relativeFile,
                            "Tag"     -> First @ StringSplit[ ToExpression @ tag[[ 2 ]], "@@" ],
                            "Line1"   -> $l1,
                            "Line2"   -> $l2,
                            "Column1" -> $c1,
                            "Column2" -> $c2
                        |>
                    ]
                ],
            Infinity
        ]
    ];

$tagTemplate = StringTemplate[ "\"`Tag`@@`File`:`Line1`,`Column1`-`Line2`,`Column2`\"" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getTagPos*)
getTagPos[ file_ ] := Cases[
    codeParseIndexed @ file,
    ResourceFunction[ "ASTPattern" ][
        HoldPattern[
            Alternatives[
                (Confirm|ConfirmAssert)[ _, $tag1_String ],
                (ConfirmBy|ConfirmMatch|ConfirmQuiet)[ _, _, $tag2_String ]
            ]
        ],
        KeyValuePattern[ cp`Source -> p_ ]
    ] :> (First @ { $tag1, $tag2 })[[ 3, Key @ cp`Source ]],
    Infinity
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build MX*)
If[ FileExistsQ @ $mxFile,
    cicd`ConsoleLog[ "Removing existing MX file..." ];
    cicd`ScriptConfirm @ DeleteFile @ $mxFile
];

cicd`ConsoleLog[ "Copying files..." ];
tmp = cicd`ScriptConfirmBy[ copyTemporary @ $pacletDir, DirectoryQ ];
cicd`ScriptConfirmBy[ setPacletReleaseID[ tmp, releaseID @ $pacletDir ], StringQ ];

If[ $assertions,
    cicd`ConsoleLog[ "Inserting confirmation source info..." ];
    cicd`ScriptConfirm @ expandTags @ tmp
];

cicd`ConsoleLog[ "Loading paclet..." ];
PacletDirectoryUnload @ $pacletDir;
cicd`ScriptConfirmBy[ PacletDirectoryLoad @ tmp, MemberQ @ tmp ];
Unprotect[ "Wolfram`Chatbook`*" ];
Remove[ "Wolfram`Chatbook`*" ];
Remove[ "Wolfram`Chatbook`*`*" ];
cicd`ScriptConfirmAssert[ Names[ "Wolfram`Chatbook`*" ] === Names[ "Wolfram`Chatbook`*`*" ] === { }, "Names" ];

Wolfram`ChatbookInternal`$BuildingMX = True;
cicd`ScriptConfirm @ CheckAbort[ Get[ "Wolfram`Chatbook`" ], $Failed ];

cicd`ScriptConfirmMatch[ DeleteDirectory[ tmp, DeleteContents -> True ], Null ];

$mxDir = cDir @ gu`EnsureDirectory @ DirectoryName @ $mxFile;
cicd`ConsoleLog @ SequenceForm[ "MX target directory: ", $mxDir  ];
cicd`ConsoleLog @ SequenceForm[ "Building MX file: "   , $mxFile ];

(* workaround for bug 425251 *)
Cases[
    DownValues @ Experimental`ValueFunction,
    HoldPattern @ RuleDelayed[
        Verbatim[ HoldPattern ][ Experimental`ValueFunction[ s_Symbol ] ],
        _
    ] :> Unset @ Experimental`ValueFunction @ s
];

DumpSave[ $mxFile, { "Wolfram`Chatbook`" }, "SymbolAttributes" -> False ];

PacletDirectoryUnload @ tmp;
PacletDirectoryLoad @ $pacletDir;

result = If[ ! FileExistsQ @ $mxFile,
             cicd`ConsoleError[ "Failed to build MX file!", "Fatal" -> True ],
             $mxFile
         ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result