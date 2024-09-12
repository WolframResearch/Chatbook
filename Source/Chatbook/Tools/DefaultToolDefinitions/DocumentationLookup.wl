(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)
$defaultChatTools0[ "DocumentationLookup" ] = <|
    toolDefaultData[ "DocumentationLookup" ],
    "ShortName"          -> "doc_lookup",
    "Icon"               -> RawBoxes @ TemplateBox[ { }, "ToolIconDocumentationLookup" ],
    "Description"        -> "Get documentation pages for Wolfram Language symbols.",
    "Function"           -> documentationLookup,
    "FormattingFunction" -> toolAutoFormatter,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "names" -> <|
            "Interpreter" -> DelimitedSequence[ "WolframLanguageSymbol", "," ],
            "Help"        -> "One or more Wolfram Language symbols separated by commas",
            "Required"    -> True
        |>
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Function*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationLookup*)
documentationLookup // beginDefinition;

documentationLookup[ KeyValuePattern[ "names" -> name_ ] ] := documentationLookup @ name;
documentationLookup[ name_Entity ] := documentationLookup @ CanonicalName @ name;
documentationLookup[ names_List ] := StringRiffle[ documentationLookup /@ names, "\n\n---\n\n" ];

documentationLookup[ name_String ] := Enclose[
    Module[ { usage, details, examples, strings, body },
        usage    = ConfirmMatch[ documentationUsage @ name, _String|_Missing, "Usage" ];
        details  = ConfirmMatch[ documentationDetails @ name, _String|_Missing, "Details" ];
        examples = ConfirmMatch[ documentationBasicExamples @ name, _String|_Missing, "Examples" ];
        strings  = ConfirmMatch[ DeleteMissing @ { usage, details, examples }, { ___String }, "Strings" ];
        body     = If[ strings === { }, ToString[ Missing[ "NotFound" ], InputForm ], StringRiffle[ strings, "\n\n" ] ];
        "# " <> name <> "\n\n" <> body
    ],
    throwInternalFailure
];

documentationLookup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationUsage*)
documentationUsage // beginDefinition;
documentationUsage[ name_String ] := documentationUsage[ name, wolframLanguageData[ name, "PlaintextUsage" ] ];
documentationUsage[ name_, missing_Missing ] := missing;
documentationUsage[ name_, usage_String ] := "## Usage\n\n" <> usage;
documentationUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationDetails*)
documentationDetails // beginDefinition;
documentationDetails[ name_String ] := Missing[ ]; (* TODO *)
documentationDetails // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*documentationBasicExamples*)
documentationBasicExamples // beginDefinition;

documentationBasicExamples[ name_String ] :=
    documentationBasicExamples[ name, wolframLanguageData[ name, "DocumentationBasicExamples" ] ];

documentationBasicExamples[ name_, missing_Missing ] := missing;

documentationBasicExamples[ name_, examples_List ] := Enclose[
    Module[ { cells, strings },
        cells   = renumberCells @ Replace[ Flatten @ examples, RawBoxes[ cell_ ] :> cell, { 1 } ];
        strings = ConfirmMatch[ cellToString /@ cells, { ___String }, "CellToString" ];
        If[ strings === { },
            Missing[ ],
            StringDelete[
                "## Basic Examples\n\n" <> StringRiffle[ strings, "\n\n" ],
                Longest[ "```\n\n```"~~("wl"|"") ]
            ]
        ]
    ],
    throwInternalFailure
];

documentationBasicExamples // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellToString*)
cellToString[ args___ ] := CellToString[
    args,
    "ContentTypes"        -> If[ TrueQ @ $multimodalMessages, { "Text", "Image" }, Automatic ],
    "MaxCellStringLength" -> 100
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*renumberCells*)
renumberCells // beginDefinition;
renumberCells[ cells_List ] := Block[ { $line = 0 }, renumberCell /@ Flatten @ cells ];
renumberCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*renumberCell*)
renumberCell // beginDefinition;

renumberCell[ Cell[ a__, "Input", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Input", CellLabel -> "In[" <> ToString @ ++$line <> "]:=" ];

renumberCell[ Cell[ a__, "Output", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, "Output", CellLabel -> "Out[" <> ToString @ $line <> "]=" ];

renumberCell[ Cell[ a__, style: "Print"|"Echo", b: (Rule|RuleDelayed)[ _, _ ]... ] ] :=
    Cell[ a, style, CellLabel -> "During evaluation of In[" <> ToString @ $line <> "]:=" ];

renumberCell[ cell_Cell ] := cell;

renumberCell // endDefinition;

$line = 0;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframLanguageData*)
wolframLanguageData // beginDefinition;

wolframLanguageData[ name_, property_ ] := Enclose[
    wolframLanguageData[ name, property ] = ConfirmBy[ WolframLanguageData[ name, property ], Not@*FailureQ ],
    Missing[ "DataFailure" ] &
];

wolframLanguageData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
