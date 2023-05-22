BeginPackage[ "Wolfram`Chatbook`Serialization`" ];

(* Avoiding context aliasing due to bug 434990: *)
Needs[ "GeneralUtilities`" -> None ];

GeneralUtilities`SetUsage[ `CellToString, "\
CellToString[cell$] serializes a Cell expression as a string for use in chat.\
" ];

`$CellToStringDebug;
`$CurrentCell;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`Errors`"     ];
Needs[ "Wolfram`Chatbook`ErrorUtils`" ];
Needs[ "Wolfram`Chatbook`Prompting`"  ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Config*)
$$delimiterStyle   = "PageBreak"|"ExampleDelimiter"|"ChatDelimiter";
$$itemStyle        = "Item"|"Notes";
$$noCellLabelStyle = "Text"|"ChatInput"|"SideChat"|"ChatSystemInput"|"ChatBlockDivider"|$$delimiterStyle;
$$docSearchStyle   = "ChatQuery";

(* Default character encoding for strings created from cells *)
$cellCharacterEncoding = "Unicode";

(* Set a max string length for output cells to avoid blowing up token counts *)
$maxOutputCellStringLength = 500;

(* Set a page width for expressions that need to be serialized as InputForm *)
$cellPageWidth = 100;

(* Whether to collect data that can help discover missing definitions *)
$CellToStringDebug = False;

(* Can be redefined locally depending on cell style *)
$showStringCharacters = True;

(* Add spacing around these operators *)
$$spacedInfixOperator = Alternatives[
    "^", "*", "+", "=", "|", "<", ">", ";", "?", "/", ":", "!=", "@*", "^=", "&&", "*=", "-=", "->", "+=", "==", "~~",
    "||", "<=", "<>", ">=", ";;", "/@", "/*", "/=", "/.", "/;", ":=", ":>", "::", "^:=", "=!=", "===", "|->", "<->",
    "//@", "//.", "\[Equal]", "\[GreaterEqual]", "\[LessEqual]", "\[NotEqual]", "\[Function]", "\[Rule]",
    "\[RuleDelayed]", "\[TwoWayRule]"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Conversion Rules*)

(* Rules to convert some 2D boxes into an infix form *)
$boxOp = <| SuperscriptBox -> "^", SubscriptBox -> "_" |>;

(* How to choose TemplateBox arguments for serialization *)
$templateBoxRules = <|
    "ChatCodeBlockTemplate"  -> First,
    "DateObject"             -> First,
    "HyperlinkDefault"       -> First,
    "RefLink"                -> First,
    "RowDefault"             -> Identity
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

(* Serialize the first argument of these and ignore the rest *)
$stringStripHeads = Alternatives[
    ButtonBox,
    CellGroupData,
    FormBox,
    FrameBox,
    ItemBox,
    PanelBox,
    RowBox,
    StyleBox,
    TagBox,
    TextData,
    TooltipBox
];

(* Boxes that should be ignored during serialization *)
$ignoredBoxPatterns = Alternatives[
    _CheckboxBox,
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
WolframAlpha[\"%%Query%%\"]

WOLFRAM_ALPHA_PARSED_INPUT: %%Code%%

" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CellToString*)
CellToString // SetFallthroughError;

CellToString // Options = {
    CharacterEncoding -> $cellCharacterEncoding,
    "Debug"           :> $CellToStringDebug,
    PageWidth         -> $cellPageWidth
};

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
CellToString[ cell_, opts: OptionsPattern[ ] ] :=
    Block[
        {
            $cellCharacterEncoding = OptionValue[ "CharacterEncoding" ],
            $CellToStringDebug     = TrueQ @ OptionValue[ "Debug" ],
            $cellPageWidth         = OptionValue[ "PageWidth" ]
        },
        $fasterCellToStringFailBag = Internal`Bag[ ];
        If[ ! StringQ @ $cellCharacterEncoding, $cellCharacterEncoding = "UTF-8" ];
        WithCleanup[
            Replace[
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
(*cellToString*)
cellToString // SetFallthroughError;

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
cellToString[ Cell[ a__, $$noCellLabelStyle, b___, CellLabel -> _, c___ ] ] :=
    cellToString @ Cell[ a, b, c ];

(* Convert delimiters to equivalent markdown *)
cellToString[ Cell[ __, $$delimiterStyle, ___ ] ] := "\n---\n";
cellToString[ Cell[ __, "ExcludedChatDelimiter", ___ ] ] := "";

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
cellToString[ cell: Cell[ _BoxData, ___ ] ] /; ! TrueQ @ $delimitedCodeBlock :=
    Block[ { $delimitedCodeBlock = True },
        With[ { s = cellToString @ cell },
            If[ StringQ @ s,
                needsBasePrompt[ "WolframLanguage" ];
                "```\n"<>s<>"\n```",
                ""
            ]
        ]
    ];

(* Prepend cell label to the cell string *)
cellToString[ Cell[ a___, CellLabel -> label_String, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, b ] }, (needsBasePrompt[ "Notebooks" ]; label<>" "<>str) /; StringQ @ str ];

(* Item styles *)
cellToString[ Cell[ a___, $$itemStyle, b___ ] ] :=
    With[ { str = cellToString @ Cell[ a, "Text", b ] },
        " * "<>str /; StringQ @ str
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
                    HoldForm[ expr_ ] :> truncateStackString @ ToString[
                        Unevaluated @ expr,
                        InputForm,
                        CharacterEncoding -> $cellCharacterEncoding
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

(* External language cells get converted to an equivalent ExternalEvaluate input *)
cellToString[ Cell[ code_, "ExternalLanguage", ___, $$cellEvaluationLanguage -> lang_String, ___ ] ] :=
    Module[ { string },
        string = cellToString0 @ code;
        (
            needsBasePrompt[ "WolframLanguage" ];
            "ExternalEvaluate[\""<>lang<>"\", \""<>string<>"\"]"
        ) /; StringQ @ string
    ];

(* Begin recursive serialization of the cell content *)
cellToString[ cell: Cell[ _TextData|_String, ___ ] ] := Block[ { $escapeMarkdown = True }, cellToString0 @ cell ];
cellToString[ cell_ ] := Block[ { $escapeMarkdown = False }, cellToString0 @ cell ];

cellToString0[ cell_ ] :=
    With[ { string = fasterCellToString @ cell },
        If[ StringQ @ string,
            string,
            slowCellToString @ cell
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cellsToString*)
cellsToString // SetFallthroughError;
cellsToString[ cells_List ] :=
    With[ { strings = cellToString /@ cells },
        StringRiffle[ Select[ strings, StringQ ], "\n\n" ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fasterCellToString*)
fasterCellToString[ arg_ ] :=
    Block[ { $catchingStringFail = True },
        Catch[
            Module[ { string },
                string = fasterCellToString0 @ arg;
                If[ StringQ @ string,
                    Replace[ StringTrim @ string, "" -> Missing[ "NotFound" ] ],
                    $Failed
                ]
            ],
            $stringFail
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Ignored/Skipped*)

fasterCellToString0[ $ignoredBoxPatterns ] := "";
fasterCellToString0[ $stringStripHeads[ a_, ___ ] ] := fasterCellToString0 @ a;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Headings*)
fasterCellToString0[ (Cell|StyleBox)[ a_, "Section", ___ ] ] := "# "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, "Subsection", ___ ] ] := "## "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, "Subsubsection", ___ ] ] := "### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, "Subsubsubsection", ___ ] ] := "#### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, "Subsubsubsubsection", ___ ] ] := "##### "<>fasterCellToString0 @ a;
fasterCellToString0[ (Cell|StyleBox)[ a_, "ChatBlockDivider", ___ ] ] := "# "<>fasterCellToString0 @ a;

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

fasterCellToString0[ "\[Bullet]" ] := "*";

(* StandardForm strings *)
fasterCellToString0[ a_String /; StringMatchQ[ a, "\""~~___~~("\\!"|"\!")~~___~~"\"" ] ] :=
    With[ { res = ToString @ ToExpression[ a, InputForm ] },
        If[ TrueQ @ $showStringCharacters,
            res,
            StringTrim[ res, "\"" ]
        ] /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ]
    ];

fasterCellToString0[ a_String /; StringContainsQ[ a, ("\\!"|"\!") ] ] :=
    With[ { res = stringToBoxes @ a }, res /; FreeQ[ res, s_String /; StringContainsQ[ s, ("\\!"|"\!") ] ] ];

(* Other strings *)
fasterCellToString0[ a_String ] :=
    ToString[
        escapeMarkdownCharacters @ If[ TrueQ @ $showStringCharacters, a, StringTrim[ a, "\"" ] ],
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
    "LLMResourceFunction[" <> StringRiffle[ toLLMArg /@ Flatten @ { name, args }, ", " ] <> "]"
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
(*Wolfram Alpha Input*)

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[
        { OrderlessPatternSequence[ Typeset`q$$ = query_String, Typeset`chosen$$ = code_String, ___ ] },
        ___
    ],
    ___
] ] := TemplateApply[ $wolframAlphaInputTemplate, <| "Query" -> query, "Code" -> code |> ];

fasterCellToString0[ NamespaceBox[
    "WolframAlphaQueryParseResults",
    DynamicModuleBox[ { ___, Typeset`chosen$$ = code_String, ___ }, ___ ],
    ___
] ] := code;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Graphics*)
fasterCellToString0[ box: $graphicsHeads[ ___ ] ] :=
    If[ TrueQ[ ByteCount @ box < $maxOutputCellStringLength ],
        (* For relatively small graphics expressions, we'll give an InputForm string *)
        needsBasePrompt[ "Notebooks" ];
        makeGraphicsString @ box,
        (* Otherwise, give the same thing you'd get in a standalone kernel*)
        needsBasePrompt[ "ConversionGraphics" ];
        "-Graphics-"
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Template Boxes*)

(* Inline Code *)
fasterCellToString0[ TemplateBox[ { code_ }, "ChatCodeInlineTemplate" ] ] :=
    Block[ { $escapeMarkdown = False },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

fasterCellToString0[ StyleBox[ code_, "TI", ___ ] ] :=
    Block[ { $escapeMarkdown = False },
        needsBasePrompt[ "DoubleBackticks" ];
        "``" <> fasterCellToString0 @ code <> "``"
    ];

(* Messages *)
fasterCellToString0[ TemplateBox[ args: { _, _, str_String, ___ }, "MessageTemplate" ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    sowMessageData @ args; (* Look for stack trace data *)
    fasterCellToString0 @ str
);

(* Row *)
fasterCellToString0[ TemplateBox[ args_, "RowDefault", ___ ] ] := fasterCellToString0 @ args;

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
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, "Entity" ] ] := fasterCellToString0 @ box;
fasterCellToString0[ TemplateBox[ { _, box_, ___ }, "EntityProperty" ] ] := fasterCellToString0 @ box;

(* Spacers *)
fasterCellToString0[ TemplateBox[ _, "Spacer1" ] ] := " ";

(* Links *)
fasterCellToString0[ TemplateBox[ { label_, uri_String }, "TextRefLink" ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")"
);

fasterCellToString0[ ButtonBox[ StyleBox[ label_, "SymbolsRefLink", ___ ], ___, ButtonData -> uri_String, ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    "[" <> fasterCellToString0 @ label <> "](" <> uri <> ")"
);

(* TeXAssistantTemplate *)
fasterCellToString0[ TemplateBox[ KeyValuePattern[ "input" -> string_ ], "TeXAssistantTemplate" ] ] := (
    needsBasePrompt[ "Math" ];
    "$" <> string <> "$"
);

(* Other *)
fasterCellToString0[ TemplateBox[ args_, name_String, ___ ] ] :=
    With[ { f = $templateBoxRules @ name },
        fasterCellToString0 @ f @ args /; ! MissingQ @ f
    ];

fasterCellToString0[ TemplateBox[ args_, ___, InterpretationFunction -> f_, ___ ] ] :=
    fasterCellToString0 @ f @ args;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Math Boxes*)

(* Sqrt *)
fasterCellToString0[ SqrtBox[ a_ ] ] :=
    (needsBasePrompt[ "WolframLanguage" ]; "Sqrt["<>fasterCellToString0 @ a<>"]");

(* Fraction *)
fasterCellToString0[ FractionBox[ a_, b_ ] ] :=
    (needsBasePrompt[ "Math" ]; "(" <> fasterCellToString0 @ a <> "/" <> fasterCellToString0 @ b <> ")");

(* Other *)
fasterCellToString0[ (box: $boxOperators)[ a_, b_ ] ] :=
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
(*Definitions*)
fasterCellToString0[ InterpretationBox[ boxes_, (Definition|FullDefinition)[ _Symbol ], ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    fasterCellToString0 @ boxes
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Other*)

fasterCellToString0[ BoxData[ boxes_List ] ] :=
    With[ { strings = fasterCellToString0 /@ boxes },
        StringRiffle[ strings, "\n" ] /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ BoxData[ boxes_ ] ] :=
    fasterCellToString0 @ boxes;

fasterCellToString0[ list_List ] :=
    With[ { strings = fasterCellToString0 /@ list },
        StringJoin @ strings /; AllTrue[ strings, StringQ ]
    ];

fasterCellToString0[ cell: Cell[ a_, ___ ] ] :=
    Block[ { $showStringCharacters = showStringCharactersQ @ cell }, fasterCellToString0 @ a ];

fasterCellToString0[ InterpretationBox[ _, expr_, ___ ] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    ToString[
        Unevaluated @ expr,
        InputForm,
        PageWidth         -> $cellPageWidth,
        CharacterEncoding -> $cellCharacterEncoding
    ]
);

fasterCellToString0[ GridBox[ grid_? MatrixQ, ___ ] ] :=
    Module[ { strings, tr, colSizes },
        strings = Map[ fasterCellToString0, grid, { 2 } ];
        (
            tr = Transpose @ strings;
            colSizes = Max /@ Map[ StringLength, tr, { 2 } ];
            StringRiffle[
                StringRiffle /@ Transpose @ Apply[
                    StringPadRight,
                    Transpose @ { tr, colSizes },
                    { 1 }
                ],
                "\n"
            ]
        ) /; AllTrue[ strings, StringQ, 2 ]
    ];

fasterCellToString0[ Cell[ TextData @ { _, _, text_String, _, Cell[ _, "ExampleCount", ___ ] }, ___ ] ] :=
    fasterCellToString0 @ text;

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

fasterCellToString0[ _[
    __,
    TaggingRules -> Association @ OrderlessPatternSequence[ "CellToStringData" -> data_, ___ ],
    ___
] ] := fasterCellToString0 @ data;

fasterCellToString0[ DynamicModuleBox[
    { ___, TypeSystem`NestedGrid`PackagePrivate`$state$$ = Association[ ___, "InitialData" -> data_, ___ ], ___ },
    ___
] ] := (
    needsBasePrompt[ "WolframLanguage" ];
    ToString[ Unevaluated @ Dataset @ data, InputForm ]
);

fasterCellToString0[ DynamicModuleBox[ a___ ] ] /; ! TrueQ @ $CellToStringDebug := (
    needsBasePrompt[ "ConversionLargeOutputs" ];
    "DynamicModule[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]"
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Missing Definition*)
fasterCellToString0[ a___ ] := (
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
        plain  = Quiet @ UsingFrontEnd @ FrontEndExecute @ FrontEnd`ExportPacket[ cell, format ];
        string = Replace[ plain, { { s_String? StringQ, ___ } :> s, ___ :> $Failed } ];

        If[ StringQ @ string,
            Replace[ StringTrim[ string, WhitespaceCharacter ], "" -> Missing[ "NotFound" ] ],
            $Failed
        ]
    ];

slowCellToString[ boxes_BoxData ] := slowCellToString @ Cell @ boxes;
slowCellToString[ text_TextData ] := Block[ { $showStringCharacters = False }, slowCellToString @ Cell @ text ];
slowCellToString[ text_String   ] := slowCellToString @ TextData @ text;
slowCellToString[ boxes_        ] := slowCellToString @ BoxData @ boxes;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Additional Utilities*)

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
        Quiet @ UsingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`UndocumentedTestFEParserPacket[ string, True ]
    ];

stringToBoxes[ string_, { BoxData[ boxes_ ], ___ } ] := boxes;
stringToBoxes[ string_, other_ ] := string;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeGraphicsString*)
makeGraphicsString // SetFallthroughError;

makeGraphicsString[ gfx_ ] := makeGraphicsString[ gfx, makeGraphicsExpression @ gfx ];

makeGraphicsString[ gfx_, HoldComplete[ expr: _Graphics|_Graphics3D|_Image|_Image3D|_Graph ] ] :=
    StringReplace[
        ToString[
            Unevaluated @ expr,
            InputForm,
            PageWidth         -> $cellPageWidth,
            CharacterEncoding -> $cellCharacterEncoding
        ],
        "\r\n" -> "\n"
    ];

makeGraphicsString[
    GraphicsBox[
        NamespaceBox[ "NetworkGraphics", DynamicModuleBox[ { ___, _ = HoldComplete @ Graph[ a___ ], ___ }, ___ ] ],
        ___
    ],
    _
] := "Graph[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ GraphicsBox[ a___ ], _ ] :=
    "Graphics[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Graphics3DBox[ a___ ], _ ] :=
    "Graphics3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ RasterBox[ a___ ], _ ] :=
    "Image[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

makeGraphicsString[ Raster3DBox[ a___ ], _ ] :=
    "Image3D[<<" <> ToString @ Length @ HoldComplete @ a <> ">>]";

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

(* This would normally give False for things like output cells, but the LLM needs to see the difference between symbols
   and strings. However, there might be cases in the future where we want to change this behavior, so this is left in
   as a stub definition for now. *)
showStringCharactersQ[ ___ ] := True;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*truncateStackString*)
truncateStackString // SetFallthroughError;
truncateStackString[ str_String ] /; StringLength @ str <= 80 := str;
truncateStackString[ str_String ] := StringTake[ str, 80 ] <> "...";

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

$markdownReplacements = { "\\`" -> "\\`", "\\$" -> "\\$", "`" -> "\\`", "$" -> "\\$" };

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*docSearchResultString*)
docSearchResultString // ClearAll;

docSearchResultString[ query_String ] /; $CurrentCell =!= True := "";

docSearchResultString[ query_String ] := Enclose[
    Module[ { search },
        search = ConfirmMatch[ documentationSearch @ query, { __String } ];
        StringJoin[
            "BEGIN_SEARCH_RESULTS\n",
            StringRiffle[ search, "\n" ],
            "\nEND_SEARCH_RESULTS"
        ]
    ],
    $noDocSearchResultsString &
];


docSearchResultString[ other_ ] :=
    With[ { str = cellToString @ other }, documentationSearch @ str /; StringQ @ str ];

docSearchResultString[ ___ ] := $noDocSearchResultsString;


documentationSearch[ query_String ] /; $localDocSearch := documentationSearch[ query ] =
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

documentationSearch[ query_String ] := documentationSearch[ query ] =
    Module[ { resp, flat, items },

        resp = URLExecute[
            "https://search.wolfram.com/search-api/search.json",
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

        makeSearchResultString /@ items
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


$noDocSearchResultsString = "BEGIN_DOCUMENTATION_SEARCH_RESULTS\n(no results found)\nEND_DOCUMENTATION_SEARCH_RESULTS";

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

makeUsageString[ Cell[ BoxData @ GridBox[ grid_List, ___ ], "Usage", ___ ] ] := makeUsageString0 /@ grid;

makeUsageString[ Cell[ BoxData @ GridBox @ { { cell_, _ } }, "ObjectNameGrid", ___ ] ] :=
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
    Module[ { examples },
        examples = cellToString /@ cellFlatten @ firstMatchingCellGroup[
            nb,
            Cell[ __, "PrimaryExamplesSection", ___ ]
        ];
        If[ MatchQ[ examples, { __String } ],
            "## Examples\n\n" <> StringRiffle[ examples, "\n" ],
            ""
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cell Utilities*)

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
End[ ];
EndPackage[ ];
