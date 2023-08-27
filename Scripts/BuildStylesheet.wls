#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];
If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Paths*)
$stylesheetFile = cStr @ FileNameJoin @ { $pacletDir, "FrontEnd", "StyleSheets", "Chatbook.nb" };
$builderFile    = cFile @ FileNameJoin @ { $pacletDir, "Developer", "StylesheetBuilder.wl" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build Stylesheet*)
If[ FileExistsQ @ $stylesheetFile,
    cicd`ConsoleLog[ "Removing existing stylesheet file..." ];
    cicd`ScriptConfirm @ DeleteFile @ $stylesheetFile;
];

cicd`ScriptConfirmAssert[ ! FileExistsQ @ $stylesheetFile ];

cicd`ConsoleLog[ "Building stylesheet..." ];
Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } },
    cicd`ScriptConfirm @ CheckAbort[ Get @ $builderFile, $Failed ]
];

cicd`ScriptConfirmAssert[ FileExistsQ @ $stylesheetFile ];

cicd`ConsoleLog @ SequenceForm[ "Built stylesheet: ", $stylesheetFile ];

result = $stylesheetFile;

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result