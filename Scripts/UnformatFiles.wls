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
    FileNames[ "*.nb", FileNameJoin @ { $pacletDir, "FrontEnd" }, Infinity ],
    { __String }
];

cicd`ConsoleLog[ "Unformatting " <> ToString @ Length @ files <> " files..." ];

result = cicd`ScriptConfirmMatch[ unformat /@ files, { __String } ];

EndPackage[ ];

Wolfram`ChatbookScripts`result