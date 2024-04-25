BeginPackage[ "Wolfram`Chatbook`Serialization`" ];

(* cSpell: ignore TOOLCALL, specialkeywords, tabletags, NFKC *)

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[ `CellToString, "\
CellToString[cell$] serializes a Cell expression as a string for use in chat.\
" ];

`$CellToStringDebug;
`$CurrentCell;
`$chatInputIndicator;
`$defaultMaxCellStringLength;
`$defaultMaxOutputCellStringLength;
`$longNameCharacters;
`documentationSearchAPI;
`escapeMarkdownString;
`truncateString;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"              ];
Needs[ "Wolfram`Chatbook`ChatMessages`" ];
Needs[ "Wolfram`Chatbook`Common`"       ];
Needs[ "Wolfram`Chatbook`ErrorUtils`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`"     ];
Needs[ "Wolfram`Chatbook`Models`"       ];
Needs[ "Wolfram`Chatbook`Prompting`"    ];
Needs[ "Wolfram`Chatbook`Tools`"        ];
Needs[ "Wolfram`Chatbook`Utils`"        ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config*)
$$delimiterStyle   = "PageBreak"|"ExampleDelimiter"|"GuideDelimiterSubsection"|"WorkflowDelimiter";
$$itemStyle        = "Item"|"Notes"|"FeaturedExampleMoreAbout";
$$subItemStyle     = "Subitem";
$$subSubItemStyle  = "Subsubitem";
$$docSearchStyle   = "ChatQuery";
$$outputStyle      = "Output"|"Print"|"Echo";
$$noCellLabelStyle = Alternatives[
    "ChatBlockDivider",
    "ChatInput",
    "ChatSystemInput",
    "Section",
    "SideChat",
    "Subsection",
    "Subsubsection",
    "Subsubsubsection",
    "Subsubsubsubsection",
    "Text",
    "Title",
    $$delimiterStyle
];

$$ignoredCellStyle = Alternatives[
    "AnchorBarGrid",
    "CitationContainerCell",
    "DiscardedMaterial"
];

(* Cell styles that will prevent wrapping BoxData in triple backticks: *)
$$noCodeBlockStyle = Alternatives[
    "FunctionEssay",
    "GuideFunctionsSubsection",
    "NotebookImage",
    "Picture",
    "TableNotes",
    "TOCChapter",
    "UsageDescription",
    "UsageInputs"
];

$maxInputFormByteCount       = 2^18;
$maxStandardFormStringLength = 2^15;

(* Default character encoding for strings created from cells *)
$cellCharacterEncoding = "Unicode";

(* Set a max string length for output cells to avoid blowing up token counts *)
$maxOutputCellStringLength        = Automatic;
$defaultMaxOutputCellStringLength = 500;

(* Set an overall max string length for any type of cell *)
$maxCellStringLength        = Automatic;
$defaultMaxCellStringLength = 10000;

(* Set a page width for expressions that need to be serialized as InputForm *)
$cellPageWidth        = 100;
$defaultCellPageWidth = $cellPageWidth;

(* Window width to use when converting cells to multimodal images (Automatic means derive from $cellPageWidth):  *)
$windowWidth        = Automatic;
$defaultWindowWidth = 625;

(* Maximum number of images to include in multimodal messages per cell before switching to a fully rasterized cell: *)
$maxMarkdownBoxes = 5;

(* Whether to generate a transcript and preview images for Video[...] expressions: *)
$generateVideoPrompt = False;

(* Whether to collect data that can help discover missing definitions *)
$CellToStringDebug = False;

(* Can be redefined locally depending on cell style *)
$showStringCharacters = True;
$inlineCode           = False;

(* Add spacing around these operators *)
$$spacedInfixOperator = Alternatives[
    "^", "*", "+", "=", "|", "<", ">", "?", "/", ":", "!=", "@*", "^=", "&&", "*=", "-=", "->", "+=", "==", "~~",
    "||", "<=", "<>", ">=", ";;", "/@", "/*", "/=", "/.", "/;", ":=", ":>", "::", "^:=", "=!=", "===", "|->", "<->",
    "//@", "//.", "\[Equal]", "\[GreaterEqual]", "\[LessEqual]", "\[NotEqual]", "\[Function]", "\[Rule]",
    "\[RuleDelayed]", "\[TwoWayRule]"
];

$delimiterString = "\n\n---\n\n";

(* Characters that should be serialized as long-form representations: *)
$longNameCharacterList = {
    "\[AltKey]",
    "\[CommandKey]",
    "\[ControlKey]",
    "\[DeleteKey]",
    "\[EnterKey]",
    "\[EscapeKey]",
    "\[OptionKey]",
    "\[ReturnKey]",
    "\[SpaceKey]",
    "\[SystemEnterKey]",
    "\[TabKey]"
};

$longNameCharacters = Normal @ AssociationMap[ "\\[" <> CharacterName[ # ] <> "]" &, $longNameCharacterList ];
$$longNameCharacter = Alternatives @@ $longNameCharacterList;

$$invisibleCharacter = Alternatives[
    FromCharacterCode[ 8203 ], (* U+200B Zero Width Space *)
    FromCharacterCode[ 62304 ] (* InvisibleSpace *)
];

(* Characters that should be automatically escaped when they appear in plain text to be valid markdown: *)
$escapedMarkdownCharacters = { "`", "$", "*", "_", "#", "|" };

(* Not included for implementation reasons:
    [] () {} + - . !
*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Conversion Rules*)

(* Rules to convert some 2D boxes into an infix form *)
$boxOp = <| SuperscriptBox -> "^", SubscriptBox -> "_" |>;

(* How to choose TemplateBox arguments for serialization *)
$templateBoxRules = <|
    "ChatCodeBlockTemplate"     -> First,
    "GrayLink"                  -> First,
    "HyperlinkDefault"          -> First,
    "Key0"                      -> First,
    "Key1"                      -> (Riffle[ #, "-" ] &),
    "RowDefault"                -> Identity,
    "ConditionalExpression"     -> makeExpressionString,
    "TransferFunctionModelFull" -> makeExpressionString
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Patterns*)

$boxOperators = Alternatives @@ Keys @ $boxOp;

$graphicsHeads = Alternatives[
    GraphicsBox,
    RasterBox,
    NamespaceBox,
    Graphics3DBox
];

$$graphicsBox = Alternatives[
    $graphicsHeads[ ___ ],
    TemplateBox[ _, "Legended", ___ ],
    DynamicBox[ _FEPrivate`ImportImage, ___ ]
];

(* Serialize the first argument of these and ignore the rest *)
$stringStripHeads = Alternatives[
    ActionMenuBox,
    ButtonBox,
    CellGroupData,
    FrameBox,
    ItemBox,
    PaneBox,
    PanelBox,
    RowBox,
    StyleBox,
    TagBox,
    TextData,
    TooltipBox
];

(* Boxes that should be ignored during serialization *)
$ignoredBoxPatterns = Alternatives[
    _PaneSelectorBox,
    StyleBox[ _GraphicsBox, ___, "NewInGraphic", ___ ]
];

(* CellEvaluationLanguage appears to not be System` at startup, so use this for matching as a precaution *)
$$cellEvaluationLanguage = Alternatives[
    "CellEvaluationLanguage",
    _Symbol? (Function[
        Null,
        AtomQ @ Unevaluated @ # && SymbolName @ Unevaluated @ # === "CellEvaluationLanguage",
        HoldFirst
    ])
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Templates*)

(* Helper function to define string templates that handle WL (with backticks) *)
codeTemplate[ template_String? StringQ ] := StringTemplate[ template, Delimiters -> "%%" ];
codeTemplate[ template_ ] := template;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Stack Trace for Message Cells*)
$stackTraceTemplate = codeTemplate[ "\
%%String%%
BEGIN_STACK_TRACE
%%StackTrace%%
END_STACK_TRACE\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Explanation with Search Results*)
$searchQueryTemplate = codeTemplate[ "\
Please explain the following query text to me:
---
%%String%%
---
Try to include information about how this relates to the Wolfram Language if it makes sense to do so.

If there are any relevant search results, feel free to use them in your explanation. Do not include search results \
that are not relevant to the query.

%%SearchResults%%\
" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Wolfram Alpha Input*)
$wolframAlphaInputTemplate = codeTemplate[ "\
\[FreeformPrompt] %%Query%%
(%%Code%%)

" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellToString*)
CellToString // SetFallthroughError;

CellToString // Options = {
    "CharacterEncoding"         -> $cellCharacterEncoding,
    "CharacterNormalization"    -> "NFKC", (* FIXME: do this *)
    "ContentTypes"              -> Automatic,
    "Debug"                     :> $CellToStringDebug,
    "MaxCellStringLength"       -> $maxCellStringLength,
    "MaxOutputCellStringLength" -> $maxOutputCellStringLength,
    "PageWidth"                 -> $cellPageWidth,
    "UnhandledBoxFunction"      -> None,
    "WindowWidth"               -> $windowWidth
};

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
CellToString[ cell_, opts: OptionsPattern[ ] ] :=
    Catch @ Block[
        {
            $cellCharacterEncoding = OptionValue[ "CharacterEncoding" ],
            $CellToStringDebug = TrueQ @ OptionValue[ "Debug" ],
            $unhandledBoxFunction = OptionValue[ "UnhandledBoxFunction" ],
            $cellPageWidth, $windowWidth, $maxCellStringLength, $maxOutputCellStringLength,
            $contentTypes, $multimodalImages
        },
        $cellPageWidth = toSize[ OptionValue @ PageWidth, $defaultCellPageWidth ];
        $windowWidth = toWindowWidth[ OptionValue @ WindowWidth, $cellPageWidth ];

        $maxCellStringLength = Ceiling @ toSize[
            OptionValue[ "MaxCellStringLength" ],
            $defaultMaxCellStringLength
        ];

        If[ $maxCellStringLength <= 0, Throw[ "[Cell Excised]" ] ];

        $maxOutputCellStringLength = Ceiling @ toSize[
            OptionValue[ "MaxOutputCellStringLength" ],
            $defaultMaxOutputCellStringLength
        ];

        $contentTypes = toContentTypes @ OptionValue[ "ContentTypes" ];
        $multimodalImages = MemberQ[ $contentTypes, "Image" ];

        If[ $CellToStringDebug, $fasterCellToStringFailBag = Internal`Bag[ ] ];
        If[ ! StringQ @ $cellCharacterEncoding, $cellCharacterEncoding = "UTF-8" ];
        WithCleanup[
            StringTrim @ Replace[
                cellToString @ cell,
                (* TODO: give a failure here *)
                Except[ _String? StringQ ] :> ""
            ],
            If[ TrueQ @ $CellToStringDebug && Internal`BagLength @ $fasterCellToStringFailBag > 0,
                Print[ "Unhandled boxes for CellToString: " ];
                Print[ Internal`BagPart[ $fasterCellToStringFailBag, All ] ];
            ]
        ]
    ];
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toContentTypes*)
toContentTypes // beginDefinition;
(* TODO: determine content types from resolved settings if Automatic *)
toContentTypes[ Automatic ] := { "Text" };
toContentTypes[ type_String ] := toContentTypes @ { type };
toContentTypes[ { a___, Automatic, b___ } ] := toContentTypes @ Flatten @ { a, toContentTypes @ Automatic, b };
toContentTypes[ { types___String } ] := Union @ Replace[ { "Text", types }, "Images" -> "Image", { 1 } ];
toContentTypes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toSize*)
toSize // beginDefinition;
toSize[ size: $$size, default_ ] := size;
toSize[ size_, default: $$size ] := default;
toSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*toWindowWidth*)
toWindowWidth[ width: $$size, pageWidth_ ] := width;
toWindowWidth[ width_, pageWidth: $$size ] := 6.25 * pageWidth;
toWindowWidth[ ___ ] := $defaultWindowWidth;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*cellToString*)
cellToString // beginDefinition;

(* Argument normalization *)
cellToString[ data: _TextData|_BoxData|_RawData ] := cellToString @ Cell @ data;
cellToString[ string_String? StringQ ] := cellToString @ Cell @ string;
cellToString[ cell_CellObject ] := cellToString @ NotebookRead @ cell;

(* Multiple cells to one string *)
cellToString[ Notebook[ cells_List, ___ ] ] := cellsToString @ cells;
cellToString[ Cell @ CellGroupData[ cells_List, _ ] ] := cellsToString @ cells;
cellToString[ nbo_NotebookObject ] := cellToString @ Cells @ nbo;
cellToString[ cells: { __CellObject } ] := cellsToString @ NotebookRead @ cells;

(* Drop cell label for some styles *)
cellToString[ Cell[ a__, style: $$noCellLabelStyle, b___, CellLabel -> _, c___ ] ] :=
    cellToString @ Cell[ a, style, b, c ];

(* Include chat input indicator for mixed content *)
cellToString[ cell: Cell[ __, $$chatInputStyle, ___ ] ] /; $chatInputIndicator && StringQ @ $chatIndicatorSymbol :=
    Block[ { $chatInputIndicator = False },
        needsBasePrompt[ "ChatInputIndicator" ];
        $chatIndicatorSymbol <> " " <> cellToString @ cell
    ];

(* Convert delimiters to equivalent markdown *)
cellToString[ Cell[ __, $$delimiterStyle, ___ ] ] := $delimiterString;
cellToString[ Cell[ __, "ExcludedChatDelimiter", ___ ] ] := "";

(* Ignore cells with certain styles *)
cellToString[ Cell[ __, $$ignoredCellStyle, ___ ] ] := "";

(* Styles that should include documentation search *)
cellToString[ Cell[ a__, $$docSearchStyle, b___ ] ] :=
    TemplateApply[
        $searchQueryTemplate,
        <|
            "String" -> cellToString @ DeleteCases[ Cell[ a, b ], CellLabel -> _ ],
            "SearchResults" -> docSearchResultString @ a
        |>
    ];

(* Delimit code blocks with triple backticks *)
cellToString[ cell: Cell[ _BoxData, ___ ] ] /; ! TrueQ @ $delimitedCodeBlock && codeBlockQ @ cell :=
    Block[ { $delimitedCodeBlock = True },
        With[ { s = cellToString @ cell },
            If[ StringQ @ s,
                needsBasePrompt[ "WolframLanguage" ];
                "```wl\n"<>s<>"\n```",
                ""
            ]
        ]
    ];

cellToString[ cell: Cell[ __, "Program", ___ ] ] /; ! TrueQ @ $delimitedCodeBlock :=
    Block[ { $delimitedCodeBlock = True },
        With[ { s = cellToString @ cell },
            If[ StringQ @ s,
                "```\n"<>s<>"\n```",
                ""
            ]
        ]
    ];

(* Prepend cell label to the cell string *)
cellToString[ Cell[ a__, CellLabel -> label_String, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, b ] },
        (
            needsBasePrompt[ "CellLabels" ];
            If[ StringContainsQ[ str, "\n" ],
                label<>"\n"<>str,
                label<>" "<>str
            ]
        ) /; StringQ @ str
    ];

(* Item styles *)
cellToString[ Cell[ a__, $$itemStyle, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, "Text", b ] },
        "* "<>str /; StringQ @ str
    ];

cellToString[ Cell[ a__, $$subItemStyle, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, "Text", b ] },
        "\t* "<>str /; StringQ @ str
    ];

cellToString[ Cell[ a__, $$subSubItemStyle, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, "Text", b ] },
        "\t\t* "<>str /; StringQ @ str
    ];

(* Cells showing raw data (ctrl-shift-e) *)
cellToString[ Cell[ RawData[ str_String ], ___ ] ] := (needsBasePrompt[ "Notebooks" ]; str);

(* Include a stack trace for message cells when available *)
cellToString[ Cell[ a__, "Message", "MSG", b___ ] ] :=
    Module[ { string, stacks, stack, stackString },
        { string, stacks } = Reap[ cellToString0 @ Cell[ a, b ], $messageStack ];
        stack = First[ First[ stacks, $Failed ], $Failed ];
        If[ MatchQ[ stack, { __HoldForm } ] && Length @ stack >= 3
            ,
            stackString = StringRiffle[
                Cases[
                    stack,
                    HoldForm[ expr_ ] :> truncateStackString @ inputFormString[
                        Unevaluated @ expr,
                        PageWidth -> Infinity
                    ]
                ],
                "\n"
            ];
            needsBasePrompt[ "WolframLanguage" ];
            TemplateApply[
                $stackTraceTemplate,
                <| "String" -> string, "StackTrace" -> stackString |>
            ]
            ,
            string
        ]
    ];

(* External language cells get converted to a code block with the corresponding language specifier  *)
cellToString[ Cell[ code_, "ExternalLanguage", ___, $$cellEvaluationLanguage -> lang_String, ___ ] ] :=
    With[ { string = cellToString0 @ code },
        (
            needsBasePrompt[ "ExternalLanguageCells" ];
            "```"<>lang<>"\n"<>string<>"\n```"
        ) /; StringQ @ string
    ];

(* Output styles that should be truncated *)
cellToString[ cell: Cell[ __, $$outputStyle, ___ ] ] /; ! TrueQ @ $truncatingOutput :=
    Block[ { $truncatingOutput = True }, truncateString @ cellToString @ cell ];

(* Don't escape markdown characters for ChatOutput cells, since a plain string means formatting was toggled off *)
cellToString[ cell: Cell[ _String, "ChatOutput", ___ ] ] := Block[ { $escapeMarkdown = False }, cellToString0 @ cell ];

(* Otherwise escape markdown characters normally as needed *)
cellToString[ cell: Cell[ _TextData|_String, ___ ] ] := Block[ { $escapeMarkdown = True }, cellToString0 @ cell ];
cellToString[ cell_ ] := Block[ { $escapeMarkdown = False }, cellToString0 @ cell ];

(* Rasterize entire cell if it contains enough graphics boxes *)
cellToString[ cell: Cell[ _BoxData, Except[ $$chatInputStyle|$$chatOutputStyle ], ___ ] ] /;
    $multimodalImages && Count[ cell, $$graphicsBox, Infinity ] > $maxMarkdownBoxes :=
        toMarkdownImageBox @ cell;

cellToString // endDefinition;

(* Recursive serialization of the cell content *)
cellToString0[ cell0_ ] :=
    With[
        { cell = fixCloudCell @ cell0 },
        { string = truncateString[ fasterCellToString @ cell, $maxCellStringLength ] },
        If[ StringQ @ string,
            string,
            slowCellToString @ cell
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellsToString*)
cellsToString // SetFallthroughError;

cellsToString[ { a___, b: Cell[ _, "UsageInputs", ___ ], c: Cell[ _, "UsageDescription", ___ ], d___ } ] :=
    StringRiffle[
        DeleteCases[
            {
                cellsToString @ { a },
                cellToString @ b <> "\n" <> cellToString @ c,
                cellsToString @ { d }
            },
            ""
        ],
        "\n\n"
    ];

cellsToString[ cells_List ] :=
    With[ { strings = cellToString /@ cells },
        StringReplace[
            StringRiffle[ Select[ strings, StringQ ], "\n\n" ],
            {
                "```wl"~~WhitespaceCharacter...~~"```" -> "",
                "```\n\n```wl" -> "",
                "```\n\n```" -> "",
                "\n\n\n\n" -> "\n\n"
            }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fasterCellToString*)
fasterCellToString[ arg_ ] :=
    Block[ { $catchingStringFail = True },
        Catch[
            With[ { string = fasterCellToString0 @ arg },
                If[ StringQ @ string,
                    (* FIXME: does this actually need StringTrim here? *)
                    StringReplace[
                        StringDelete[ StringTrim @ string, "$$NO_TRIM$$" ],
                        $globalStringReplacements
                    ],
                    $Failed
                ]
            ],
            $stringFail
        ]
    ];


$globalStringReplacements = {
    (* "\[ExponentialE]"     -> "\:2147",
    "\[ImaginaryI]"       -> "\:2148", *)
    "\[Equal]"                     -> "==",
    "\[ExponentialE]"              -> "E",
    "\[ImaginaryI]"                -> "I",
    "\[InvisiblePrefixScriptBase]" -> " ",
    "\[LeftAssociation]"           -> "<|",
    "\[LeftSkeleton]"              -> "\:00AB",
    "\[LineSeparator]"             -> "\n",
    "\[LongEqual]"                 -> "=",
    "\[NonBreakingSpace]"          -> " ",
    "\[RightAssociation]"          -> "|>",
    "\[RightSkeleton]"             -> "\:00BB",
    "\[Rule]"                      -> "->",
    "\n\n\t\n"                     -> "\n",
    "``$$" ~~ math__ ~~ "$$``"     :> "$$"<>math<>"$$",
    link: ("``[" ~~ Except[ "]" ].. ~~ "](" ~~ Except[ ")" ].. ~~ ")``") :> StringTrim[ link, "``" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Headings*)
$$titleStyle = Alternatives[
    "CFunctionName",
    "FeaturedExampleTitle",
    "GuideTitle",
    "ObjectName",
    "ObjectNameAlt",
    "Title",
    "TOCDocumentTitle"
];

$$sectionStyle = Alternatives[
    "BatchComputationProviderSection",
    "CategorizationSection",
    "ChatBlockDivider",
    "ClassifierSection",
    "CompiledTypeSection",
    "ContextNameCell",
    "CorrespondenceTableSection",
    "DatabaseConnectionSection",
    "ElementsSection",
    "EmbeddingFormatSection",
    "EntitySection",
    "FeaturedExampleMoreAboutSection",
    "FormatBackground",
    "FunctionEssaySection",
    "ImportExportSection",
    "IndicatorAbbreviationSection",
    "IndicatorCategorizationSection",
    "IndicatorDescriptionSection",
    "IndicatorExampleSection",
    "IndicatorFormulaSection",
    "InterpreterSection",
    "MethodSection",
    "NotesSection",
    "OptionsSection",
    "PredictorSection",
    "PrimaryExamplesSection",
    "ProgramSection",
    "Section",
    "WorkflowHeader",
    "WorkflowNotesSection"
];

$$subsectionStyle = "Subsection"|"ExampleSection"|"GuideFunctionsSubsection"|"NotesSubsection"|"FooterHeader";
$$subsubsectionStyle = "Subsubsection"|"ExampleSubsection";
$$subsubsubsectionStyle = "Subsubsubsection"|"ExampleSubsubsection";
$$subsubsubsubsectionStyle = "Subsubsubsubsection"|"ExampleSubsubsubsection";

fasterCellToString0[ (Cell|StyleBox)[ a_, $$titleStyle, ___ ] ] := "# "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, $$sectionStyle, ___ ] ] := "## "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, $$subsectionStyle, ___ ] ] := "### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, $$subsubsectionStyle, ___ ] ] := "#### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, $$subsubsubsectionStyle, ___ ] ] := "##### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, $$subsubsubsubsectionStyle, ___ ] ] := "###### "<>fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Styles*)
fasterCellToString0[ (h: Cell|StyleBox)[ a__, FontWeight -> Bold|"Bold", b___ ] ] :=
    "**" <> fasterCellToString0 @ h[ a, b ] <> "**";

fasterCellToString0[ (h: Cell|StyleBox)[ a__, FontSlant -> Italic|"Italic", b___ ] ] :=
    "*" <> fasterCellToString0 @ h[ a, b ] <> "*";

fasterCellToString0[ (h: Cell|StyleBox)[ a__, ShowStringCharacters -> b: True|False, c___ ] ] :=
    Block[ { $showStringCharacters = b }, fasterCellToString0 @ h[ a, c ] ];

fasterCellToString0[ (box_)[ a__, BaseStyle -> { b___, ShowStringCharacters -> c: True|False, d___ }, e___ ] ] :=
    Block[ { $showStringCharacters = c }, fasterCellToString0 @ box[ a, BaseStyle -> { b, d }, e ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*String Normalization*)

(* Add spacing between RowBox elements that are comma separated *)
fasterCellToString0[ "," ] := ", ";
fasterCellToString0[ c: $$spacedInfixOperator ] := " "<>c<>" ";
fasterCellToString0[ RowBox[ row: { ___, ","|$$spacedInfixOperator, " ", ___ } ] ] :=
    fasterCellToString0 @ RowBox @ DeleteCases[ row, " " ];

(* IndentingNewline *)
fasterCellToString0[ FromCharacterCode[ 62371 ] ] := "\n\t";

fasterCellToString0[ "\[Bullet]"|"\[FilledSmallSquare]" ] := "*";

(* Invisible characters *)
fasterCellToString0[ $$invisibleCharacter ] := "";

(* Long name characters: *)
fasterCellToString0[ char: $$longNameCharacter ] := Lookup[ $longNameCharacters, char, char ];

fasterCellToString0[ string_String ] /; StringContainsQ[ string, $$longNameCharacter|$$invisibleCharacter ] :=
    fasterCellToString0 @ StringDelete[ StringReplace[ string, $longNameCharacters ], $$invisibleCharacter ];

(* StandardForm strings *)
fasterCellToString0[ s_String ] /; StringContainsQ[
    s,
    a: ("\!\(" ~~ Except[ "\)" ] .. ~~ "\)") /; StringLength @ a < $maxStandardFormStringLength
] :=
    Module[ { split },
        split = StringSplit[
            s,
            "\!\(" ~~ b: Except[ "\)" ].. ~~ "\)" :>
                usingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket[ "\!\("<>b<>"\)" ]
            ];

        StringJoin[ fasterCellToString0 /@ split ] /; ! MatchQ[ split, { s } ]
    ];

fasterCellToString0[ a_String ] /;
    StringLength @ a < $maxStandardFormStringLength && StringMatchQ[ a, "\""~~___~~("\\!"|"\!")~~___~~"\"" ] :=
    With[ { res = ToString @ ToExpression[ a, InputForm ] },
        If[ TrueQ @ $showStringCharacters,
            res,
            StringReplace[ StringTrim[ res, "\"" ], { "\\\"" -> "\"" } ]
        ] /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ]
    ];

fasterCellToString0[ a_String ] /;
    StringLength @ a < $maxStandardFormStringLength && StringContainsQ[ a, ("\\!"|"\!") ] :=
    With[ { res = stringToBoxes @ a }, res /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ] ];

(* Other strings *)
fasterCellToString0[ a_String ] :=
    ToString[
        escapeMarkdownCharacters @
            If[ TrueQ @ $showStringCharacters,
                a,
                StringReplace[ StringTrim[ a, "\"" ], { "\\\"" -> "\"" } ]
            ],
        CharacterEncoding -> $cellCharacterEncoding
    ];

fasterCellToString0[ a: { ___String } ] := StringJoin[ fasterCellToString0 /@ a ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Inline References*)
fasterCellToString0[
    Cell[ _, "InlinePersonaReference", ___, TaggingRules -> KeyValuePattern[ "PersonaName" -> name_String ], ___ ]
] := "@"<>name;

fasterCellToString0[ Cell[
    _,
    "InlineFunctionReference",
    ___,
    TaggingRules -> KeyValuePattern @ { "PromptFunctionName" -> name_String, "PromptArguments" -> args_List },
    ___
] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    "LLMResourceFunction[\"" <> name <> "\"][" <> StringRiffle[ toLLMArg /@ Flatten @ { args }, ", " ] <> "]"
);

fasterCellToString0[
    Cell[
        _,
        "InlineModifierReference",
        ___,
        TaggingRules -> KeyValuePattern @ { "PromptModifierName" -> name_String, "PromptArguments" -> { } },
        ___
    ]
] := "#" <> name;

fasterCellToString0[
    Cell[
        _,
        "InlineModifierReference",
        ___,
        TaggingRules -> KeyValuePattern @ { "PromptModifierName" -> name_String, "PromptArguments" -> args_List },
        ___
    ]
] := (
    needsBasePrompt[ "WolframLanguage" ];
    StringJoin[
        "LLMSynthesize[{",
        StringRiffle[ Flatten @ { "LLMPrompt[\""<>name<>"\"]", toLLMArg /@ Flatten @ { args } }, ", " ],
        "}]"
    ]
);


toLLMArg[ ">" ] := "$RestOfCellContents";
toLLMArg[ "^" ] := "$PreviousCellContents";
toLLMArg[ "^^" ] := "$ChatHistory";
toLLMArg[ arg_ ] := ToString[ arg, InputForm ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Tools*)
fasterCellToString0[
    Cell[ _, "InlineToolCall", ___, TaggingRules -> KeyValuePattern[ "ToolCall" -> s_String ], ___ ]
] := s;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Wolfram Alpha Input*)

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[
        { OrderlessPatternSequence[ Typeset`q$$ = query_String, Typeset`chosen$$ = code_String, ___ ] },
        ___
    ],
    ___
] ] := (
    needsBasePrompt[ "WolframAlphaInputIndicator" ];
    TemplateApply[ $wolframAlphaInputTemplate, <| "Query" -> query, "Code" -> code |> ]
);

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[ { ___, Typeset`chosen$$ = code_String, ___ }, ___ ],
    ___
] ] := code;

fasterCellToString0[ Cell[
    BoxData[ DynamicModuleBox[ { ___, _ = <| ___, "query" -> query_String, ___ |>, ___ }, __ ], ___ ],
    "DeployedNLInput",
    ___
] ] := (
    needsBasePrompt[ "WolframAlphaInputIndicator" ];
    "\[FreeformPrompt] " <> query
);

(* Control equals input *)
fasterCellToString0[ NamespaceBox[
    "LinguisticAssistant",
    DynamicModuleBox[ { ___, Typeset`query$$ = query_String, ___ }, __ ],
    ___
] ] := "\[FreeformPrompt][\""<>query<>"\"]";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Graphics*)
fasterCellToString0[ box: GraphicsBox[ TagBox[ RasterBox[ _, r___ ], t___ ], g___ ] ] /; ! TrueQ @ $multimodalImages :=
    StringJoin[
        "\\!\\(\\*",
        StringReplace[
            inputFormString @ GraphicsBox[ TagBox[ RasterBox[ "$$DATA$$", r ], t ], g ],
            $graphicsBoxStringReplacements
        ],
        "\\)"
    ];

fasterCellToString0[ box: $$graphicsBox ] :=
    Which[
        (* If in multimodal mode, sow the rasterized box and insert the id: *)
        TrueQ @ $multimodalImages,
        toMarkdownImageBox @ box,

        (* For relatively small graphics expressions, we'll give an InputForm string *)
        TrueQ[ ByteCount @ box < $maxOutputCellStringLength ],
        (
            needsBasePrompt[ "Notebooks" ];
            truncateString @ makeGraphicsString @ box
        ),

        (* Otherwise, give the same thing you'd get in a standalone kernel*)
        True,
        (
            needsBasePrompt[ "ConversionGraphics" ];
            truncateString[
                "\\!\\(\\*" <> StringReplace[ inputFormString @ box, $graphicsBoxStringReplacements ] <> "\\)"
            ]
        )
    ];



$graphicsBoxStringReplacements = {
    a: DigitCharacter ~~ "." ~~ b: Repeated[ DigitCharacter, { 4, Infinity } ] :> a <> "." <> StringTake[ b, 3 ],
    "\"$$DATA$$\"" -> "...",
    "$$DATA$$" -> "..."
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*toMarkdownImageBox*)
toMarkdownImageBox // beginDefinition;

toMarkdownImageBox[ graphics_ ] := Enclose[
    Module[ { img, uri },
        img    = ConfirmBy[ rasterizeGraphics @ graphics, ImageQ, "RasterizeGraphics" ];
        uri    = ConfirmBy[ MakeExpressionURI[ "image", img ], StringQ, "RasterID" ];
        needsBasePrompt[ "MarkdownImageBox" ];
        If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "MarkdownImageBoxImporting" ] ];
        "\\!\\(\\*MarkdownImageBox[\"" <> uri <> "\"]\\)"
    ],
    throwInternalFailure[ toMarkdownImageBox @ graphics, ## ] &
];

toMarkdownImageBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*rasterizeGraphics*)
rasterizeGraphics // beginDefinition;
rasterizeGraphics[ gfx: $$graphicsBox ] := rasterizeGraphics[ gfx ] = rasterize @ RawBoxes @ gfx;
rasterizeGraphics[ cell_Cell ] := rasterizeGraphics[ cell, 6.25*$cellPageWidth ];

rasterizeGraphics[ cell_Cell, width_Real ] := rasterizeGraphics[ cell, width ] =
    rasterize @ Append[ cell, PageWidth -> width ];

rasterizeGraphics // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Video*)
fasterCellToString0[ box: TemplateBox[ _, "VideoBox2", ___ ] ] /; $multimodalImages && $generateVideoPrompt :=
    generateVideoPrompt @ box;

fasterCellToString0[ box: TemplateBox[ _, "VideoBox2", ___ ] ] :=
    serializeVideo @ box;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*generateVideoPrompt*)
generateVideoPrompt // beginDefinition;

generateVideoPrompt[ box: TemplateBox[ _, "VideoBox2", ___ ] ] := generateVideoPrompt[ box ] =
    With[ { video = Quiet @ ToExpression[ box, StandardForm ] },
        If[ VideoQ @ video,
            generateVideoPrompt @ video,
            "\\!\\(\\*VideoBox[...]\\)"
        ]
    ];


generateVideoPrompt[ video_? VideoQ ] := Enclose[
    Module[ { small, audio, transcript, w, h, t, d, frames, preview },

        small      = ConfirmBy[ ImageResize[ video, { UpTo[ 150 ], UpTo[ 150 ] } ], VideoQ, "Resize" ];
        audio      = ConfirmBy[ Audio @ video, AudioQ, "Audio" ];
        transcript = ConfirmBy[ SpeechRecognize[ audio, Method -> "OpenAI" ], StringQ, "Transcript" ];
        w          = 4;
        h          = 6;
        t          = ConfirmBy[ Information[ small, "Duration" ], QuantityQ, "Duration" ];
        d          = t / (w * h);
        t          = Table[ (i - 0.5) * d, { i, w * h } ];
        frames     = ConfirmMatch[ VideoExtractFrames[ small, t ], { __Image }, "Frames" ];
        preview    = ToBoxes @ ConfirmBy[ ImageAssemble[ Partition[ frames, w ], Spacings -> 3 ], ImageQ, "Assemble" ];

        StringJoin[
            "VIDEO TRANSCRIPT\n-----\n",
            transcript,
            "\n\nVIDEO PREVIEW\n-----\n",
            ConfirmBy[ toMarkdownImageBox @ preview, StringQ, "Preview" ]
        ]
    ],
    throwInternalFailure
];

generateVideoPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serializeVideo*)
serializeVideo // beginDefinition;

serializeVideo[ box: TemplateBox[ _, "VideoBox2", ___ ] ] := serializeVideo[ box ] =
    serializeVideo[ box, Quiet @ ToExpression[ box, StandardForm ] ];

serializeVideo[ box_, video_ ] := Enclose[
    If[ VideoQ @ video,
        "\\!\\(\\*VideoBox[\"" <> ConfirmBy[ MakeExpressionURI @ video, StringQ, "URI" ] <> "\"]\\)",
        "\\!\\(\\*VideoBox[...]\\)"
    ],
    throwInternalFailure
];

serializeVideo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Audio*)
fasterCellToString0[ box: TagBox[ _, _Audio`AudioBox, ___ ] ] := serializeAudio @ box;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serializeAudio*)
serializeAudio // beginDefinition;

serializeAudio[ box: TagBox[ content_, _Audio`AudioBox, ___ ] ] := serializeAudio[ box ] =
    serializeAudio[ content, Quiet @ ToExpression[ box, StandardForm ] ];

serializeAudio[ content_, audio_ ] := Enclose[
    If[ AudioQ @ audio,
        "\\!\\(\\*AudioBox[\"" <> ConfirmBy[ MakeExpressionURI @ audio, StringQ, "URI" ] <> "\"]\\)",
        "\\!\\(\\*AudioBox[...]\\)"
    ],
    throwInternalFailure
];

serializeAudio // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Inline Code*)
fasterCellToString0[ TemplateBox[ { code_ }, "ChatCodeInlineTemplate" ] ] /; ! $inlineCode :=
    Block[ { $escapeMarkdown = False, $inlineCode = True },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

fasterCellToString0[ StyleBox[ code_, "TI", ___ ] ] /; ! $inlineCode :=
    Block[ { $escapeMarkdown = False, $inlineCode = True },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

fasterCellToString0[
    Cell[ BoxData[ link: TemplateBox[ _, $$refLinkTemplate, ___ ], ___ ], "InlineCode"|"InlineFormula", ___ ]
] /; ! $inlineCode := fasterCellToString0 @ link;

fasterCellToString0[ Cell[ code_, "InlineCode"|"InlineFormula", ___ ] ] /; ! $inlineCode :=
    Block[ { $escapeMarkdown = False, $inlineCode = True },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Template Boxes*)

(* Messages *)
fasterCellToString0[ TemplateBox[ args: { _, _, str_String, ___ }, "MessageTemplate" ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    sowMessageData @ args; (* Look for stack trace data *)
    fasterCellToString0 @ str
);

(* Large Outputs *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "shortenedBoxes" -> boxes_ ], "OutputSizeLimitTemplate" ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ TemplateBox[ { size_ }, "OutputSizeLimit`Skeleton" ] ] :=
    " \[LeftSkeleton]" <> fasterCellToString0 @ size <> "\[RightSkeleton] ";

(* Row *)
fasterCellToString0[ TemplateBox[ args_, "RowDefault", ___ ] ] := fasterCellToString0 @ args;
fasterCellToString0[ TemplateBox[ { sep_, items__ }, "RowWithSeparator" ] ] :=
    fasterCellToString0 @ Riffle[ { items }, sep ];

(* Tooltips *)
fasterCellToString0[ TemplateBox[ { a_, ___ }, "PrettyTooltipTemplate", ___ ] ] := fasterCellToString0 @ a;

(* Control-Equal Input *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "boxes" -> box_ ], "LinguisticAssistantTemplate" ] ] :=
    fasterCellToString0 @ box;

(* NotebookObject *)
fasterCellToString0[
    TemplateBox[ KeyValuePattern[ "label" -> label_String ], "NotebookObjectUUIDsUnsaved"|"NotebookObjectUUIDs" ]
] := (
    needsBasePrompt[ "Notebooks" ];
    "NotebookObject["<>label<>"]"
);

(* Entity *)
$$entityBoxType = "Entity"|"EntityClass"|"EntityProperty"|"EntityType";
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, $$entityBoxType ] ] := fasterCellToString0 @ box;
fasterCellToString0[ TemplateBox[ _, "InertEntity", ___ ] ] := "\[LeftSkeleton]formatted entity\[RightSkeleton]";

(* Quantities *)
$$quantityBoxType = "QuantityPrefixUnit"|"QuantityPrefix"|"Quantity"|"QuantityPostfix";
fasterCellToString0[ box: TemplateBox[ _, $$quantityBoxType, ___ ] ] :=
    With[ { s = makeExpressionString @ box }, s /; StringQ @ s ];

(* DateObject *)
$$dateBoxType = "DateObject"|"TimeObject";
fasterCellToString0[ TemplateBox[ { _, boxes_, ___ }, $$dateBoxType, ___ ] ] := fasterCellToString0 @ boxes;

(* Inactive *)
$$inactiveTemplate = Alternatives[
    "InactiveContinuedFractionK",
    "InactiveContinuedFractionKNoMin",
    "InactiveCurl",
    "InactiveD",
    "InactiveDifferenceDelta",
    "InactiveDifferenceDelta3",
    "InactiveDifferenceDelta4",
    "InactiveDiscreteLimit",
    "InactiveDiscreteMaxLimit",
    "InactiveDiscreteMinLimit",
    "InactiveDiscreteRatio",
    "InactiveDiscreteRatio3",
    "InactiveDiscreteRatio4",
    "InactiveDiscreteShift",
    "InactiveDiscreteShift3",
    "InactiveDiscreteShift4",
    "InactiveDiv",
    "InactiveGrad",
    "InactiveHead",
    "InactiveIntegrate",
    "InactiveLaplacian",
    "InactiveLimit",
    "InactiveLimit2Arg",
    "InactiveLimitFromAutomatic",
    "InactiveLimitFromLeft",
    "InactiveLimitFromRight",
    "InactiveLimitWithSuperscript",
    "InactiveLimitWithTooltip",
    "InactiveMaxLimit2Arg",
    "InactiveMaxLimitWithSuperscript",
    "InactiveMaxLimitWithTooltip",
    "InactiveMinLimit2Arg",
    "InactiveMinLimitWithSuperscript",
    "InactiveMinLimitWithTooltip",
    "InactivePart",
    "InactiveProduct",
    "InactiveSum"
];
fasterCellToString0[ box: TemplateBox[ { ___ }, $$inactiveTemplate, ___ ] ] :=
    With[ { str = makeExpressionString @ box }, str /; StringQ @ str ];

(* Spacers *)
fasterCellToString0[ TemplateBox[ _, "Spacer1" ] ] := " ";

(* Links *)
$$refLinkTemplate = Alternatives[
    "AnyLink",
    "EntityTypeLink",
    "GrayLink",
    "GrayLinkWithIcon",
    "HyperlinkPaclet",
    "KnowLink",
    "MenuGrayLink",
    "NonWLLink",
    "OrangeLink",
    "PackageLink",
    "RefLink",
    "RefLinkPlain",
    "SearchResultLink",
    "SearchResultPageLink",
    "StringTypeLink",
    "TealLink",
    "TextRefLink",
    "WFOrangeLink"
];

fasterCellToString0[ TemplateBox[ { label_, uri_String, ___ }, $$refLinkTemplate, ___ ] ] /; $inlineCode :=
    fasterCellToString0 @ label;

fasterCellToString0[ TemplateBox[ { label_, uri_String, ___ }, $$refLinkTemplate, ___ ] ] :=
    If[ StringStartsQ[ uri, "paclet:" ],
        needsBasePrompt[ "WolframLanguage" ];
        "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")",
        "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")"
    ];

fasterCellToString0[
    ButtonBox[ label_, OrderlessPatternSequence[ BaseStyle -> "Link", ButtonData -> uri_String, ___ ] ]
] :=
    If[ StringStartsQ[ uri, "paclet:" ],
        needsBasePrompt[ "WolframLanguage" ];
        "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")",
        "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")"
    ];

fasterCellToString0[ ButtonBox[ StyleBox[ label_, "SymbolsRefLink", ___ ], ___, ButtonData -> uri_String, ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")"
);

fasterCellToString0[
    ButtonBox[
        label_,
        OrderlessPatternSequence[
            BaseStyle  -> "Hyperlink",
            ButtonData -> { url: _String|_URL, _ },
            ___
        ]
    ]
] := "[" <> fasterCellToString0 @ label <> "](" <> TextString @ url <> ")";

(* TeXAssistantTemplate *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "input" -> string_ ], "TeXAssistantTemplate" ] ] := (
    needsBasePrompt[ "Math" ];
    "$$" <> string <> "$$"
);

(* Inline WL code template *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "input" -> input_ ], "ChatbookWLTemplate", ___ ] ] :=
    Replace[
        Quiet[ ToExpression[ input, StandardForm ], ToExpression::esntx ],
        {
            string_String? StringQ :> string,
            $Failed :> "\n\n[Inline parse failure: " <> ToString[ fasterCellToString0 @ input, InputForm ] <> "]",
            expr_ :> fasterCellToString0 @ ToBoxes @ expr
        }
    ];

(* Other *)
fasterCellToString0[ box: TemplateBox[ args_, name_String, ___ ] ] /;
    $templateBoxRules @ name === makeExpressionString :=
        With[ { str = makeExpressionString @ box },
            str /; StringQ @ str
        ];

fasterCellToString0[ box: TemplateBox[ args_, name_String, ___ ] ] :=
    With[ { f = $templateBoxRules @ name },
        fasterCellToString0 @ f @ args /; ! MissingQ @ f && f =!= makeExpressionString
    ];

fasterCellToString0[ TemplateBox[ { args___ }, ___, InterpretationFunction -> f_, ___ ] ] :=
    fasterCellToString0 @ f @ args;

fasterCellToString0[ TemplateBox[ args_, ___, InterpretationFunction -> f_, ___ ] ] :=
    fasterCellToString0 @ f @ args;

fasterCellToString0[ OverlayBox[ { a_, ___ }, ___ ] ] :=
    fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*TeX*)
fasterCellToString0[ FormBox[
    StyleBox[ RowBox @ { "L", StyleBox[ AdjustmentBox[ "A", ___ ], ___ ], "T", AdjustmentBox[ "E", ___ ], "X" }, ___ ],
    TraditionalForm,
    ___
] ] := "LaTeX";

fasterCellToString0[ FormBox[
    StyleBox[ RowBox @ { "T", AdjustmentBox[ "E", ___ ], "X" }, ___ ],
    TraditionalForm,
    ___
] ] := "TeX";

fasterCellToString0[ box: FormBox[ _, TraditionalForm, ___ ] ] :=
    serializeTraditionalForm @ box;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serializeTraditionalForm*)
serializeTraditionalForm // beginDefinition;

serializeTraditionalForm[ box0: FormBox[ inner_, ___ ] ] := serializeTraditionalForm[ box0 ] =
    Module[ { box, string },
        box = preprocessTraditionalForm @ box0;
        string = Quiet @ ExportString[ Cell @ BoxData @ box, "TeXFragment" ];
        If[ StringQ @ string && StringMatchQ[ string, "\\("~~__~~"\\)"~~WhitespaceCharacter... ],
            fixLineEndings @ StringReplace[
                StringTrim @ string,
                StartOfString~~"\\("~~math__~~"\\)"~~EndOfString :> "$$"<>math<>"$$"
            ],
            fasterCellToString0 @ inner
        ]
    ];

serializeTraditionalForm // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*preprocessTraditionalForm*)
preprocessTraditionalForm // beginDefinition;

preprocessTraditionalForm[ box_ ] := box //. {
    "\[InvisiblePrefixScriptBase]" :> " "
};

preprocessTraditionalForm // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Math Boxes*)

fasterCellToString0[ SubscriptBox[ "\[InvisiblePrefixScriptBase]", x_ ] ] :=
    fasterCellToString0 @ SubscriptBox[ " ", x ];

(* Sqrt *)
fasterCellToString0[ SqrtBox[ a_ ] ] :=
    (needsBasePrompt[ "WolframLanguage" ]; "Sqrt["<>fasterCellToString0 @ a<>"]");

(* Fraction *)
fasterCellToString0[ FractionBox[ a_, b_ ] ] :=
    (needsBasePrompt[ "Math" ]; "(" <> fasterCellToString0 @ a <> "/" <> fasterCellToString0 @ b <> ")");

(* Piecewise *)
fasterCellToString0[ box: TagBox[ _, "Piecewise", ___ ] ] :=
    With[ { expr = Quiet @ ToExpression[ box, StandardForm, HoldComplete ] },
        Replace[ expr, HoldComplete[ e_ ] :> inputFormString @ Unevaluated @ e ] /;
            MatchQ[ expr, HoldComplete[ _Piecewise ] ]
    ];

(* CenteredInterval *)
fasterCellToString0[
    TemplateBox[ KeyValuePattern[ "Interpretation" -> int_InterpretationBox ], "CenteredInterval", ___ ]
] := fasterCellToString0 @ int;

(* DoubleStruck Capitals *)
fasterCellToString0[ TemplateBox[ { }, "Integers" , ___ ] ] := "\:2124";
fasterCellToString0[ TemplateBox[ { }, "Reals"    , ___ ] ] := "\:211d";
fasterCellToString0[ TemplateBox[ { }, "Complexes", ___ ] ] := "\:2102";

(* C *)
fasterCellToString0[ TemplateBox[ { n_ }, "C", ___ ] ] := "C[" <> fasterCellToString0 @ n <> "]";

(* Typesetting *)
fasterCellToString0[ SubscriptBox[ a_, b_ ] ] :=
    If[ TrueQ @ $inlineCode,
        StringJoin[ fasterCellToString0 @ a, fasterCellToString0 @ b ],
        "Subscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]"
    ];

fasterCellToString0[ OverscriptBox[ a_, b_ ] ] :=
    "Overscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]";

fasterCellToString0[ UnderscriptBox[ a_, b_ ] ] :=
    "Underscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]";

fasterCellToString0[ UnderoverscriptBox[ a_, b_, c_ ] ] := StringJoin[
    "Underoverscript[",
    fasterCellToString0 @ a,
    ", ",
    fasterCellToString0 @ b,
    ", ",
    fasterCellToString0 @ c,
    "]"
];

fasterCellToString0[ box_RadicalBox ] :=
    With[ { s = makeExpressionString @ box }, s /; StringQ @ s ];

(* Other *)
fasterCellToString0[ (box: $boxOperators)[ a_, b_, OptionsPattern[ ] ] ] :=
    Module[ { a$, b$ },
        a$ = fasterCellToString0 @ a;
        b$ = fasterCellToString0 @ b;
        If[ StringQ @ a$ && StringQ @ b$,
            a$ <> $boxOp @ box <> b$,
            { a$, b$ }
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Large Outputs*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* cSpell: ignore noinfoker *)
fasterCellToString0[
    InterpretationBox[
        boxes_,
        If[ _Integer === $SessionID, Out[ _ ], ___ ],
        ___
    ]
] := (
    needsBasePrompt[ "WolframLanguage" ];
    outputSizeLimitString @ boxes
);
(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*outputSizeLimitString*)
outputSizeLimitString // beginDefinition;

outputSizeLimitString[ boxes_ ] :=
    FirstCase[
        boxes,
        HoldPattern @ TagBox[ b_, Short[ #, ___ ] &, ___ ] :> fasterCellToString0 @ b,
        fasterCellToString0 @ boxes,
        Infinity
    ];

outputSizeLimitString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Iconized Expressions*)
fasterCellToString0[
    InterpretationBox[ DynamicModuleBox[ { ___ }, iconized: TemplateBox[ _, "IconizedObject" ] ], ___ ]
] := fasterCellToString0 @ iconized;

fasterCellToString0[ TemplateBox[ { _, label_, ___ }, "IconizedObject", ___ ] ] :=
    "IconizedObject[\[LeftSkeleton]" <> StringTrim[ fasterCellToString0 @ label, "\"" ] <> "\[RightSkeleton]]";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Definitions*)
fasterCellToString0[ InterpretationBox[ boxes_, (Definition|FullDefinition)[ _Symbol ], ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    fasterCellToString0 @ boxes
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Tables*)
fasterCellToString0[ GridBox[ { row: { ___ } }, ___ ] ] :=
    fasterCellToString0 @ RowBox @ row;

(* Columns combined via row: *)
fasterCellToString0[ box: GridBox[ grids: { { GridBox[ _? MatrixQ, ___ ].. } }, ___ ] ] :=
    Module[ { subGrids, dim, reshaped, spliced },
        subGrids = Cases[ grids, GridBox[ m_, ___ ] :> m, { 2 } ];
        dim = Max /@ Transpose[ Dimensions /@ subGrids ];
        reshaped = (ArrayReshape[ #1, dim, "" ] &) /@ subGrids;
        spliced = Flatten /@ Transpose @ reshaped;
        fasterCellToString0 @ GridBox @ spliced
    ];

fasterCellToString0[ box: GridBox[ grid_? MatrixQ, ___ ] ] :=
    Module[ { strings, tr, colSizes, padded, columns },
        strings = Map[ fasterCellToString0, grid, { 2 } ];
        (
            tr       = Transpose @ strings /. "\[Null]"|"\[InvisibleSpace]" -> "";
            colSizes = Max[ #, 1 ] & /@ Map[ StringLength, tr, { 2 } ];
            padded   = Transpose @ Apply[ StringPadRight, Transpose @ { tr, colSizes }, { 1 } ];
            columns  = StringRiffle[ #, " | " ] & /@ padded;
            If[ TrueQ @ $columnHeadings,
                StringRiffle[ "| "<>#<> " |" & /@ insertColumnDelimiter[ columns, colSizes, box ], "\n" ],
                StringRiffle[
                    "| "<>#<> " |" & /@ Join[
                        {
                            StringRiffle[ StringRepeat[ " ", # ] & /@ colSizes, " | " ],
                            StringRiffle[ createAlignedDelimiters[ colSizes, box ], " | " ]
                        },
                        columns
                    ],
                    "\n"
                ]
            ]
        ) /; AllTrue[ strings, StringQ, 2 ]
    ];

fasterCellToString0[ TagBox[ grid_GridBox, { _, OutputFormsDump`HeadedColumns }, ___ ] ] :=
    Block[ { $columnHeadings = True }, fasterCellToString0 @ grid ];


insertColumnDelimiter // beginDefinition;

insertColumnDelimiter[ { headings_String, rows__String }, colSizes: { __Integer }, box_ ] := {
    headings,
    StringRiffle[ createAlignedDelimiters[ colSizes, box ], " | " ],
    rows
};

insertColumnDelimiter[ rows_List, _List, box_ ] := rows;

insertColumnDelimiter // endDefinition;


createAlignedDelimiters // beginDefinition;

createAlignedDelimiters[ colSizes_, GridBox[ ___, GridBoxAlignment -> { ___, "Columns" -> alignments_, ___ }, ___ ] ] :=
    createAlignedDelimiters[ colSizes, alignments ];

createAlignedDelimiters[ colSizes_, _GridBox ] :=
    StringRepeat[ "-", Max[ #, 1 ] ] & /@ colSizes;

createAlignedDelimiters[ colSizes_List, alignments_List ] /; Length @ colSizes === Length @ alignments :=
    createAlignedDelimiter @@@ Transpose @ {
        colSizes,
        Replace[
            alignments,
            { (Center|"Center"|{Center|"Center"}).. } :> ConstantArray[ Automatic, Length @ colSizes ]
        ]
    };

createAlignedDelimiters[ colSizes_List, { a: Except[ { _ } ]..., { repeat_ }, b: Except[ { _ } ]... } ] :=
    Module[ { total, current, need, expanded, full, alignments },
        total      = Length @ colSizes;
        current    = Length @ { a, b };
        need       = Max[ total - current, 0 ];
        expanded   = ConstantArray[ repeat, need ];
        full       = Join[ { a }, expanded, { b } ];
        alignments = Take[ full, UpTo @ total ];
        createAlignedDelimiter @@@ Transpose @ {
            colSizes,
            Replace[ alignments, { (Center|"Center").. } :> ConstantArray[ Automatic, total ] ]
        }
    ];

createAlignedDelimiters // endDefinition;


createAlignedDelimiter // beginDefinition;
createAlignedDelimiter[ size_Integer, "Left"  | Left   ] := ":" <> StringRepeat[ "-", Max[ size-1, 1 ] ];
createAlignedDelimiter[ size_Integer, "Right" | Right  ] := StringRepeat[ "-", Max[ size-1, 1 ] ] <> ":";
createAlignedDelimiter[ size_Integer, "Center"| Center ] := ":" <> StringRepeat[ "-", Max[ size-2, 1 ] ] <> ":";
createAlignedDelimiter[ size_Integer, { alignment_ } ] := createAlignedDelimiter[ size, alignment ];
createAlignedDelimiter[ size_Integer, _ ] := StringRepeat[ "-", Max[ size, 1 ] ];
createAlignedDelimiter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Documentation Notebooks*)
fasterCellToString0[ Cell[ boxes_, ___, "ObjectNameGrid", ___ ] ] :=
    Module[ { header, note, version },
        header = "# " <> FirstCase[
            boxes,
            Cell[ name_, ___, "ObjectName", ___ ] :> fasterCellToString0 @ name,
            fasterCellToString0 @ boxes,
            Infinity
        ];

        note = FirstCase[
            boxes,
            StyleBox[ box_, "PrerequisiteTag" ] :> fasterCellToString0 @ box,
            "",
            Infinity
        ];

        If[ StringQ @ note && note =!= "",
            note = "\:26A0 *" <> StringTrim[ note, "\"" ] <> "*"
        ];

        version = FirstCase[
            boxes,
            TooltipBox[ StyleBox[ _, "NewInGraphic", ___ ], box_, ___ ] :> fasterCellToString0 @ box,
            "",
            Infinity
        ];

        If[ StringQ @ version && version =!= "",
            version = "*" <> StringTrim[ version, "\"" ] <> "*"
        ];

        StringRiffle[
            Select[ { header, note, version }, StringQ @ # && # =!= "" & ],
            "\n"
        ]
    ];

$$usageStyle = "Usage"|"CFunctionUsage"|"EntityUsage";
fasterCellToString0[ Cell[ BoxData[ GridBox[ grid_? MatrixQ, ___ ] ], $$usageStyle, ___ ] ] :=
    StringRiffle[ docUsageString /@ grid, "\n\n" ];

fasterCellToString0[
    Cell[ __, "SeeAlsoSection", ___, TaggingRules -> KeyValuePattern[ "SeeAlsoGrid" -> grid_ ], ___ ]
] := seeAlsoSection @ grid;

fasterCellToString0[ Cell[ BoxData[ grid_GridBox, ___ ], ___, "SeeAlsoSection", ___ ] ] := seeAlsoSection @ grid;

fasterCellToString0[ Cell[
    BoxData @ GridBox @ { { Cell[ _BoxData, ___ ], Cell[ note_, "ObsolescenceNote"|"AwaitingReviewNote", ___ ] } },
    "ObsolescenceNote"|"AwaitingReviewNote",
    ___
] ] := "\:26A0 " <> fasterCellToString0 @ note;

fasterCellToString0[ DynamicBox[ If[ True, cell_Cell, __ ], ___ ] ] :=
    fasterCellToString0 @ cell;

fasterCellToString0[ Cell[ boxes_, "FunctionEssay", ___ ] ] :=
    fasterCellToString0 @ boxes <> "\n\n";


$$relatedGuideSection     = "MoreAboutSection"|"GuideMoreAboutSection"|"FeaturedExampleMoreAboutSection";
$$relatedWorkflowsSection = "RelatedWorkflowsSection"|"GuideRelatedWorkflowsSection";
$$relatedTutorialSection  = "TutorialsSection"|"GuideTutorialsSection"|"RelatedTutorialsSection";
$$relatedLinksSection     = "RelatedLinksSection"|"GuideRelatedLinksSection";

fasterCellToString0[ Cell[ BoxData[ grid_, ___ ], $$relatedGuideSection, ___ ] ] :=
    relatedLinksSection[ grid, $$relatedGuideSection, "Related Guides" ];

fasterCellToString0[ Cell[ BoxData[ grid_, ___ ], $$relatedWorkflowsSection, ___ ] ] :=
    relatedLinksSection[ grid, $$relatedWorkflowsSection, "Related Workflows" ];

fasterCellToString0[ Cell[ BoxData[ grid_, ___ ], $$relatedTutorialSection, ___ ] ] :=
    relatedLinksSection[ grid, $$relatedTutorialSection, "Related Tutorials" ];

fasterCellToString0[ Cell[ BoxData[ grid_, ___ ], $$relatedLinksSection, ___ ] ] :=
    relatedLinksSection[ grid, $$relatedLinksSection, "Related Links" ];

fasterCellToString0[ Cell[ BoxData[ grid_, ___ ], "HistorySection", ___ ] ] :=
    historySection @ grid;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*docUsageString*)
docUsageString // beginDefinition;

docUsageString[ row_List ] :=
    Block[ { $inlineCode = True },
        StringReplace[ StringJoin[ fasterCellToString0 /@ row ], "\[LineSeparator]" -> " " ]
    ];

docUsageString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*seeAlsoSection*)
seeAlsoSection // beginDefinition;

seeAlsoSection[ grid_ ] :=
    Module[ { header, items },
        header = "## See Also\n";
        items = Cases[
            grid,
            b: TemplateBox[ { __ }, $$refLinkTemplate, ___ ] :>
                "* " <> fasterCellToString0 @ b,
            Infinity
        ];
        If[ items === { }, "", StringRiffle[ Flatten @ { header, items }, "\n" ] ]
    ];

seeAlsoSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*relatedLinksSection*)
relatedLinksSection // beginDefinition;

relatedLinksSection[ grid_, style_, header0_String ] := Enclose[
    Module[ { header, items },

        header = ConfirmBy[
            FirstCase[
                grid,
                StyleBox[ box_, style, ___ ] :> "## " <> fasterCellToString0 @ box,
                "## "<>header0,
                Infinity
            ],
            StringQ,
            "Header"
        ];

        items = Cases[
            grid,
            b: (TemplateBox[ { __ }, $$refLinkTemplate, ___ ]|ButtonBox[ __, BaseStyle -> "Link", ___ ]) :>
                "* " <> ConfirmBy[ fasterCellToString0 @ b, StringQ, "Item" ],
            Infinity
        ];

        If[ items === { }, "", StringRiffle[ Flatten @ { header<>"\n", items }, "\n" ] ]
    ],
    throwInternalFailure
];

relatedLinksSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*historySection*)
historySection // beginDefinition;

historySection[ grid_ ] := Enclose[
    Module[ { header, items },

        header = ConfirmBy[
            FirstCase[
                grid,
                StyleBox[ box_, "HistorySection", ___ ] :> "## " <> fasterCellToString0 @ box,
                "## History",
                Infinity
            ],
            StringQ,
            "Header"
        ];

        items = DeleteDuplicates @ Cases[
            grid,
            c: Cell[ __, "History", ___ ] :> "* " <> fasterCellToString0 @ c,
            Infinity
        ];

        If[ items === { }, "", StringRiffle[ Flatten @ { header<>"\n", items }, "\n" ] ]
    ],
    throwInternalFailure
];

historySection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Resource Definition Notebooks*)

(* Function Usage *)
fasterCellToString0[ Cell[ code_, "UsageInputs", ___ ] ] /; ! $inlineCode :=
    Block[ { $escapeMarkdown = False, $inlineCode = True },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

fasterCellToString0[ Cell[ description_, "UsageDescription", ___  ] ] :=
    "$$NO_TRIM$$\t" <> fasterCellToString0 @ description;

(* Text from info buttons: *)
fasterCellToString0[
    PaneSelectorBox[ { ___, True -> button: TemplateBox[ _, "MoreInfoOpenerButtonTemplate", ___ ], ___ }, ___ ]
] := fasterCellToString0 @ button;

fasterCellToString0[ TemplateBox[ { _, info_ }, "MoreInfoOpenerButtonTemplate", ___ ] ] :=
    StringJoin[
        $delimiterString,
        "[ Instructions ]\n\n",
        fasterCellToString0 @ info,
        $delimiterString,
        "\n"
    ];

(* OS-specific displays: *)
fasterCellToString0 @ DynamicBox[ ToBoxes[ If[ $OperatingSystem === os_String, a_, b_ ], StandardForm ], ___ ] :=
    If[ $OperatingSystem === os, fasterCellToString0 @ a, fasterCellToString0 @ b ];

(* Checkboxes: *)
fasterCellToString0[ Cell[
    BoxData[ TagBox[ grid_GridBox, "Grid", ___ ], ___ ],
    ___,
    CellTags -> { ___, "CheckboxCell", ___ },
    ___
] ] :=
    Block[ { $showStringCharacters = False },
        StringRiffle[
            Cases[
                grid,
                { checkbox_CheckboxBox, ___, label: _StyleBox | _String } :>
                    StringRiffle @ { fasterCellToString0 @ checkbox, fasterCellToString0 @ label },
                Infinity
            ],
            "\n"
        ]
    ];

fasterCellToString0[ CheckboxBox[ a_, { a_, __ }, ___ ] ] := checkbox @ False;
fasterCellToString0[ CheckboxBox[ b_, { _, b_, ___ }, ___ ] ] := checkbox @ True;
fasterCellToString0[ CheckboxBox[ True, ___ ] ] := checkbox @ True;
fasterCellToString0[ CheckboxBox[ False, ___ ] ] := checkbox @ False;
fasterCellToString0[ CheckboxBox[ ___ ] ] := checkbox @ None;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*checkbox*)
checkbox // beginDefinition;
checkbox[ True  ] := (needsBasePrompt["Checkboxes"]; "[\[Checkmark]]");
checkbox[ False ] := (needsBasePrompt["Checkboxes"]; "[ ]");
checkbox[ None  ] := (needsBasePrompt["CheckboxesIndeterminate"]; "[-]");
checkbox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored Patterns*)
$$ignoredBox = Alternatives[
    (* Documentation structures: *)
    DynamicBox[
        ToBoxes @ If[
            MatchQ[ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "Openers", __ }, ___ ], _ ],
            _,
            _
        ],
        ___
    ]
    ,
    DynamicBox[
        ToBoxes @ If[
            MatchQ[ Dynamic[ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "Openers", __ }, ___ ] ][[ _ ]], _ ],
            _,
            _
        ],
        ___
    ]
    ,
    DynamicBox[ If[ CurrentValue[ EvaluationNotebook[ ], { TaggingRules, "ShowCitation" } ] === False, _, _ ], ___ ]
    ,
    TemplateBox[ { ___ }, "ExampleJumpLink"|"OptsTableJumpLink", ___ ]
    ,
    Cell[ __, "NotesThumbnails", ___ ]
    ,
    Cell[ __, "TutorialJumpBox", ___ ]
    ,
    Cell[ __, $$ignoredCellStyle, ___ ]
];


fasterCellToString0[ $$ignoredBox ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other*)
fasterCellToString0[ Cell[ _, "ObjectNameTranslation", ___ ] ] := "";

fasterCellToString0[ ProgressIndicatorBox[ args___ ] ] :=
    inputFormString @ Unevaluated @ ProgressIndicator @ args;

fasterCellToString0[ PaneSelectorBox[ { ___, False -> b_, ___ }, Dynamic[ CurrentValue[ "MouseOver" ], ___ ], ___ ] ] :=
    fasterCellToString0 @ b;

fasterCellToString0[
    TagBox[ _, "MarkdownImage", ___, TaggingRules -> KeyValuePattern[ "CellToStringData" -> string_String ], ___ ]
] := string;

fasterCellToString0[ BoxData[ boxes_List, ___ ] ] :=
    With[ { strings = fasterCellToString0 /@ DeleteCases[ boxes, "\n" ] },
        StringRiffle[ strings, "\n" ] /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ BoxData[ boxes_, ___ ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ list_List ] :=
    With[ { strings = fasterCellToString0 /@ list },
        StringJoin @ strings /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ cell: Cell[ a_, ___ ] ] :=
    Block[
        {
            $showStringCharacters = showStringCharactersQ @ cell,
            $escapeMarkdown       = escapeMarkdownCharactersQ @ cell
        },
        fasterCellToString0 @ a
    ];

fasterCellToString0[ InterpretationBox[ _, expr_, ___ ] ] := Quiet[
    With[ { held = replaceCellContext @ HoldComplete @ expr },
        needsBasePrompt[ "WolframLanguage" ];
        Replace[ held, HoldComplete[ e_ ] :> inputFormString @ Unevaluated @ e ]
    ],
    Rule::rhs
];

fasterCellToString0[ Cell[ TextData @ { _, _, text_String, _, Cell[ _, "ExampleCount", ___ ] }, ___ ] ] :=
    fasterCellToString0 @ text;

fasterCellToString0[ DynamicModuleBox[
    _,
    TagBox[
        Cell[
            BoxData[
                TagBox[
                    _,
                    "MarkdownImage",
                    ___,
                    TaggingRules -> Association @ OrderlessPatternSequence[ "CellToStringData" -> str_String, ___ ]
                ],
                ___
            ],
            __
        ],
        ___
    ],
    ___
] ] := str;

fasterCellToString0[ DynamicModuleBox[
    _,
    box_,
    ___,
    TaggingRules -> Association @ OrderlessPatternSequence[
        "CellToStringType" -> "InlineInteractiveCodeCell",
        "CodeLanguage"     -> lang_String,
        ___
    ],
    ___
] ] := Block[ { $escapeMarkdown = False }, "```" <> lang <> "\n" <> fasterCellToString0 @ box <> "\n```" ];

fasterCellToString0[ Cell[
    box_,
    ___,
    TaggingRules -> Association @ OrderlessPatternSequence[
        "CellToStringType" -> "InlineCodeCell",
        "CodeLanguage"     -> lang_String,
        ___
    ],
    ___
] ] := Block[ { $escapeMarkdown = False }, "```" <> lang <> "\n" <> fasterCellToString0 @ box <> "\n```" ];

fasterCellToString0[ Cell[ BoxData[ boxes_, ___ ], "ChatCodeBlock", ___ ] ] :=
    Module[ { string },
        string = Block[ { $escapeMarkdown = False }, fasterCellToString0 @ boxes ];
        If[ StringMatchQ[ string, "```" ~~ __ ~~ "```" ], string, "```\n"<>string<>"\n```" ]
    ];

fasterCellToString0[ _[
    __,
    TaggingRules -> Association @ OrderlessPatternSequence[ "CellToStringData" -> data_, ___ ],
    ___
] ] := fasterCellToString0 @ data;

fasterCellToString0[ box_TabViewBox ] :=
    With[ { str = makeExpressionString @ box }, str /; StringQ @ str ];

fasterCellToString0[ DynamicModuleBox[
    { ___, TypeSystem`NestedGrid`PackagePrivate`$state$$ = Association[ ___, "InitialData" -> data_, ___ ], ___ },
    ___
] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    inputFormString @ Unevaluated @ Dataset @ data
);

fasterCellToString0[ DynamicModuleBox[ a___ ] ] /; ! TrueQ @ $CellToStringDebug := (
    needsBasePrompt[ "ConversionLargeOutputs" ];
    "DynamicModule[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]"
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored/Skipped*)
fasterCellToString0[ FormBox[ box_, ___ ] ] := fasterCellToString0 @ box;
fasterCellToString0[ $ignoredBoxPatterns ] := "";
fasterCellToString0[ $stringStripHeads[ a_, ___ ] ] := fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Missing Definition*)
fasterCellToString0[ a___ ] := (
    $unhandledBoxFunction @ a;
    If[ TrueQ @ $CellToStringDebug, Internal`StuffBag[ $fasterCellToStringFailBag, HoldComplete @ a ] ];
    If[ TrueQ @ $catchingStringFail, Throw[ $Failed, $stringFail ], "" ]
);

$fasterCellToStringFailBag := $fasterCellToStringFailBag = Internal`Bag[ ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*slowCellToString*)
slowCellToString // SetFallthroughError;

slowCellToString[ cell_Cell ] :=
    Module[ { format, plain, string },

        format = If[ TrueQ @ $showStringCharacters, "InputText", "PlainText" ];
        plain  = Quiet @ usingFrontEnd @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, format ];
        string = Replace[ plain, { { s_String? StringQ, ___ } :> s, ___ :> $Failed } ];

        If[ StringQ @ string,
            truncateString @ StringReplace[ StringTrim @ string, $exportPacketStringReplacements ],
            $Failed
        ]
    ];

slowCellToString[ boxes_BoxData ] := slowCellToString @ Cell @ boxes;
slowCellToString[ text_TextData ] := Block[ { $showStringCharacters = False }, slowCellToString @ Cell @ text ];
slowCellToString[ text_String   ] := slowCellToString @ TextData @ text;
slowCellToString[ boxes_        ] := slowCellToString @ BoxData @ boxes;


$exportPacketStringReplacements = {
    "\r\n" -> "\n",
    "CompressedData[\"" ~~ s: Except[ "\"" ].. ~~ "\"]" :>
        "CompressedData[\"" <> truncateString[ StringDelete[ s, Whitespace ], 8 ] <> "\"]"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Additional Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inputFormString*)
inputFormString // SetFallthroughError;

inputFormString[ expr: h_[ args___ ], opts: OptionsPattern[ ] ] /;
    ByteCount @ Unevaluated @ expr > $maxInputFormByteCount :=
        StringJoin[
            inputFormString @ Unevaluated @ h,
            "[\[LeftSkeleton]", ToString @ Length @ HoldComplete @ args, "\[RightSkeleton]]"
        ];

inputFormString[ expr_, opts: OptionsPattern[ ] ] := StringReplace[
    ToString[ Unevaluated @ expr,
              InputForm,
              opts,
              PageWidth         -> $cellPageWidth,
              CharacterEncoding -> $cellCharacterEncoding
    ],
    $inputFormReplacements
];

$inputFormReplacements = {
    "CompressedData[\"" ~~ s: Except[ "\"" ].. ~~ "\"]" :>
        "CompressedData[\"\[LeftSkeleton]" <> ToString @ StringLength @ s <> "\[RightSkeleton]\"]"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeExpressionString*)
makeExpressionString // beginDefinition;

makeExpressionString[ box_ ] :=
    makeExpressionString[ box, Quiet @ ToExpression[ box, StandardForm, HoldComplete ] ];

makeExpressionString[ box_, HoldComplete[ e_ ] ] := makeExpressionString[ box ] =
    inputFormString @ Unevaluated @ e;

makeExpressionString[ box_, $Failed ] :=
    With[ { expr = Quiet @ MakeExpression @ box },
        makeExpressionString[ box, expr ] /; ! FailureQ @ expr
    ];

makeExpressionString[ box_, _ ] := makeExpressionString[ box ] =
    $Failed;

makeExpressionString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // SetFallthroughError;

stringToBoxes[ s_String /; StringMatchQ[ s, "\"" ~~ __ ~~ "\"" ] ] :=
    With[ { str = stringToBoxes @ StringTrim[ s, "\"" ] }, "\""<>str<>"\"" /; StringQ @ str ];

stringToBoxes[ string_String ] :=
    stringToBoxes[
        string,
        (* TODO: there could be a kernel implementation of this *)
        Quiet @ usingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`UndocumentedTestFEParserPacket[ string, True ]
    ];

stringToBoxes[ string_, { BoxData[ boxes_, ___ ], ___ } ] := boxes;
stringToBoxes[ string_, other_ ] := string;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGraphicsString*)
makeGraphicsString // SetFallthroughError;

makeGraphicsString[ gfx_ ] := makeGraphicsString[ gfx, makeGraphicsExpression @ gfx ];

makeGraphicsString[ gfx_, HoldComplete[ expr: _Graphics|_Graphics3D|_Image|_Image3D|_Graph ] ] :=
    StringReplace[ inputFormString @ Unevaluated @ expr, "\r\n" -> "\n" ];

makeGraphicsString[
    GraphicsBox[
        NamespaceBox[ "NetworkGraphics", DynamicModuleBox[ { ___, _ = HoldComplete @ Graph[ a___ ], ___ }, ___ ] ],
        ___
    ],
    _
] := "Graph[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]";

makeGraphicsString[ GraphicsBox[ a___ ], _ ] :=
    "Graphics[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]";

makeGraphicsString[ Graphics3DBox[ a___ ], _ ] :=
    "Graphics3D[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]";

makeGraphicsString[ RasterBox[ a___ ], _ ] :=
    "Image[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]";

makeGraphicsString[ Raster3DBox[ a___ ], _ ] :=
    "Image3D[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeGraphicsExpression*)
makeGraphicsExpression // SetFallthroughError;
makeGraphicsExpression[ gfx_ ] := Quiet @ Check[ ToExpression[ gfx, StandardForm, HoldComplete ], $Failed ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowMessageData*)
sowMessageData[ { _, _, _, _, line_Integer, counter_Integer, session_Integer, _ } ] :=
    With[ { stack = MessageMenu`MessageStackList[ line, counter, session ] },
        Sow[ stack, $messageStack ] /; MatchQ[ stack, { __HoldForm } ]
    ];

sowMessageData[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showStringCharactersQ*)
showStringCharactersQ[ Cell[ __, "TextTableForm", ___ ] ] := False;
showStringCharactersQ[ Cell[ __, "MoreInfoText", ___ ] ] := False;
showStringCharactersQ[ ___ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeMarkdownCharactersQ*)
escapeMarkdownCharactersQ[ Cell[ __, "TextTableForm", ___ ] ] := False;
escapeMarkdownCharactersQ[ Cell[ _BoxData, ___ ] ] := False;
escapeMarkdownCharactersQ[ ___ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncateString*)
truncateString // beginDefinition;
truncateString[ str_String ] := truncateString[ str, $maxOutputCellStringLength ];
truncateString[ str_String, Automatic ] := truncateString[ str, $defaultMaxOutputCellStringLength ];
truncateString[ str_String, max: $$size ] := stringTrimMiddle[ str, max ];
truncateString[ other_ ] := other;
truncateString[ other_, _Integer ] := other;
truncateString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncateStackString*)
truncateStackString // SetFallthroughError;
truncateStackString[ str_String ] /; StringLength @ str <= 80 := str;
truncateStackString[ str_String ] := StringTake[ str, 80 ] <> "...";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeMarkdownString*)
escapeMarkdownString // SetFallthroughError;
escapeMarkdownString[ text_String ] := Block[ { $escapeMarkdown = True }, escapeMarkdownCharacters @ text ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeMarkdownCharacters*)
escapeMarkdownCharacters // SetFallthroughError;
escapeMarkdownCharacters[ text_ ] /; ! TrueQ @ $escapeMarkdown := text;
escapeMarkdownCharacters[ text_String ] := StringReplace[ text, $markdownReplacements ];
escapeMarkdownCharacters[ TextData[ text_ ] ] := escapeMarkdownCharacters @ text;
escapeMarkdownCharacters[ text_List ] := escapeMarkdownCharacters /@ text;
escapeMarkdownCharacters[ text_ ] := text;

$escapeMarkdown = False;

$markdownReplacements = Flatten[ { "\\" <> # -> "\\" <> #, # -> "\\" <> # } & /@ $escapedMarkdownCharacters ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*docSearchResultString*)
docSearchResultString // ClearAll;

docSearchResultString[ query_String ] /; $CurrentCell =!= True := "";

docSearchResultString[ query_String ] := Enclose[
    Module[ { search },
        search = ConfirmMatch[ documentationSearchAPI @ query, { __String } ];
        StringJoin[
            "BEGIN_SEARCH_RESULTS\n",
            StringRiffle[ search, "\n" ],
            "\nEND_SEARCH_RESULTS"
        ]
    ],
    $noDocSearchResultsString &
];


docSearchResultString[ other_ ] :=
    With[ { str = cellToString @ other }, documentationSearchAPI @ str /; StringQ @ str ];

docSearchResultString[ ___ ] := $noDocSearchResultsString;


documentationSearchAPI[ query_String ] /; $localDocSearch := documentationSearchAPI[ query ] =
    Module[ { result },
        Needs[ "DocumentationSearch`" -> None ];
        result = Association @ DocumentationSearch`SearchDocumentation[
            query,
            "MetaData" -> { "Title", "URI", "ShortenedSummary", "Score" },
            "Limit"    -> 5
        ];
        makeSearchResultString /@ Cases[
            result[ "Matches" ],
            { title_, uri_String, summary_, score_ } :>
                { title, "paclet:"<>StringTrim[ uri, "paclet:" ], summary, score }
        ]
    ];

documentationSearchAPI[ query_String ] := documentationSearchAPI[ query ] =
    Module[ { resp, flat, items, main },

        resp = URLExecute[
            "https://reference.wolframcloud.com/search-api/search.json",
            {
                "query"           -> query,
                "limit"           -> "5",
                "disableSpelling" -> "true",
                "fields"          -> "title,summary,url,label",
                "collection"      -> "blogs,demonstrations,documentation10,mathworld,resources,wa_products"
            },
            "RawJSON"
        ];

        flat = Take[
            ReverseSortBy[ Flatten @ Values @ KeyTake[ resp[ "results" ], resp[ "sortOrder" ] ], #score & ],
            UpTo[ 5 ]
        ];

        items = Select[ flat, #score > 1 & ];

        main = Replace[ resp[ "adResult" ], { as_Association :> makeSearchResultString @ as, _ :> Nothing } ];

        makeSearchResultString /@ Prepend[ items, main ]
    ];


makeSearchResultString // ClearAll;

makeSearchResultString[ { title_, uri_String, summary_, score_ } ] :=
    TemplateApply[
        "* [`1`](`2`) - (score: `4`) `3`",
        { title, uri, summary, score }
    ];


makeSearchResultString[ KeyValuePattern[ "ad" -> True ] ] := Nothing;

makeSearchResultString[ KeyValuePattern @ { "fields" -> fields_Association, "score" -> score_ } ] :=
    makeSearchResultString @ Replace[
        Append[ fields, "score" -> score ],
        { s_String, ___ } :> s,
        { 1 }
    ];


makeSearchResultString[ KeyValuePattern @ {
    "summary" -> summary_String,
    "title"   -> name_String,
    "label"   -> "Built-in Symbol"|"Entity Type"|"Featured Example"|"Guide"|"Import/Export Format"|"Tech Note",
    "uri"     -> uri_String,
    "score"   -> score_
} ] := TemplateApply[
    "* [`1`](`2`) - (score: `4`) `3`",
    { name, "paclet:"<>StringTrim[ uri, "paclet:" ], summary, score }
];

makeSearchResultString[ KeyValuePattern @ {
    "summary" -> summary_String,
    "title"   -> name_String,
    "url"     -> url_String,
    "score"   -> score_
} ] := TemplateApply[ "* [`1`](`2`) - (score: `4`) `3`", { name, url, summary, score } ];


makeSearchResultString[ as_ ] := ToString[ as, InputForm ];

$noDocSearchResultsString = "BEGIN_DOCUMENTATION_SEARCH_RESULTS\n(no results found)\nEND_DOCUMENTATION_SEARCH_RESULTS";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Documentation Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDocumentationString*)
makeDocumentationString // SetFallthroughError;

makeDocumentationString[ file_? FileExistsQ ] := makeDocumentationString[ file ] =
    Module[ { nb, string },
        nb = Import[ file, "NB" ];

        string = TemplateApply[
            "`Usage`\n\n`Details`\n\n`Examples`\n\n`Metadata`",
            <|
                "Usage"    -> getUsageString @ nb,
                "Details"  -> getDetailsString @ nb,
                "Examples" -> getExamplesString @ nb,
                "Metadata" -> getMetadataString @ nb
            |>
        ];

        StringDelete[ StringReplace[ StringTrim @ string, "\n\n\n\n" -> "\n\n" ], "```"~~"\n"..~~"```" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getUsageString*)
getUsageString // SetFallthroughError;

getUsageString[ nb_Notebook ] := makeUsageString @ cellCases[
    firstMatchingCellGroup[ nb, Cell[ __, "ObjectNameGrid", ___ ], All ],
    Cell[ __, "ObjectNameGrid"|"Usage", ___ ]
];


makeUsageString // SetFallthroughError;

makeUsageString[ usage_List ] := StringRiffle[ Flatten[ makeUsageString /@ usage ], "\n" ];

makeUsageString[ Cell[ BoxData[ GridBox[ grid_List, ___ ], ___ ], "Usage", ___ ] ] := makeUsageString0 /@ grid;

makeUsageString[ Cell[ BoxData[ GridBox[ { { cell_, _ } }, ___ ], ___ ], "ObjectNameGrid", ___ ] ] :=
    "# " <> cellToString @ cell <> "\n";

makeUsageString0 // SetFallthroughError;
makeUsageString0[ list_List ] := StringTrim @ StringReplace[ StringRiffle[ cellToString /@ list ], Whitespace :> " " ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getDetailsString*)
getDetailsString // SetFallthroughError;

getDetailsString[ nb_Notebook ] :=
    Module[ { notes },
        notes = cellToString /@ cellFlatten @ firstMatchingCellGroup[ nb, Cell[ __, "NotesSection", ___ ] ];
        If[ MatchQ[ notes, { __String } ],
            "## Notes\n\n" <> StringRiffle[ notes, "\n" ],
            ""
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getExamplesString*)
getExamplesString // SetFallthroughError;

getExamplesString[ nb_Notebook ] :=
    Module[ { cells, examples },
        cells    = cellFlatten @ firstMatchingCellGroup[ nb, Cell[ __, "PrimaryExamplesSection", ___ ] ];
        examples = Block[ { $maxOutputCellStringLength = 100 }, cellToString /@ cells ];
        If[ MatchQ[ examples, { __String } ],
            "## Examples\n\n" <> StringRiffle[ examples, "\n" ],
            ""
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getMetadataString*)
getMetadataString // SetFallthroughError;

getMetadataString[ Notebook[ ___, TaggingRules -> tags_, ___ ] ] :=
    getMetadataString @ tags;

getMetadataString[ KeyValuePattern[ "Metadata" -> md: KeyValuePattern @ { } ] ] :=
    formatMetadata @ KeyTake[ md, { "keywords", "specialkeywords", "summary", "synonyms", "tabletags", "title" } ];

getMetadataString[ ___ ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*formatMetadata*)
formatMetadata // SetFallthroughError;

formatMetadata[ as_Association ] :=
    "## Metadata\n\n" <> StringRiffle[ KeyValueMap[ formatMetadata, as ], "\n\n" ];

formatMetadata[ key_String, values: { __String } ] :=
    "### " <> key <> "\n\n" <> StringRiffle[ ("* " <> #1 &) /@ values, "\n" ];

formatMetadata[ _, { } ] :=
    Nothing;

formatMetadata[ key_String, value_String ] :=
    "### "<>key<>"\n\n"<>value;

formatMetadata[ ___ ] :=
    Nothing;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*codeBlockQ*)
codeBlockQ // beginDefinition;
codeBlockQ[ Cell[ __, $$noCodeBlockStyle, ___ ] ] := False;
codeBlockQ[ Cell[ __, "Program", ___ ] ] := True;
codeBlockQ[ Cell[ __, CellTags -> { ___, "CheckboxCell", ___ }, ___ ] ] := False;
codeBlockQ[ Cell[ BoxData[ _GridBox, ___ ], ___ ] ] := False;
codeBlockQ[ Cell[ BoxData[ GraphicsBox[ TagBox[ _RasterBox, ___ ], ___ ], ___ ], "Input", ___ ] ] := False;
codeBlockQ[ Cell[ _BoxData, ___ ] ] := True;
codeBlockQ[ Cell[ _TextData, ___ ] ] := False;
codeBlockQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellMap*)
cellMap // SetFallthroughError;
cellMap[ f_, cells_List ] := (cellMap[ f, #1 ] &) /@ cells;
cellMap[ f_, Cell[ CellGroupData[ cells_, a___ ], b___ ] ] := Cell[ CellGroupData[ cellMap[ f, cells ], a ], b ];
cellMap[ f_, cell_Cell ] := f @ cell;
cellMap[ f_, Notebook[ cells_, opts___ ] ] := Notebook[ cellMap[ f, cells ], opts ];
cellMap[ f_, other_ ] := other;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellGroupMap*)
cellGroupMap // SetFallthroughError;
cellGroupMap[ f_, Notebook[ cells_, opts___ ] ] := Notebook[ cellGroupMap[ f, cells ], opts ];
cellGroupMap[ f_, cells_List ] := Map[ cellGroupMap[ f, # ] &, cells ];
cellGroupMap[ f_, Cell[ group_CellGroupData, a___ ] ] := Cell[ cellGroupMap[ f, f @ group ], a ];
cellGroupMap[ f_, other_ ] := other;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellScan*)
cellScan // SetFallthroughError;
cellScan[ f_, Notebook[ cells_, opts___ ] ] := cellScan[ f, cells ];
cellScan[ f_, cells_List ] := Scan[ cellScan[ f, # ] &, cells ];
cellScan[ f_, Cell[ CellGroupData[ cells_, _ ], ___ ] ] := cellScan[ f, cells ];
cellScan[ f_, cell_Cell ] := (f @ cell; Null);
cellScan[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellGroupScan*)
cellGroupScan // SetFallthroughError;
cellGroupScan[ f_, (Notebook|CellGroupData)[ cells_, ___ ] ] := cellGroupScan[ f, cells ];
cellGroupScan[ f_, cells_List ] := Scan[ cellGroupScan[ f, # ] &, cells ];
cellGroupScan[ f_, Cell[ group_CellGroupData, ___ ] ] := (f @ group; cellGroupScan[ f, group ]);
cellGroupScan[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellCases*)
cellCases // SetFallthroughError;
cellCases[ cells_, patt_ ] := Cases[ cellFlatten @ cells, patt ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellFlatten*)
cellFlatten // SetFallthroughError;

cellFlatten[ cells_ ] :=
    Module[ { bag },
        bag = Internal`Bag[ ];
        cellScan[ Internal`StuffBag[ bag, # ] &, cells ];
        Internal`BagPart[ bag, All ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*firstMatchingCellGroup*)
firstMatchingCellGroup // SetFallthroughError;

firstMatchingCellGroup[ nb_, patt_ ] := firstMatchingCellGroup[ nb, patt, "Content" ];

firstMatchingCellGroup[ nb_, patt_, All ] := Catch[
    cellGroupScan[
        Replace[ CellGroupData[ { header: patt, content___ }, _ ] :> Throw[ { header, content }, $cellGroupTag ] ],
        nb
    ];
    Missing[ "NotFound" ],
    $cellGroupTag
];

firstMatchingCellGroup[ nb_, patt_, "Content" ] := Catch[
    cellGroupScan[
        Replace[ CellGroupData[ { patt, content___ }, _ ] :> Throw[ { content }, $cellGroupTag ] ],
        nb
    ];
    Missing[ "NotFound" ],
    $cellGroupTag
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    Null;
];

End[ ];
EndPackage[ ];
