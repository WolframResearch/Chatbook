#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];
Needs[ "GeneralUtilities`"   -> "gu`"   ];

Wolfram`ChatbookInternal`$BuildingMX = True;

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
(*Build MX*)
If[ FileExistsQ @ $mxFile,
    cicd`ConsoleLog[ "Removing existing MX file..." ];
    cicd`ScriptConfirm @ DeleteFile @ $mxFile
];

cicd`ConsoleLog[ "Loading paclet..." ];
cicd`ScriptConfirmBy[ PacletDirectoryLoad @ $pacletDir, MemberQ @ $pacletDir ];
cicd`ScriptConfirm @ CheckAbort[ Get[ "Wolfram`Chatbook`" ], $Failed ];

$mxDir = cDir @ gu`EnsureDirectory @ DirectoryName @ $mxFile;
cicd`ConsoleLog @ SequenceForm[ "MX target directory: ", $mxDir  ];
cicd`ConsoleLog @ SequenceForm[ "Building MX file: "   , $mxFile ];

DumpSave[ $mxFile, { "Wolfram`Chatbook`" }, "SymbolAttributes" -> False ];

result = If[ ! FileExistsQ @ $mxFile,
             cicd`ConsoleError[ "Failed to build MX file!", "Fatal" -> True ],
             $mxFile
         ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result