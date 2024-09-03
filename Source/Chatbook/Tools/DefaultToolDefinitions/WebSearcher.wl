(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$defaultChatTools0[ "WebSearcher" ] = <|
    toolDefaultData[ "WebSearcher" ],
    "ShortName"          -> "web_search",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebSearcher" ],
    "Description"        -> "Search the web.",
    "Function"           -> webSearch,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "Search query text",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*webSearch*)
webSearch // beginDefinition;

webSearch[ KeyValuePattern[ "query" -> query_ ] ] :=
    Block[ { PrintTemporary }, webSearch @ query ];

webSearch[ query_String ] := Enclose[
    Catch @ Module[ { result, json, string },
        result = ConfirmMatch[ webSearch0 @ query, _Dataset|_Failure, "WebSearch" ];

        If[ MatchQ[ result, _Failure ],
            Throw @ <| "Result" -> result, "String" -> makeFailureString @ result |>
        ];

        json   = ConfirmBy[ Developer`WriteRawJSONString[ Normal @ result /. URL[ url_ ] :> url ], StringQ, "JSON" ];
        json   = StringReplace[ json, "\\/" -> "/" ];
        string = ConfirmBy[ TemplateApply[ $webSearchResultTemplate, json ], StringQ, "TemplateApply" ];

        <| "Result" -> result, "String" -> string |>
    ],
    throwInternalFailure
];

webSearch // endDefinition;


webSearch0 // beginDefinition;

webSearch0[ query_String ] := Enclose[
    Module[ { opts, raw, result, held, $unavailable },
        opts   = Sequence @@ ConfirmMatch[ toolOptions[ "WebSearcher" ], { $$optionsSequence }, "Options" ];
        result = Quiet[
            Check[
                raw = WebSearch[ query, opts ],
                $unavailable,
                (* cSpell: ignore unexp *)
                IntegratedServices`IntegratedServices::unexp
            ],
            IntegratedServices`IntegratedServices::unexp
        ];

        held = HoldForm @ Evaluate @ raw;

        Quiet @ Replace[
            result,
            {
                $unavailable       :> messageFailure[ "IntegratedServiceUnavailable", "WebSearch", held ],
                Except[ _Dataset ] :> messageFailure[ "IntegratedServiceError"      , "WebSearch", held ]
            }
        ]
    ],
    throwInternalFailure
];

webSearch0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$webSearchResultTemplate*)
$webSearchResultTemplate := StringTemplate @ StringJoin[
    "Results\n-------\n\n`1`\n\n-------",
    If[ toolSelectedQ[ "WebFetcher" ],
        $webSearchFetchPrompt,
        ""
    ]
];

$webSearchFetchPrompt = "

Important: The snippet text is not enough information to write an informed response! If there are any relevant \
results, you should now immediately use the web_fetcher tool to retrieve them before responding. Do not ask the user \
for permission first. If it made sense to use the web_searcher tool, it's also implied that you should use the \
web_fetcher tool.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
