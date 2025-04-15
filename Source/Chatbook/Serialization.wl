BeginPackage[ "Wolfram`Chatbook`Serialization`" ];

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[ CellToString, "\
CellToString[cell$] serializes a Cell expression as a string for use in chat.\
" ];

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config*)
$$delimiterStyle = Alternatives[
    "Delimiter",
    "ExampleDelimiter",
    "GuideDelimiter",
    "GuideDelimiterSubsection",
    "GuideMoreAboutDelimiter",
    "HistoryDelimiter",
    "HowToDelimiter",
    "KeyEventDelimiter",
    "MarkdownDelimiter",
    "MenuNameDelimiter",
    "PageBreak",
    "PageDelimiter",
    "PointerEventDelimiter",
    "RootMoreAboutDelimiter",
    "WeakDivider",
    "WorkflowDelimiter",
    "WorkflowFooterBottomDelimiter",
    "WorkflowFooterDelimiter",
    "WorkflowFooterTopDelimiter",
    "WorkflowGuideDelimiter",
    "WorkflowHeaderDelimiter",
    "WorkflowPlatformDelimiter"
];

$$itemStyle = "Item"|"Notes"|"FeaturedExampleMoreAbout"|"InterpreterNotes"|"BulletedText"|"MonographBulletedText";

$$subItemStyle     = "Subitem";
$$subSubItemStyle  = "Subsubitem";
$$docSearchStyle   = "ChatQuery";
$$outputStyle      = "Output"|"Print"|"Echo";
$$noCellLabelStyle = Alternatives[
    "ChatBlockDivider",
    "ChatInput",
    "ChatSystemInput",
    "Message",
    "Section",
    "SideChat",
    "Subsection",
    "Subsubsection",
    "Subsubsubsection",
    "Subsubsubsubsection",
    "Text",
    "Title",
    "Subtitle",
    $$delimiterStyle
];

$$ignoredCellStyle = Alternatives[
    "AnchorBarGrid",
    "CitationContainerCell",
    "DiscardedMaterial"
];

(* Cell styles that will prevent wrapping BoxData in triple backticks: *)
$$noCodeBlockStyle = Alternatives[
    "ChatInput",
    "ChatOutput",
    "DisplayFormula",
    "DisplayFormulaNumbered",
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

(* Maximum number of bytes to include in multimodal messages per cell before switching to a fully rasterized cell: *)
$maxMarkdownImageCellBytes = 10000000;

(* Maximum number of bytes for a single box to be rasterized: *)
$maxBoxSizeForImages = 1000000;

(* Whether to generate a transcript and preview images for Video[...] expressions: *)
$generateVideoPrompt = False;

(* Whether to collect data that can help discover missing definitions *)
$CellToStringDebug = False;

(* Can be redefined locally depending on cell style *)
$showStringCharacters = True;
$inlineCode           = False;

(* Replacement rules that are applied to the cell before serialization: *)
$conversionRules = None;

(* Add spacing around these operators *)
$$spacedInfixOperator = Alternatives[
    "^", "*", "+", "-", "=", "|", "<", ">", "?", "/", ":", "!=", "@*", "^=", "&&", "*=", "-=", "->", "+=", "==", "~~",
    "||", "<=", "<>", ">=", ";;", "/@", "/*", "/=", "/.", "/;", ":=", ":>", "^:=", "=!=", "===", "|->", "<->",
    "//@", "//.", "\[Equal]", "\[GreaterEqual]", "\[LessEqual]", "\[NotEqual]", "\[Function]", "\[Rule]",
    "\[RuleDelayed]", "\[TwoWayRule]"
];

$$unspacedPrefixOperator = Alternatives[
    "-", "+", "--", "++"
];

$delimiterString = "\n\n---\n\n";

(* Characters that should be serialized as long-form representations: *)
$longNameCharacterNames = {
    "AltKey",
    "CommandKey",
    "ControlKey",
    "DeleteKey",
    "EnterKey",
    "EscapeKey",
    "OptionKey",
    "ReturnKey",
    "SpaceKey",
    "SystemEnterKey",
    "TabKey"
};

$longNameCharacterList = ToExpression[ "\"\\[" <> # <> "]\"" & /@ $longNameCharacterNames ];

$longNameCharacters = Thread[ $longNameCharacterList -> ("\\["<>#<>"]" &) /@ $longNameCharacterNames ];
$$longNameCharacter = Alternatives @@ $longNameCharacterList;

$$invisibleCharacter = Alternatives[
    FromCharacterCode[ 8203 ], (* U+200B Zero Width Space *)
    FromCharacterCode[ 62304 ], (* InvisibleSpace *)
    "\[SpanFromLeft]",
    "\[SpanFromAbove]",
    "\[SpanFromBoth]"
];

(* Characters that should be automatically escaped when they appear in plain text to be valid markdown: *)
$escapedMarkdownCharacters = { "`", "$", "*", "_", "#", "|" };

(* Not included for implementation reasons:
    [] () {} + - . !
*)

(* $leftSelectionIndicator  = "\\["<>"BeginSelection"<>"]";
$rightSelectionIndicator = "\\["<>"EndSelection"<>"]"; *)

$leftSelectionIndicator  = "<selection>";
$rightSelectionIndicator = "</selection>";

(* Determines if serialized cell content should be wrapped in <cell id=xxxx>...</cell> *)
$includeCellXML    = False;
$xmlCellAttributes = { "id" };

(* Whether to include a stack trace for message cells *)
$includeStackTrace = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Conversion Rules*)

(* Rules to convert some 2D boxes into an infix form *)
$boxOp = <| SuperscriptBox -> "^", SubscriptBox -> "_" |>;

(* How to choose TemplateBox arguments for serialization *)
$templateBoxRules = <|
    "AssistantMessageBox"          -> First,
    "ConditionalExpression"        -> makeExpressionString,
    "GrayLink"                     -> First,
    "HyperlinkDefault"             -> First,
    "Key0"                         -> First,
    "Key1"                         -> (Riffle[ #, "-" ] &),
    "RowDefault"                   -> Identity,
    "TransferFunctionModelFull"    -> makeExpressionString,
    "UserMessageBox"               -> First,
    "CMYKColorSwatchTemplate"      -> inputFormString @* Lookup[ "color" ],
    "GrayLevelColorSwatchTemplate" -> inputFormString @* Lookup[ "color" ],
    "HueColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "LABColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "LCHColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "LUVColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "RGBColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "XYZColorSwatchTemplate"       -> inputFormString @* Lookup[ "color" ],
    "PlatformDynamic"              -> First,
    "URLArgument"                  -> First
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

$$ignoredImportImage = Alternatives[
    FrontEnd`FileName[ { "Documentation", "FooterIcons" }, _ ]
];

$$graphicsBox = With[ { ignored = $$ignoredImportImage },
    Alternatives[
        $graphicsHeads[ ___ ],
        TemplateBox[ _, "Legended", ___ ],
        DynamicBox[ FEPrivate`ImportImage @ Except @ ignored, ___ ],
        DynamicBox[ _Charting`iInteractiveTradingChart, ___ ]
    ]
];

(* Serialize the first argument of these and ignore the rest *)
$stringStripHeads = Alternatives[
    ActionMenuBox,
    AdjustmentBox,
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
$$squarePlusIcon = (FEPrivate`FrontEndResource|FrontEndResource)[
    "FEBitmaps",
    "SquarePlusIconSmall"|"SquarePlusIconMedium"
];

$$ifWhich = (If | Which | FEPrivate`If | FEPrivate`Which);

$ignoredBoxPatterns = With[ { icon = $$squarePlusIcon, iw = $$ifWhich, ignored = $$ignoredImportImage },
    Alternatives[
        _PaneSelectorBox,
        StyleBox[ _GraphicsBox, ___, "NewInGraphic", ___ ],
        DynamicBox[ iw[ ___, icon | StyleBox[ icon, ___ ], ___ ], ___ ],
        DynamicBox[ FEPrivate`ImportImage @ ignored, ___ ]
    ]
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

$$controlBox = HoldPattern @ Alternatives[
    AnimatorBox,
    CheckboxBox,
    ColorSetterBox,
    InputFieldBox,
    ListPickerBox,
    LocatorPaneBox,
    OpenerBox,
    PopupMenuBox,
    RadioButtonBox,
    SetterBox,
    Slider2DBox,
    SliderBox,
    TableViewBox,
    TogglerBox
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
<message_stack_trace>
%%StackTrace%%
</message_stack_trace>
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
CellToString // beginDefinition;

CellToString // Options = {
    "CharacterEncoding"         -> $cellCharacterEncoding,
    "CharacterNormalization"    -> "NFKC", (* FIXME: do this *)
    "ContentTypes"              -> Automatic,
    "ConversionRules"           :> $conversionRules,
    "CurrentSelection"          -> None, (* TODO *)
    "Debug"                     :> $CellToStringDebug,
    "MaxCellStringLength"       -> $maxCellStringLength,
    "MaxOutputCellStringLength" -> $maxOutputCellStringLength,
    "PageWidth"                 -> $cellPageWidth,
    "UnhandledBoxFunction"      -> None,
    "WindowWidth"               -> $windowWidth,
    "IncludeStackTrace"         :> $includeStackTrace,
    "IncludeXML"                :> $includeCellXML,
    "XMLCellAttributes"         :> $xmlCellAttributes
};

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
CellToString[ cell_, opts: OptionsPattern[ ] ] :=
    catchMine @ Catch @ Block[
        {
            $cellCharacterEncoding = OptionValue[ "CharacterEncoding" ],
            $CellToStringDebug = TrueQ @ OptionValue[ "Debug" ],
            $unhandledBoxFunction = OptionValue[ "UnhandledBoxFunction" ],
            $includeCellXML = TrueQ @ OptionValue[ "IncludeXML" ],
            $includeStackTrace = TrueQ @ OptionValue[ "IncludeStackTrace" ],
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
                cellToString @ applyConversionRules[ cell, OptionValue[ "ConversionRules" ] ],
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

CellToString // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyConversionRules*)
applyConversionRules // beginDefinition;
applyConversionRules[ cell_, rules_ ] := applyConversionRules[ cell, rules, makeConversionRules @ rules ];
applyConversionRules[ cell_, rules_, None | { } ] := cell;
applyConversionRules[ cell_, rules_, dispatch_Dispatch? DispatchQ ] := ReplaceRepeated[ cell, dispatch ];
applyConversionRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeConversionRules*)
makeConversionRules // beginDefinition;
makeConversionRules[ None | { } ] := None;
makeConversionRules[ rules_ ] := makeConversionRules[ rules, Quiet @ Dispatch @ rules ];
makeConversionRules[ rules_, dispatch_Dispatch? DispatchQ ] := makeConversionRules[ rules ] = dispatch;
makeConversionRules[ rules_, other_ ] := (messagePrint[ "InvalidConversionRules", rules ]; None);
makeConversionRules // endDefinition;

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
cellToString[ cell_CellObject ] := cellToString @ notebookRead @ cell;

(* Multiple cells to one string *)
cellToString[ Notebook[ cells_List, ___ ] ] := cellsToString @ cells;
cellToString[ Cell @ CellGroupData[ cells_List, _ ] ] := cellsToString @ cells;
cellToString[ nbo_NotebookObject ] := cellToString @ Cells @ nbo;
cellToString[ cells: { __CellObject } ] := cellsToString @ notebookRead @ cells;

(* Wrap serialized cell in xml tags for the notebook editor tool: *)
cellToString[ cell_Cell? xmlCellQ ] :=
    cellToXMLString @ cell;

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

(* Workflow cells: *)
cellToString[ Cell[ BoxData[ TemplateBox[ { name_String, content_ }, "FileListing", ___ ], ___ ], ___ ] ] :=
    name <> "\n```\n" <> fasterCellToString @ content <> "\n```";

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

(* Add a cell label for Echo cells *)
cellToString[ Cell[ a__, "Echo", b___ ] ] :=
    cellToString @ Cell[ a, b, CellLabel -> ">>" ];

cellToString[ Cell[ a__, "EchoTiming", b___ ] ] :=
    cellToString @ Cell[ a, b, CellLabel -> "\:231A" ];

cellToString[ Cell[
    a__,
    "EchoBefore"|"EchoAfter",
    b___,
    CellDingbat -> Cell @ BoxData @ TemplateBox[
        { StyleBox[ dingbat_, "EchoBeforeDingbat"|"EchoAfterDingbat", ___ ], ___ },
        "HyperlinkDefault",
        ___
    ],
    c___
] ] := cellToString @ Cell[
    a, b, c,
    CellLabel -> StringReplace[
        fasterCellToString @ dingbat,
        { "\[RightGuillemet]" -> ">>", "\[LeftGuillemet]" -> "<<" }
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
cellToString[ Cell[ RawData[ str_String ], ___ ] ] :=
    Catch @ Module[ { held },
        If[ ! TrueQ @ $WorkspaceChat, needsBasePrompt[ "Notebooks" ]; Throw @ str ];
        held = Quiet @ ToExpression[ str, InputForm, HoldComplete ];
        If[ MatchQ[ held, HoldComplete[ _Cell ] ],
            cellToString @@ held,
            needsBasePrompt[ "Notebooks" ]; str
        ]
    ];

(* Raw output form: *)
cellToString[ Cell[ OutputFormData[ output_String, ___ ], ___ ] ] :=
    output;

(* StyleData cells: *)
cellToString[ cell: Cell[ _StyleData, ___ ] ] :=
    inputFormString @ cell;

(* Include a stack trace for message cells when available *)
cellToString[ Cell[ a__, "Message"|"MSG", b___ ] ] :=
    Module[ { string, stacks, stack, stackString },
        { string, stacks } = Reap[ cellToString0 @ Cell[ a, b ], $messageStack ];
        stack = First[ First[ stacks, $Failed ], $Failed ];
        If[ MatchQ[ stack, { __HoldForm } ] && Length @ stack >= 3
            ,
            stackString = StringRiffle[ Cases[ stack, HoldForm[ expr_ ] :> stackFrameString @ expr ], "\n" ];
            needsBasePrompt[ "MessageStackTrace" ];
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
    Block[ { $escapeMarkdown = False },
        needsBasePrompt[ "ExternalLanguageCells" ];
        "```" <> lang <> "\n" <> cellToString0 @ code <> "\n```"
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
cellToString[ cell: Cell[ _, Except[ "Input"|"Code"|$$chatInputStyle|$$chatOutputStyle ], ___ ] ] /;
    rasterWholeCellQ @ cell :=
        MakeExpressionURI[ "cell image", RawBoxes @ StyleBox[ cell, "GraphicsRawBoxes" ] ];

cellToString[ cell: Cell[ _, "Picture", ___ ] ] /; $multimodalImages :=
        MakeExpressionURI[ "cell image", RawBoxes @ StyleBox[ cell, "GraphicsRawBoxes" ] ];

cellToString[ other_ ] :=
    cellToString0 @ other;

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
            StringReplace[
                StringRiffle[ Select[ strings, StringQ ], "\n\n" ],
                {
                    "```wl"~~WhitespaceCharacter...~~"```" -> "",
                    "```\n\n```wl" -> "",
                    "```\n\n```" -> ""
                }
            ],
            "\n\n" ~~ Longest[ "\n".. ] -> "\n\n"
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*rasterWholeCellQ*)
rasterWholeCellQ // beginDefinition;

rasterWholeCellQ[ cell_Cell ] := Enclose[
    Module[ { maxBoxCount, boxes, count },
        maxBoxCount = ConfirmMatch[ $maxMarkdownBoxes, _Integer? Positive, "MaxMarkdownBoxes" ];
        boxes = Cases[ cell, $$graphicsBox, Infinity ];
        count = Length @ boxes;
        Which[
            count > maxBoxCount, True,
            count > 0 && ByteCount @ boxes > $maxMarkdownImageCellBytes, True,
            True, False
        ]
    ],
    throwInternalFailure
];

rasterWholeCellQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*xmlCellQ*)
xmlCellQ // beginDefinition;
xmlCellQ[ Cell[ __, $$chatInputStyle|$$chatOutputStyle, ___ ] ] := False;
xmlCellQ[ _Cell ] := TrueQ @ $includeCellXML;
xmlCellQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellToXMLString*)
cellToXMLString // beginDefinition;

cellToXMLString[ cell_Cell ] := Enclose[
    Catch @ Module[ { string, attributes, attributeString },
        string = ConfirmBy[ Block[ { $includeCellXML = False }, cellToString @ cell ], StringQ, "String" ];
        attributes = ConfirmBy[ cellXMLAttributes @ cell, AssociationQ, "XMLAttributes" ];
        attributeString = StringTrim @ StringRiffle @ KeyValueMap[ StringJoin[ #1, "='", #2, "'" ] &, attributes ];
        If[ StringLength @ attributeString > 0, attributeString = " " <> attributeString ];
        StringJoin[
            "<cell", attributeString, ">\n",
            string,
            "\n</cell>"
        ]
    ],
    throwInternalFailure
];

cellToXMLString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellXMLAttributes*)
cellXMLAttributes // beginDefinition;

cellXMLAttributes[ cell_Cell ] := DeleteMissing @ AssociationMap[
    Apply @ Rule,
    KeyTake[
        <|
            "id"    :> xmlCellID @ cell,
            "style" :> xmlCellStyle @ cell,
            "label" :> xmlCellLabel @ cell
        |>,
        $xmlCellAttributes
    ]
];

cellXMLAttributes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*xmlCellID*)
xmlCellID // beginDefinition;
xmlCellID[ Cell[ __, CellObject -> cell_CellObject, ___ ] ] := cellReference @ cell;
xmlCellID[ _Cell ] := Missing[ ];
xmlCellID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*xmlCellStyle*)
xmlCellStyle // beginDefinition;
xmlCellStyle[ Cell[ _, style__String, OptionsPattern[ ] ] ] := { style };
xmlCellStyle[ _Cell ] := Missing[ ];
xmlCellStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*xmlCellLabel*)
xmlCellLabel // beginDefinition;
xmlCellLabel[ Cell[ __, CellLabel -> label_String, ___ ] ] := label;
xmlCellLabel[ _Cell ] := Missing[ ];
xmlCellLabel // endDefinition;

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
    "\[LeftDoubleBracket]"         -> "[[",
    "\[RightDoubleBracket]"        -> "]]",
    "\n\n" ~~ Longest[ "\n".. ]    -> "\n\n",
    "```\n```"                     -> "```\n\n```",
    "\n\n\t\n"                     -> "\n",
    "``$$" ~~ math__ ~~ "$$``"     :> "$$"<>math<>"$$",
    Shortest[ "$$" ~~ a__ ~~ "$$$$" ~~ b__ ~~ "$$" ] :> "$$"<>a<>" "<>b<>"$$",
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
    "Subtitle",
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

fasterCellToString0[ Cell[ BoxData @ PaneBox[ StyleBox[ box_, style_String, ___ ], ___ ], "InlineSection", ___ ] ] :=
    Block[ { $showStringCharacters = False, $escapeMarkdown = False },
        StringJoin[
            "\n",
            fasterCellToString0 @ Cell[ fasterCellToString0 @ box, style ],
            "\n"
        ]
    ];

fasterCellToString0[ Cell[ __, $$delimiterStyle, ___ ] ] := $delimiterString;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Styles*)
fasterCellToString0[ (h: Cell|StyleBox)[ a__, FontWeight -> Bold|"Bold", b___ ] ] :=
    "**" <> fasterCellToString0 @ h[ a, b ] <> "**";

fasterCellToString0[ (h: Cell|StyleBox)[ a__, FontSlant -> Italic|"Italic", b___ ] ] :=
    "*" <> fasterCellToString0 @ h[ a, b ] <> "*";

fasterCellToString0[ (h: Cell|StyleBox)[ a__, FontVariations -> { b___, "StrikeThrough" -> True, c___ }, d___ ] ] :=
    "~~" <> fasterCellToString0 @ h[ a, FontVariations -> { b, c }, d ] <> "~~";

fasterCellToString0[ (h: Cell|StyleBox)[ a__, ShowStringCharacters -> b: True|False, c___ ] ] :=
    Block[ { $showStringCharacters = b }, fasterCellToString0 @ h[ a, c ] ];

fasterCellToString0[ (box_)[ a__, BaseStyle -> { b___, ShowStringCharacters -> c: True|False, d___ }, e___ ] ] :=
    Block[ { $showStringCharacters = c }, fasterCellToString0 @ box[ a, BaseStyle -> { b, d }, e ] ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*String Normalization*)

(* Conversion Rules can specify Verbatim["..."] to prevent any further processing on strings: *)
fasterCellToString0[ Verbatim[ Verbatim ][ string_String? StringQ ] ] := string;

(* Separate definition for comments, since we don't want to add spacing around operators, etc: *)
fasterCellToString0[ boxes: RowBox @ { "(*", ___, "*)" } ] :=
    With[ { flat = Flatten[ boxes //. RowBox[ a___ ] :> a ] },
        StringReplace[ StringJoin @ flat, FromCharacterCode[ 62371 ] -> "\n" ] /; MatchQ[ flat, { ___String } ]
    ];

(* Add spacing between RowBox elements that are comma separated *)
fasterCellToString0[ "," ] := ", ";
fasterCellToString0[ RowBox[ { op: $$unspacedPrefixOperator, a_ } ] ] := op<>fasterCellToString0 @ a;
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
fasterCellToString0[ s_String ] /;
    StringLength @ s < $maxStandardFormStringLength && StringContainsQ[ s, "\!\(" ~~ __ ~~ "\)" ] :=
        serializeStandardFormString @ s;

fasterCellToString0[ a_String ] /;
    StringLength @ a < $maxStandardFormStringLength && StringMatchQ[ a, "\""~~___~~("\\!"|"\!")~~___~~"\"" ] :=
        With[ { res = ToString @ ToExpression[ a, InputForm ] },
            If[ TrueQ @ $showStringCharacters,
                res,
                StringReplace[ StringTrim[ res, "\"" ], { "\\\"" -> "\"" } ]
            ] /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ]
        ];

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
(* ::Subsubsubsubsection::Closed:: *)
(*serializeStandardFormString*)
serializeStandardFormString // beginDefinition;

serializeStandardFormString[ str_String ] := Enclose[
    Catch @ Module[ { split, strings, result },
        split = StringSplit[
            str,
            {
                Shortest[ "\!\(\*" ~~ boxes__ ~~ "\)" ] :> fromBoxString @ boxes,
                Shortest[ "\!\(" ~~ raw__ ~~ "\)" ] :> StringReplace[ raw, { "\/" -> "/", "\^" -> "^" } ]
            }
        ];
        If[ MatchQ[ split, { str } ], serializeStandardFormString[ str ] = Throw @ str ];
        strings = ConfirmMatch[ fasterCellToString0 /@ split, { ___String }, "Strings" ];
        result = StringJoin @ strings;
        serializeStandardFormString[ str ] = result
    ],
    throwInternalFailure
];

serializeStandardFormString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*fromBoxString*)
fromBoxString // beginDefinition;
fromBoxString[ str_String ] := fromBoxString[ str, Quiet @ ToExpression[ str, InputForm, HoldComplete ] ];
fromBoxString[ _, HoldComplete[ expr_ ] ] := expr;
fromBoxString[ str_String, _ ] := Verbatim @ ToString[ "\!\(\*" <> str <> "\)" ];
fromBoxString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Current Selection*)
fasterCellToString0[ (Cell|StyleBox|TagBox)[ boxes_, "CurrentSelection", ___ ] ] :=
    StringJoin[ $leftSelectionIndicator, fasterCellToString0 @ boxes, $rightSelectionIndicator ];

(* TODO: Determine selection position from "CurrentSelection" option value *)

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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* Control equals input *)
fasterCellToString0[ NamespaceBox[
    "LinguisticAssistant",
    DynamicModuleBox[ { ___, Typeset`query$$|WolframAlphaClient`Private`query$$ = query_String, ___ }, __ ],
    ___
] ] := "\[FreeformPrompt][\""<>query<>"\"]";
(* :!CodeAnalysis::EndBlock:: *)

(* FreeformEvaluate *)
fasterCellToString0[ RowBox @ { "=[", query_String, "]" } ] := "\[FreeformPrompt]["<>query<>"]";

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

fasterCellToString0[ System`LabeledGraphicsBox[ gfx_, label_, ___ ] ] :=
    "Labeled[" <> fasterCellToString0 @ gfx <> ", " <> fasterCellToString0 @ label <> "]";

$graphicsBoxStringReplacements = {
    a: DigitCharacter ~~ "." ~~ b: Repeated[ DigitCharacter, { 4, Infinity } ] :> a <> "." <> StringTake[ b, 3 ],
    "\"$$DATA$$\"" -> "...",
    "$$DATA$$" -> "..."
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*toMarkdownImageBox*)
toMarkdownImageBox // beginDefinition;

toMarkdownImageBox[ box: GraphicsBox[ TagBox[ _RasterBox, ___ ], ___ ] ] :=
    toMarkdownImageBox0 @ box;

toMarkdownImageBox[ graphics_ ] /; $multimodalImages && ByteCount @ graphics > $maxBoxSizeForImages :=
    Block[ { $multimodalImages = False },
        fasterCellToString0 @ graphics
    ];

toMarkdownImageBox[ graphics_ ] :=
    toMarkdownImageBox0 @ graphics;

toMarkdownImageBox // endDefinition;


toMarkdownImageBox0 // beginDefinition;

toMarkdownImageBox0[ graphics_ ] := Enclose[
    Catch @ Module[ { uri },
        uri = ConfirmBy[ boxesToExpressionURI @ graphics, StringQ, "RasterID" ];
        needsBasePrompt[ "MarkdownImageBox" ];
        If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "MarkdownImageBoxImporting" ] ];
        "\\!\\(\\*MarkdownImageBox[\"" <> uri <> "\"]\\)"
    ],
    throwInternalFailure
];

toMarkdownImageBox0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*boxesToExpressionURI*)
boxesToExpressionURI // beginDefinition;

boxesToExpressionURI[ RawBoxes[ boxes_ ] ] :=
    boxesToExpressionURI @ boxes;

boxesToExpressionURI[ boxes_ ] :=
    Replace[
        Quiet @ ToExpression[ boxes, StandardForm, HoldComplete ],
        {
            HoldComplete[ expr_ ] /; graphicsQ @ Unevaluated @ expr :> (
                (* Ensure that the expression is recognized as a graphics expression later: *)
                cacheBoxRaster[ boxes, expr ];
                MakeExpressionURI @ Unevaluated @ expr
            ),
            _ :> MakeExpressionURI[ "image", RawBoxes @ StyleBox[ boxes, "GraphicsRawBoxes" ] ]
        }
    ];

boxesToExpressionURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*cacheBoxRaster*)
cacheBoxRaster // beginDefinition;

cacheBoxRaster[ boxes_, expr_ ] /; $useRasterCache && $countImageTokens :=
    Catch @ Module[ { hash, img },
        hash = rasterHash @ expr;
        img = Lookup[ $rasterCache, hash, None ];
        If[ img =!= None, Throw @ img ];
        img = Block[ { $useRasterCache = False }, rasterize @ RawBoxes @ boxes ];
        $rasterCache[ hash ] = img;
        img
    ];

cacheBoxRaster[ boxes_, expr_ ] :=
    Null;

cacheBoxRaster // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*rasterizeGraphics*)
rasterizeGraphics // beginDefinition;

rasterizeGraphics[ gfx: $$graphicsBox ] :=
    If[ TrueQ @ $ChatNotebookEvaluation,
        rasterizeGraphics[ Verbatim[ gfx ] ] = checkedRasterize @ RawBoxes @ gfx,
        checkedRasterize @ RawBoxes @ gfx
    ];

rasterizeGraphics[ cell_Cell ] :=
    rasterizeGraphics[ cell, 6.25*$cellPageWidth ];

rasterizeGraphics[ cell_Cell, width_Real ] :=
    If[ TrueQ @ $ChatNotebookEvaluation,
        rasterizeGraphics[ Verbatim[ cell ], width ] = checkedRasterize @ Append[ cell, PageWidth -> width ],
        checkedRasterize @ Append[ cell, PageWidth -> width ]
    ];

rasterizeGraphics // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Video*)
fasterCellToString0[ box: TemplateBox[ _, "VideoBox1"|"VideoBox2", ___ ] ] /;
    $multimodalImages && $generateVideoPrompt :=
        generateVideoPrompt @ box;

fasterCellToString0[ box: TemplateBox[ _, "VideoBox1"|"VideoBox2", ___ ] ] :=
    serializeVideo @ box;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*generateVideoPrompt*)
generateVideoPrompt // beginDefinition;

generateVideoPrompt[ box: TemplateBox[ _, "VideoBox1"|"VideoBox2", ___ ] ] := generateVideoPrompt[ box ] =
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

serializeVideo[ box: TemplateBox[ _, "VideoBox1"|"VideoBox2", ___ ] ] := serializeVideo[ box ] =
    serializeVideo[ box, Quiet @ ToExpression[ box, StandardForm ] ];

serializeVideo[ box_, video_ ] := Enclose[
    If[ VideoQ @ video,
        If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "VideoBoxImporting" ] ];
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
fasterCellToString0[ box: TemplateBox[ _, "AudioBox1", ___ ] ] := serializeAudio @ box;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serializeAudio*)
serializeAudio // beginDefinition;

serializeAudio[ box_ ] := serializeAudio[ box ] =
    serializeAudio[ box, Quiet @ ToExpression[ box, StandardForm ] ];

serializeAudio[ box_, audio_ ] := Enclose[
    If[ AudioQ @ audio,
        If[ toolSelectedQ[ "WolframLanguageEvaluator" ], needsBasePrompt[ "AudioBoxImporting" ] ];
        "\\!\\(\\*AudioBox[\"" <> ConfirmBy[ MakeExpressionURI @ audio, StringQ, "URI" ] <> "\"]\\)",
        "\\!\\(\\*AudioBox[...]\\)"
    ],
    throwInternalFailure
];

serializeAudio // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Block quotes*)
fasterCellToString0[ Cell[ boxes_, "BlockQuote", ___ ] ] :=
    With[ { string = fasterCellToString0 @ boxes },
        ("\n> " <> StringReplace[ string, "\n" -> "\n> " ]) /; StringQ @ string
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Inline Code*)
fasterCellToString0[ TemplateBox[ { code_ }, "ChatCodeInlineTemplate", ___ ] ] /; ! $inlineCode :=
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

fasterCellToString0[ (Cell|StyleBox)[ code_, "InlineCode"|"InlineFormula", ___ ] ] /; ! $inlineCode :=
    Block[ { $escapeMarkdown = False, $inlineCode = True },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Code Blocks*)
fasterCellToString0[ TemplateBox[ { code_, language_ }, "ChatCodeBlockTemplate", ___ ] ] :=
    Block[ { $escapeMarkdown = False },
        "\n" <> cellToString @ Replace[ code, Cell @ BoxData[ c_Cell, ___ ] :> c ] <> "\n"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Template Boxes*)

(* Messages *)
$$messageTemplate = "MessageTemplate"|"MessageTemplate2";

fasterCellToString0[ TemplateBox[ args: { sym_String, tag_String, str0_String, ___ }, $$messageTemplate, ___ ] ] :=
    Module[ { str },
        str = If[ StringMatchQ[ str0, "\""~~__~~"\"" ],
                  Replace[ Quiet @ ToExpression[ str0, InputForm, HoldComplete ], HoldComplete[ s_String ] :> s ],
                  str0
              ];
        If[ ! StringQ @ str, str = str0 ];
        needsBasePrompt[ "WolframLanguage" ];
        sowMessageData @ args; (* Look for stack trace data *)
        sym <> "::" <> tag <> ": "<> Block[ { $escapeMarkdown = False }, fasterCellToString0 @ str ]
    ];

fasterCellToString0[ TemplateBox[ args: { _, _, str0_String, ___ }, $$messageTemplate, ___ ] ] :=
    Module[ { str },
        str = If[ StringMatchQ[ str0, "\""~~__~~"\"" ],
                  Replace[ Quiet @ ToExpression[ str0, InputForm, HoldComplete ], HoldComplete[ s_String ] :> s ],
                  str0
              ];
        If[ ! StringQ @ str, str = str0 ];
        needsBasePrompt[ "WolframLanguage" ];
        sowMessageData @ args; (* Look for stack trace data *)
        Block[ { $escapeMarkdown = False }, fasterCellToString0 @ str ]
    ];

(* Percent References *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "OutNumber" -> n_Integer ], "PercentRef", ___ ] ] :=
    "%" <> ToString @ n;

(* Large Outputs *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "shortenedBoxes" -> boxes_ ], "OutputSizeLimitTemplate", ___ ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ TemplateBox[ { size_ }, "OutputSizeLimit`Skeleton", ___ ] ] :=
    " \[LeftSkeleton]" <> fasterCellToString0 @ size <> "\[RightSkeleton] ";

(* Row *)
fasterCellToString0[ TemplateBox[ args_, "RowDefault", ___ ] ] := fasterCellToString0 @ args;
fasterCellToString0[ TemplateBox[ { sep_, items__ }, "RowWithSeparator", ___ ] ] :=
    fasterCellToString0 @ Riffle[ { items }, sep ];

(* Tooltips *)
fasterCellToString0[ TemplateBox[ { a_, ___ }, "PrettyTooltipTemplate", ___ ] ] := fasterCellToString0 @ a;

(* Control-Equal Input *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "query" -> query_String ], "LinguisticAssistantTemplate", ___ ] ] :=
    "\[FreeformPrompt][\""<>query<>"\"]";

fasterCellToString0[ TemplateBox[ KeyValuePattern[ "boxes" -> box_ ], "LinguisticAssistantTemplate", ___ ] ] :=
    fasterCellToString0 @ box;

(* NotebookObject *)
fasterCellToString0[
    TemplateBox[ KeyValuePattern[ "label" -> label_String ], "NotebookObjectUUIDsUnsaved"|"NotebookObjectUUIDs", ___ ]
] := (
    needsBasePrompt[ "Notebooks" ];
    "NotebookObject["<>label<>"]"
);

fasterCellToString0[ TemplateBox[ { _, _, _, _, label_String, _ }, "NotebookObject", ___ ] ] :=
    "NotebookObject[(* " <> StringTrim[ label, "\"" ] <> " *)]";

(* Entity *)
$$entityBoxType = "Entity"|"EntityClass"|"EntityProperty"|"EntityType";
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, $$entityBoxType, ___ ] ] := fasterCellToString0 @ box;
fasterCellToString0[ TemplateBox[ _, "InertEntity", ___ ] ] := "Entity[...]";

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
fasterCellToString0[ TemplateBox[ _, "Spacer1", ___ ] ] := " ";

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
    "WebLink",
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

fasterCellToString0[ TemplateBox[ { label_, url_String | URL[ url_String ] }, "HyperlinkURL", ___ ] ] :=
    Block[ { $showStringCharacters = False },
        "[" <> fasterCellToString0 @ label <> "](" <> url <> ")"
    ];

fasterCellToString0[ TemplateBox[ { label_, { url_String | URL[ url_String ], _ }, _ }, "HyperlinkDefault", ___ ] ] :=
    Block[ { $showStringCharacters = False },
        "[" <> fasterCellToString0 @ label <> "](" <> url <> ")"
    ];

fasterCellToString0[ { a___, StyleBox[ ButtonBox[ label_, opts___ ], styles___ ], b___ } ] :=
    fasterCellToString0 @ { a, ButtonBox[ StyleBox[ label, styles ], opts ], b };

fasterCellToString0[ {
    a___,
    btn1: ButtonBox[ label1_, opts1___ ],
    btn2: ButtonBox[ label2_, opts2___ ],
    b___
} /; sameURLQ[ btn1, btn2 ] ] :=
    fasterCellToString0 @ { a, ButtonBox[ RowBox @ { label1, label2 }, opts1 ], b };

(* TeXAssistantTemplate *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "input" -> string_ ], "TeXAssistantTemplate", ___ ] ] := (
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

(* Keyboard keys *)
fasterCellToString0[ TemplateBox[ keys: { __String }, "Key0"|"Key1"|"Key2", ___ ] ] :=
    StringRiffle[ keys, "+" ];

(* Tabular *)
fasterCellToString0[ box: TemplateBox[ _, "Tabular", ___ ] ] :=
    With[ { str = makeExpressionString @ box },
        str /; StringQ @ str
    ];

fasterCellToString0[ TemplateBox[ KeyValuePattern[ "Main" -> main_ ], "Tabular"|"TabularRef", ___ ] ] :=
    fasterCellToString0 @ main;

fasterCellToString0[ TemplateBox[
    KeyValuePattern[ "Snapshot" -> tabular_System`Tabular ],
    "TabularReferenceWrapper",
    ___
] ] := inputFormString @ Unevaluated @ tabular;

fasterCellToString0[ TableViewBox[ tabular_System`Tabular, ___ ] ] :=
    inputFormString @ Unevaluated @ tabular;

(* Reasoning Text *)
fasterCellToString0[ TemplateBox[ { thoughts_String, _ }, "ThinkingOpener"|"ThoughtsOpener", ___ ] ] :=
    "<think>\n" <> thoughts <> "\n</think>\n";

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

fasterCellToString0[ OverlayBox[ { a_, ___ }, ___ ] ] :=
    fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*sameURLQ*)
sameURLQ // beginDefinition;

sameURLQ[ btn1_, btn2_ ] :=
    Catch @ Module[ { url1, url2 },
        url1 = getHyperlinkURL @ btn1;
        If[ ! StringQ @ url1, Throw @ False ];
        url2 = getHyperlinkURL @ btn2;
        If[ ! StringQ @ url2, Throw @ False ];
        url1 === url2
    ];

sameURLQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*getHyperlinkURL*)
getHyperlinkURL // beginDefinition;

getHyperlinkURL[ URL[ uri_String ] ] := uri;
getHyperlinkURL[ uri_String ] := uri;
getHyperlinkURL[ { uri_, _ } ] := getHyperlinkURL @ uri;

getHyperlinkURL[ ButtonBox[
    _,
    OrderlessPatternSequence[ BaseStyle -> "Link"|"Hyperlink", ButtonData -> uri_, ___ ]
] ] := getHyperlinkURL @ uri;

getHyperlinkURL[ _ ] :=
    Missing[ "NotAvailable" ];

getHyperlinkURL // endDefinition;

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

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*FormBox*)
fasterCellToString0[ box: FormBox[ _, TraditionalForm, ___ ] ] :=
    serializeTraditionalForm @ box;

fasterCellToString0[ FormBox[ box_, TextForm, ___ ] ] :=
    Block[ { $showStringCharacters = False, $escapeMarkdown = True }, fasterCellToString0 @ box ];

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

(* Derivative *)
fasterCellToString0[ SuperscriptBox[ f_, "\[Prime]", ___ ] ] :=
    "Derivative[1][" <> fasterCellToString0 @ f <> "]";

fasterCellToString0[ SuperscriptBox[ f_, "\[Prime]\[Prime]", ___ ] ] :=
    "Derivative[2][" <> fasterCellToString0 @ f <> "]";

fasterCellToString0[ SuperscriptBox[ f_, TagBox[ RowBox @ { "(", n_String, ")" }, Derivative ], ___ ] ] :=
    "Derivative[" <> n <> "][" <> fasterCellToString0 @ f <> "]";

(* Sqrt *)
fasterCellToString0[ SqrtBox[ a_, OptionsPattern[ ] ] ] :=
    (needsBasePrompt[ "WolframLanguage" ]; "Sqrt["<>fasterCellToString0 @ a<>"]");

(* Fraction *)
fasterCellToString0[ FractionBox[ a_, b_, OptionsPattern[ ] ] ] :=
    (needsBasePrompt[ "Math" ]; "(" <> fasterCellToString0 @ a <> "/" <> fasterCellToString0 @ b <> ")");

(* RadicalBox *)
fasterCellToString0[ RadicalBox[ a_, b_, ___, SurdForm -> True, ___ ] ] :=
    (needsBasePrompt[ "Math" ]; "Surd[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]");
s
fasterCellToString0[ RadicalBox[ a_, b_, OptionsPattern[ ] ] ] :=
    (needsBasePrompt[ "Math" ]; fasterCellToString0 @ a <> "^(1/(" <> fasterCellToString0 @ b <> "))");

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
fasterCellToString0[ SubscriptBox[ a_, b_, OptionsPattern[ ] ] ] :=
    If[ TrueQ @ $inlineCode,
        StringJoin[ fasterCellToString0 @ a, fasterCellToString0 @ b ],
        "Subscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]"
    ];

fasterCellToString0[ SubsuperscriptBox[ a_, b_, c_, OptionsPattern[ ] ] ] :=
    If[ TrueQ @ $inlineCode,
        fasterCellToString0 @ a <> fasterCellToString0 @ b <> fasterCellToString0 @ c,
        StringJoin[
            "Subsuperscript[",
            fasterCellToString0 @ a,
            ", ",
            fasterCellToString0 @ b,
            ", ",
            fasterCellToString0 @ c,
            "]"
        ]
    ];

fasterCellToString0[ OverscriptBox[ a_, b_, OptionsPattern[ ] ] ] :=
    "Overscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]";

fasterCellToString0[ UnderscriptBox[ a_, b_, OptionsPattern[ ] ] ] :=
    "Underscript[" <> fasterCellToString0 @ a <> ", " <> fasterCellToString0 @ b <> "]";

fasterCellToString0[ UnderoverscriptBox[ a_, b_, c_, OptionsPattern[ ] ] ] := StringJoin[
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
    InterpretationBox[ DynamicModuleBox[ { ___ }, iconized: TemplateBox[ _, "IconizedObject", ___ ] ], expr_, ___ ]
] := serializeIconizedObject[ iconized, HoldComplete @ expr ];

fasterCellToString0[ box: TemplateBox[ _, "IconizedObject", ___ ] ] :=
    serializeIconizedObject[ box, None ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*serializeIconizedObject*)
serializeIconizedObject // beginDefinition;

serializeIconizedObject[
    TemplateBox[ { _, (StyleBox|TagBox)[ n_, "IconizedCustomName"|"IconizedName", ___ ], ___ }, "IconizedObject" ],
    _
] :=
    Block[ { $showStringCharacters = False },
        "IconizedObject[\[LeftSkeleton]" <> fasterCellToString0 @ n <> "\[RightSkeleton]]"
    ];

serializeIconizedObject[ TemplateBox[ { _, "ListIcon", ___ }, "IconizedObject", ___ ], _ ] := "{...}";
serializeIconizedObject[ TemplateBox[ { _, "AssociationIcon", ___ }, "IconizedObject", ___ ], _ ] := "<|...|>";
serializeIconizedObject[ TemplateBox[ { _, "StringIcon", ___ }, "IconizedObject", ___ ], _ ] := "\"...\"";
serializeIconizedObject[ TemplateBox[ { _, "SequenceIcon", ___ }, "IconizedObject", ___ ], _ ] := "...";

serializeIconizedObject[ TemplateBox[ _, "IconizedObject", ___ ], HoldComplete[ (s_Symbol)[ ___ ] ] ] :=
    ToString @ Unevaluated @ s <> "[...]";

serializeIconizedObject[ TemplateBox[ _, "IconizedObject", ___ ], _ ] := "...";

serializeIconizedObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Definitions*)
fasterCellToString0[ InterpretationBox[ GridBox[ boxes_List, ___ ], (Definition|FullDefinition)[ ___ ], ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    StringRiffle[ DeleteCases[ StringTrim[ fasterCellToString0 /@ gridFlatten @ boxes ], "" ], "\n\n" ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*gridFlatten*)
gridFlatten // beginDefinition;
gridFlatten[ GridBox[ grid_List, ___ ] ] := gridFlatten @ Flatten @ grid;
gridFlatten[ boxes_List ] := Flatten[ gridFlatten /@ boxes ];
gridFlatten[ other_ ] := other;
gridFlatten // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Tables*)
fasterCellToString0[ GridBox[ { { box_ } }, ___ ] ] :=
    fasterCellToString0 @ box;

fasterCellToString0[ GridBox[ { row: { ___ } }, ___ ] ] :=
    fasterCellToString0 @ RowBox @ Riffle[ row, "\t" ];

fasterCellToString0[ TagBox[ GridBox[ items_List, ___ ], "Column" ] ] :=
    StringRiffle[ fasterCellToString0 /@ items, "\n" ];

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
        strings = Block[ { $maxOutputCellStringLength = 2*$cellPageWidth, $inlineCode = True },
            Map[ truncateString@*escapeTableCharacters@*fasterCellToString0, grid, { 2 } ]
        ];
        (
            tr       = Transpose @ strings /. "\[Null]"|"\[InvisibleSpace]" -> "";
            tr       = Select[ tr, AnyTrue[ #, Not @* StringMatchQ[ WhitespaceCharacter... ] ] & ];
            colSizes = Max[ #, 1 ] & /@ Map[ StringLength, tr, { 2 } ];
            padded   = padColumns[ colSizes, tr ];
            columns  = StringRiffle[ #, " | " ] & /@ padded;
            If[ TrueQ @ $columnHeadings,
                riffleTableString[ "| "<>#<> " |" & /@ insertColumnDelimiter[ columns, colSizes, box ] ],
                riffleTableString[
                    "| "<>#<> " |" & /@ Join[
                        {
                            If[ AnyTrue[ colSizes, GreaterThan[ $cellPageWidth ] ],
                                StringRiffle[ StringRepeat[ " ", Min[ 3, # ] ] & /@ colSizes, " | " ],
                                StringRiffle[ StringRepeat[ " ", # ] & /@ colSizes, " | " ]
                            ],
                            StringRiffle[ createAlignedDelimiters[ colSizes, box ], " | " ]
                        },
                        columns
                    ]
                ]
            ]
        ) /; AllTrue[ strings, StringQ, 2 ]
    ];

fasterCellToString0[ TagBox[ grid_GridBox, { _, OutputFormsDump`HeadedColumns }, ___ ] ] :=
    Block[ { $columnHeadings = True }, fasterCellToString0 @ grid ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*riffleTableString*)
riffleTableString // beginDefinition;

riffleTableString[ rows: { ___String } ] := Enclose[
    Catch @ Module[ { count, lengths, max, a, b, remaining, removed, message },
        count = Length @ rows;
        If[ count <= 3, Throw @ StringRiffle[ rows, "\n" ] ];
        lengths = StringLength @ rows;

        max = ConfirmMatch[
            Replace[ $maxCellStringLength, Except[ _Integer ] :> $defaultMaxCellStringLength ],
            $$size,
            "Max"
        ];

        If[ Total @ lengths <= max, Throw @ StringRiffle[ rows, "\n" ] ];
        a = Max[ LengthWhile[ Accumulate @ lengths, # <= Floor[ 2 * (max / 3) ] & ], 3 ];
        remaining = ConfirmMatch[ max - Total @ lengths[[ 1;;a ]], $$size, "Remaining" ];
        b = LengthWhile[ Accumulate @ Reverse @ lengths, # <= remaining & ];
        removed = ConfirmMatch[ count - (a + b), $$size, "Removed" ];
        If[ removed === 0, Throw @ StringRiffle[ rows, "\n" ] ];

        message = ConfirmBy[
            Replace[
                removed,
                {
                    1 :> "one row removed",
                    _? Positive :> ToString @ removed <> " rows removed"
                }
            ],
            StringQ,
            "Message"
        ];

        StringRiffle[
            Join[
                rows[[ 1;;a ]],
                { "\[LeftSkeleton]" <> message <> "\[RightSkeleton]" },
                rows[[ -b ;; All ]]
            ],
            "\n"
        ]
    ],
    throwInternalFailure
];

riffleTableString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*padColumns*)
padColumns // beginDefinition;

padColumns[ colSizes0_, tr_ ] :=
    Module[ { colSizes },
        colSizes = If[ AnyTrue[ colSizes0, GreaterThan[ $cellPageWidth ] ], Clip[ colSizes0, { 1, 3 } ], colSizes0 ];
        Transpose @ Apply[ padColumn, Transpose @ { tr, colSizes }, { 1 } ]
    ];

padColumns // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*padColumn*)
padColumn // beginDefinition;
padColumn[ string_String, size_Integer ] := If[ StringLength @ string >= size, string, StringPadRight[ string, size ] ];
padColumn[ strings_List, size_Integer ] := padColumn[ #, size ] & /@ strings;
padColumn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*escapeTableCharacters*)
escapeTableCharacters // beginDefinition;
escapeTableCharacters[ str_String ] := StringReplace[ str, { "|" -> "\\|", "\n" -> " " } ];
escapeTableCharacters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*insertColumnDelimiter*)
insertColumnDelimiter // beginDefinition;

insertColumnDelimiter[ { headings_String, rows__String }, colSizes: { __Integer }, box_ ] := {
    headings,
    StringRiffle[ createAlignedDelimiters[ colSizes, box ], " | " ],
    rows
};

insertColumnDelimiter[ rows_List, _List, box_ ] := rows;

insertColumnDelimiter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*createAlignedDelimiters*)
createAlignedDelimiters // beginDefinition;

createAlignedDelimiters[ colSizes_, GridBox[ ___, GridBoxAlignment -> { ___, "Columns" -> alignments_, ___ }, ___ ] ] :=
    createAlignedDelimiters[ colSizes, alignments ];

createAlignedDelimiters[ colSizes_, _GridBox ] :=
    If[ AnyTrue[ colSizes, GreaterThan[ $cellPageWidth ] ],
        StringRepeat[ "-", Min[ 3, Max[ #, 1 ] ] ] & /@ colSizes,
        StringRepeat[ "-", Min[ $cellPageWidth, Max[ #, 1 ] ] ] & /@ colSizes
    ];

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
            If[ AnyTrue[ colSizes, GreaterThan[ $cellPageWidth ] ], Clip[ colSizes, { 1, 3 } ], colSizes ],
            Replace[ alignments, { (Center|"Center").. } :> ConstantArray[ Automatic, total ] ]
        }
    ];

createAlignedDelimiters[ colSizes_List, { alignment: Except[ _List ] } ] :=
    createAlignedDelimiters[ colSizes, ConstantArray[ alignment, Length @ colSizes ] ];

createAlignedDelimiters[ colSizes_List, alignments_List ] /; Length @ alignments =!= Length @ colSizes :=
    createAlignedDelimiters[ colSizes, PadRight[ alignments, Length @ colSizes, Automatic ] ];

createAlignedDelimiters // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*createAlignedDelimiter*)
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
    Catch @ Module[ { header, items, string },

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

        If[ items === { }, Throw[ "" ] ];

        string = StringRiffle[ Flatten @ { header<>"\n", items }, "\n" ];

        StringReplace[
            string,
            {
                Shortest[
                    StringExpression[
                        "[",
                        label1: Except[ "\n" ]...,
                        "](",
                        url1: Except[ ")" ]..,
                        ")\n* [",
                        label2: Except[ "\n" ]...,
                        "](",
                        url2: Except[ ")" ]..,
                        ")"
                    ] /; url1 === url2
                ] :> "["<>label1<>label2<>"]("<>url1<>")",

                "[``" ~~ name: Repeated[ "$"|LetterCharacter|DigitCharacter, { 1, 80 } ] ~~ "``](paclet:" :>
                    "["<>name<>"](paclet:"
            }
        ]
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
    If[ $OperatingSystem === os, inputFormString @ a, inputFormString @ b ];

fasterCellToString0 @ DynamicBox[ If[ $OperatingSystem === os_String, a_, b_ ], ___ ] :=
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
(*Chatbook Text Resources*)
fasterCellToString0[ DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "Close" ][ ___ ], ___ ] ] :=
    "";

fasterCellToString0[ DynamicBox[ ToBoxes[ FEPrivate`FrontEndResource[ "ChatbookStrings", name_String ], _ ], ___ ] ] :=
    With[ { str = trRaw @ name }, str /; StringQ @ str ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other FE Resources*)
fasterCellToString0[ DynamicBox[ (FEPrivate`FrontEndResource|FrontEndResource)[ "FEBitmaps", "IconizeEllipsis" ] ] ] :=
    "...";

fasterCellToString0[
    DynamicBox[ (FEPrivate`FrontEndResource|FrontEndResource)[ type: "FEBitmaps"|"WABitmaps", name_String ], ___ ]
] := fasterCellToString0 @ feResource[ type, name ];

fasterCellToString0[
    DynamicBox[ FEPrivate`FrontEndResource[ "FEExpressions", "ChoiceButtonsOrder" ][ buttons: { ___ } ], ___ ]
] := fasterCellToString0 @ RowBox @ Riffle[ buttons, " " ];

fasterCellToString0[ DynamicBox[ FEPrivate`FrontEndResourceString[ "okButtonText" ], ___ ] ] :=
    "OK";

fasterCellToString0[ DynamicBox[ FEPrivate`FrontEndResourceString[ "cancelButtonText" ], ___ ] ] :=
    "Cancel";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*feResource*)
feResource // beginDefinition;
feResource[ type_String, name_String ] := feResource[ type, name ] = FrontEndResource[ type, name ];
feResource // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other*)
fasterCellToString0[ Cell[ _, "ObjectNameTranslation", ___ ] ] := "";

fasterCellToString0[ ProgressIndicatorBox[ args___ ] ] :=
    inputFormString @ Unevaluated @ ProgressIndicator @ args;

fasterCellToString0[ PaneSelectorBox[ { ___, False -> b_, ___ }, Dynamic[ CurrentValue[ "MouseOver" ], ___ ], ___ ] ] :=
    fasterCellToString0 @ b;

fasterCellToString0[ (h: $$controlBox)[ args___ ] ] :=
    With[ { head = Symbol @ StringDelete[ ToString @ h, "Box"~~EndOfString ] },
        inputFormString @ Unevaluated @ head @ args
    ];

fasterCellToString0[ RotationBox[ box_, ___, BoxRotation -> r_, ___ ] ] :=
    StringJoin[ "Rotate[", fasterCellToString0 @ box, ", ", inputFormString @ Unevaluated @ r, "]" ];

fasterCellToString0[ DynamicBox[ ToBoxes[ expr_, StandardForm ], ___ ] ] :=
    inputFormString @ Dynamic @ expr;

fasterCellToString0[ DynamicBox[ ToBoxes[ expr_ ], ___ ] ] :=
    inputFormString @ Dynamic @ expr;

fasterCellToString0[ DynamicBox[ If[ CurrentValue[ "MouseOver" ], a_, b_ ], ___ ] ] :=
    fasterCellToString0 @ b;

fasterCellToString0[ DynamicWrapperBox[ box_, ___ ] ] :=
    fasterCellToString0 @ box;

fasterCellToString0[
    TagBox[ _, "MarkdownImage", ___, TaggingRules -> KeyValuePattern[ "CellToStringData" -> string_String ], ___ ]
] := string;

fasterCellToString0[ BoxData[ boxes_List, ___ ] ] :=
    With[ { strings = fasterCellToString0 /@ DeleteCases[ boxes, "\n" ] },
        StringRiffle[ strings, "\n" ] /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ BoxData[ boxes_, ___ ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ GraphicsData[ "CompressedBitmap"|"PostScript", ___ ] ] :=
    "Image[...]";

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
        Replace[ held, HoldComplete[ e_ ] :> truncateString @ inputFormString @ Unevaluated @ e ]
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

fasterCellToString0[ Cell[ BoxData[ b: TemplateBox[ _, "ChatCodeBlockTemplate", ___ ], ___ ], "ChatCodeBlock", ___ ] ] :=
    fasterCellToString0 @ b;

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

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
fasterCellToString0[ DynamicModuleBox[
    { ___, TypeSystem`NestedGrid`PackagePrivate`$state$$ = Association[ ___, "InitialData" -> data_, ___ ], ___ },
    ___
] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    inputFormString @ Unevaluated @ Dataset @ data
);
(* :!CodeAnalysis::EndBlock:: *)

fasterCellToString0[ DynamicModuleBox[ a___ ] ] /; ! TrueQ @ $CellToStringDebug := (
    needsBasePrompt[ "ConversionLargeOutputs" ];
    "DynamicModule[\[LeftSkeleton]" <> ToString @ Length @ HoldComplete @ a <> "\[RightSkeleton]]"
);

fasterCellToString0[ CounterBox[ args__String ] ] :=
    "\\!\\(\\*CounterBox[\"" <> StringRiffle[ { args }, "\", \"" ] <> "\"]\\)";

fasterCellToString0[ ValueBox[ args__String ] ] :=
    "\\!\\(\\*ValueBox[\"" <> StringRiffle[ { args }, "\", \"" ] <> "\"]\\)";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Unhandled TemplateBoxes*)
fasterCellToString0[ box: TemplateBox[ args_, ___ ] ] :=
    With[ { f = getTemplateBoxFunction @ box },
        fasterCellToString0 @ applyTemplateBoxDisplayFunction[ f, args ] /; ! MissingQ @ f
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*getTemplateBoxFunction*)
getTemplateBoxFunction // beginDefinition;
getTemplateBoxFunction[ TemplateBox[ __, InterpretationFunction -> f: Except[ $$unspecified ], ___ ] ] := f;
getTemplateBoxFunction[ TemplateBox[ __, DisplayFunction -> f: Except[ $$unspecified ], ___ ] ] := f;
getTemplateBoxFunction[ TemplateBox[ _, name_String, ___, InterpretationFunction -> Automatic, ___ ] ] := name;
getTemplateBoxFunction[ TemplateBox[ _, name_String, ___ ] ] := getTemplateBoxFunction @ name;
getTemplateBoxFunction[ name_String ] := Lookup[ $templateBoxCache, name, getTemplateBoxFunction0 @ name ];
getTemplateBoxFunction // endDefinition;


getTemplateBoxFunction0 // beginDefinition;

getTemplateBoxFunction0[ name_String ] :=
    getTemplateBoxFunction0[ name, getTemplateBoxOptions @ name ];

getTemplateBoxFunction0[
    name_,
    KeyValuePattern[ InterpretationFunction|"InterpretationFunction" -> f: Except[ $$unspecified ] ]
] := $templateBoxCache[ name ] = f;

getTemplateBoxFunction0[
    name_,
    KeyValuePattern[ InterpretationFunction|"InterpretationFunction" -> Automatic ]
] := $templateBoxCache[ name ] = name;

getTemplateBoxFunction0[
    name_,
    KeyValuePattern[ DisplayFunction|"DisplayFunction" -> f: Except[ $$unspecified ] ]
] := $templateBoxCache[ name ] = f;

getTemplateBoxFunction0[ name_, _ ] :=
    $templateBoxCache[ name ] = Missing[ "NotFound" ];

getTemplateBoxFunction0 // endDefinition;


$templateBoxCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*getTemplateBoxOptions*)
getTemplateBoxOptions // beginDefinition;

getTemplateBoxOptions[ id_String ] /; KeyExistsQ[ $templateBoxOptionsCache, id ] :=
    $templateBoxOptionsCache[ id ];

getTemplateBoxOptions[ id_String ] := (
    $templateBoxOptionsCache;
    $templateBoxOptionsCache[ id ] = usingFrontEnd @ CurrentValue @ { StyleDefinitions, id, TemplateBoxOptions }
);

getTemplateBoxOptions // endDefinition;


$templateBoxOptionsCache :=
    Module[ { file, data },
        file = $thisPaclet[ "AssetLocation", "TemplateBoxOptions" ];
        data = If[ FileExistsQ @ file, Developer`ReadWXFFile @ file, <| |> ];
        If[ ! AssociationQ @ data, data = <| |> ];
        If[ TrueQ @ Wolfram`ChatbookInternal`$BuildingMX,
            data,
            $templateBoxOptionsCache = data
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsubsection::Closed:: *)
(*applyTemplateBoxDisplayFunction*)
applyTemplateBoxDisplayFunction // beginDefinition;

applyTemplateBoxDisplayFunction[ f_, TemplateBox[ args_, ___ ] ] :=
    applyTemplateBoxDisplayFunction[ f, args ];

applyTemplateBoxDisplayFunction[ f_String, a_List ] :=
    f <> "[" <> StringRiffle[ fasterCellToString0 /@ a, ", " ] <> "]";

applyTemplateBoxDisplayFunction[ f0_, { args___ } ] :=
    Module[ { n, f },
        n = Length @ HoldComplete @ args;
        f = ReplaceRepeated[
            ReplaceAll[
                f0,
                {
                    TemplateSlotSequence[ { a_Integer, b_Integer }, riffle_ ] :>
                        RuleCondition[ sequence @@ Riffle[ Slot /@ Range[ a, b ], riffle ] ],
                    TemplateSlotSequence[ a_Integer, riffle_ ] :>
                        RuleCondition[ sequence @@ Riffle[ Slot /@ Range[ a, n ], riffle ] ]
                }
            ],
            {
                h_[ c___, sequence[ d___ ], e___ ] :> h[ c, d, e ],
                sequence[ d___ ] :> d
            }
        ];
        f @ args
    ];

applyTemplateBoxDisplayFunction[ f_, args___ ] :=
    f @ args;

applyTemplateBoxDisplayFunction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored/Skipped*)
fasterCellToString0[ FormBox[ box_, ___ ] ] := fasterCellToString0 @ box;
fasterCellToString0[ $ignoredBoxPatterns ] := "";
fasterCellToString0[ $stringStripHeads[ a_, ___ ] ] := fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Hacks*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
fasterCellToString0[ HoldPattern @ DocuTools`Private`StylizeTemplatePart[ box_ ] ] := fasterCellToString0 @ box;
(* :!CodeAnalysis::EndBlock:: *)

(* Some system model related boxes have raw values: *)
$$rawSymbol = Alternatives[ None, Automatic, StateSpaceModel, True, False, $Failed ];
fasterCellToString0[ sym: $$rawSymbol ] := ToString @ sym;
fasterCellToString0[ n_? NumberQ ] := ToString @ n;
fasterCellToString0[ HoldPattern @ BoxData[ ] ] := "";

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*FE Failure Modes*)
e: fasterCellToString0[ (DefaultStyleDefinitions -> "Default.nb") | Function[ _ ] | (ScreenRectangle -> _) ] :=
    throwInternalFailure[ e, "BadFrontEndState" ];

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
        "CompressedData[\"\[LeftSkeleton]" <> ToString @ StringLength @ s <> "\[RightSkeleton]\"]",
    "$CellContext`" -> ""
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
(*makeGraphicsString*)
makeGraphicsString // SetFallthroughError;

makeGraphicsString[ DynamicBox[ import_FEPrivate`ImportImage, ___ ] ] :=
    ToString[ RawBoxes @ DynamicBox @ import, StandardForm ];

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
makeGraphicsExpression[ gfx_ ] /; ByteCount @ gfx > $maxBoxSizeForImages := $Failed;
makeGraphicsExpression[ gfx_ ] := Quiet @ Check[ ToExpression[ gfx, StandardForm, HoldComplete ], $Failed ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*sowMessageData*)
sowMessageData[ { _, _, _, _, line_Integer, counter_Integer, session_Integer, __ } ] /; $includeStackTrace :=
    With[ { stack = MessageMenu`MessageStackList[ line, counter, session ] },
        Sow[ stack, $messageStack ] /; MatchQ[ stack, { __HoldForm } ]
    ];

sowMessageData[ ___ ] := Null;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showStringCharactersQ*)
showStringCharactersQ[ Cell[ __, "TextTableForm", ___ ] ] := False;
showStringCharactersQ[ Cell[ __, "MoreInfoText", ___ ] ] := False;
showStringCharactersQ[ Cell[ _, OptionsPattern[ ] ] ] := False;
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
truncateString[ str_String? truncatedTableStringQ ] := str;
truncateString[ str_String ] := truncateString[ str, $maxOutputCellStringLength ];
truncateString[ str_String, Automatic ] := truncateString[ str, $defaultMaxOutputCellStringLength ];
truncateString[ str_String, max: $$size ] := stringTrimMiddle[ str, max ];
truncateString[ other_ ] := other;
truncateString[ other_, _Integer ] := other;
truncateString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncatedTableStringQ*)
truncatedTableStringQ // beginDefinition;

truncatedTableStringQ[ str_String ] := TrueQ @ And[
    StringStartsQ[ str, "|" ],
    StringMatchQ[
        str,
        StringExpression[
            Shortest[ ("| " ~~ Except[ "\n" ].. ~~ " |\n").. ],
            "\[LeftSkeleton]" ~~ ("one row removed" | (DigitCharacter.. ~~ " rows removed")) ~~ "\[RightSkeleton]\n",
            Shortest[ ("| " ~~ Except[ "\n" ].. ~~ " |" ~~ ("\n"|EndOfString))... ]
        ]
    ]
];

truncatedTableStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stackFrameString*)
stackFrameString // beginDefinition;
stackFrameString // Attributes = { HoldAllComplete };
stackFrameString[ expr_ ] := stringTrimMiddle[ inputFormString[ Unevaluated @ expr, PageWidth -> Infinity ], 160 ];
stackFrameString // endDefinition;

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
codeBlockQ[ Cell[ _, OptionsPattern[ ] ] ] := False;
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
(*Backwards Compatibility*)

(* The resource function ExportMarkdownString depends on CellToString in the original context: *)
Wolfram`Chatbook`Serialization`CellToString = CellToString;
(* https://resources.wolframcloud.com/FunctionRepository/resources/ExportMarkdownString *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
