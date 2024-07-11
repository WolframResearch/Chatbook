#!/usr/bin/env wolframscript
(* ::Package:: *)

(*
    To configure this script to run automatically before each commit, run the
    following in the repository directory:
    ```
    git config --local core.hooksPath Scripts/.githooks
    ```
*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingEnclose:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.36.0/Wolfram__PacletCICD-0.36.0.paclet" ]
];
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

SetOptions[
    ResourceFunction[ "SaveReadableNotebook" ],
    "RealAccuracy" -> 10,
    "ExcludedNotebookOptions" -> {
        ExpressionUUID,
        FrontEndVersion,
        WindowMargins,
        WindowSize
    }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Defaults*)
$defaultRoot   = DirectoryName[ $InputFileName, 2 ];
$defaultIgnore = FileNameJoin @ { $defaultRoot, "build" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Get arguments*)
$root   := $root   = makeRootString @ getArg[ "root"  , $defaultRoot   ];
$ignore := $ignore = makeIgnorePatt @ getArg[ "ignore", $defaultIgnore ];
$strict := $strict = Interpreter[ "Boolean" ][ getArg[ "strict", "True" ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getArg*)
getArg[ name_String, default_: None ] :=
    SelectFirst[ Flatten @ StringCases[
                     $ScriptCommandLine,
                     "--" <> name <> "=" ~~ root___ ~~ EndOfString :> root
                 ],
                 StringQ,
                 default
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*enclose*)
enclose // Attributes = { HoldAll };
enclose[ eval_           ] := enclose[ eval, "An unspecified error occurred." ];
enclose[ eval_, msg_     ] := enclose[ eval, msg, 1 ];
enclose[ eval_, msg_, n_ ] := Enclose[
    eval,
    (Print @ ToString @ msg; If[ $strict, Exit @ n ]) &
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeRootString*)
makeRootString[ str_String ] := enclose[
    ConfirmBy[ ExpandFileName @ StringTrim[ str, "\"" ], DirectoryQ ],
    StringForm[ "`1` is not a valid directory", str ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeIgnorePatt*)
makeIgnorePatt[ "None"|"none" ] := None;

makeIgnorePatt[ str_String ] :=
    Alternatives @@ (StringTrim[ #1, "\"" ] & /@ StringSplit[ str, "," ]);

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getFiles*)
getFiles[             ] := getFiles @ $root;
getFiles[ root_       ] := getFiles[ root, $ignore ];
getFiles[ root_, None ] := FileNames[ "*.nb", root, Infinity ];

getFiles[ root_, ignore_ ] :=
    getFiles[ root, ignore, getNotebookArgs[ ] ];

getFiles[ root_, ignore_, files: { ___String } ] :=
    Select[ files, FileExistsQ ];

getFiles[ root_, ignore_, _ ] :=
    Select[ FileNames[ { "*.nb", "*.wlt" }, root, Infinity ],
            Not @* StringMatchQ[ ignore~~___ ]
    ];

getNotebookArgs[ ] := getNotebookArgs @ getArg[ "files", None ];
getNotebookArgs[ nbs_String ] := getNotebookArgs @ StringSplit[ nbs, "\n" ];
getNotebookArgs[ files: { __String } ] := Select[ files, FileExistsQ ];
getNotebookArgs[ ___ ] := Missing[ "NotFound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*print*)
print[ ind_Integer, msg__ ] :=
    Print[ StringJoin @ ConstantArray[ " ", ind ],
           DateString @ { "DateTimeShort", ".", "Millisecond" },
           ": ",
           msg
    ];

print[ msg__ ] := print[ 0, msg ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeUnreadable*)
makeUnreadable[ file_ ] := enclose[
    ConfirmBy[ Export[ file, Import[ file, "NB" ] ], FileExistsQ ],
    StringForm[ "Failed to unformat notebook: `1`", file ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*notebookFileQ*)
notebookFileQ[ file_String ] := StringEndsQ[ file, ".nb", IgnoreCase -> True ];
notebookFileQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*testFileQ*)
testFileQ[ file_String ] := StringEndsQ[ file, ".wlt", IgnoreCase -> True ];
testFileQ[ ___ ] := False;

(******************************************************************************)
(* ::Subsection::Closed:: *)
(*makeReadable*)
makeReadable[ file_? notebookFileQ ] := makeReadable[ file, cicd`FormatNotebooks @ file ];
makeReadable[ file_? testFileQ ] := makeReadable[ file, cicd`AnnotateTestIDs @ file ];

makeReadable[ file_, Missing[ "Skipped", ___ ] ] :=
    print[ "Skipped: ", StringDelete[ file, StartOfString~~$root ] ];

makeReadable[ file_, formatted_File ] :=
    print[ "Formatted: ", StringDelete[ file, StartOfString~~$root ] ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } },
    If[ MemberQ[ $ScriptCommandLine, "--unformat" ],
        makeUnreadable /@ getFiles[ ],
        makeReadable /@ Echo[ getFiles[ ] ]
    ]
]

(* :!CodeAnalysis::EndBlock:: *)