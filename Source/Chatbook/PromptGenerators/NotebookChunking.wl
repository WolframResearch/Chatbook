(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`PromptGenerators`NotebookChunking`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                         ];
Needs[ "Wolfram`Chatbook`Common`"                  ];
Needs[ "Wolfram`Chatbook`PromptGenerators`Common`" ];

(* TODO: Need to generate anchor IDs during chunking in order to create URIs later *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)

(* Configure chunk size parameters (in tokens): *)
$targetTokens      = 2^10;
$targetTokensLow   = $targetTokens/2;
$targetTokensHigh  = 2*$targetTokens;
$maxTokens         = 2*$targetTokensHigh;

(* The tokenizer to use for chunking: *)
$chunkingTokenizer = "gpt-4o";

(* The content types to include in the chunks: *)
$chunkContentTypes = { "Text", "Image" };

(* The maximum length of a cell's content to include in a chunk: *)
$maxChunkCellStringLength = 4096;

(* The maximum length of an output cell's content to include in a chunk: *)
$maxChunkOutputCellStringLength = 500;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Patterns*)

$$regroupCheckStyle = "CodeText" | "Text";
$$inputStyle        = "Input" | "Code";

$$groupDividerStyle = Alternatives[
    "AllowableOptions",
    "AllowableOptionsSection",
    "AlternativeNamesSection",
    "ApplicationNotesSection",
    "Attributes",
    "AttributesSection",
    "BatchComputationProviderSection",
    "CategorizationSection",
    "CFunctionName",
    "Chapter",
    "CharacterImage",
    "ChatBlockDivider",
    "ClassifierSection",
    "CompiledTypeSection",
    "CompiledTypeSubsection",
    "ContextNameCell",
    "CorrespondenceTableSection",
    "DatabaseConnectionSection",
    "DataSourceTitle",
    "DesignDiscussionSection",
    "DesignJustificationSection",
    "DeviceSubsection",
    "DocumentStatusSection",
    "ElementsSection",
    "EmbeddingFormatSection",
    "EntitySection",
    "ErrorMessages",
    "ErrorMessagesSection",
    "ExampleSection",
    "ExampleSubsection",
    "ExampleSubsubsection",
    "ExampleSubsubsubsection",
    "ExportElementsSection",
    "ExtendedExamplesSection",
    "ExtensionsSection",
    "ExternalEvaluateSystemSection",
    "FeaturedExampleTitle",
    "FormatBackground",
    "FunctionEssaySection",
    "GuideFeaturedExamplesSection",
    "GuideFunctionsSection",
    "GuideFunctionsSectionIcon",
    "GuideFunctionsSubsection",
    "GuideFunctionsSubsubsection",
    "GuideHowToSection",
    "GuideIcon",
    "GuideLearningResourcesSection",
    "GuideReferenceSection",
    "GuideTitle",
    "GuideTitleGrid",
    "GuideTOCLink",
    "GuideTOCTitle",
    "GuideTOCTitleGrid",
    "GuideTutorialCollectionSection",
    "GuideWorkflowGuidesSection",
    "History",
    "HistorySection",
    "HowToScreencastLink",
    "HowToTitle",
    "HowToTitleGrid",
    "ImportExportSection",
    "IndicatorAbbreviationSection",
    "IndicatorCategorizationSection",
    "IndicatorDescriptionSection",
    "IndicatorExampleSection",
    "IndicatorFormulaSection",
    "IndicatorUsage",
    "InterpreterSection",
    "LegacyMaterialSection",
    "MethodSection",
    "MonographSection",
    "MonographSubsection",
    "MonographSubsubsection",
    "MonographSubsubsubsection",
    "MonographSubsubsubsubsection",
    "MonographTitle",
    "MonographTOCChapter",
    "MonographTOCChapterNumber",
    "MonographTOCDocumentTitle",
    "MonographTOCSection",
    "MonographTOCSubsection",
    "MoreInformationSection",
    "MoreToExploreSection",
    "NotebookInterfaceSection",
    "NotesSection",
    "NotesSubsection",
    "NotesThumbnails",
    "ObjectName",
    "ObjectNameAlt",
    "ObjectNameGrid",
    "ObjectNameSmall",
    "OptionsSection",
    "PacletNotesSection",
    "PredictorSection",
    "PrimaryExamplesSection",
    "ProgramName",
    "ProgramSection",
    "ProgramSubsection",
    "QuestionInterfaceSection",
    "ResourceObjectSection",
    "SearchPageHeading",
    "SearchPageHeadingGrid",
    "SearchResultPageLinksGrid",
    "Section",
    "SectionFooterSpacer",
    "ServiceSubsection",
    "SessionLabel",
    "Subsection",
    "SubsectionOpener",
    "Subsubsection",
    "SubsubsectionOpener",
    "Subsubsubsection",
    "SubsubsubsectionOpener",
    "Subsubsubsubsection",
    "TechNoteSection",
    "TechNoteSubsection",
    "TechNoteSubsubsection",
    "TechNoteSubsubsubsection",
    "TechNoteTitle",
    "Template",
    "TemplatesSection",
    "Title",
    "TOCChapter",
    "TOCDocumentTitle",
    "TOCPart",
    "TOCSection",
    "TOCSubsection",
    "TOCSubsubsection",
    "TOCSubsubsubsection",
    "TutorialCollectionSection",
    "UnnumberedWorkflowStep",
    "UpgradeDetailLabel",
    "UpgradeLabel",
    "UpgradePackageSection",
    "UsageDetailsSection",
    "UsageMessages",
    "UsageMessagesSection",
    "WorkflowGuideDivider",
    "WorkflowGuideGroupHeader",
    "WorkflowGuideSection",
    "WorkflowGuideSubdivider",
    "WorkflowGuideTitle",
    "WorkflowGuideTitleHeader",
    "WorkflowGuideVideo",
    "WorkflowHeader",
    "WorkflowNotesHeader",
    "WorkflowNotesSection",
    "WorkflowPlatform",
    "WorkflowTitle"
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Chunking*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*chunkNotebook*)
chunkNotebook // beginDefinition;

chunkNotebook[ file_? FileExistsQ ] := Enclose[
    Module[ { nb, name, titled },
        nb     = ConfirmMatch[ importNotebook @ file, _Notebook, "Notebook" ];
        name   = ConfirmMatch[ guessNotebookTitle[ nb, file ], _String|None, "Name" ];
        titled = ConfirmMatch[ prependTitleCell[ nb, name ], Notebook[ { __Cell }, OptionsPattern[ ] ], "Title" ];
        chunkNotebook @ titled
    ],
    throwInternalFailure
];

chunkNotebook[ nb_Notebook ] := Enclose[
    Module[ { trailed, merged, flatNodes },
        trailed   = ConfirmBy[ insertTrailInfo @ nb, AssociationQ, "Trailed" ];
        merged    = ConfirmBy[ mergeSmallNodes @ trailed, AssociationQ, "Merged" ];
        flatNodes = Cases[ merged, KeyValuePattern[ "String" -> _String ], Infinity ];
        flatNodes
    ],
    throwInternalFailure
];

chunkNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertTrailInfo*)
insertTrailInfo // beginDefinition;


(* Top level: *)
insertTrailInfo[ Notebook[ cells_List, ___ ] ] :=
    insertTrailInfo[ 0, 1, { }, Cell @ CellGroupData[ cells, Open ] ];


(* Cell group with a header cell: *)
insertTrailInfo[
    level_Integer,
    group_Integer,
    { trail___ },
    source: Cell @ CellGroupData[ { header_Cell? breadCrumbHeaderCellQ, contents___Cell }, ___ ]
] :=
    Module[ { string, name, new },

        string = cellToString @ header;

        name = If[ StringQ @ string, StringTrim @ StringDelete[ StringTrim @ string, StartOfString ~~ "#".. ] ];

        new = If[ StringQ @ string,
                  MapIndexed[
                    insertTrailInfo[ level + 1, First[ #2 ], { trail, name }, #1 ] &,
                    regroup @ { contents }
                  ]
              ];

        <|
            "Level"    -> level,
            "Group"    -> group,
            "Trail"    -> { trail, name },
            "Name"     -> name,
            "LeafNode" -> False,
            "Children" -> Prepend[ new, insertTrailInfo[ level + 1, 0, { trail, name }, header ] ]
        |> /; StringQ @ name && StringFreeQ[ name, "\n" ] && StringLength @ name < 200
    ];


(* Cell group without a header cell: *)
insertTrailInfo[ level_Integer, group_Integer, trail: { ___String }, cell: Cell @ CellGroupData[ cells_List, ___ ] ] :=
    Module[ { new },
        new = MapIndexed[ insertTrailInfo[ level + 1, First[ #2 ], trail, #1 ] &, regroup @ cells ];
        <|
            "Level"    -> level,
            "Group"    -> group,
            "Trail"    -> trail,
            "Name"     -> None,
            "LeafNode" -> False,
            "Children" -> new
        |>
    ];


(* Leaf node: *)
insertTrailInfo[ level_Integer, group_Integer, trail: { ___String }, cell: Cell[ Except[ _CellGroupData ], ___ ] ] :=
    Catch @ Enclose[
        Module[ { string, tokens, styles, divided },
            string = ConfirmBy[ cellToString @ cell, StringQ, "String" ];
            tokens = ConfirmBy[ tokenCount @ string, IntegerQ, "TokenCount" ];
            styles = ConfirmMatch[ cellStyles @ cell, { ___String }, "Styles" ];

            If[ tokens > $maxTokens && divideQ @ cell,
                divided = divideCell @ cell;
                If[ MatchQ[ divided, { _Cell, __Cell } ],
                    Throw @ insertTrailInfo[ level, group, trail, Cell @ CellGroupData[ divided, Open ] ]
                ]
            ];

            <|
                "Level"      -> level,
                "Group"      -> group,
                "Trail"      -> trail,
                "Name"       -> None,
                "LeafNode"   -> True,
                "TokenCount" -> tokens,
                "String"     -> string,
                "Cells"      -> { cell },
                "Styles"     -> styles
            |>
        ],
        throwInternalFailure
    ];


insertTrailInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*breadCrumbHeaderCellQ*)
breadCrumbHeaderCellQ // beginDefinition;
breadCrumbHeaderCellQ[ Cell[ __, s_? (MatchQ @ $$groupDividerStyle), ___ ] ] := True;
breadCrumbHeaderCellQ[ _Cell ] := False;
breadCrumbHeaderCellQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tokenCount*)
tokenCount // beginDefinition;
tokenCount[ str_String ] := Length @ cachedTokenizer[ $chunkingTokenizer ][ str ];
tokenCount[ data_List ] := With[ { tokens = tokenCount /@ data }, Total @ tokens /; AllTrue[ tokens, IntegerQ ] ];
tokenCount[ KeyValuePattern[ "TotalTokenCount" -> count_Integer ] ] := count;
tokenCount[ KeyValuePattern[ "TokenCount" -> count_Integer ] ] := count;
tokenCount // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*mergeSmallNodes*)
mergeSmallNodes // beginDefinition;

mergeSmallNodes[ KeyValuePattern[ "Children" -> { node_Association } ] ] :=
    mergeSmallNodes @ node;

mergeSmallNodes[ node: KeyValuePattern[ "LeafNode" -> True ] ] :=
    node;

mergeSmallNodes[ node: KeyValuePattern[ "Children" -> nodes_List ] ] :=
    <| node, "Children" -> mergeSmallNodes @ nodes |>;

mergeSmallNodes[ items_List ] :=
    With[ { merged = Flatten[ mergeSplitNodes /@ SplitBy[ items, Lookup[ "LeafNode" ] ] ] },
        If[ merged === items, merged, mergeSmallNodes @ merged ]
    ];

mergeSmallNodes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeSplitNodes*)
mergeSplitNodes // beginDefinition;

mergeSplitNodes[ { } ] := { };
mergeSplitNodes[ { node: KeyValuePattern[ "LeafNode" -> True ] } ] := { node };
mergeSplitNodes[ nodes: { KeyValuePattern[ "LeafNode" -> False ], ___ } ] := mergeSmallNodes /@ nodes;

mergeSplitNodes[ nodes: { KeyValuePattern[ "LeafNode" -> True ], __ } ] :=
    Catch @ Module[ { tokenCounts, acc, min, len, merge, remaining },
        tokenCounts = Lookup[ nodes, "TokenCount" ];
        acc = Accumulate @ tokenCounts;
        min = If[ First @ tokenCounts < $targetTokensLow, Min[ 2, Length @ acc ], 1 ];
        (* TODO: Also ensure small nodes at the end are merged *)
        len = Max[ min, LengthWhile[ acc, LessEqualThan @ $targetTokens ] ];
        { merge, remaining } = TakeDrop[ nodes, len ];
        Flatten @ { mergeNodes @ merge, mergeSplitNodes @ remaining }
    ];

mergeSplitNodes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*mergeNodes*)
mergeNodes // beginDefinition;

mergeNodes[ { node_Association } ] := node;

mergeNodes[ nodes: { first_Association, __Association } ] :=
    Module[ { cells, string, tokens },
        cells  = Flatten @ Lookup[ nodes, "Cells" ];
        string = cellToString @ Notebook @ cells;
        tokens = tokenCount @ string;
        Association[
            first,
            "TokenCount" -> tokens,
            "String"     -> string,
            "Cells"      -> cells,
            "Styles"     -> Missing[ "MergedNodes" ]
        ]
    ];

mergeNodes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellToString*)
cellToString // beginDefinition;

cellToString[ cell_ ] :=
	cellToString[ cell, $chunkContentTypes, $maxChunkCellStringLength, $maxChunkOutputCellStringLength ];

cellToString[ cell_, contentTypes_, maxCellStringLength_, maxOutputCellStringLength_ ] :=
    Block[ { Speak, PopupWindow }, (* Workaround for bug(456374) *)
        Quiet[
            CellToString[
                cell,
                "ContentTypes"              -> contentTypes,
                "MaxCellStringLength"       -> maxCellStringLength,
                "MaxOutputCellStringLength" -> maxOutputCellStringLength
            ],
            RegularExpression::maxrec
        ]
    ];

cellToString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*divideCell*)
divideCell // beginDefinition;

divideCell[ cell: Cell[ _BoxData, ___ ] ] :=
    With[ { divided = Quiet @ NotebookTools`DivideCell[ cell, { "Input", Automatic, True } ] },
        If[ MatchQ[ divided, { __Cell } ], divided, { cell } ]
    ];

divideCell[ cell: Cell[ _TextData | _String, ___ ] ] :=
    With[ { divided = Quiet @ NotebookTools`DivideCell[ cell, { "NaturalLanguage", Automatic, True } ] },
        If[ MatchQ[ divided, { __Cell } ], divided, { cell } ]
    ];

divideCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*divideQ*)
divideQ // beginDefinition;
divideQ[ Cell[ _TextData | _String, ___ ] ] := True;
divideQ[ Cell[ _BoxData, "Input"|"Code", ___ ] ] := True;
divideQ[ ___ ] := False;
divideQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*regroup*)
regroup // beginDefinition;

regroup[ { a___, b: Cell[ __, $$regroupCheckStyle, ___ ], c_Cell, d___ } ] /;
    Length @ { a, d } > 0 && regroupQ[ cellStyles @ b, c ] :=
        Flatten @ { regroup @ { a }, Cell @ CellGroupData @ { b, c }, regroup @ { d } };

regroup[ cells_List ] :=
    cells;

regroup // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*regroupQ*)
regroupQ // beginDefinition;
regroupQ[ styles: { ___String }, Cell @ CellGroupData[ { first_Cell, ___ }, ___ ] ] := regroupQ[ styles, first ];
regroupQ[ { ___, $$regroupCheckStyle, ___ }, Cell[ __, $$inputStyle, ___ ] ] := True;
regroupQ[ { ___, "Text", ___ }, Cell[ __, "CodeText", ___ ] ] := True;
regroupQ[ ___ ] := False;
regroupQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*guessNotebookTitle*)
guessNotebookTitle // beginDefinition;

guessNotebookTitle[ Notebook[ __, TaggingRules -> tags_, ___ ], file_ ] :=
    guessNotebookTitle[ tags, file ];

guessNotebookTitle[ KeyValuePattern[ "Metadata" -> KeyValuePattern[ "title"|"Title" -> title_String ] ], file_ ] :=
    StringReplace[
        title,
        WhitespaceCharacter... ~~ ("\r\n" | "\n" | FromCharacterCode[ 8232 ]) ~~ WhitespaceCharacter... -> " "
    ];

guessNotebookTitle[ _, None ] :=
    None;

guessNotebookTitle[ _, file_ ] :=
    FileBaseName @ file;

guessNotebookTitle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*prependTitleCell*)
prependTitleCell // beginDefinition;
prependTitleCell[ nb_Notebook, None ] := nb;
prependTitleCell[ Notebook[ cells_, opts___ ], name_ ] := Notebook[ prependTitleCell[ cells, name ], opts ];
prependTitleCell[ { first_Cell? hasTitleQ, rest___Cell }, name_String ] := { first, rest };
prependTitleCell[ { cells___Cell }, name_String ] := { Cell[ name, "Title" ], cells };
prependTitleCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*hasTitleQ*)
hasTitleQ // beginDefinition;
hasTitleQ[ Cell[ CellGroupData[ { cell_, ___ }, ___ ], ___ ] ] := hasTitleQ @ cell;
hasTitleQ[ cell_Cell ] := breadCrumbHeaderCellQ @ cell;
hasTitleQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*importNotebook*)
importNotebook // beginDefinition;

importNotebook[ file_? FileExistsQ ] := FirstCase[
    Quiet @ Import[ file, { "WL", "HeldExpressions" } ],
    HoldComplete[ nb: Notebook[ { ___Cell }, OptionsPattern[ ] ] ] :> rewriteCellLabels @ nb,
    Failure[
        "ImportFailure",
        <| "MessageTemplate" -> "Failed to import notebook `1`.", "MessageParameters" -> { file } |>
    ]
];

importNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteCellLabels*)
rewriteCellLabels // beginDefinition;

rewriteCellLabels[ nbo_NotebookObject ] :=
    With[ { nb = NotebookGet @ nbo },
        SetOptions[ nbo, CellLabelAutoDelete -> False ];
        NotebookPut[ rewriteCellLabels @ nb, nbo ] /; MatchQ[ nb, _Notebook ]
    ];

rewriteCellLabels[ Notebook[ cells_, opts___ ] ] :=
    Block[ { $line = 0, $lastStyle = None },
        Notebook[ rewriteCellLabels @ cells, opts ]
    ];

rewriteCellLabels[ list_List ] := rewriteCellLabels /@ list;

rewriteCellLabels[ Cell[ CellGroupData[ group_, a___ ], b___ ] ] :=
    Cell[ CellGroupData[ rewriteCellLabels @ group, a ], b ];

rewriteCellLabels[ cell_Cell ] := rewriteCellLabel @ cell;

rewriteCellLabels[ other_ ] := other;

rewriteCellLabels // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Cell label state*)
$line      = 0;
$lastStyle = None;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteCellLabel argument patterns*)
$cellLabelOpt = (Rule | RuleDelayed)[ CellLabel, _ ];

$resetCounterStyles = Alternatives[
    "Section",
    "Subsection",
    "Subsubsection",
    "Subsubsubsection",
    "ExampleSection",
    "ExampleSubsection",
    "ExampleSubsubsection",
    "ExampleSubsubsubsection",
    "PageBreak",
    "ExampleDelimiter"
];

$inputStyles      = "Input" | "Code" | "InputOnly" | "ExampleInput";
$outputStyles     = "Output";
$sideEffectStyles = "Print" | "PrintTemporary" | "Message" | "MSG";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rewriteCellLabel*)
rewriteCellLabel // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
rewriteCellLabel[
    cell: Cell[
        BoxData @ InterpretationBox[
            _,
            ($Line = n_Integer) | (___; $Line = n_Integer; ___),
            ___
        ],
        ___
    ]
] := (
    $line = n;
    setLastStyle @ cell
);
(* :!CodeAnalysis::EndBlock:: *)

rewriteCellLabel[ cell: Cell[ ___, style: $resetCounterStyles, ___ ] ] := (
    $line = 0;
    setLastStyle @ cell
);

rewriteCellLabel[
    Cell[ a___, style: $inputStyles, b___, CellLabel -> _? inputLabelQ, c___ ]
] :=
    Cell[
        a,
        $lastStyle = style,
        b,
        CellLabel -> TemplateApply[ "In[``]:=", ++$line ],
        c
    ];

rewriteCellLabel[
    Cell[
        a___,
        style: $outputStyles,
        b___,
        CellLabel -> _? outputLabelQ,
        c___
    ]
] :=
    Module[ { label },
        label = If[ MatchQ[ $lastStyle, $outputStyles ], ++$line, $line ];
        Cell[
            a,
            $lastStyle = style,
            b,
            CellLabel -> TemplateApply[ "Out[``]=", label ],
            c
        ]
    ];

rewriteCellLabel[
    Cell[
        a___,
        style: $sideEffectStyles,
        b___,
        CellLabel -> _? sideEffectLabelQ,
        c___
    ]
] :=
    Cell[
        a,
        style,
        b,
        CellLabel -> TemplateApply[ "During evaluation of In[``]:=", $line ],
        c
    ];

rewriteCellLabel[
    Cell[ a___, style: $inputStyles, b___String, c: Except[ $cellLabelOpt, _Rule|_RuleDelayed ]... ]
] :=
    rewriteCellLabel @ Cell[ a, style, b, CellLabel -> "In[0]:=", c ];

rewriteCellLabel[
    Cell[ a___, style: $outputStyles, b___String, c: Except[ $cellLabelOpt, _Rule|_RuleDelayed ]... ]
] :=
    rewriteCellLabel @ Cell[ a, style, b, CellLabel -> "Out[0]=", c ];

rewriteCellLabel[
    Cell[ a___, style: $sideEffectStyles, b___String, c: Except[ $cellLabelOpt, _Rule|_RuleDelayed ]... ]
] :=
    rewriteCellLabel @ Cell[
        a,
        style,
        b,
        CellLabel -> "During evaluation of In[0]:=",
        c
    ];

rewriteCellLabel[ other_ ] := setLastStyle @ other;

rewriteCellLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*setLastStyle*)
setLastStyle // beginDefinition;
setLastStyle[ cell: Cell[ _, s_String, ___ ] ] := ($lastStyle = s; cell);
setLastStyle[ other_ ] := ($lastStyle = None; other);
setLastStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inputLabelQ*)
inputLabelQ // beginDefinition;

inputLabelQ[ label_String? StringQ ] :=
    StringMatchQ[
        label,
        StringExpression[
            WhitespaceCharacter...,
            "In[",
            __,
            "]",
            ":=" | "=",
            WhitespaceCharacter...
        ]
    ];

inputLabelQ[ ___ ] := False;

inputLabelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*outputLabelQ*)
outputLabelQ // beginDefinition;

outputLabelQ[ label_String? StringQ ] :=
    StringMatchQ[
        label,
        StringExpression[
            WhitespaceCharacter...,
            "Out[",
            __,
            "]",
            ":=" | "=",
            WhitespaceCharacter...
        ]
    ];

outputLabelQ[ ___ ] := False;

outputLabelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sideEffectLabelQ*)
sideEffectLabelQ // beginDefinition;

sideEffectLabelQ[ label_String? StringQ ] :=
    StringMatchQ[
        label,
        StringExpression[
            WhitespaceCharacter...,
            "During evaluation of In[",
            __,
            "]",
            ":=" | "=",
            WhitespaceCharacter...
        ]
    ];

sideEffectLabelQ[ ___ ] := False;

sideEffectLabelQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
