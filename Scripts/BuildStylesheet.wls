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
$stylesheetFiles = FileNames[ "*.nb", FileNameJoin[ { $pacletDir, "FrontEnd", "StyleSheets" } ], 2 ];
$builderFile     = cFile @ FileNameJoin @ { $pacletDir, "Developer", "StylesheetBuilder.wl" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Build Stylesheet*)
Do[
    If[ FileExistsQ @ file,
        cicd`ConsoleLog @ SequenceForm[ "Removing existing stylesheet file: ", file ];
        cicd`ScriptConfirm @ DeleteFile @ file;
    ];
    cicd`ScriptConfirmAssert[ ! FileExistsQ @ file ],
    {file, $stylesheetFiles}
]

cicd`ConsoleLog[ "Building stylesheet..." ];
Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" }, $ContextAliases = $ContextAliases },
    UsingFrontEnd[
        cicd`ScriptConfirm @ CheckAbort[ Get @ $builderFile, $Failed ];
        result = cicd`ScriptConfirmBy[ Wolfram`ChatbookStylesheetBuilder`BuildStylesheets[ All ], AssociationQ ];
    ];
];

cicd`ConsoleLog @ SequenceForm[ "Built stylesheets: ", result ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result