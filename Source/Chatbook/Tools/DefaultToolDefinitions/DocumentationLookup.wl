(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$markdownPageTimeConstraint = 30;

(* Whole pages can be very long (e.g. 65k characters for Plot), so they are cut to this many characters: *)
$maxPageLength = 20000;

$$referenceURL = ("https"|"http") ~~ "://reference.wolfram.com/language/";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$documentationLookupDescription = "\
Get Wolfram Language documentation, including Function, Data, Neural Net and Paclet Repository resources. \
Pass all the ids you need in one call.";

$documentationIDsHelp = "\
Comma-separated ids: symbol names (e.g. 'Table'), page URIs for a whole page, which can be long \
(e.g. 'paclet:ref/Table', 'paclet:guide/ListManipulation' or 'resource:function/FITImport'), \
or snippet URIs with a # fragment for just that snippet \
(e.g. 'paclet:ref/Table#23775' or 'resource:function/FITImport#334957977')";

$defaultChatTools0[ "DocumentationLookup" ] = <|
    toolDefaultData[ "DocumentationLookup" ],
    "ShortName"          -> "doc_lookup",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationLookup" ],
    "CallIcon"           -> toolCallIconResource[ "DocumentationLookup" ],
    "Description"        -> $documentationLookupDescription,
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
(* Gives the pages and snippets for the ids, then any instructions that they need, separated by "======". An id that
   isn't found gives Missing["NotFound", uri] in InputForm. *)
(* NOTE: Looked up snippets are not added to the sources for citations (AddToSources), unlike the RAG prompt's
   filtered snippets. *)
documentationLookup // beginDefinition;

(* The interpreter gives a list of lists when "ids" is given as a list: *)
documentationLookup[ KeyValuePattern[ "ids" -> ids_ ] ] := documentationLookup @ Flatten @ { ids };

documentationLookup[ id_String ] := documentationLookup @ { id };

documentationLookup[ ids: { ___String } ] := Enclose[
    Module[ { uris, results, found, instructions },
        uris = toDocumentationURI /@ ids;
        results = ConfirmMatch[ lookupDocumentation /@ uris, { (_String|_Missing)... }, "Results" ];
        found = Pick[ uris, StringQ /@ results ];
        instructions = ConfirmMatch[ lookupInstructions @ found, { ___String }, "Instructions" ];
        addExampleDataHint @ cleanSnippets @ StringRiffle[
            Join[ Replace[ results, missing_Missing :> ToString[ missing, InputForm ], { 1 } ], instructions ],
            "\n\n======\n\n"
        ]
    ],
    throwInternalFailure
];

documentationLookup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*lookupDocumentation*)
lookupDocumentation // beginDefinition;

lookupDocumentation[ uri_String ] :=
    Replace[ catchQuiet @ lookupDocumentation0 @ uri, Except[ _String ] :> Missing[ "NotFound", uri ] ];

lookupDocumentation // endDefinition;


lookupDocumentation0 // beginDefinition;

(* Documentation pages are Markdown files in the cloud: *)
lookupDocumentation0[ uri_String ] /; StringStartsQ[ uri, "paclet:" ] && StringFreeQ[ uri, "#" ] :=
    truncatePage @ markdownPage @ uri;

(* Snippets are read from their page's block, so that a snippet or page that the store doesn't have (e.g. a guessed
   URI) is just not found: *)
lookupDocumentation0[ uri_String ] /; StringContainsQ[ uri, "#" ] :=
    Replace[
        Lookup[ Replace[ getPageSnippets @ snippetRootURI @ uri, _Missing -> <| |> ], uri ],
        snippet_String :> "# " <> StringDelete[ snippet, StartOfString ~~ "# " ]
    ];

(* Resource pages are made from their snippets: *)
lookupDocumentation0[ uri_String ] :=
    truncatePage @ resourcePage @ uri;

lookupDocumentation0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownPage*)
markdownPage // beginDefinition;

markdownPage[ uri_String ] := Module[ { url, response, body },
    url = URLBuild @ { $documentationMarkdownBaseURL, StringDelete[ uri, "paclet:" ] <> ".md" };
    response = Quiet @ URLRead[ url, TimeConstraint -> $markdownPageTimeConstraint ];
    (* The pages are UTF-8, but are served without a charset, so "Body" would decode them as ISO-8859-1: *)
    body = If[ response[ "StatusCode" ] === 200, ByteArrayToString @ response[ "BodyByteArray" ] ];
    (* Only pages that were found are memoized, so that a network problem doesn't hide a page for the rest of the
       session. NOTE: the memoized pages have no size limit. *)
    If[ StringQ @ body, markdownPage[ uri ] = body, Missing[ "NotFound", uri ] ]
];

markdownPage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncatePage*)
truncatePage // beginDefinition;
truncatePage[ page_String ] /; StringLength @ page <= $maxPageLength := page;
truncatePage[ page_String ] := StringTake[ page, $maxPageLength ] <> "\n\n[Page truncated]";
truncatePage[ missing_Missing ] := missing;
truncatePage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resourcePage*)
(* There are no Markdown pages for resources, but the store has all the snippets of each page, in page order: *)
resourcePage // beginDefinition;
resourcePage[ uri_String ] := resourcePage[ uri, getPageSnippets @ uri ];
resourcePage[ uri_String, missing_Missing ] := missing;
resourcePage[ uri_String, snippets_Association ] := assemblePage[ uri, Values @ snippets ];
resourcePage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*assemblePage*)
(* Each snippet is "<breadcrumb>\n<snippet URI>\n\n<body>", with a breadcrumb such as
   "WFR > FITImport > Examples > Basic Examples > 2". The page title is the start of the breadcrumb that all snippets
   share, and the rest is the heading of the snippet's section, unless it continues the previous one (" > 2", ...): *)
assemblePage // beginDefinition;

assemblePage[ uri_String, snippets: { __String } ] := Module[ { parts, crumbs, title, sections, items },
    parts    = PadRight[ StringSplit[ #, "\n", 3 ], 3, "" ] & /@ snippets;
    crumbs   = StringSplit[ parts[[ All, 1 ]], " > " ];
    title    = Take[ First @ crumbs, commonPrefixLength @ crumbs ];
    sections = StringRiffle[ Drop[ #, Length @ title ], " > " ] & /@ crumbs;
    sections = StringDelete[ sections, " > " ~~ DigitCharacter.. ~~ EndOfString ];
    items    = MapThread[
        If[ #1 === "" || #1 === #2, #3, "## " <> #1 <> "\n\n" <> #3 ] &,
        { sections, Prepend[ Most @ sections, "" ], StringTrim @ parts[[ All, 3 ]] }
    ];
    StringRiffle[ Prepend[ items, "# " <> StringRiffle[ title, " > " ] <> "\n" <> uri ], "\n\n" ]
];

assemblePage // endDefinition;


commonPrefixLength // beginDefinition;
commonPrefixLength[ lists: { __List } ] :=
    LengthWhile[ Transpose[ Take[ #, Min[ Length /@ lists ] ] & /@ lists ], Apply @ SameQ ];
commonPrefixLength // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*lookupInstructions*)
(* The instructions that the RAG prompt adds to some kinds of snippets (see addInstructions in RelatedDocumentation.wl),
   once for all the found uris: *)
lookupInstructions // beginDefinition;

lookupInstructions[ uris: { ___String } ] := Enclose[
    Module[ { entity, paclet },

        entity = If[ AnyTrue[ uris, StringStartsQ[ "paclet:ref/entity/" ] ],
                     Prepend[
                         instructionStrings @ getInstructionsFunction[ "EntityValues" ],
                         ConfirmBy[ getNamedSnippet[ "BasicEntityUsage" ], StringQ, "BasicEntityUsage" ]
                     ],
                     { }
                 ];

        paclet = If[ AnyTrue[ uris, StringStartsQ[ "https://paclets.com/" ] ],
                     instructionStrings @ getInstructionsFunction[ "PacletRepositoryURIs" ],
                     { }
                 ];

        ConfirmMatch[ DeleteCases[ Join[ entity, paclet ], "" ], { ___String }, "Result" ]
    ],
    throwInternalFailure
];

lookupInstructions // endDefinition;


instructionStrings // beginDefinition;
instructionStrings[ None ] := { };
instructionStrings[ instructions_String ] := { instructions };
instructionStrings[ URL[ uri_String ] ] := { getSnippets @ uri };
instructionStrings[ instructions_List ] := Flatten[ instructionStrings /@ instructions ];
instructionStrings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toDocumentationURI*)
toDocumentationURI // beginDefinition;

toDocumentationURI[ name_String ] /; Internal`SymbolNameQ[ name, True ] :=
    "paclet:ref/" <> StringReplace[ StringDelete[ name, StartOfString ~~ "System`" ], "`" -> "/" ];

toDocumentationURI[ id_String ] /; StringFreeQ[ id, ":" ] && StringContainsQ[ id, "/" ] :=
    "paclet:" <> StringTrim[ id, "/" ];

(* e.g. "https://reference.wolfram.com/language/ref/Table.html#23775" -> "paclet:ref/Table#23775" *)
toDocumentationURI[ id_String ] /; StringStartsQ[ id, $$referenceURL ] :=
    "paclet:" <> StringReplace[
        StringDelete[ id, StartOfString ~~ $$referenceURL ],
        { ".html#" -> "#", ".html" ~~ EndOfString -> "" }
    ];

(* Short resource URIs, e.g. "resource:function/FITImport#334957977", are expanded: *)
toDocumentationURI[ id_String ] :=
    expandSnippetURI @ id;

toDocumentationURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
