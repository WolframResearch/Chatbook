#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "CodeInspector`" -> "ci`" ];
Needs[ "CodeParser`"    -> "cp`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules*)
CodeInspector`AbstractRules`$DefaultAbstractRules = <|
    CodeInspector`AbstractRules`$DefaultAbstractRules,
    cp`CallNode[ cp`LeafNode[ Symbol, "Throw", _ ], { _ }, _ ] -> scanSingleArgThrow
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scanSingleArgThrow*)
scanSingleArgThrow // ClearAll;
scanSingleArgThrow[ pos_, ast_ ] := Catch[
    Replace[
        Fold[ walkASTForCatch, ast, pos ],
        {
            cp`CallNode[ cp`LeafNode[ Symbol, "Throw", _ ], _, as_Association ] :>
                ci`InspectionObject[
                    "NoSurroundingCatch",
                    "``Throw`` has no tag or surrounding ``Catch``",
                    "Warning",
                    <| as, ConfidenceLevel -> 0.9 |>
                ],
            ___ :> { }
        }
    ],
    $tag
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*walkASTForCatch*)
walkASTForCatch // ClearAll;

walkASTForCatch[ cp`CallNode[ cp`LeafNode[ Symbol, "Catch"|"Hold"|"HoldForm"|"HoldComplete", _ ], { _ }, _ ], _ ] :=
    Throw[ { }, $tag ];

walkASTForCatch[ ast_, pos_ ] :=
    Extract[ ast, pos ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Run*)
result = checkResult @ Wolfram`PacletCICD`CheckPaclet[
    $defNB,
    "Target"           -> "Submit",
    "FailureCondition" -> { "Warning", "Error" }
];

EndPackage[ ];

Wolfram`ChatbookScripts`result