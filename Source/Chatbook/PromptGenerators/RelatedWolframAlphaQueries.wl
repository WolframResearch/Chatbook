(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaQueries`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaQueries*)
RelatedWolframAlphaQueries // beginDefinition;

GeneralUtilities`SetUsage[ RelatedWolframAlphaQueries, "\
RelatedWolframAlphaQueries[\"string$\"] gives a list of Wolfram|Alpha queries that are semantically related to the \
conversational-style question specified by \"string$\".
RelatedWolframAlphaQueries[All] gives the full list of available Wolfram|Alpha sample queries." ];

RelatedWolframAlphaQueries[ ___ ] /; $noSemanticSearch := Failure[
    "SemanticSearchUnavailable",
    <|
        "MessageTemplate"   :> "SemanticSearch paclet is not available.",
        "MessageParameters" -> { }
    |>
];

RelatedWolframAlphaQueries[ prompt: _String | { ___String } ] :=
    catchMine @ RelatedWolframAlphaQueries[ prompt, Automatic ];

RelatedWolframAlphaQueries[ prompt: _String | { ___String }, Automatic ] := catchMine @ Enclose[
    ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", prompt, "Values" ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedWolframAlphaQueries[ prompt_, UpTo[ n_Integer ] ] :=
    RelatedWolframAlphaQueries[ prompt, n ];

RelatedWolframAlphaQueries[ prompt_, n_Integer ] := catchMine @ Enclose[
    ConfirmMatch[ Take[ RelatedWolframAlphaQueries[ prompt, Automatic ], UpTo @ n ], { ___String }, "Queries" ],
    throwInternalFailure
];

RelatedWolframAlphaQueries[ All ] := catchMine @ $uniqueWAQueries;

RelatedWolframAlphaQueries[ args___ ] := catchMine @ throwFailure[
    "InvalidArguments",
    RelatedWolframAlphaQueries,
    HoldForm @ RelatedWolframAlphaQueries @ args
];

RelatedWolframAlphaQueries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$uniqueWAQueries*)
$uniqueWAQueries := Enclose[
    $uniqueWAQueries = Union @ ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", All ], { __String }, "QueryList" ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
