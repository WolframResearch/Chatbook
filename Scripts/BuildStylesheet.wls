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
    cicd`ConsoleLog @ SequenceForm[ "Removing existing stylesheet file: ", $stylesheetFile ];
    cicd`ScriptConfirm @ DeleteFile @ $stylesheetFile;
];

cicd`ScriptConfirmAssert[ ! FileExistsQ @ $stylesheetFile ];

cicd`ConsoleLog[ "Building stylesheet..." ];
Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" }, $ContextAliases = $ContextAliases },
    UsingFrontEnd[
        cicd`ScriptConfirm @ CheckAbort[ Get @ $builderFile, $Failed ];
        result = cicd`ScriptConfirmBy[ Wolfram`ChatbookStylesheetBuilder`BuildChatbookStylesheet[ ], FileExistsQ ];
    ];
];

cicd`ConsoleLog @ SequenceForm[ "Built stylesheet: ", result ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result