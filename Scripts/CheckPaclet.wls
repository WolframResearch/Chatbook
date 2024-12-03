#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "CodeInspector`" -> "ci`" ];
Needs[ "CodeParser`"    -> "cp`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$inGitHub := $inGitHub = StringQ @ Environment[ "GITHUB_ACTION" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules*)
CodeInspector`AbstractRules`$DefaultAbstractRules = <|
    CodeInspector`AbstractRules`$DefaultAbstractRules,
    cp`CallNode[ cp`LeafNode[ Symbol, "Throw", _ ], { _ }, _ ] -> scanSingleArgThrow
|>;

CodeInspector`ConcreteRules`$DefaultConcreteRules = <|
    CodeInspector`ConcreteRules`$DefaultConcreteRules,
    cp`LeafNode[
        Token`Comment,
        _String? (StringStartsQ[ "(*"~~WhitespaceCharacter...~~"FIXME:" ]),
        _
    ] /; $inGitHub -> scanFixMeComment
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
                    "Error",
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
(* ::Subsection::Closed:: *)
(*scanFixMeComment*)
scanFixMeComment // ClearAll;
scanFixMeComment[ pos_, ast_ ] :=
    Enclose @ Module[ { node, comment, as },
        node = ConfirmMatch[ Extract[ ast, pos ], _[ _, _, __ ], "Node" ];
        comment = StringTrim @ StringTrim[ ConfirmBy[ node[[ 2 ]], StringQ, "Comment" ], { "(*", "*)" } ];
        as = ConfirmBy[ node[[ 3 ]], AssociationQ, "Metadata" ];
        ci`InspectionObject[ "FixMeComment", comment, "Remark", <| as, ConfidenceLevel -> 0.9 |> ]
    ];

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