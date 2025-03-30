(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icon*)
$documentationSearcherIcon = RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationSearcher" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
(* $documentationSearcherDescription = "\
Search Wolfram Language documentation for symbols and more. \
Follow up search results with the documentation lookup tool to get the full information."; *)

$documentationSearcherDescription = "\
Discover relevant Wolfram Language documentation snippets using semantic search.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "DocumentationSearcher" ] = <|
    toolDefaultData[ "DocumentationSearcher" ],
    "ShortName"          -> "doc_search",
    "Icon"               -> $documentationSearcherIcon,
    "Description"        -> $documentationSearcherDescription,
    "Function"           -> documentationSearch,
    "FormattingFunction" -> documentationSearchFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A natural language question or description of what you're trying to achieve",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationSearch*)
documentationSearch // beginDefinition;
documentationSearch[ KeyValuePattern[ "query" -> name_ ] ] := documentationSearch @ name;
documentationSearch[ names_List ] := StringRiffle[ documentationSearch /@ names, "\n\n" ];
documentationSearch[ name_String ] /; NameQ[ "System`" <> name ] := documentationLookup @ name;
documentationSearch[ query_String ] := documentationRAGSearch @ query;
documentationSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*documentationRAGSearch*)
documentationRAGSearch // beginDefinition;

documentationRAGSearch[ query_String ] :=
    documentationRAGSearch[ query, $filterDocumentationRAG ];

documentationRAGSearch[ query_String, True ] :=
    processSearchResults @ LogChatTiming @ RelatedDocumentation[
        query,
        "Prompt",
        MaxItems        -> 30,
        "FilterResults" -> True,
        "PromptHeader"  -> False
    ];

documentationRAGSearch[ query_String, False ] :=
    processSearchResults @ LogChatTiming @ RelatedDocumentation[
        query,
        "Prompt",
        MaxItems        -> 10,
        "FilterResults" -> False,
        "PromptHeader"  -> False
    ];

documentationRAGSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*processSearchResults*)
processSearchResults // beginDefinition;
processSearchResults[ "" ] := Missing[ "NoResults" ];
processSearchResults[ results_String ] := results;
processSearchResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationSearchFormatter*)
documentationSearchFormatter // beginDefinition;

documentationSearchFormatter[ query_String, "Parameters", "query" ] :=
    clickToCopy @ query;

documentationSearchFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    documentationSearchFormatter[ result, "Result" ];

documentationSearchFormatter[ result_String, "Result" ] :=
    formatDocumentationSearchResults @ result;

documentationSearchFormatter[ expr_, ___ ] :=
    expr;

documentationSearchFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDocumentationSearchResults*)
formatDocumentationSearchResults // beginDefinition;

formatDocumentationSearchResults[ result_String ] := Enclose[
    Module[ { split },
        split = ConfirmMatch[ StringTrim @ StringSplit[ result, "\n======\n" ], { __String }, "Split" ];
        Column[
            formatDocumentationSearchResult /@ split,
            Dividers   -> Center,
            FrameStyle -> Directive[ GrayLevel[ 0.75 ], Thick ],
            Spacings   -> 4
        ]
    ],
    throwInternalFailure
];

formatDocumentationSearchResults // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDocumentationSearchResult*)
formatDocumentationSearchResult // beginDefinition;

formatDocumentationSearchResult[ item_String ] :=
    formatItem @ StringReplace[
        item,
        {
            StartOfString ~~ header: Except[ "\n" ].. ~~ "\n" ~~ uri: Except[ "\n" ].. ~~ "\n" :>
                "["<>StringDelete[ header, StartOfString ~~ "# " ]<>"]("<>uri<>")\n",
            Shortest[ "\\!\\(\\*MarkdownImageBox[\"" ~~ link__ ~~ "\"]\\)" ] :>
                "\[LeftSkeleton]\[RightSkeleton]"
        }
    ];

formatDocumentationSearchResult // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatItem*)
formatItem // beginDefinition;

formatItem[ link_Hyperlink ] := link;

formatItem[ text_String ] := Style[
    ReplaceAll[
        ReplaceAll[
            FormatChatOutput @ text,
            Cell[
                BoxData @ TemplateBox[ { cell: Cell[ __, "ChatCode", ___ ], ___ }, "ChatCodeBlockTemplate", ___ ],
                "ChatCodeBlock",
                ___
            ] :> Cell @ PaneBox[ cell, ImageMargins -> { { 0, 0 }, { 0, 20 } } ]
        ],
        Cell[ BoxData @ GridBox[ grid_, gOpts___ ], "CellGroupBlock", cOpts___ ] :>
            Cell[
                BoxData @ PaneBox[
                    GridBox[
                        grid,
                        gOpts,
                        GridBoxSpacings -> { "Columns" -> { { Automatic } }, "Rows" -> { 0.5, { 0.5, 1 } } }
                    ],
                    ImageMargins -> { { 0, 0 }, { 10, 10 } }
                ],
                "CellGroupBlock",
                cOpts
            ]
    ],
    "Text"
];

formatItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
