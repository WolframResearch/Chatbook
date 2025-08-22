(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`RelatedWolframAlphaQueries`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];
Needs[ "Wolfram`Chatbook`Common`"                  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::InvalidMaxItems = "\
Value of option MaxItems -> `1` should be a non-negative integer or Infinity.";

Chatbook::InvalidRandomMaxItems = "\
Value of option MaxItems -> {`1`, `2`} should have a non-negative integer as its second element.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*RelatedWolframAlphaQueries*)
RelatedWolframAlphaQueries // beginDefinition;
RelatedWolframAlphaQueries // Options = { MaxItems -> Automatic };

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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Default Arguments*)
RelatedWolframAlphaQueries[ context_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaQueries[ context, OptionValue[ "MaxItems" ], opts ];

(* Convert MaxItems argument to option: *)
RelatedWolframAlphaQueries[ context_, count: _Integer|_UpTo|_Infinity, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaQueries[ context, MaxItems -> count, opts ];

(* Default property is "Queries": *)
RelatedWolframAlphaQueries[ context_, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaQueries[ context, "Queries", opts ];

RelatedWolframAlphaQueries[ context_, Automatic, opts: OptionsPattern[ ] ] :=
    catchMine @ RelatedWolframAlphaQueries[ context, "Queries", opts ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Main Definition*)
RelatedWolframAlphaQueries[ context_, "Queries", opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ConfirmMatch[
        relatedWolframAlphaQueries[ ensureChatMessages @ context, toMaxItems @ OptionValue @ MaxItems ],
        { ___String },
        "Queries"
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Prompt*)
RelatedWolframAlphaQueries[ context_, "Prompt", opts: OptionsPattern[ ] ] := catchMine @ Enclose[
    ConfirmBy[
        relatedWolframAlphaQueriesPrompt[ ensureChatMessages @ context, toMaxItems @ OptionValue @ MaxItems ],
        StringQ,
        "Prompt"
    ],
    throwInternalFailure
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*All Available Queries*)
RelatedWolframAlphaQueries[ All, opts: OptionsPattern[ ] ] :=
    catchMine @ $uniqueWAQueries;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*End Definition*)
RelatedWolframAlphaQueries // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Helper Definitions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toMaxItems*)
toMaxItems // beginDefinition;
toMaxItems[ { relevant_, random_ } ] := { toMaxItems0 @ relevant, toRandomMaxItems[ relevant, random ] };
toMaxItems[ other_                 ] := { toMaxItems0 @ other, 0 };
toMaxItems // endDefinition;


toMaxItems0 // beginDefinition;
toMaxItems0[ n_Integer? NonNegative         ] := n;
toMaxItems0[ UpTo[ n_Integer? NonNegative ] ] := n;
toMaxItems0[ Infinity                       ] := Automatic;
toMaxItems0[ UpTo[ Infinity ]               ] := Automatic;
toMaxItems0[ Automatic                      ] := Automatic;
toMaxItems0[ other_                         ] := throwFailure[ "InvalidMaxItems", other ];
toMaxItems0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toRandomMaxItems*)
toRandomMaxItems // beginDefinition;
toRandomMaxItems[ c_, n_Integer? NonNegative         ] := n;
toRandomMaxItems[ c_, UpTo[ n_Integer? NonNegative ] ] := n;
toRandomMaxItems[ c_, Automatic                      ] := 0;
toRandomMaxItems[ c_, other_                         ] := throwFailure[ "InvalidRandomMaxItems", c, other ];
toRandomMaxItems // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaQueries*)
relatedWolframAlphaQueries // beginDefinition;

relatedWolframAlphaQueries[ context_, { count_Integer? NonNegative, randomCount_Integer? NonNegative } ] := Enclose[
    Module[ { queries, top, random },
        queries = ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", context, "Values" ], { ___String }, "Queries" ];
        top     = ConfirmMatch[ Take[ queries, UpTo @ count ], { ___String }, "Top" ];
        random  = ConfirmMatch[ RandomSample[ $uniqueWAQueries, UpTo @ randomCount ], { ___String }, "Random" ];
        Join[ top, random ]
    ],
    throwInternalFailure
];

relatedWolframAlphaQueries[ context_, { Automatic, randomCount_Integer? NonNegative } ] := Enclose[
    Module[ { queries, random },
        queries = ConfirmMatch[ vectorDBSearch[ "WolframAlphaQueries", context, "Values" ], { ___String }, "Queries" ];
        random  = ConfirmMatch[ RandomSample[ $uniqueWAQueries, UpTo @ randomCount ], { ___String }, "Random" ];
        Join[ queries, random ]
    ],
    throwInternalFailure
];

relatedWolframAlphaQueries // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*relatedWolframAlphaQueriesPrompt*)
relatedWolframAlphaQueriesPrompt // beginDefinition;

relatedWolframAlphaQueriesPrompt[ context_, items_ ] := Enclose[
    Module[ { queries },
        queries = ConfirmMatch[ relatedWolframAlphaQueries[ context, items ], { ___String }, "Queries" ];
        StringRiffle[
            Flatten @ {
                "Here are some valid Wolfram|Alpha queries to demonstrate what kinds of queries it can accept:\n",
                queries
            },
            "\n"
        ]
    ],
    throwInternalFailure
];

relatedWolframAlphaQueriesPrompt // endDefinition;

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
