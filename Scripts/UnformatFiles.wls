#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "Wolfram`PacletCICD`" -> "cicd`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unformat*)
unformat[ file_ ] :=
    Enclose @ Module[ { nb, exported },
        nb = ConfirmMatch[ Import[ file, "NB" ], _Notebook, "Import" ];
        exported = ConfirmBy[ Export[ file, nb, "NB" ], FileExistsQ, "Export" ];
        ConfirmAssert[ StringContainsQ[ Import[ file, "String" ], "(* Internal cache information *)" ], "CacheCheck" ];
        cicd`ConsoleLog[ "    "<>exported ];
        exported
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
files = cicd`ScriptConfirmMatch[
    FileNames[ "*.nb", { FileNameJoin @ { $pacletDir, "FrontEnd" }, FileNameJoin @ { $pacletDir, "DarkModeSupport" } }, Infinity ],
    { __String }
];

cicd`ConsoleLog[ "Unformatting " <> ToString @ Length @ files <> " files..." ];

(* These symbols are known for 14.2+, but this script may run in 14.1. *)
System`LightDark;
System`LightDarkSwitched;

result = cicd`ScriptConfirmMatch[ UsingFrontEnd[
    CurrentValue[ $FrontEndSession, { PrivateFrontEndOptions, "ExperimentalNotebookParser" } ] = False; (* ensure the file outline cache is built with the old parser *)
    CurrentValue[ $FrontEndSession, DynamicUpdating ] = False;
    unformat /@ files
], { __String } ];

EndPackage[ ];

Wolfram`ChatbookScripts`result