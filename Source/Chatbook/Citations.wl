(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Citations`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$sources       = None;
$stopTokens    = { "[NONE]" };
$defaultConfig = <| "StopTokens" -> $stopTokens, "Model" -> <| "Name" -> "gpt-4o-mini" |> |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Patterns*)
$$uri     = _String | URL[ _String ];
$$source  = KeyValuePattern @ { "URI" -> $$uri, "Content" -> $$messageContent };
$$sources = { $$source... };

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Messages*)
Chatbook::NoAutoSources = "No automatic sources are available for citations.";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$generationTemplate*)
$generationTemplate = StringTemplate[ "\
Your task is to identify which sources were used in an assistant's response \
for the purposes of generating accurate citations.

Here is the assistant's response:

<response>
`Response`
</response>

Here are the list of sources that the assistant looked at before responding:

<sources>

`Sources`

</sources>

Respond with the IDs of sources that should be used to cite the assistant's response, each on a separate line.
Respond with the IDs and nothing else.
If the assistant did not use any of the listed sources, reply only with [NONE].

Reminder, these are the available source IDs:

`SourceIDs`\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$sourceTemplate*)
$sourceTemplate = StringTemplate[ "<source id='`ShortID`'>\n`Content`\n</source>" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*GenerateCitations*)
GenerateCitations // beginDefinition;

GenerateCitations[ text_ ] :=
    catchMine @ GenerateCitations[ text, Automatic ];

GenerateCitations[ text_, sources: $$sources|Automatic ] :=
    catchMine @ GenerateCitations[ text, sources, Automatic ];

GenerateCitations[ text_, sources: $$sources|Automatic, fmt_ ] :=
    catchMine @ formatCitations[ generateCitations[ text, sources ], fmt ];

GenerateCitations // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*generateCitations*)
generateCitations // beginDefinition;

generateCitations[ text_, Automatic ] := Enclose[
    Module[ { sourcesList },
        sourcesList = ConfirmMatch[ getAutoSources[ ], $$sources, "Sources" ];
        generateCitations[ text, sourcesList ]
    ],
    throwInternalFailure
];

generateCitations[ text_String, sources0_List ] := Enclose[
    Catch @ Module[
        {
            sources, shortIDs, idsString, sourcesStrings, sourcesString, instructions,
            response, chosen, uris, uriLookup, citations
        },

        sources = ConfirmMatch[
            DeleteMissing[ ensureStringContent /@ sources0 ],
            { KeyValuePattern[ "Content" -> _String ]... },
            "Sources"
        ];

        shortIDs = ConfirmMatch[ sources[[ All, "ShortID" ]], { ___String }, "ShortIDs" ];
        If[ shortIDs === { }, Throw @ { } ];

        idsString      = StringRiffle[ shortIDs, "\n" ];
        sourcesStrings = ConfirmMatch[ TemplateApply[ $sourceTemplate, # ] & /@ sources, { ___String }, "Sources" ];
        sourcesString  = StringRiffle[ sourcesStrings, "\n\n" ];

        instructions = ConfirmBy[
            TemplateApply[
                $generationTemplate,
                <|
                    "Response"  -> text,
                    "Sources"   -> sourcesString,
                    "SourceIDs" -> idsString
                |>
            ],
            StringQ,
            "Prompt"
        ];

        response = ConfirmBy[
            LogChatTiming[
                setServiceCaller[ llmSynthesize[ instructions, $defaultConfig ], "GenerateCitations" ],
                "WaitForGenerateCitationsTask"
            ],
            StringQ,
            "Response"
        ];

        chosen = ConfirmMatch[
            DeleteDuplicates @ DeleteCases[
                StringTrim @ StringSplit[ response, "\n" ],
                "" | "[NONE]"
            ],
            { ___String },
            "Chosen"
        ];

        If[ chosen === { }, Throw @ { } ];

        uris = ConfirmMatch[ snippetIDToURI /@ chosen, { ___String }, "URIs" ];

        uriLookup = Association[ #URI -> # & /@ sources ];

        citations = ConfirmMatch[ Values @ KeyTake[ uriLookup, uris ], $$sources, "Citations" ];

        addHandlerArguments @ <| "Sources" -> sources, "Citations" -> KeyDrop[ citations, "Content" ] |>;

        citations
    ],
    throwInternalFailure
];

generateCitations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*ensureStringContent*)
ensureStringContent // beginDefinition;

ensureStringContent[ source: KeyValuePattern[ "Content" -> _String ] ] := source;

ensureStringContent[ source: KeyValuePattern[ "Content" -> content: { __Association } ] ] := Enclose[
    Catch @ Module[ { strings, string },
        strings = ConfirmMatch[
            Cases[ content, KeyValuePattern @ { "Type" -> "Text", "Data" -> text_String } :> text ],
            { __String },
            "Strings"
        ];

        string = StringTrim @ StringJoin @ strings;
        If[ string === "", Throw @ Missing[ "EmptyString" ] ];

        <| source, "Content" -> string |>
    ],
    throwInternalFailure
];

ensureStringContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getAutoSources*)
getAutoSources // beginDefinition;
getAutoSources[ ] := getAutoSources[ $ChatHandlerData[ "Sources" ], $sources ];
getAutoSources[ sources: $$sources, _ ] := sources;
getAutoSources[ _, sources_Association ] := Values @ sources;
getAutoSources[ _, _ ] := throwFailure[ "NoAutoSources" ];
getAutoSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatCitations*)
formatCitations // beginDefinition;
formatCitations[ citations_, Automatic ] := citations;
formatCitations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AddToSources*)
AddToSources // beginDefinition;
AddToSources[ source: $$source ] := catchMine @ addToSources @ source;
AddToSources[ sources: { $$source... } ] := catchMine[ addToSources /@ sources ];
AddToSources[ uri: $$uri, mc: $$messageContent ] := catchMine @ addToSources @ <| "URI" -> uri, "Content" -> mc |>;
AddToSources // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*addToSources*)
addToSources // beginDefinition;

addToSources[ source_ ] := Enclose[
    Module[ { uri, data },

        uri  = ConfirmMatch[ source[ "URI" ], $$uri, "URI" ];
        data = ConfirmMatch[ toSourceData @ source, $$source, "Data" ];

        If[ ! AssociationQ @ $sources,
            $sources = <| uri -> data |>,
            $sources[ uri ] = data
        ];

        ConfirmBy[ $sources, AssociationQ, "Result" ];

        data
    ],
    throwInternalFailure
];

addToSources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toSourceData*)
toSourceData // beginDefinition;

toSourceData[ source_Association ] := Enclose[
    KeySort @ <|
        source,
        "ShortID" -> ConfirmBy[ getSourceID @ source, StringQ, "ID" ],
        "Type"    -> ConfirmBy[ getSourceType @ source, StringQ, "Type" ],
        "URI"     -> ConfirmBy[ Replace[ source[ "URI" ], URL[ uri_String ] :> uri ], StringQ, "URI" ]
    |>,
    throwInternalFailure
];

toSourceData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSourceID*)
getSourceID // beginDefinition;
getSourceID[ KeyValuePattern[ "ShortID" -> id_String ] ] := id;
getSourceID[ KeyValuePattern[ "URI" -> uri_ ] ] := uriToSnippetID @ uri;
getSourceID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSourceType*)
getSourceType // beginDefinition;
getSourceType[ KeyValuePattern[ "Type" -> type_String ] ] := type;
getSourceType[ KeyValuePattern[ "URI" -> uri_ ] ] := getSourceTypeFromURI @ uri;
getSourceType // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getSourceTypeFromURI*)
getSourceTypeFromURI // beginDefinition;
getSourceTypeFromURI[ URL[ uri_String ] ] := getSourceTypeFromURI @ uri;
getSourceTypeFromURI[ uri_String ] := getSourceTypeFromURI @ URLParse @ uri;
getSourceTypeFromURI[ KeyValuePattern[ "Scheme" -> "paclet" ] ] := "Documentation";
getSourceTypeFromURI[ as_Association ] := getSourceTypeFromURI[ as[ "Scheme" ], as[ "Domain" ], as[ "Path" ] ];
getSourceTypeFromURI[ _, "reference.wolfram.com", _ ] := "Documentation";
getSourceTypeFromURI[ _, "paclets.com", _ ] := "PacletRepository";
getSourceTypeFromURI[ _, "datarepository.wolframcloud.com", _ ] := "DataRepository";
getSourceTypeFromURI[ _, "resources.wolframcloud.com", { "", type_String, __ } ] := type;
getSourceTypeFromURI[ _, "www.wolframalpha.com", _ ] := "WolframAlpha";
getSourceTypeFromURI[ "http"|"https", _, _ ] := "Web";
getSourceTypeFromURI[ "file", _, _ ] := "File";
getSourceTypeFromURI[ _, _, _ ] := "Unknown";
getSourceTypeFromURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Append Citations to End of Response*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*appendCitations*)
appendCitations // beginDefinition;
appendCitations // Attributes = { HoldFirst };

appendCitations[ container_, settings_ ] := Enclose[
    Catch @ Module[ { sources, citations },
        sources = Values @ ConfirmBy[ $sources, AssociationQ, "Sources" ];
        applyHandlerFunction[ settings, "AppendCitationsStart", "Sources" -> sources ];
        If[ ! TrueQ @ settings[ "AppendCitations" ], Throw @ Null ];
        citations = ConfirmBy[ makeCitationsString[ container[ "FullContent" ], sources ], StringQ, "Citations" ];
        container[ "FullContent" ] = container[ "FullContent" ] <> citations;
        container[ "DynamicContent" ] = container[ "DynamicContent" ] <> citations;
        applyHandlerFunction[ settings, "AppendCitationsEnd", <| "CitationString" -> citations |> ];
    ],
    throwInternalFailure
];

appendCitations // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCitationsString*)
makeCitationsString // beginDefinition;

makeCitationsString[ text_String, sources: $$sources ] := Enclose[
    Catch @ Module[ { citations, grouped, mdGroups, markdown },
        citations = ConfirmMatch[ LogChatTiming @ GenerateCitations[ text, sources ], $$sources, "Citations" ];
        If[ citations === { }, Throw[ "" ] ];
        grouped = GroupBy[ citations, Lookup[ "Type" ] -> Lookup[ "URI" ] ];
        mdGroups = ConfirmMatch[ KeyValueMap[ makeSourceGroup, grouped ], { __String }, "MDGroups" ];
        markdown = StringTrim @ StringRiffle[ mdGroups, "\n\n" ];
        If[ markdown === "", Throw[ "" ] ];
        "\n\n<wolfram-sources>\n### Sources\n\n" <> markdown <> "\n</wolfram-sources>"
    ],
    throwInternalFailure
];

makeCitationsString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeSourceGroup*)
makeSourceGroup // beginDefinition;

makeSourceGroup[ type_String, urls_List ] :=
    "* " <> type <> ": " <> StringRiffle[ MapIndexed[ makeSourceLink, urls ], " " ];

makeSourceGroup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeSourceLink*)
makeSourceLink // beginDefinition;
makeSourceLink[ uri_String, { idx_Integer } ] := "[" <> ToString @ idx <> "](" <> uri <> ")";
makeSourceLink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
