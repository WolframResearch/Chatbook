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
$documentationSearcherDescription = "\
Search Wolfram Language documentation for symbols and more. \
Follow up search results with the documentation lookup tool to get the full information.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "DocumentationSearcher" ] = <|
    toolDefaultData[ "DocumentationSearcher" ],
    "ShortName"          -> "doc_search",
    "Icon"               -> $documentationSearcherIcon,
    "Description"        -> $documentationSearcherDescription,
    "Function"           -> documentationSearch,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "A string representing a documentation search query",
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
documentationSearch[ query_String ] := documentationSearch[ query, documentationSearchAPI @ query ];
documentationSearch[ query_String, { } ] := ToString[ Missing[ "NoResults" ], InputForm ];
documentationSearch[ query_String, results_List ] := StringRiffle[ results, "\n" ];
documentationSearch // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
