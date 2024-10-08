(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$defaultChatTools0[ "WebImageSearcher" ] = <|
    toolDefaultData[ "WebImageSearcher" ],
    "ShortName"          -> "img_search",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconWebImageSearcher" ],
    "Description"        -> "Search the web for images.",
    "Function"           -> webImageSearch,
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
(*webImageSearch*)
webImageSearch // beginDefinition;

webImageSearch[ KeyValuePattern[ "query" -> query_ ] ] := Block[ { PrintTemporary }, webImageSearch @ query ];
webImageSearch[ query_String ] := webImageSearch[ query, webImageSearch0[ query ] ];

webImageSearch[ query_, { } ] := <|
    "Result" -> { },
    "String" -> "No results found"
|>;

webImageSearch[ query_, urls: { __ } ] := <|
    "Result" -> Column[ Hyperlink /@ urls, BaseStyle -> "Text" ],
    "String" -> StringRiffle[ TextString /@ urls, "\n" ]
|>;

webImageSearch[ query_, failed_Failure ] := <|
    "Result" -> failed,
    "String" -> makeFailureString @ failed
|>;

webImageSearch // endDefinition;


webImageSearch0 // beginDefinition;

webImageSearch0[ query_String ] := Enclose[
    Module[ { opts, raw, result, held, $unavailable },
        opts   = Sequence @@ ConfirmMatch[ toolOptions[ "WebImageSearcher" ], { $$optionsSequence }, "Options" ];
        result = Quiet[
            Check[
                raw = WebImageSearch[ query, "ImageHyperlinks", opts ],
                $unavailable,
                IntegratedServices`IntegratedServices::unexp
            ],
            IntegratedServices`IntegratedServices::unexp
        ];

        held = HoldForm @ Evaluate @ raw;

        Quiet @ Replace[
            result,
            {
                $unavailable    :> messageFailure[ "IntegratedServiceUnavailable", "WebImageSearch", held ],
                Except[ _List ] :> messageFailure[ "IntegratedServiceError"      , "WebImageSearch", held ]
            }
        ]
    ],
    throwInternalFailure
];

webImageSearch0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
