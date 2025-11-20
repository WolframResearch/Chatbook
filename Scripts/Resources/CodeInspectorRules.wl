BeginPackage[ "Wolfram`ChatbookScripts`" ];

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
    cp`LeafNode[ Symbol, _String? privateContextQ, _ ] -> scanPrivateContext,
    cp`LeafNode[ Symbol, _String? globalSymbolQ, _ ] -> scanGlobalSymbol
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

walkASTForCatch[
    cp`CallNode[ cp`LeafNode[ Symbol, "Catch"|"Hold"|"HoldForm"|"HoldComplete"|"HoldCompleteForm", _ ], { _ }, _ ],
    _
] := Throw[ { }, $tag ];

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
(*scanGlobalSymbol*)
scanGlobalSymbol // ClearAll;
scanGlobalSymbol[ pos_, ast_ ] :=
    Enclose @ Module[ { node, name, as },
        node = ConfirmMatch[ Extract[ ast, pos ], _[ _, _, __ ], "Node" ];
        name = ConfirmBy[ node[[ 2 ]], StringQ, "Name" ];
        as = ConfirmBy[ node[[ 3 ]], AssociationQ, "Metadata" ];
        ci`InspectionObject[
            "GlobalSymbol",
            "The symbol ``" <> name <> "`` is in the global context",
            "Error",
            <| as, ConfidenceLevel -> 0.9 |>
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*globalSymbolQ*)
globalSymbolQ // ClearAll;
globalSymbolQ[ name_String ] := StringStartsQ[ name, "Global`" ];
globalSymbolQ[ ___ ] := False;

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

EndPackage[ ];