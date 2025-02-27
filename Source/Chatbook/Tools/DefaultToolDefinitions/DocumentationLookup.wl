(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$documentationIDsHelp = "\
One or more symbol names or documentation URIs separated by commas, \
e.g. 'Table', 'paclet:ref/Table', or 'paclet:ref/Table,paclet:tutorial/Lists,guide/ListManipulation'";

$defaultChatTools0[ "DocumentationLookup" ] = <|
    toolDefaultData[ "DocumentationLookup" ],
    "ShortName"          -> "doc_lookup",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationLookup" ],
    "Description"        -> "Get Wolfram Language documentation pages.",
    "Function"           -> documentationLookup,
    "FormattingFunction" -> documentationSearchFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "ids" -> Block[ { DelimitedSequence },
            <|
                "Interpreter" -> DelimitedSequence[ "String", "," ],
                "Help"        -> $documentationIDsHelp,
                "Required"    -> True
            |>
        ]
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationLookup*)
documentationLookup // beginDefinition;
documentationLookup[ KeyValuePattern[ "ids" -> ids_ ] ] := documentationLookup @ ids;
documentationLookup[ ids_List ] := StringRiffle[ documentationLookup /@ ids, "\n\n======\n\n" ];
documentationLookup[ id_String ] := documentationLookup0 @ toDocumentationURI @ id;
documentationLookup // endDefinition;


documentationLookup0 // beginDefinition;

documentationLookup0[ uri_String ] /; StringStartsQ[ uri, "paclet:" ] && StringFreeQ[ uri, "#" ] :=
    Module[ { url, response, body },
        url = URLBuild @ { $documentationMarkdownBaseURL, StringDelete[ uri, "paclet:" ] <> ".md" };
        response = URLRead @ url;
        body = If[ response[ "StatusCode" ] === 200, response[ "Body" ] ];
        documentationLookup0[ uri ] =
            If[ StringQ @ body,
                body,
                ToString[ Missing[ "NotFound", uri ], InputForm ]
            ]
    ];

documentationLookup0[ uri_String ] :=
    Module[ { snippet },
        snippet = Quiet @ catchAlways @ getSnippets @ uri;
        documentationLookup0[ uri ] =
            If[ StringQ @ snippet,
                snippet,
                ToString[ Missing[ "NotFound", uri ], InputForm ]
            ]
    ];

documentationLookup0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toDocumentationURI*)
toDocumentationURI // beginDefinition;

toDocumentationURI[ name_String ] /; Internal`SymbolNameQ[ name, True ] :=
    "paclet:ref/" <> StringReplace[ StringDelete[ name, StartOfString ~~ "System`" ], "`" -> "/" ];

toDocumentationURI[ id_String ] /; StringFreeQ[ id, ":" ] && StringContainsQ[ id, "/" ] :=
    "paclet:" <> StringTrim[ id, "/" ];

toDocumentationURI[ id_String ] /; StringStartsQ[ id, ("https"|"http") ~~ "://reference.wolfram.com/language/" ] :=
    "paclet:" <> StringDelete[ id, ("https"|"http") ~~ "://reference.wolfram.com/language/" ];

toDocumentationURI[ id_String ] :=
    id;

toDocumentationURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
