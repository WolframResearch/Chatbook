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
$sourceFile = cFile @ FileNameJoin @ { $pacletDir, "Developer", "VectorDatabases", "VectorDatabaseBuilder.wl" };
$sourceDir  = cDir @ FileNameJoin @ { $pacletDir, "Developer", "VectorDatabases", "SourceData" };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
cicd`ScriptConfirmMatch[ DeleteFile /@ FileNames[ "*.jsonl", $sourceDir ], { Null... } ];
cicd`ScriptConfirmMatch[ Get @ $sourceFile, Null ];
result = cicd`ScriptConfirmBy[ BuildVectorDatabase @ All, AssociationQ ];
cicd`ConfirmAssert @ AllTrue[ result, MatchQ[ _VectorDatabaseObject ] ];

(* :!CodeAnalysis::EndBlock:: *)

EndPackage[ ];

Wolfram`ChatbookScripts`result