#!/usr/bin/env wolframscript

BeginPackage[ "Wolfram`ChatbookScripts`" ];

If[ ! TrueQ @ $loadedDefinitions, Get @ FileNameJoin @ { DirectoryName @ $InputFileName, "Common.wl" } ];

Needs[ "CodeInspector`" -> "ci`" ];
Needs[ "CodeParser`"    -> "cp`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$inGitHub := $inGitHub = StringQ @ Environment[ "GITHUB_ACTIONS" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Custom Rules*)
CodeInspector`AbstractRules`$DefaultAbstractRules = <|
    CodeInspector`AbstractRules`$DefaultAbstractRules,
    cp`CallNode[ cp`LeafNode[ Symbol, "Throw", _ ], { _ }, _ ] -> scanSingleArgThrow,
    cp`LeafNode[ Symbol, _String? privateContextQ, _ ] -> scanPrivateContext
|>;

CodeInspector`ConcreteRules`$DefaultConcreteRules = <|
    CodeInspector`ConcreteRules`$DefaultConcreteRules,
    cp`LeafNode[
        Token`Comment,
        _String? (StringStartsQ[ "(*"~~WhitespaceCharacter...~~"FIXME:" ]),
        _
    ] -> scanFixMeComment
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
(*scanPrivateContext*)
scanPrivateContext // ClearAll;
scanPrivateContext[ pos_, ast_ ] :=
    Enclose @ Module[ { node, name, as },
        node = ConfirmMatch[ Extract[ ast, pos ], _[ _, _, __ ], "Node" ];
        name = ConfirmBy[ node[[ 2 ]], StringQ, "Name" ];
        as = ConfirmBy[ node[[ 3 ]], AssociationQ, "Metadata" ];
        ci`InspectionObject[
            "PrivateContextSymbol",
            "The symbol ``" <> name <> "`` is in a private context",
            "Warning",
            <| as, ConfidenceLevel -> 0.9 |>
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*privateContextQ*)
privateContextQ // ClearAll;
privateContextQ[ name_String ] /; StringStartsQ[ name, "System`Private`" ] := False;
privateContextQ[ name_String ] := StringContainsQ[ name, __ ~~ ("`Private`"|"`PackagePrivate`") ];
privateContextQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*scanFixMeComment*)
scanFixMeComment // ClearAll;

scanFixMeComment[ pos_, ast_ ] /; $inGitHub :=
    Enclose @ Module[ { node, comment, as },
        node = ConfirmMatch[ Extract[ ast, pos ], _[ _, _, __ ], "Node" ];
        comment = StringTrim @ StringTrim[ ConfirmBy[ node[[ 2 ]], StringQ, "Comment" ], { "(*", "*)" } ];
        as = ConfirmBy[ node[[ 3 ]], AssociationQ, "Metadata" ];
        ci`InspectionObject[ "FixMeComment", comment, "Remark", <| as, ConfidenceLevel -> 0.9 |> ]
    ];

scanFixMeComment[ pos_, ast_ ] := { };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug*)
Needs[ "Wolfram`PacletCICD`" -> None ];

PrependTo[
    DownValues @ Wolfram`PacletCICD`ToMarkdownString,
    HoldPattern[ Wolfram`PacletCICD`ToMarkdownString[ args___ ] /; ! TrueQ @ $override ] :>
        Block[ { $override = True, out },
            Print[ "Markdown input: ", ToString[ HoldComplete @ args, InputForm ] ];
            out = Wolfram`PacletCICD`ToMarkdownString @ args;
            Print[ "Markdown output: ", ToString[ out, InputForm ] ];
            out
        ]
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