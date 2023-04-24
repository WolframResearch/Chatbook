#!/usr/bin/env wolframscript

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
If[ ! PacletObjectQ @ PacletObject[ "Wolfram/PacletCICD" ],
    PacletInstall[ "https://github.com/WolframResearch/PacletCICD/releases/download/v0.34.0/Wolfram__PacletCICD-0.34.0.paclet" ]
];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];
Needs[ "GeneralUtilities`"   -> "gu`"   ];

cFile = cicd`ScriptConfirmBy[ #, FileExistsQ ] &;
cDir  = cicd`ScriptConfirmBy[ #, DirectoryQ  ] &;
cStr  = cicd`ScriptConfirmBy[ #, StringQ     ] &;

Wolfram`Chatbook`Internal`$BuildingMX = True;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$inputFileName = cFile @ Replace[ $InputFileName, "" :> NotebookFileName[ ] ];
$pacletDir     = cDir @ DirectoryName[ $inputFileName, 2 ];
$mxFile        = cStr @ FileNameJoin @ {
                     $pacletDir,
                     "Source",
                     "Chatbook",
                     ToString @ $SystemWordLength <> "Bit",
                     "Chatbook.mx"
                 };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build MX*)
If[ FileExistsQ @ $mxFile,
    cicd`ConsoleLog[ "Removing existing MX file..." ];
    cicd`ScriptConfirm @ DeleteFile @ $mxFile
];

cicd`ConsoleLog[ "Loading paclet..." ];
cicd`ScriptConfirmBy[ PacletDirectoryLoad @ $pacletDir, MemberQ @ $pacletDir ];
cicd`ScriptConfirm @ Get[ "Wolfram`Chatbook`" ];

$mxDir = cDir @ gu`EnsureDirectory @ DirectoryName @ $mxFile;
cicd`ConsoleLog @ SequenceForm[ "MX target directory: ", $mxDir  ];
cicd`ConsoleLog @ SequenceForm[ "Building MX file: "   , $mxFile ];

DumpSave[ $mxFile, { "Wolfram`Chatbook`" }, "SymbolAttributes" -> False ];

If[ ! FileExistsQ @ $mxFile,
    cicd`ConsoleError[ "Failed to build MX file!", "Fatal" -> True ],
    $mxFile
]

(* :!CodeAnalysis::EndBlock:: *)