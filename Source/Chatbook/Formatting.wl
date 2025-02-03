(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)
$customToolFormatter = None;
$dynamicImageScale   = 0.25;
$maxImageSize        = 800;
$maxDynamicImageSize = Ceiling[ $maxImageSize * $dynamicImageScale ];

$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "Wolfram_Language_Evaluator",
    "Wolfram_Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica",
    "WL"
];

$resultCellCache = <| |>;

sectionStyle[ 1 ] := "Title";
sectionStyle[ 2 ] := "Section";
sectionStyle[ 3 ] := "Subsection";
sectionStyle[ 4 ] := "Subsubsection";
sectionStyle[ 5 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

$tinyLineBreak = StyleBox[ "\n", "TinyLineBreak", FontSize -> 3 ];

$externalLanguages = {
    "Java",
    "Julia",
    "Jupyter",
    "NodeJS",
    "Octave",
    "Python",
    "R",
    "Ruby",
    "Shell",
    "SQL-JDBC",
    "SQL",
    "SQLite"
};

$$externalLanguage = Alternatives @@ $externalLanguages;

$externalLanguageRules = Replace[
    Flatten @ {
        "JS"         -> "NodeJS",
        "Javascript" -> "NodeJS",
        "NPM"        -> "NodeJS",
        "Node"       -> "NodeJS",
        "Bash"       -> "Shell",
        "SH"         -> "Shell",
        Cases[ $externalLanguages, lang_ :> (lang -> lang) ]
    },
    HoldPattern[ lhs_ -> rhs_ ] :> (StartOfString~~lhs~~EndOfString -> rhs),
    { 1 }
];

$$ws      = Shortest[ WhitespaceCharacter... ];
$$mdRow1  = $$ws ~~ "|" ~~ Except[ "\n" ]... ~~ "|" ~~ $$ws ~~ ("\n"|EndOfString);
$$mdRow2  = Except[ "\n" ].. ~~ Repeated[ ("|" ~~ Except[ "\n" ]...), { 2, Infinity } ] ~~ ("\n"|EndOfString);
$$mdRow   = $$mdRow1 | $$mdRow2;
$$mdTable = $$mdRow ~~ $$mdRow ..;

$$blockQuoteLine = StartOfLine ~~ ">" ~~ $$ws ~~ Except[ "\n" ].. ~~ ("\n"|EndOfString);
$$blockQuote     = Longest[ $$blockQuoteLine.. ];

$$hyphenDelimiter     = Repeated[ "-", { 3, Infinity } ];
$$asteriskDelimiter   = Repeated[ "*", { 3, Infinity } ];
$$underscoreDelimiter = Repeated[ "_", { 3, Infinity } ];
$$delimiter           = StartOfLine ~~ ($$hyphenDelimiter|$$asteriskDelimiter|$$underscoreDelimiter) ~~ EndOfLine;

$chatGeneratedCellTag = "ChatGeneratedCell";

$simpleToolMethod := $ChatHandlerData[ "ChatNotebookSettings", "ToolMethod" ] === "Simple";

$autoOperatorRenderings = <|
    "|->" -> "\[Function]",
    "->"  -> "\[Rule]",
    ":>"  -> "\[RuleDelayed]",
    "<="  -> "\[LessEqual]",
    ">="  -> "\[GreaterEqual]",
    "!="  -> "\[NotEqual]",
    "=="  -> "\[Equal]",
    "<->" -> "\[TwoWayRule]",
    "[["  -> "\[LeftDoubleBracket]",
    "]]"  -> "\[RightDoubleBracket]",
    "<|"  -> "\[LeftAssociation]",
    "|>"  -> "\[RightAssociation]"
 |>;

 $expressionURIPlaceholder = "\[LeftSkeleton]\[Ellipsis]\[RightSkeleton]";
 $freeformPromptBox        = StyleBox[ "\[FreeformPrompt]", FontColor -> RGBColor[ "#ff6f00" ], FontSize -> 9 ];


 $delimiterCell = Cell[
    BoxData @ TagBox[
        GridBox[
            { { TemplateBox[ { 0 }, "Spacer1" ] }, { TemplateBox[ { 0 }, "Spacer1" ] } },
            AutoDelete      -> False,
            GridBoxDividers -> { "Columns" -> { False, { True }, False }, "Rows" -> { False, { True }, False } },
            GridBoxItemSize -> { "Columns" -> { { Fit } }, "Rows" -> { { Automatic } } },
            FrameStyle      -> Directive[ GrayLevel[ 0.8 ], AbsoluteThickness[ 1 ] ]
        ],
        "Grid"
    ],
    "MarkdownDelimiter",
    Background           -> None,
    ShowStringCharacters -> False
];


esc[ c_ ] := "\[EntityStart]" <> IntegerString @ FromDigits[ ToCharacterCode[ c, "UTF-8" ], 255 ] <> "\[EntityEnd]";

$mdEscapedCharacters = { "`", "$", "*", "_", "#", "|" };
$$mdEscapedCharacter = Alternatives @@ Map[ "\\"<># &, $mdEscapedCharacters ];

$mdEscapeRules   = "\\" <> # -> esc @ # & /@ $mdEscapedCharacters;
$mdUnescapeRules = esc @ # -> # & /@ $mdEscapedCharacters;

(* ::**************************************************************************************************************:: *)
 (* ::Section::Closed:: *)
 (*StringToBoxes*)
StringToBoxes // beginDefinition;
StringToBoxes[ string_String? StringQ ] := catchAlways[ stringToBoxes @ string, StringToBoxes ];
StringToBoxes[ string_String? StringQ, "WL" ] := catchAlways[ wlStringToBoxes @ string, StringToBoxes ];
StringToBoxes // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CachedBoxes*)
CachedBoxes // beginDefinition;
CachedBoxes[ expr_ ] := catchMine @ cachedBoxes @ Unevaluated @ expr;
CachedBoxes // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*DisplayBase64Boxes*)
DisplayBase64Boxes // beginDefinition;
DisplayBase64Boxes[ b64_String ] := catchMine @ displayBase64Boxes @ b64;
DisplayBase64Boxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Output Formatting*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatChatOutput*)
FormatChatOutput // beginDefinition;

FormatChatOutput[ output_ ] :=
    FormatChatOutput[ output, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ];

FormatChatOutput[ output_, as_Association ] :=
    formatChatOutput[ output, Lookup[ as, "Status", "Finished" ] ];

FormatChatOutput // endDefinition;
(* TODO: actual error handling for invalid arguments *)

formatChatOutput // beginDefinition;

formatChatOutput[ output: $$progressIndicator, _ ] :=
    output;

formatChatOutput[ output_, "Waiting" ] :=
    ProgressIndicator[ Appearance -> "Percolate" ];

formatChatOutput[ output_String, "Streaming" ] :=
    Block[ { $dynamicText = True }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput[ output_String, "Finished" ] :=
    Block[ { $dynamicText = False }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*FormatToolCall*)
FormatToolCall // beginDefinition;

FormatToolCall[ string_String, parsed_ ] :=
    FormatToolCall[ string, parsed, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ];

FormatToolCall[ string_String, parsed_, info_Association ] :=
    formatToolCall[ string, parsed, Lookup[ info, "Status", "Finished" ] ];

FormatToolCall // endDefinition;


formatToolCall // beginDefinition;

formatToolCall[ string_String, parsed_, "Streaming" ] :=
    Block[ { $dynamicText = True }, formatToolCall0[ string, parsed ] ];

formatToolCall[ string_String, parsed_, "Finished" ] :=
    Block[ { $dynamicText = False }, formatToolCall0[ string, parsed ] ];

formatToolCall // endDefinition;


formatToolCall0 // beginDefinition;

formatToolCall0[ string_String, as_Association ] := makeToolCallBoxLabel @ as;

formatToolCall0[ string_String, failed_Failure ] := Framed[
    failed,
    Background   -> White,
    BaseStyle    -> "Output",
    FrameMargins -> 10,
    FrameStyle   -> GrayLevel[ 0.95 ],
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

formatToolCall0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reformatTextData*)
reformatTextData // beginDefinition;

reformatTextData[ string_String ] /; StringContainsQ[ string, $$mdEscapedCharacter ] :=
    ReplaceAll[
        reformatTextData @ StringReplace[ string, $mdEscapeRules ],
        s_String :> RuleCondition @ StringReplace[ s, $mdUnescapeRules ]
    ];

reformatTextData[ string_String ] := joinAdjacentStrings @ Flatten[
    makeResultCell /@ discardBadToolCalls @ DeleteCases[
        Quiet[
            StringSplit[
                importHTMLEntities @ string,
                $textDataFormatRules,
                IgnoreCase -> True
            ],
            RegularExpression::maxrec
        ],
        ""
    ]
];

reformatTextData[ other_ ] := other;

reformatTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*importHTMLEntities*)
importHTMLEntities // beginDefinition;

importHTMLEntities[ string_String ] := StringReplace[
    string,
    entity: ("&" ~~ Repeated[ Except[ "\n" ], { 1, 6 } ] ~~ ";") :> importHTMLEntity @ entity
];

importHTMLEntities // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importHTMLEntity*)
importHTMLEntity // beginDefinition;

importHTMLEntity[ entity_String ] := importHTMLEntity[ entity ] =
    With[ { str = Quiet @ ImportString[ ToLowerCase @ entity, "HTML" ] },
        If[ StringQ @ str, str, entity ]
    ];

importHTMLEntity // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*discardBadToolCalls*)
discardBadToolCalls // beginDefinition;

discardBadToolCalls[ {
    a___,
    tc_inlineToolCallCell,
    b: Except[ _inlineToolCallCell ]...,
    $discardPreviousToolCall,
    c___
} ] := discardBadToolCalls @ { a, $lastDiscarded = discardedMaterial[ tc, b ], c };

discardBadToolCalls[ { a: Except[ _inlineToolCallCell ]..., $discardPreviousToolCall, b___ } ] :=
    discardBadToolCalls @ { a, b };

discardBadToolCalls[ { a___, discardedMaterial[ b___ ], discardedMaterial[ c___ ], d___ } ] :=
    discardBadToolCalls @ { a, $lastDiscarded = discardedMaterial[ b, c ], d };

discardBadToolCalls[ textData_List ] :=
    textData;

discardBadToolCalls // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeResultCell*)
makeResultCell // beginDefinition;

makeResultCell[ expr_ ] /; $dynamicText :=
    Lookup[ $resultCellCache,
            HoldComplete @ expr,
            $resultCellCache[ HoldComplete @ expr ] = makeResultCell0 @ expr
    ];

makeResultCell[ expr_ ] := makeResultCell0 @ expr;

makeResultCell // endDefinition;


makeResultCell0 // beginDefinition;

makeResultCell0[ thinkingOpener[ thoughts_String ] ] := (
    If[ $thinkingStart === None, $thinkingStart = AbsoluteTime[ ] ];
    Cell[
        BoxData @ templateBox[ { StringTrim @ thoughts, "\"Thinking\[Ellipsis]\"" }, "ThinkingOpener" ],
        "ThinkingOpener",
        Background -> None
    ]
);

makeResultCell0[ thoughtsOpener[ thoughts_String ] ] :=
    Module[ { seconds, label },
        If[ $thinkingEnd === None, $thinkingEnd = AbsoluteTime[ ] ];
        seconds = If[ NumberQ @ $thinkingStart && NumberQ @ $thinkingEnd, Round[ $thinkingEnd - $thinkingStart ] ];
        label = If[ NumberQ @ seconds, "Thought for " <> ToString @ seconds <> " seconds", "Thoughts" ];
        Cell[
            BoxData @ templateBox[ { StringTrim @ thoughts, label }, "ThoughtsOpener" ],
            "ThoughtsOpener",
            Background -> None
        ]
    ];

makeResultCell0[ discardedMaterial[ stuff___ ] ] :=
    makeDiscardedMaterialCell @ stuff;

makeResultCell0[ str_String ] := formatTextString @ str;

makeResultCell0[ codeBlockCell[ language_String, code_String ] ] :=
    makeCodeBlockCell[
        StringReplace[ StringTrim @ language, $externalLanguageRules, IgnoreCase -> True ],
        StringDelete[ code, { StartOfString~~Whitespace~~StartOfLine, Whitespace~~EndOfString } ]
    ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := ReplaceAll[
    makeInlineCodeCell @ code,
    "\[FreeformPrompt]" :> RuleCondition @ $freeformPromptBox
];

makeResultCell0[ mathCell[ math_String ] ] /; StringMatchQ[ math, (DigitCharacter|"."|","|" ").. ] :=
    math;

makeResultCell0[ mathCell[ name_String ] ] /; NameQ @ name && Context @ name === "System`" && StringLength @ name > 1 :=
    makeResultCell0 @ inlineCodeCell @ name;

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = makeTeXBoxes @ math },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ toTeXBoxes @ boxes,
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ imageCell[ alt_, url_String ] ] := image[ alt, url ];

makeResultCell0[ hyperlinkCell[ label_String, url_String ] ] := hyperlink[ label, url ];

makeResultCell0[ bulletCell[ "", item_String ] ] := {
    "\n",
    Cell[
        TextData @ Flatten @ {
            StyleBox[ "\[Bullet]", FontColor -> GrayLevel[ 0.5 ] ],
            " ",
            formatTextString @ item
        },
        "InlineItem"
    ]
};

makeResultCell0[ bulletCell[ whitespace_String, item_String ] ] := {
    "\n",
    Cell[
        TextData @ Flatten @ {
            whitespace,
            StyleBox[ "\[Bullet]", FontColor -> GrayLevel[ 0.5 ] ],
            " ",
            formatTextString @ item
        },
        "InlineSubitem"
    ]
};

makeResultCell0[ sectionCell[ n_, section_String ] ] := Flatten @ {
    "\n",
    inlineSection[ section, sectionStyle @ n ]
};

makeResultCell0[ inlineToolCallCell[ string_String ] ] := (
    $lastToolCallString = string;
    $lastFormattedToolCall = inlineToolCall @ string
);

makeResultCell0[ tableCell[ string_String ] ] :=
    makeTableCell @ string;

makeResultCell0[ delimiterCell[ ] ] :=
    $delimiterCell;

makeResultCell0[ blockQuoteCell[ quote_String ] ] := Cell[
    BoxData @ GridBox[
        {
            {
                PaneBox[
                    formatTextToBoxes @ StringDelete[ StringTrim @ quote, StartOfLine ~~ ">" ~~ " "... ],
                    ImageMargins -> 5,
                    ImageSize    -> { Full, Automatic },
                    BaseStyle    -> { "Text", FontColor -> GrayLevel[ 0.35 ] }
                ]
            }
        },
        AutoDelete        -> False,
        GridBoxBackground -> { "Columns" -> { { GrayLevel[ 1 ] } } },
        GridBoxDividers   -> {
            "ColumnsIndexed" -> { 1 -> Directive[ RGBColor[ 0.87, 0.94, 1 ], AbsoluteThickness[ 4 ] ] },
            "Rows"           -> { { False } }
        },
        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
    ],
    "BlockQuote",
    Background -> None
];

makeResultCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineSection*)
inlineSection // beginDefinition;

inlineSection[ content_, style_String ] :=
    inlineSection[ content, style, sectionMargins @ style ];

inlineSection[ content_, style_String, margins: { { _, _ }, { _, _ } } ] := Cell[
    BoxData @ PaneBox[
        StyleBox[ formatTextToBoxes @ content, style, ShowStringCharacters -> False ],
        ImageMargins -> margins
    ],
    "InlineSection",
    Background -> None
];

inlineSection[ content_, style_String, { bottom_Integer, top_Integer } ] :=
    inlineSection[ content, style, { { 0, 0 }, { bottom, top } } ];

inlineSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*formatTextToBoxes*)
formatTextToBoxes // beginDefinition;
formatTextToBoxes[ text_String ] := formatTextToBoxes[ text, styleBox @ text ];
formatTextToBoxes[ text_String, formatted_String ] := ToBoxes @ formatted;
formatTextToBoxes[ text_String, data: $$textData ] := Cell[ TextData @ Flatten @ { data }, Background -> None ];
formatTextToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*sectionMargins*)
sectionMargins // beginDefinition;
sectionMargins[ "Title"|"Section"|"Subsection"|"Subsubsection" ] := { { 0, 0 }, { 5, 15 } };
sectionMargins[ _String ] := { { 0, 0 }, { 2, 5 } };
sectionMargins // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDiscardedMaterialCell*)
makeDiscardedMaterialCell // beginDefinition;

makeDiscardedMaterialCell[ stuff___ ] := {
    Cell[
        BoxData @ templateBox[
            {
                ToBoxes @ compressUntilViewed @ RawBoxes @ Cell[
                    TextData @ joinAdjacentStrings @ Flatten[ makeResultCell /@ { stuff } ],
                    "Text",
                    Background  -> None,
                    FontOpacity -> 0.5
                ]
            },
            "DiscardedMaterialOpener"
        ],
        "DiscardedMaterial",
        Background -> None
    ],
    "\n"
};

makeDiscardedMaterialCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTableCell*)
makeTableCell // beginDefinition;

makeTableCell[ table_String ] := Flatten @ {
    "\n",
    Riffle[ makeTableCell0 /@ StringSplit[ StringTrim @ table, "\n\n" ], "\n" ]
};

makeTableCell // endDefinition;


makeTableCell0 // beginDefinition;

makeTableCell0[ string_String ] :=
    makeTableCell0[ StringTrim /@ StringSplit[ StringSplit[ string, "\n" ], "|" ] ];

makeTableCell0 @ { { __String? emptyTableItemQ }, { b__String? delimiterItemQ }, items__ } :=
    Cell[ BoxData @ alignTable[ ToBoxes @ textTableForm @ { items }, { b } ], "TextTableForm" ];

makeTableCell0[ { a_List, { b__String? delimiterItemQ }, c__ } ] :=
    Cell[
        BoxData @ PaneBox[
            alignTable[ ToBoxes @ textTableForm[ { c }, TableHeadings -> { None, formatRaw /@ a } ], { b } ],
            ImageMargins -> { { 0, 0 }, { 5, 5 } }
        ],
        "TextTableForm"
    ];

makeTableCell0[ items_List ] :=
    Cell[ BoxData @ ToBoxes @ textTableForm @ items, "TextTableForm" ];

makeTableCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*alignTable*)
alignTable // beginDefinition;

alignTable[ boxes_, delimiters_List ] :=
    boxes /. HoldPattern[ ColumnAlignments -> _ ] :>
        (ColumnAlignments -> delimiterAlignment /@ delimiters);

alignTable // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*delimiterAlignment*)
delimiterAlignment[ s_String ] := delimiterAlignment @ StringSplit[ StringDelete[ s, Whitespace ], "-".. -> " " ];
delimiterAlignment[ { ":", " "      } ] := Left;
delimiterAlignment[ { ":", " ", ":" } ] := Center;
delimiterAlignment[ {      " ", ":" } ] := Right;
delimiterAlignment[ ___               ] := Center;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*textTableForm*)
textTableForm // beginDefinition;

textTableForm[ items_? MatrixQ, opts___ ] := Pane[
    Style[
        TableForm[ Map[ formatRaw, items, { 2 } ], opts ],
        "Text",
        ShowStringCharacters -> False
    ],
    ImageMargins -> { { 0, 0 }, { 5, 5 } }
];

(* Not a rectangular set of table items, so we'll pad as necessary: *)
textTableForm[ items: { __List }, opts___ ] := Enclose[
    Module[ { width, padded, trimmed },
        (* Get the maximum row length: *)
        width = ConfirmBy[ Max[ Length /@ items ], Positive, "Width" ];

        (* Pad all rows to match: *)
        padded = ConfirmBy[ PadRight[ #, width, "" ] & /@ items, MatrixQ, "Padded" ];

        (* Remove the right-most column if it just contains empty strings: *)
        trimmed = ConfirmBy[
            FixedPoint[ Replace[ i: { { __, "" }.. } :> i[[ All, 1;;-2 ]] ], padded ],
            MatrixQ,
            "Trimmed"
        ];

        (* Items are now rectangular, so proceed with previous definition: *)
        textTableForm[ trimmed, opts ]
    ],
    throwInternalFailure
];

textTableForm // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*formatRaw*)
formatRaw // beginDefinition;
formatRaw[ "" ] := "";
formatRaw[ item_String ] := formatRaw[ item, styleBox @ item ];
formatRaw[ item_, { } ] := item;
formatRaw[ item_, StyleBox[ box_ ] ] := formatRaw[ item, box ];
formatRaw[ item_, box: _ButtonBox|_Cell|_StyleBox ] := RawBoxes @ box;
formatRaw[ item_, string_String ] := string;
formatRaw[ item_, text: $$textDataList ] := RawBoxes @ Cell @ TextData @ text;
formatRaw // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Table Item String Patterns*)
$$ws            = WhitespaceCharacter...;
$$delimiterItem = $$ws ~~ (":"|"") ~~ $$ws ~~ "-".. ~~ $$ws ~~ (":"|"") ~~ $$ws;
$$delimiterRow  = $$delimiterItem ~~ ("|" ~~ $$delimiterItem)..;


emptyTableItemQ[ ""               ] := True;
emptyTableItemQ[ " "              ] := True;
emptyTableItemQ[ "\"\""           ] := True;
emptyTableItemQ[ "\" \""          ] := True;
emptyTableItemQ[ string_? StringQ ] := StringMatchQ[ StringTrim[ string, "\"" ], Whitespace ];
emptyTableItemQ[ ___              ] := False;


delimiterItemQ[ "-"              ] := True;
delimiterItemQ[ " - "            ] := True;
delimiterItemQ[ "---"            ] := True;
delimiterItemQ[ " --- "          ] := True;
delimiterItemQ[ string_? StringQ ] := StringMatchQ[ string, $$delimiterItem ];
delimiterItemQ[ ___              ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toTeXBoxes*)
toTeXBoxes // beginDefinition;

toTeXBoxes[ RawBoxes[ boxes_ ] ] := toTeXBoxes @ boxes;

toTeXBoxes[ a: TemplateBox[ KeyValuePattern[ "boxes" -> b_ ], "TeXAssistantTemplate" ] ] :=
    FormBox[ If[ TrueQ @ $dynamicText, StyleBox[ b, "TeXAssistantBoxes" ], a ], TraditionalForm ];

toTeXBoxes[ boxes_TemplateBox ] := FormBox[ boxes, TraditionalForm ];

toTeXBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatTextString*)
formatTextString // beginDefinition;

formatTextString[ str_String ] := StringSplit[
    StringReplace[
        StringDelete[
            str,
            {
                StartOfString~~("\n"...)~~"```",
                "```"~~("\n"...)~~EndOfString
            }
        ],
        {
            StartOfString~~"\n\n" -> "\n",
            "\n\n"~~EndOfString -> "\n"
        }
    ],
    $stringFormatRules,
    IgnoreCase -> True
];

formatTextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*floatingButtonGrid*)
floatingButtonGrid // beginDefinition;

floatingButtonGrid[ cell_Cell, lang_ ] /; $cloudNotebooks :=
    Grid[
        {
            {
                button[ evaluateLanguageLabel[ lang, False ], insertCodeBelow[ EvaluationCell[ ], True ] ],
                button[ $insertInputButtonLabel, insertCodeBelow[ EvaluationCell[ ], False ] ],
                button[ $copyToClipboardButtonLabel, copyCodeBlock @ EvaluationCell[ ] ]
            }
        },
        Alignment  -> Top,
        Spacings   -> 0.2,
        FrameStyle -> GrayLevel[ 0.85 ]
    ];

floatingButtonGrid[ cell_Cell, lang_ ] :=
    Module[ { cellObj },
        cellObj = topParentCell @ EvaluationCell[ ];
        Grid[
            {
                checkTemplateBoxes @ If[ TrueQ @ CurrentChatSettings[ cellObj, "WorkspaceChat" ],
                    {
                        button[ $copyToClipboardButtonLabelWorkspaceChat, copyCodeBlock @ EvaluationCell[ ] ],
                        button[ evaluateLanguageLabel[ lang, True ], insertCodeBelow[ EvaluationCell[ ], True ] ]
                    },
                    {
                        button[ evaluateLanguageLabel[ lang, False ], insertCodeBelow[ EvaluationCell[ ], True ] ],
                        button[ $insertInputButtonLabel, insertCodeBelow[ EvaluationCell[ ], False ] ],
                        button[ $copyToClipboardButtonLabel, copyCodeBlock @ EvaluationCell[ ] ]
                    }
                ]
            },
            Alignment  -> Top,
            Spacings   -> 0.2,
            FrameStyle -> GrayLevel[ 0.85 ]
        ]
    ];

(* TODO: I'm assuming this still works on the cloud as written *)
(* For cloud notebooks (no attached cell) *)
floatingButtonGrid[ string_, lang_ ] := RawBoxes @ templateBox[
    {
        ToBoxes @ Grid[
            {
                checkTemplateBoxes @ {
                    button[ evaluateLanguageLabel[ lang, False ], insertCodeBelow[ string, True ] ],
                    button[ $insertInputButtonLabel, insertCodeBelow[ string, False ] ],
                    button[ $copyToClipboardButtonLabel, copyCodeBlock @ string ]
                }
            },
            Alignment  -> Top,
            Spacings   -> 0.2,
            FrameStyle -> GrayLevel[ 0.85 ]
        ]
    },
    "ChatCodeBlockButtonPanel"
];

floatingButtonGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkTemplateBoxes*)
checkTemplateBoxes // beginDefinition;
checkTemplateBoxes[ boxes_ ] := checkTemplateBoxes[ boxes, $InlineChat ];
checkTemplateBoxes[ boxes_, True ] := checkTemplateBoxes[ Verbatim @ boxes, True ] = inlineTemplateBoxes @ boxes;
checkTemplateBoxes[ boxes_, _ ] := boxes;
checkTemplateBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateLanguageLabel*)
evaluateLanguageLabel[ name_String, False ] :=
    With[ { icon = $languageIcons @ name },
        fancyTooltip[
            MouseAppearance[
                buttonMouseover[
                    buttonFrameDefault[ buttonPane @ icon, False ],
                    buttonFrameActive[ buttonPane @ icon, False ]
                ],
                "LinkHand"
            ],
            tr[ "FormattingInsertContentAndEvaluateTooltip" ]
        ] /; MatchQ[ icon, _Graphics | _Image | _Dynamic ]
    ];

evaluateLanguageLabel[ name_String, True ] :=
    Catch @ Module[ { wl, icon, labeled },

        wl = wolframLanguageQ @ name;
        icon = If[ wl, chatbookExpression[ "WorkspaceCodeBlockInsertAndEvaluate" ], $languageIcons @ name ];
        If[ ! MatchQ[ icon, _Graphics | _Dynamic | _Image | _RawBoxes ], Throw @ $insertEvaluateButtonLabel ];
        labeled = labeledIcon[ icon, "FormattingInsertContentAndEvaluateLabel" ];

        fancyTooltip[
            MouseAppearance[
                buttonMouseover[ buttonFrameDefault[ labeled, True ], buttonFrameActive[ labeled, True ] ],
                "LinkHand"
            ],
            targetNotebookLabel @ EvaluationNotebook[ ]
        ]
    ];

evaluateLanguageLabel[ ___ ] := $insertEvaluateButtonLabel;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*targetNotebookLabel*)
targetNotebookLabel // beginDefinition;

targetNotebookLabel[ nbo_NotebookObject ] :=
    targetNotebookLabel[ nbo, GetFocusedNotebook @ nbo ];

targetNotebookLabel[ nbo_, None ] :=
    tr[ "FormattingInsertContentAndEvaluateWorkspaceChatTooltipNew" ];

targetNotebookLabel[ nbo_, focused_NotebookObject ] :=
    targetNotebookLabel[ nbo, focused, AbsoluteCurrentValue[ focused, WindowTitle ] ];

targetNotebookLabel[ nbo_, focused_NotebookObject, title_ ] :=
    Row @ Flatten @ {
        trExprTemplate[ "FormattingInsertContentAndEvaluateWorkspaceChatTooltip" ][ <|
            "1" -> {
                chatbookExpression[ "WorkspaceFocusIndicatorNotebook" ],
                "\[ThinSpace]",
                Style[ formatNotebookTitle @ title, FontWeight -> Bold ]
            }
        |> ]
    };

targetNotebookLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Buttons*)
(* FIXME: move this stuff to the stylesheet *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Labels*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$copyToClipboardButtonLabel*)
$copyToClipboardButtonLabel := $copyToClipboardButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyClipboard", "FormattingCopyToClipboardLabel" ],
            buttonFrameActive @ labeledIcon[ "AssistantCopyClipboard", "FormattingCopyToClipboardLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingCopyToClipboardTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$copyToClipboardButtonLabelWorkspaceChat*)
$copyToClipboardButtonLabelWorkspaceChat := $copyToClipboardButtonLabelWorkspaceChat = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ { "WorkspaceCodeBlockCopy", False }, "FormattingCopyToClipboardLabel" ],
            buttonFrameActive @ labeledIcon[ { "WorkspaceCodeBlockCopy", False }, "FormattingCopyToClipboardLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingCopyToClipboardTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertInputButtonLabel*)
$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyBelow", "FormattingInsertContentLabel" ],
            buttonFrameActive @ labeledIcon[ "AssistantCopyBelow", "FormattingInsertContentLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertInputButtonLabelWorkspaceChat*)
$insertInputButtonLabelWorkspaceChat := $insertInputButtonLabelWorkspaceChat = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantCopyRight", "FormattingInsertContentLabel" ],
            buttonFrameActive @ labeledIcon[ "AssistantCopyRight", "FormattingInsertContentLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertEvaluateButtonLabel*)
$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ labeledIcon[ "AssistantEvaluate", "FormattingInsertContentAndEvaluateLabel" ],
            buttonFrameActive @ labeledIcon[ "AssistantEvaluate", "FormattingInsertContentAndEvaluateLabel" ]
        ],
        "LinkHand"
    ],
    tr[ "FormattingInsertContentAndEvaluateTooltip" ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCodeBelow*)
insertCodeBelow // beginDefinition;

insertCodeBelow[ code_ ] := insertCodeBelow[ code, False ];

insertCodeBelow[ cell_CellObject, evaluate_ ] :=
    If[ TrueQ @ CurrentChatSettings[ cell, "WorkspaceChat" ],
        insertCodeInUserNotebook[ parentNotebook @ cell, getCodeBlockContent @ cell, evaluate ],
        insertCodeBelow[ getCodeBlockContent @ cell, evaluate ]
    ];

insertCodeBelow[ cell_Cell, evaluate_ ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo = parentNotebook @ cellObj;
        If[ TrueQ @ CurrentChatSettings[ cellObj, "WorkspaceChat" ],
            insertCodeInUserNotebook[ nbo, getCodeBlockContent @ cell, evaluate ]
            ,
            insertAfterChatGeneratedCells[ cellObj, getCodeBlockContent @ cell ];
            If[ TrueQ @ evaluate,
                selectionEvaluateCreateCell @ nbo,
                SelectionMove[ nbo, After, CellContents ]
            ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_ ] :=
    insertCodeBelow[ reparseCodeBoxes @ Cell[ BoxData @ string, "Input" ], evaluate ];

insertCodeBelow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCodeInUserNotebook*)
insertCodeInUserNotebook // beginDefinition;

insertCodeInUserNotebook[ chatNB_NotebookObject, cell_Cell, evaluate_ ] := Enclose[
    Module[ { nbo, cellObj },
        nbo = ConfirmMatch[ getNotebookForCodeInsertion @ chatNB, _NotebookObject, "UserNotebook" ];
        cellObj = ConfirmMatch[ getLastSelectedCell @ nbo, _CellObject|None, "SelectedCell" ];

        If[ cellObj === None
            ,
            SelectionMove[ nbo, After, Cell, AutoScroll -> True ];
            NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ]
            ,
            insertAfterChatGeneratedCells[ cellObj, cell ]
        ];

        SetSelectedNotebook @ nbo;

        If[ TrueQ @ evaluate,
            selectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ],
    throwInternalFailure
];

insertCodeInUserNotebook[ chatNB_NotebookObject, code_String, evaluate_ ] :=
    insertCodeInUserNotebook[ chatNB, reparseCodeBoxes @ Cell[ BoxData @ code, "Input" ], evaluate ];

insertCodeInUserNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachCopiedTooltip*)
attachCopiedTooltip // beginDefinition;

attachCopiedTooltip[ ] :=
    AttachCell[
        EvaluationBox[ ],
        Cell[ BoxData[
            PaneBox[
                PanelBox[
                 GridBox[{{PaneBox[
                     DynamicBox[
                      StyleBox[
                       FEPrivate`ImportImage[
                        FrontEnd`FileName[{"Typeset", "ClickToCopy"}, "Checkmark.png"]],
                        Magnification -> 0.5`]],
                     BaselinePosition -> Scaled[0.1`] -> Baseline],
                    DynamicBox[
                     ToBoxes[FEPrivate`FrontEndResource["FEStrings",
                       "clicktocopyDoneTooltip"], StandardForm]]}},
                  GridBoxAlignment -> {"Columns" -> {{Left}}, "Rows" -> {{Baseline}}},
                   GridBoxItemSize -> {"Columns" -> {{Automatic}},
                    "Rows" -> {{Automatic}}},
                  GridBoxSpacings -> {"Columns" -> {{0.3`}}, "Rows" -> {{0}}}],
                 Alignment -> Center,
                 Appearance -> {"Default" ->
                    FrontEnd`FileName[{"Chatbook"}, "CopyTooltip.9.png"]}, ImageSize -> {100, Automatic},
                 FrameMargins -> {{0, 0}, {0, 0}},
                 BaseStyle -> {LineBreakWithin -> Automatic,
                   LinebreakAdjustments -> {1.`, 10, 1, 0, 1}, LineIndent -> 0,
                   Hyphenation -> False,
                   HyphenationOptions -> {"HyphenationCharacter" -> "\[Null]"},
                   FontFamily -> "Source Sans Pro", FontSize -> 12,
                   FontColor -> GrayLevel[0.5]}],
                Alignment    -> { Center, Bottom },
                FrameMargins -> 0,
                ImageSize    -> { All, 60 }
            ]
        ] ],
        { Center, Bottom }, Offset[ { 0, -7 }, Automatic ], { Center, Center },
        RemovalConditions -> { "MouseExit" }
    ];

attachCopiedTooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*copyCodeBlock*)
copyCodeBlock // beginDefinition;
copyCodeBlock[ cell_CellObject ] := copyCodeBlock @ getCodeBlockContent @ cell;
copyCodeBlock[ code_String ] := (CopyToClipboard @ code; attachCopiedTooltip[ ]);
copyCodeBlock[ Cell[ BoxData[ cell_Cell, ___ ] ] ] := copyCodeBlock @ cell;
copyCodeBlock[ Cell[ code_String, ___ ] ] := copyCodeBlock @ code;
copyCodeBlock[ cell0_Cell ] := With[ { cell = getCodeBlockContent @ cell0 }, copyCodeBlock @ cell /; cell =!= cell0 ];
copyCodeBlock[ cell_Cell ] := (CopyToClipboard @ cell; attachCopiedTooltip[ ]);
copyCodeBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getNotebookForCodeInsertion*)
getNotebookForCodeInsertion // beginDefinition;
getNotebookForCodeInsertion[ chatNB_NotebookObject ] := getNotebookForCodeInsertion[ chatNB, GetFocusedNotebook @ chatNB ];
getNotebookForCodeInsertion[ _, userNB_NotebookObject ] := userNB;
getNotebookForCodeInsertion[ _, None ] := CreateNotebook[ ];
getNotebookForCodeInsertion // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getLastSelectedCell*)
getLastSelectedCell // beginDefinition;
getLastSelectedCell[ nbo_NotebookObject ] := getLastSelectedCell @ SelectedCells @ nbo;
getLastSelectedCell[ { ___, cell_CellObject } ] := cell;
getLastSelectedCell[ _ ] := None;
getLastSelectedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertAfterChatGeneratedCells*)
insertAfterChatGeneratedCells // beginDefinition;

(* FIXME: outputs do not inherit the "ChatGeneratedCell" tag from inputs in cloud notebooks, so this is a workaround *)
insertAfterChatGeneratedCells[ cellObj_CellObject, cell_Cell ] /; $cloudNotebooks := Enclose[
    Module[ { nbo },
        nbo = ConfirmMatch[ parentNotebook @ cellObj, _NotebookObject, "ParentNotebook" ];
        SelectionMove[ cellObj, After, CellContents ];
        SelectionMove[ nbo, All, Cell ];
        (* If the selection is in the next chat input cell, create cell immediately before so the next chat input
           stays at the bottom *)
        If[ MatchQ[ NotebookRead @ nbo, Cell[ _, "ChatInput", ___ ] ],
            SelectionMove[ nbo, Before, Cell ],
            SelectionMove[ nbo, After, Cell ]
        ];
        NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ];
    ],
    throwInternalFailure
];

insertAfterChatGeneratedCells[ cellObj_CellObject, cell_Cell ] := Enclose[
    Module[ { nbo, allCells, cellsAfter, taggedQ, tagged, generated, skip, skipped, insertionPoint },

        nbo        = ConfirmMatch[ parentNotebook @ cellObj, _NotebookObject, "ParentNotebook" ];
        allCells   = ConfirmMatch[ Cells @ nbo, { __CellObject }, "AllCells" ];
        cellsAfter = Replace[ allCells, { { ___, cellObj, after___ } :> { after }, _ :> { } } ];
        taggedQ    = MemberQ[ Flatten @ List @ #, $chatGeneratedCellTag ] &;

        tagged = ConfirmBy[
            AssociationThread[ cellsAfter -> taggedQ /@ CurrentValue[ cellsAfter, CellTags ] ],
            AssociationQ,
            "Tagged"
        ];

        generated = ConfirmBy[
            AssociationThread[ cellsAfter -> CurrentValue[ cellsAfter, GeneratedCell ] ],
            AssociationQ,
            "Generated"
        ];

        skip = ConfirmBy[
            Merge[ { tagged, generated }, Apply @ Or ],
            AssociationQ,
            "Skip"
        ];

        skipped = ConfirmBy[ TakeWhile[ skip, TrueQ ], AssociationQ, "Inserted" ];
        insertionPoint = ConfirmMatch[ Last[ Keys @ skipped, cellObj ], _CellObject, "InsertionPoint" ];

        SelectionMove[ insertionPoint, After, Cell ];
        NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ];
    ],
    throwInternalFailure
];

insertAfterChatGeneratedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*copyCode*)
copyCode // beginDefinition;
copyCode[ cell_CellObject ] := copyCode @ getCodeBlockContent @ cell;
copyCode[ code: _Cell|_String ] := CopyToClipboard @ stripMarkdownBoxes @ code;
copyCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessInsertedCell*)
preprocessInsertedCell // beginDefinition;
preprocessInsertedCell[ cell_ ] := addInsertedCellTags @ stripMarkdownBoxes @ cell;
preprocessInsertedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addInsertedCellTags*)
addInsertedCellTags // beginDefinition;

addInsertedCellTags[ Cell[ a__, CellTags -> tag_String, b___ ] ] :=
    addInsertedCellTags @ Cell[ a, CellTags -> { tag }, b ];

addInsertedCellTags[ Cell[ a__, CellTags -> { tags___String }, b___ ] ] :=
    Cell[ a, CellTags -> DeleteDuplicates @ { $chatGeneratedCellTag, tags }, b ];

addInsertedCellTags[ Cell[ a: Except[ CellTags -> _ ].. ] ] :=
    Cell[ a, CellTags -> { $chatGeneratedCellTag } ];

addInsertedCellTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripMarkdownBoxes*)
stripMarkdownBoxes // beginDefinition;

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ TooltipBox[ boxes_, _String ], "MarkdownImage", ___ ], ___ ], a___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ boxes_, "MarkdownImage", ___ ], a___ ], ___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ expr: _Cell|_String ] :=
    expr;

stripMarkdownBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCodeBlockContent*)
getCodeBlockContent // beginDefinition;
getCodeBlockContent[ cell_CellObject ] := getCodeBlockContent @ NotebookRead @ cell;
getCodeBlockContent[ Cell[ BoxData[ boxes_, ___ ], ___, "ChatCodeBlock", ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ TemplateBox[ { boxes_, ___ }, "ChatCodeBlockTemplate", ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ Cell[ BoxData[ boxes_, ___ ] ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ DynamicModuleBox[ _, boxes_, ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ TagBox[ boxes_, _EventHandlerTag, ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ Cell[ boxes_, "ChatCode", "Input", ___ ] ] := reparseCodeBoxes @ Cell[ boxes, "Input" ];

getCodeBlockContent[ Cell[ boxes_, "ExternalLanguage", ___, CellEvaluationLanguage -> lang_, ___ ] ] :=
    Cell[ boxes, "ExternalLanguage", CellEvaluationLanguage -> lang ];

getCodeBlockContent[ cell: Cell[ _, _String, ___ ] ] := cell;

getCodeBlockContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reparseCodeBoxes*)
reparseCodeBoxes // beginDefinition;

reparseCodeBoxes[ Cell[ BoxData[ s_String ], a___ ] ] /; $cloudNotebooks :=
    Cell[ BoxData @ usingFrontEnd @ stringToBoxes @ s, a ];

reparseCodeBoxes[ cell_Cell ] :=
    cell;

reparseCodeBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*button*)
button // beginDefinition;
button // Attributes = { HoldRest };

button[ label_, code_, opts___ ] := Button[
    label, code, opts,
    Appearance -> Dynamic @ FEPrivate`FrontEndResource[ "FEExpressions", "SuppressMouseDownNinePatchAppearance" ],
    BaselinePosition -> Baseline
];

button // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonMouseover*)
buttonMouseover[ a_, b_ ] := Mouseover[ a, b, BaselinePosition -> Baseline ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameDefault*)
buttonFrameDefault[ expr_, extendMarginsQ: True|False : True ] :=
    Framed[
        expr,
        FrameStyle       -> None,
        Background       -> None,
        BaselinePosition -> Baseline,
        FrameMargins     -> If[ extendMarginsQ, { { 0, 4 }, { 0, 0 } }, 0 ], (* If there's text then we need larger right-margins *)
        RoundingRadius   -> 3
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameActive*)
buttonFrameActive[ expr_, extendMarginsQ: True|False : True ] :=
    Framed[
        expr,
        FrameStyle       -> RGBColor[ "#d4e5ed" ],
        Background       -> GrayLevel[ 1 ],
        BaselinePosition -> Baseline,
        FrameMargins     -> If[ extendMarginsQ, { { 0, 4 }, { 0, 0 } }, 0 ], (* If there's text then we need larger right-margins *)
        RoundingRadius   -> 3
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonPane*)
buttonPane[ expr_ ] :=
    Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center }, BaselinePosition -> Baseline ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*labeledIcon*)
labeledIcon // beginDefinition;


labeledIcon[ iconTemplateName_String, textResource_String ] :=
    labeledIcon[ { iconTemplateName, True }, textResource ];


labeledIcon[ { iconTemplateName_String, useTemplateBoxQ_ }, textResource_String ] :=
    labeledIcon[
        If[ useTemplateBoxQ,
            RawBoxes @ templateBox[ { }, iconTemplateName ],
            chatbookExpression @ iconTemplateName
        ],
        textResource
    ];


labeledIcon[ icon_, textResource_String ] := Grid[
    {
        {
            buttonPane @ icon,
            Style[
                tr @ textResource,
                FontColor  -> RGBColor[ "#333333" ],
                FontFamily -> "Source Sans Pro",
                FontSize   -> 12
            ]
        }
    },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 2 },
    Spacings         -> { 0, 0 }
];


labeledIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fancyTooltip*)
fancyTooltip[ expr_, tooltip_ ] := Tooltip[
    expr,
    Framed[
        Style[
            tooltip,
            "Text",
            FontColor    -> RGBColor[ 0.53725, 0.53725, 0.53725 ],
            FontSize     -> 12,
            FontWeight   -> "Plain",
            FontTracking -> "Plain"
        ],
        Background   -> RGBColor[ 0.96078, 0.96078, 0.96078 ],
        FrameStyle   -> RGBColor[ 0.89804, 0.89804, 0.89804 ],
        FrameMargins -> 8
    ],
    TooltipDelay -> 0.15,
    TooltipStyle -> { Background -> None, CellFrame -> 0 }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing Rules*)
$$endToolCall       = Longest[ "ENDRESULT" ~~ (("(" ~~ (LetterCharacter|DigitCharacter).. ~~ ")") | "") ];
$$eol               = " "... ~~ "\n";
$$cmd               = Repeated[ Except[ WhitespaceCharacter ], { 1, 80 } ];
$$simpleToolCommand = StartOfLine ~~ $$ws ~~ ("/" ~~ $$cmd) ~~ $$eol;
$$simpleToolCall    = Shortest[ $$simpleToolCommand ~~ ___ ~~ ($$endToolCall|EndOfString) ];

(* TODO:
    Maybe it would be simpler to use a regex here? The command string part would need to be dynamically generated.
    RegularExpression["(?m)^(\\/wl|\\/wa)\\n(((?!\\/).*\\n)*?)\\/exec$"] :> simpleToolCallCell["$1", "$2"]
*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$textDataFormatRules*)
$textDataFormatRules = {
    "<think>"~~thoughts__~~"</think>" :> thoughtsOpener @ thoughts,
    "<think>"~~thoughts__~~EndOfString :> thinkingOpener @ thoughts,

    StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        ("```"|EndOfString)
    ] /; StringFreeQ[ code, ("TOOLCALL:" ~~ ___ ~~ ($$endToolCall|EndOfString))|$$simpleToolCall ] :>
        If[ StringMatchQ[ code, $$mdTable ],
            tableCell @ code,
            codeBlockCell[ language, code ]
        ]
    ,
    Longest @ StringExpression[
        (("```" ~~ Except[ "\n" ]... ~~ (" "...) ~~ "\n"))|"",
        tool: ("TOOLCALL:" ~~ Shortest[ ___ ] ~~ ($$endToolCall|EndOfString))
    ] :> inlineToolCallCell @ tool
    ,
    Longest @ StringExpression[
        (("```" ~~ Except[ "\n" ]... ~~ (" "...) ~~ "\n"))|"",
        tool: $$simpleToolCall
     ] /; ! StringStartsQ[ tool, $$ws ~~ "/retry" ~~ $$eol ] :> inlineToolCallCell @ tool
    ,
    StartOfLine ~~ "/retry" ~~ (WhitespaceCharacter|EndOfString) :> $discardPreviousToolCall
    ,
    "![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")" /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            imageCell[ alt, url ]
    ,
    ("\n"|StartOfString).. ~~ w:" "... ~~ ("* "|"- ") ~~ item: Longest[ Except[ "\n" ].. ] :>
        bulletCell[ w, item ]
    ,
    ("\n"|StartOfString).. ~~ h:"#".. ~~ " " ~~ sec: Longest[ Except[ "\n" ].. ] :>
        sectionCell[ StringLength @ h, sec ]
    ,
    $$delimiter :> delimiterCell[ ]
    ,
    table: $$mdTable :> tableCell @ table
    ,
    quote: $$blockQuote :> blockQuoteCell @ quote
    ,
    "[`" ~~ label: Except[ "[" ].. ~~ "`](" ~~ url: Except[ ")" ].. ~~ ")" :> "[" <> label <> "]("<>url<>")",

    "``" ~~ code__ ~~ "``" /; StringFreeQ[ code, "``" ] :> inlineCodeCell @ code,
    "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`" /; inlineSyntaxQ @ code :> inlineCodeCell @ code,
    "`" ~~ code: Except[ "`"|"\n" ].. ~~ "`" :> inlineCodeCell @ code,
    "$$" ~~ math__ ~~ "$$" /; StringFreeQ[ math, "$$" ] :> mathCell @ math,
    "\\(" ~~ math__ ~~ "\\)" /; StringFreeQ[ math, "\\)" ] :> mathCell @ math,
    "\\[" ~~ math__ ~~ "\\]" /; StringFreeQ[ math, "\\]" ] :> mathCell @ math,
    "$" ~~ math: Except[ "$" ].. ~~ "$" /; probablyMathQ @ math :> mathCell @ math
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolShortNameQ*)
toolShortNameQ // beginDefinition;
toolShortNameQ[ cmd_String ] := MatchQ[ $ChatHandlerData[ "ToolShortNames" ][ cmd ], _LLMTool ];
toolShortNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$dynamicSplitRules*)

(* Defines safe points to split content into static/dynamic parts. These patterns must be different from
   `$textDataFormatRules`, since there will be no additional formatting passes once static content is written.
   Therefore, some of the patterns that would match up to `EndOfString` must instead be explicitly terminated here.
*)
$dynamicSplitRules = {
    (* Code blocks *)
    s: StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        "```"
    ] /; StringFreeQ[ code, "TOOLCALL:" ~~ ___ ~~ ($$endToolCall|EndOfString) ] :> s
    ,
    (* Markdown image *)
    s: ("![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")") /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            s
    ,
    (* Tool call *)
    s: Shortest[ "TOOLCALL:" ~~ ___ ~~ $$endToolCall ] :> s,
    s: Shortest[ $$simpleToolCommand ~~ ___ ~~ $$endToolCall ] :> s
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$stringFormatRules*)
$stringFormatRules = {
    "```" ~~ code: Except[ "\n" ].. ~~ "```" :> inlineCodeCell @ code,

    "***" ~~ text: Except[ "*" ].. ~~ "***" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    "___" ~~ text: Except[ "_" ].. ~~ "___" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    "**" ~~ text: Except[ "*" ].. ~~ "**" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold ],

    "__" ~~ text: Except[ "_" ].. ~~ "__" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold ],

    "~~" ~~ text: Except[ "~" ].. ~~ "~~" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontVariations -> { "StrikeThrough" -> True } ],

    "``" ~~ code__ ~~ "``" /; StringFreeQ[ code, "``" ] :>
        makeResultCell @ inlineCodeCell @ code,

    "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`" /; inlineSyntaxQ @ code :>
        makeResultCell @ inlineCodeCell @ code,

    "`" ~~ code: Except[ "`"|"\n" ].. ~~ "`" :>
        makeResultCell @ inlineCodeCell @ code,

    "*" ~~ text: Except[ "*" ].. ~~ "*" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "_" ~~ text: Except[ "_" ].. ~~ "_" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "$$" ~~ math__ ~~ "$$" /; StringFreeQ[ math, "$$" ] :>
        makeResultCell @ mathCell @ math,

    "\\(" ~~ math__ ~~ "\\)" /; StringFreeQ[ math, "\\)" ] :>
        makeResultCell @ mathCell @ math,

    "\\[" ~~ math__ ~~ "\\]" /; StringFreeQ[ math, "\\]" ] :>
        makeResultCell @ mathCell @ math,

    "$" ~~ math: Except[ "$" ].. ~~ "$" /; probablyMathQ @ math :>
        makeResultCell @ mathCell @ math,

    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :>
        hyperlink[ label, url ],

    "\\textit{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "\\textbf{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :>
        styleBox[ text, FontWeight -> Bold ],

    "\[FreeformPrompt]" :>
        Cell @ BoxData @ TemplateBox[
            { $freeformPromptBox, "paclet:guide/KnowledgeRepresentationAndAccess#203374175" },
            "HyperlinkPaclet"
        ],

    StringExpression[
        "<!",
        uri: (Repeated[ LetterCharacter, { 1, 20 } ] ~~ "://content-" ~~ Repeated[ LetterCharacter|DigitCharacter, 5 ]),
        "!>"
    ] :> image[ None, uri ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatted Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCodeBlockCell*)
makeCodeBlockCell // beginDefinition;
makeCodeBlockCell[ _, code_String ] /; StringMatchQ[ StringTrim @ code, "!["~~__~~"]("~~__~~")" ] := image @ code;
makeCodeBlockCell[ _, code_String ] /; StringStartsQ[ StringTrim @ code, "TOOLCALL: " ] := inlineToolCall @ code;
makeCodeBlockCell[ language_String, code_String ] := makeInteractiveCodeCell[ language, stripCodePadding @ code ];
makeCodeBlockCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripCodePadding*)
stripCodePadding // beginDefinition;

stripCodePadding[ code_String ] :=
    Catch @ Module[ { padding, split },
        padding = First[ StringCases[ code, StartOfString~~Whitespace, 1 ], Throw @ code ];
        split = StringSplit[ code, "\n" ];
        If[ AllTrue[ split, StringMatchQ[ #, WhitespaceCharacter... ] || StringStartsQ[ #, padding ] & ],
            StringDelete[ code, StartOfLine~~padding ],
            code
        ]
    ];

stripCodePadding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineToolCall*)
inlineToolCall // beginDefinition;

inlineToolCall[ string_String ] :=
    inlineToolCall[ string, parseToolCallString @ string ];

inlineToolCall[ string_String, as_ ] :=
    With[ { formatter = $ChatHandlerData[ "ChatNotebookSettings", "ProcessingFunctions", "FormatToolCall" ] },
        makeInlineToolCallCell[
            formatter[ string, as ],
            string,
            as
        ] /; MatchQ[ formatter, Except[ None | _Missing ] ]
    ];

inlineToolCall[ string_String, as_ ] :=
    makeInlineToolCallCell[
        FormatToolCall[ string, as, <| "Status" -> If[ TrueQ @ $dynamicText, "Streaming", "Finished" ] |> ],
        string,
        as
    ];

inlineToolCall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInlineToolCallCell*)
makeInlineToolCallCell // beginDefinition;

makeInlineToolCallCell[ expr_, string_, as_Association ] := Cell[
    BoxData @ inlineChatbookExpressions @ ToBoxes @ expr,
    "InlineToolCall",
    Background   -> None,
    TaggingRules -> KeyDrop[ as, { "Icon", "Result" } ]
];

makeInlineToolCallCell[ expr_, string_String, failed_Failure ] := Cell[
    BoxData @ inlineChatbookExpressions @ ToBoxes @ expr,
    "FailedToolCall",
    Background   -> None,
    TaggingRules -> <| "ToolCall" -> string |>
];

makeInlineToolCallCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseToolCallString*)
parseToolCallString // beginDefinition;
parseToolCallString[ string_String ] := parseToolCallString[ parseToolCallID @ string, string ];
parseToolCallString[ id_String, string_String ] := parseFullToolCallString[ id, string ];
parseToolCallString[ _Missing, string_String ] := parsePartialToolCallString @ string;
parseToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parsePartialToolCallString*)
parsePartialToolCallString // beginDefinition;

(* TODO: define a `parsePartialSimpleToolCallString` that can also be used in `simpleToolRequestParser` *)

parsePartialToolCallString[ string_String ] /; $simpleToolMethod := Enclose[
    Module[ { command, argString, tool, name, paramNames, params, result },
        command = ConfirmBy[
            StringReplace[
                string,
                StartOfString ~~ $$ws ~~ ("/" ~~ cmd: $$cmd) ~~ $$eol ~~ ___ :> cmd
            ],
            toolShortNameQ,
            "Command"
        ];

        argString = First[
            StringCases[
                string,
                Shortest @ StringExpression[
                    StartOfString,
                    $$ws,
                    "/",
                    command,
                    WhitespaceCharacter...,
                    "\n",
                    a___,
                    "/exec"|EndOfString
                ] :> a,
                1
            ],
            Missing[ ]
        ];

        tool = ConfirmMatch[ $ChatHandlerData[ "ToolShortNames" ][ command ], _LLMTool, "Tool" ];
        name = ConfirmBy[ toolName @ tool, StringQ, "ToolName" ];

        If[ StringQ @ argString,
            paramNames = Keys @ ConfirmMatch[ tool[ "Parameters" ], KeyValuePattern @ { }, "ParameterNames" ];
            params = ConfirmBy[
                parseSimpleToolCallParameterStrings[ paramNames, argString ],
                AssociationQ,
                "Parameters"
            ]
            ,
            params = <| |>
        ];

        result = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        DeleteMissing @ <|
            "Name"        -> name,
            "DisplayName" -> getToolDisplayName @ tool,
            "Icon"        -> getToolIcon @ tool,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> params,
            "Result"      -> result
        |>
    ],
    throwInternalFailure
];

parsePartialToolCallString[ string_String ] /; StringMatchQ[ string, "TOOLCALL:"~~__~~"{"~~___ ] :=
    Module[ { noPrefix, noSuffix, name, tool, displayName, icon, query, result },

        noPrefix    = StringDelete[ string, StartOfString~~"TOOLCALL:" ];
        noSuffix    = StringTrim @ StringDelete[ noPrefix, "ENDRESULT"~~___~~EndOfString ];
        name        = StringTrim @ StringDelete[ noSuffix, ("\n"|"{")~~___~~EndOfString ];
        tool        = getToolByName @ name;
        displayName = getToolDisplayName[ tool, name ];
        icon        = getToolIcon @ tool;
        query       = First[ StringCases[ string, "TOOLCALL:" ~~ q___ ~~ "\nRESULT" :> q ], "" ];
        result      = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        <|
            "Name"        -> name,
            "DisplayName" -> displayName,
            "Icon"        -> icon,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> StringTrim @ query,
            "Result"      -> StringTrim @ result
        |>
    ];

parsePartialToolCallString[ string_String ] := <| "ToolCall" -> StringTrim @ string |>;

parsePartialToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseFullToolCallString*)
parseFullToolCallString // beginDefinition;

parseFullToolCallString[ id_String, string_String ] :=
    parseFullToolCallString[ id, $toolEvaluationResults[ id ], string ];

parseFullToolCallString[ id_, _Missing, string_String ] :=
    parsePartialToolCallString @ string;

parseFullToolCallString[ id_, failed_Failure, string_String ] :=
    failed;

parseFullToolCallString[ id_String, resp: HoldPattern[ _LLMToolResponse ], string_String ] :=
    parseFullToolCallString[
        id,
        resp[ "Tool" ],
        resp[ "InterpretedParameterValues" ],
        resp[ "Output" ],
        string
    ];

parseFullToolCallString[ id_String, tool: HoldPattern[ _LLMTool ], parameters_Association, output_, string_ ] :=
    $lastFullParsed = <|
        "ID"                 -> id,
        "Name"               -> toolName @ tool,
        "DisplayName"        -> getToolDisplayName @ tool,
        "Icon"               -> getToolIcon @ tool,
        "FormattingFunction" -> getToolFormattingFunction @ tool,
        "ToolCall"           -> StringTrim @ string,
        "Parameters"         -> parameters,
        "Result"             -> output,
        "Open"               -> TrueQ @ $openToolCallBoxes
    |>;

parseFullToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*parseToolCallID*)
parseToolCallID // beginDefinition;

parseToolCallID[ string_String? StringQ ] :=
    Replace[
        StringReplace[
            string,
            {
                StringExpression[
                    StartOfString,
                    WhitespaceCharacter...,
                    Alternatives[
                        "TOOLCALL:",
                        StartOfLine ~~ "/" ~~ cmd: Except[ WhitespaceCharacter ].. ~~ WhitespaceCharacter... ~~ "\n"
                    ],
                    ___,
                    "ENDRESULT(",
                    hex: (LetterCharacter|DigitCharacter)..,
                    ")",
                    WhitespaceCharacter...,
                    EndOfString
                ] :> hex,
                StartOfString ~~ ___ ~~ EndOfString :> ""
            }
        ],
        "" -> Missing[ "NotAvailable" ]
    ];

parseToolCallID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*fullToolCallStringQ*)
fullToolCallStringQ // beginDefinition;
fullToolCallStringQ[ string_String? StringQ ] := StringQ @ parseToolCallID @ string;
fullToolCallStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallBoxLabel*)
makeToolCallBoxLabel // beginDefinition;

makeToolCallBoxLabel[ as: KeyValuePattern[ "DisplayName" -> name_String ] ] :=
    makeToolCallBoxLabel[ as, name ];

makeToolCallBoxLabel[ as: KeyValuePattern[ "Name" -> name_String ] ] :=
    makeToolCallBoxLabel[
        as,
        StringRiffle @ Capitalize @ StringSplit[
            StringDelete[ StringTrim @ name, (Whitespace|"{") ~~ ___ ~~ EndOfString ],
            "_"
        ]
    ];

makeToolCallBoxLabel[ as_Association ] := tr[ "FormattingToolUsingLoading" ];

makeToolCallBoxLabel[ as_Association, name_String ] :=
    makeToolCallBoxLabel[ as, name, getToolIcon @ as ];

makeToolCallBoxLabel[ as_, name_String, icon_ ] /; $dynamicText :=
    fakeOpenerView[
        makeToolCallBoxLabel0[ as, name, icon ],
        as[ "Result" ] =!= ""
    ];

makeToolCallBoxLabel[ as0_, name_String, icon_ ] :=
    With[ { as = resolveToolFormatter @ as0 },
        openerView[
            {
                makeToolCallBoxLabel0[ as, name, icon ],
                (*TODO: custom interface LLM 667 *)
                TabView[
                    {
                        "Raw"         -> makeToolCallRawView @ as,
                        "Interpreted" -> makeToolCallInterpretedView @ as
                    },
                    2,
                    ImageSize  -> Automatic,
                    LabelStyle -> { FontSize -> 12 }
                ]
            },
            TrueQ @ as0[ "Open" ]
        ]
    ];

makeToolCallBoxLabel // endDefinition;


makeToolCallBoxLabel0 // beginDefinition;

makeToolCallBoxLabel0[ KeyValuePattern[ "Result" -> "" ], string_String, icon_ ] :=
With[ { col = RGBColor[ "#3383AC" ] },
    Flatten @ {
        toolCallIconPane @ icon,
        Style[ tr[ "FormattingToolUsing" ], FontColor -> col ],
        Style[ string, FontWeight -> "DemiBold", FontColor -> col ],
        RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "FEExpressions", "PercolateColorAnimator" ][ Small, col ]
    }
];

makeToolCallBoxLabel0[ as_, string_String, icon_ ] := Flatten @ {
    toolCallIconPane @ icon,
    Style[ tr[ "FormattingToolUsed" ], FontColor -> RGBColor[ "#3383AC" ] ],
    Style[ string, FontWeight -> "DemiBold", FontColor -> RGBColor[ "#3383AC" ] ]
};

makeToolCallBoxLabel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIconPane*)
toolCallIconPane // beginDefinition;

toolCallIconPane[ icon_ ] := Pane[
    toolCallIconPane0 @ icon,
    BaselinePosition -> Scaled[ 0.2 ],
    ContentPadding   -> False,
    FrameMargins     -> { { 0, 0 }, { 0, 0 } }
];

toolCallIconPane // endDefinition;


toolCallIconPane0 // beginDefinition;

toolCallIconPane0[ $$unspecified ] :=
    toolCallIconPane0 @ RawBoxes @ FEPrivate`FrontEndResource[ "ChatbookExpressions", "WrenchIcon" ];

toolCallIconPane0[ icon_ ] :=
    Dynamic[
        If[ TrueQ @ $CloudEvaluation,
            #1,
            Pane[ #1, ImageSize -> { 16, 16 }, ImageSizeAction -> "ShrinkToFit" ]
        ] &[ icon ],
        SingleEvaluation -> True,
        TrackedSymbols   :> { }
    ];

toolCallIconPane0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallRawView*)
makeToolCallRawView // beginDefinition;

makeToolCallRawView[ KeyValuePattern[ "ToolCall" -> raw_String ] ] :=
    Framed[
        Framed[
            RawBoxes @ Cell[
                BoxData @ ToBoxes @ wideScrollPane @ raw,
                "Text", "RawToolCall",
                FontSize   -> 11,
                Background -> None
            ],
            Background   -> White,
            FrameMargins -> 5,
            FrameStyle   -> None,
            ImageSize    -> { Scaled[ 1 ], Automatic },
            BaseStyle    -> "Text"
        ],
        Background   -> White,
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallRawView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallInterpretedView*)
makeToolCallInterpretedView // beginDefinition;

makeToolCallInterpretedView[ as_Association ] :=
    Framed[
        Column[
            {
                Item[
                    Pane[ Style[ "INPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> GrayLevel[ 0.95 ]
                ],
                Framed[
                    makeToolCallInputSection @ as,
                    Background   -> White,
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ],
                Item[
                    Pane[ Style[ "OUTPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> GrayLevel[ 0.95 ]
                ],
                Framed[
                    makeToolCallOutputSection @ as,
                    Background   -> White,
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            },
            Alignment -> Left
        ],
        Background   -> White,
        BaseStyle    -> { Editable -> False },
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallInterpretedView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallInputSection*)
makeToolCallInputSection // beginDefinition;

makeToolCallInputSection[ as: KeyValuePattern[ "Parameters" -> params_Association ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        Grid[
            KeyValueMap[ { #1, formatter[ #2, "Parameters", #1 ] } &, params ],
            Alignment  -> Left,
            BaseStyle  -> "Text",
            Dividers   -> All,
            FrameStyle -> GrayLevel[ 0.9 ],
            Spacings   -> 1
        ]
    ],
    throwInternalFailure[ makeToolCallInputSection @ as, ## ] &
];

makeToolCallInputSection[ KeyValuePattern[ "Parameters" -> query_String ] ] :=
    TextCell[ query, "Program", FontSize -> 0.75 * Inherited, Background -> None ];

makeToolCallInputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveToolFormatter*)
resolveToolFormatter // beginDefinition;
resolveToolFormatter[ as_Association ] := Append[ as, "FormattingFunction" -> resolveToolFormatter0 @ as ];
resolveToolFormatter // endDefinition;

resolveToolFormatter0 // beginDefinition;
resolveToolFormatter0[ as_Association ] := resolveToolFormatter0 @ Lookup[ as, "FormattingFunction", Inherited ];
resolveToolFormatter0[ Automatic      ] := clickToCopy[ #1 ] &;
resolveToolFormatter0[ Inherited      ] := toolAutoFormatter;
resolveToolFormatter0[ None           ] := #1 &;
resolveToolFormatter0[ f_             ] := f;
resolveToolFormatter0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolAutoFormatter*)
toolAutoFormatter // beginDefinition;

toolAutoFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    toolAutoFormatter[ result, "Result" ];

toolAutoFormatter[ result_String, "Result" ] := RawBoxes @ Cell[
    TextData @ reformatTextData @ result,
    "Text",
    Background -> None
];

toolAutoFormatter[ parameter_, "Parameters", ___ ] := clickToCopy @ parameter;

toolAutoFormatter[ result_, ___ ] := result;

toolAutoFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallOutputSection*)
makeToolCallOutputSection // beginDefinition;

makeToolCallOutputSection[ as: KeyValuePattern[ "Result" -> result_ ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        TextCell[
            wideScrollPane @ formatter[ result, "Result" ],
            "Text",
            Background      -> None,
            FrameBoxOptions -> { BaselinePosition -> Automatic },
            PaneBoxOptions  -> { BaselinePosition -> Automatic }
        ]
    ],
    throwInternalFailure
];

makeToolCallOutputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*wideScrollPane*)
wideScrollPane // beginDefinition;

wideScrollPane[ expr_ ] := Pane[
    expr,
    ImageSize          -> { Scaled[ 1 ], UpTo[ 400 ] },
    Scrollbars         -> Automatic,
    AppearanceElements -> None
];

wideScrollPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

(* TODO: define template boxes for these *)
makeInteractiveCodeCell[ language_, code_String ] /; $dynamicText :=
    If[ TrueQ @ wolframLanguageQ @ language,
        codeBlockFrame[ Cell[ BoxData @ wlStringToBoxes @ code, "ChatCodeActive" ], code, language ],
        codeBlockFrame[ Cell[ code, "ChatPreformatted" ], code, language ]
    ];

(* Wolfram Language code blocks *)
makeInteractiveCodeCell[ lang_String? wolframLanguageQ, code0_ ] := Enclose[
    Catch @ Module[ { code, display, handler },
        code = ConfirmMatch[ parseCellGroupBlock @ code0, _Cell | _? boxDataQ, "Code" ];
        If[ MatchQ[ code, _Cell ], Throw @ code ];
        display = RawBoxes @ Cell[
            BoxData @ If[ StringQ @ code, wlStringToBoxes @ code, code ],
            "ChatCode",
            "Input",
            Background           -> GrayLevel[ 1 ],
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            TranslationOptions   -> {
                "Enabled" -> Dynamic @ AbsoluteCurrentValue[ $FrontEnd, { TranslationOptions, "Enabled" } ]
            }
        ];
        handler = inlineInteractiveCodeCell[ display, code ];
        codeBlockFrame[ ToBoxes @ handler, code ]
    ],
    throwInternalFailure
];

(* Supported external language code blocks *)
makeInteractiveCodeCell[ lang_String? externalLanguageQ, code_String ] :=
    Module[ { cell, display, handler },
        cell = Cell[ code, "ExternalLanguage", FontSize -> 14, System`CellEvaluationLanguage -> lang ];
        display = RawBoxes @ Cell[
            code,
            "ExternalLanguage",
            System`CellEvaluationLanguage -> lang,
            FontSize   -> 13,
            Background -> None,
            CellFrame  -> None
        ];
        handler = inlineInteractiveCodeCell[ display, cell ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code, lang ] (* TODO: unclear if we need Cell[BoxData[...]] for non-Wolfram code *)
    ];

(* Code blocks for any other languages *)
makeInteractiveCodeCell[ language_String, code_String ] :=
    codeBlockFrame[
        Cell[
            code,
            "ChatPreformatted",
            Background   -> GrayLevel[ 1 ],
            TaggingRules -> <| "CellToStringType" -> "InlineCodeCell", "CodeLanguage" -> language |>
        ],
        code,
        language
    ];

makeInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseCellGroupBlock*)
parseCellGroupBlock // beginDefinition;

parseCellGroupBlock[ code_String ] := Enclose[
    Catch @ Module[ { split, trimmed, rows },

        split = StringSplit[
            code,
            {
                l: $$inLabel         :> label[ "Input"     , StringTrim @ l ],
                l: $$outLabel        :> label[ "Output"    , StringTrim @ l ],
                l: $$echoLabel       :> label[ "Echo"      , StringTrim @ l ],
                l: $$echoTimingLabel :> label[ "EchoTiming", StringTrim @ l ],
                l: $$messageLabel    :> label[ "Message"   , StringTrim @ l ],
                l: $$printLabel      :> label[ "Print"     , StringTrim @ l ]
            }
        ];

        trimmed = DeleteCases[ Replace[ split, s_String :> StringTrim @ s, { 1 } ], "" ];

        Replace[
            trimmed,
            {
                (* No labels: *)
                { _ } :> Throw @ code,

                (* A single in/out label with some code: *)
                { label[ "In"|"Out", _ ], s_String } :> Throw @ s}
        ];

        rows = Replace[
            SequenceReplace[
                trimmed,
                { label[ style_, l_ ], s_String } :> makeLabeledBlockCell[ s, style, l ]
            ],
            s_String :> { "", makeInteractiveCodeCell[ "Plaintext", s ] },
            { 1 }
        ];

        Cell[
            BoxData @ GridBox[
                rows,
                GridBoxAlignment -> { "Columns" -> { Right, Left }, "Rows" -> { { Baseline } } }(*,
                GridBoxItemSize -> { "Columns" -> { 4, Automatic }, "Rows" -> { { Automatic } } }*)
            ],
            "CellGroupBlock"
        ]
    ],
    throwInternalFailure
];

parseCellGroupBlock[ boxes_ ] := boxes;

parseCellGroupBlock // endDefinition;


$$equals          = ":=" | "=";
$$inLabel         = "In" ~~ "[" ~~ Except["]"] ... ~~ "]" ~~ $$equals;
$$outLabel        = "Out" ~~ "[" ~~ Except["]"] ... ~~ "]" ~~ $$equals;
$$echoLabel       = Longest[ ">>".. | "<<".. ];
$$echoTimingLabel = "\[WatchIcon]";
$$messageLabel    = Except[ WhitespaceCharacter ].. ~~ "::" ~~ (LetterCharacter|DigitCharacter) .. ~~ ":";
$$printLabel      = "During evaluation of " ~~ $$inLabel;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLabeledBlockCell*)
makeLabeledBlockCell // beginDefinition;

makeLabeledBlockCell[ text_String, "Message", label_String ] :=
    makeBlockMessage[ StringSplit[ StringTrim[ label, ":" ], "::" ], text ];

makeLabeledBlockCell[ code_, style_, label_ ] := {
    makeBlockLabel[ label, style ],
    makeLabeledBlockCell0[ code, style ]
};

makeLabeledBlockCell // endDefinition;


makeLabeledBlockCell0 // beginDefinition;

makeLabeledBlockCell0[ code_String, "Input" ] :=
    makeInteractiveCodeCell[ "Wolfram", code ];

makeLabeledBlockCell0[ code_String, style_String ] :=
    Cell[ BoxData @ StringToBoxes[ code, "WL" ], style ];

makeLabeledBlockCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeBlockMessage*)
makeBlockMessage // beginDefinition;

makeBlockMessage[ { sym_String, tag_String }, text_String ] :=
    { "", TemplateBox[ { sym, tag, text, 2, 0, 0, 0, "Local" }, "MessageTemplate", BaseStyle -> "MSG" ] };

makeBlockMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeBlockLabel*)
makeBlockLabel // beginDefinition;

makeBlockLabel[ label_String, "Input"  ] := StyleBox[ label, "CellLabelExpired" ];
makeBlockLabel[ label_String, "Output" ] := StyleBox[ label, "CellLabelExpired" ];
makeBlockLabel[ label_, "EchoTiming" ] := StyleBox[ "\[WatchIcon]", "EchoDingbat" ];
makeBlockLabel[ label_String, "Message" ] := StyleBox[ label, "MessageMenuLabel" ];
makeBlockLabel[ label_, "Print" ] := "";

makeBlockLabel[ label_String, "Echo" ] := StyleBox[
    StringReplace[ label, { ">>" -> "\[RightGuillemet]", "<<" -> "\[LeftGuillemet]" } ],
    "EchoDingbat"
];

makeBlockLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wlStringToBoxes*)
wlStringToBoxes // beginDefinition;

wlStringToBoxes[ string_String ] /; $dynamicText := formatNLInputs @ string;

wlStringToBoxes[ string_String ] :=
    formatNLInputs @ inlineExpressionURIs @ stringToBoxes @ preprocessSandboxString @ string;

wlStringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNLInputs*)
formatNLInputs // beginDefinition;

formatNLInputs[ string_String ] :=
    StringReplace[
        string,
        {
            "\[FreeformPrompt][\"" ~~ q: Except[ "\"" ].. ~~ ("\"]"|EndOfString) :>
                ToString[ RawBoxes @ formatNLInputFast @ q, StandardForm ],
            "ResourceFunction[\"" ~~ name: Except[ "\"" ].. ~~ ("\"]"|EndOfString) :>
                ToString[ RawBoxes @ formatResourceFunctionFast @ name, StandardForm ]
        }
    ];

formatNLInputs[ boxes_ ] :=
    boxes /. {
        RowBox @ { "\[FreeformPrompt]", "[", q_String, "]" } /; StringMatchQ[ q, "\""~~Except[ "\""]..~~"\"" ] :>
            RuleCondition @ If[ TrueQ @ $dynamicText, formatNLInputFast @ q, formatNLInputSlow @ q ]
        ,
        RowBox @ { "\[FreeformPrompt]", "[", q_String } /; StringMatchQ[ q, "\""~~Except[ "\""]..~~("\""|"") ] :>
            RuleCondition @ formatNLInputFast @ q
        ,
        RowBox @ { "ResourceFunction", "[", name_String, "]" } /; StringMatchQ[ name, "\""~~Except[ "\""]..~~"\"" ] :>
            RuleCondition @ If[ TrueQ @ $dynamicText,
                                formatResourceFunctionFast @ name,
                                formatResourceFunctionSlow @ name
                            ]
        ,
        box: RowBox @ { "DateObject", "[", ___, "]" } :>
            RuleCondition @ formatDateObjectBoxes @ box
    };

formatNLInputs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDateObjectBoxes*)
formatDateObjectBoxes // beginDefinition;

formatDateObjectBoxes[ boxes_RowBox ] :=
    Quiet @ Module[ { held, date },
        held = ToExpression[ boxes, StandardForm, HoldComplete ];
        If[ MatchQ[ held, _[ $$possibleDateObject ] ],
            date = Quiet @ ReleaseHold @ held;
            If[ DateObjectQ @ date,
                ToBoxes @ date,
                boxes
            ],
            boxes
        ]
    ];

formatDateObjectBoxes // endDefinition;


$$possibleDateObject = HoldPattern @ DateObject[
    { (_Real|_Integer).. },
    ___String,
    (_Real|_Integer)...,
    OptionsPattern[ ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatResourceFunctionFast*)
formatResourceFunctionFast // beginDefinition;

formatResourceFunctionFast[ name_String ] := (
    Needs[ "FunctionResource`" -> None ];
    FunctionResource`InertResourceFunctionBoxes[ "Published", StringTrim[ name, "\"" ] ]
);

formatResourceFunctionFast // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatResourceFunctionSlow*)
formatResourceFunctionSlow // beginDefinition;

formatResourceFunctionSlow[ name_String ] := (
    Needs[ "FunctionResource`" -> None ];
    FunctionResource`MakeResourceFunctionBoxes @ StringTrim[ name, "\"" ]
);

formatResourceFunctionSlow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNLInputFast*)
formatNLInputFast // beginDefinition;

formatNLInputFast[ q_String ] := OverlayBox[
    {
        FrameBox[
            StyleBox[ q, ShowStringCharacters -> False, FontWeight -> Plain ],
            BaseStyle      -> { "CalculateInput", LineBreakWithin -> False },
            FrameStyle     -> GrayLevel[ 0.85 ],
            RoundingRadius -> 3,
            ImageMargins   -> { { 5, 0 }, { 0, 0 } },
            FrameMargins   -> { { 6, 3 }, { 3, 3 } },
            StripOnInput   -> False
        ],
        Append[ $freeformPromptBox, Background -> White ]
    },
    Alignment -> { Left, Baseline }
];

formatNLInputFast // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNLInputSlow*)
formatNLInputSlow // beginDefinition;

formatNLInputSlow[ query_String ] :=
    With[ { h = ToExpression[ query, InputForm, HoldComplete ] },
        (
            formatNLInputSlow[ query ] =
                ReplaceAll[
                    ToBoxes @ WolframAlpha[ ReleaseHold @ h, "LinguisticAssistant" ],
                    as: KeyValuePattern[ "open" -> { 1, 2 } ] :> RuleCondition @ <| as, "open" -> { 1 } |>
                ]
        ) /; MatchQ[ h, HoldComplete[ _String ] ]
    ];

formatNLInputSlow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageQ*)
wolframLanguageQ // ClearAll;
wolframLanguageQ[ language_String ] := StringMatchQ[ StringTrim @ language, $wlCodeString, IgnoreCase -> True ];
wolframLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineInteractiveCodeCell*)
inlineInteractiveCodeCell // beginDefinition;

inlineInteractiveCodeCell[ display_, string_ ] /; $dynamicText := display;

inlineInteractiveCodeCell[ display_, string_ ] :=
    inlineInteractiveCodeCell[ display, string, contentLanguage @ string ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] := display;

inlineInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonOverlay*)
buttonOverlay // beginDefinition;

buttonOverlay[ a_, b_ ] := Overlay[
    { a, b },
    All,
    2,
    Alignment      -> { Left, Bottom },
    ContentPadding -> False,
    FrameMargins   -> 0,
    ImageMargins   -> 0
];

buttonOverlay // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInlineCodeCell*)
makeInlineCodeCell // beginDefinition;

makeInlineCodeCell[ s_String? nameQ ] /; Context @ s === "System`" :=
    hyperlink[ s, "paclet:ref/" <> Last @ StringSplit[ s, "`" ] ];

makeInlineCodeCell[ s_String? LowerCaseQ ] :=
    StyleBox[ unescapeInlineMarkdown @ s, "TI" ];

makeInlineCodeCell[ code_String ] := Cell[
    BoxData @ TemplateBox[ { Cell[ unescapeInlineMarkdown @ code, Background -> None ] }, "ChatCodeInlineTemplate" ],
    "ChatCodeActive"
];

makeInlineCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeBlockFrame*)
codeBlockFrame // beginDefinition;

codeBlockFrame[ cell_, string_ ] := codeBlockFrame[ cell, string, "Wolfram" ];

codeBlockFrame[ cell_, string_, lang_ ] := Cell[
    BoxData @ templateBox[ { cell, lang }, "ChatCodeBlockTemplate" ],
    "ChatCodeBlock",
    Background -> None
];

codeBlockFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*styleBox*)
styleBox // beginDefinition;

styleBox[ text_String, a___ ] := styleBox[ formatTextString @ text, a ];
styleBox[ { link: Cell @ BoxData[ TemplateBox[ { _, ___ }, "TextRefLink", ___ ], ___ ] }, ___ ] := link;
styleBox[ { text_String } ] := text;
styleBox[ { StyleBox[ text_ ], a___ } ] := styleBox @ { text, a };
styleBox[ { text: _ButtonBox|_String }, a___ ] := StyleBox[ text, a ];
styleBox[ { StyleBox[ text_, a___ ] }, b___ ] := DeleteDuplicates @ StyleBox[ text, a, b ];
styleBox[ { Cell[ text_, a___ ] }, b___ ] := DeleteDuplicates @ Cell[ text, a, b ];
styleBox[ { }, ___ ] := "";

styleBox[ { a___, b: Except[ _ButtonBox|_Cell|_String|_StyleBox ], c___ }, d___ ] :=
    styleBox[ { a, Cell @ BoxData @ b, c }, d ];

styleBox[ a_, ___ ] := a;

styleBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*image*)
image // beginDefinition;

image[ str_String ] := First @ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> image[ alt, url ] ];

image[ alt_, url_String ] := Enclose[
    Module[ { keys, key },
        keys = ConfirmMatch[ Keys @ $attachments, { ___String? StringQ }, "Keys" ];
        key  = SelectFirst[ keys, StringContainsQ[ url, #1, IgnoreCase -> True ] & ];
        If[ StringQ @ key,
            Cell[
                BoxData @ markdownImageBoxes[
                    alt,
                    key,
                    Replace[ $attachments[ key ], HoldComplete[ expr_ ] :> expr ]
                ],
                Background -> None
            ],
            image[ alt, url, urlParse @ url ]
        ]
    ],
    throwInternalFailure
];

image[ alt_, url_, KeyValuePattern @ { "Scheme" -> "attachment"|"expression", "Domain" -> key_String } ] :=
    attachment[ alt, key ];

image[ alt_, url_, KeyValuePattern @ { "Scheme" -> "file", "Path" -> path_String } ] :=
    importedImage[ alt, path ];

image[ alt_, url_, _ ] :=
    importedImage[ alt, url ];

image // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*urlParse*)
urlParse // beginDefinition;
urlParse[ url_String ] := With[ { parsed = localParse @ url }, parsed /; AssociationQ @ parsed ];
urlParse[ url_String ] := URLParse @ url;
urlParse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*localParse*)
localParse // beginDefinition;

localParse[ uri_String ] /; StringStartsQ[ uri, ("attachment"|"file")~~"://" ] :=
    With[ { path = StringDelete[ uri, StartOfString ~~ ("attachment"|"file") ~~ "://" ] },
        <| "Scheme" -> "file", "Path" -> path |> /; FileExistsQ @ path
    ];

localParse[ uri_String ] :=
    Missing[ "NotAvailable" ];

localParse // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachment*)
attachment // beginDefinition;
attachment[ alt_String, key_String ] := attachment[ alt, key, $attachments[ key ] ];
attachment[ alt_String, key_String, HoldComplete[ expr_ ] ] := attachment[ alt, key, Defer @ expr ];
attachment[ alt_String, key_String, _Missing ] := attachment[ alt, key, $missingImage ];

attachment[ alt_String, key_String, Defer[ img_Image ] ] /; ImageQ @ Unevaluated @ img :=
    Cell[ BoxData @ PaneBox[ attachmentBoxes[ alt, key, resizeImage @ img ], ImageMargins -> 10 ], Background -> None ];

attachment[ alt_String, key_String, expr_ ] /; $dynamicText :=
    codeBlockFrame[ Cell[ BoxData @ attachmentBoxes[ alt, key, expr ], "ChatCodeActive" ], expr ];

attachment[ alt_String, key_String, expr_ ] :=
    Module[ { boxes, display, handler },
        boxes = attachmentBoxes[ alt, key, expr ];
        display = RawBoxes @ Cell[
            BoxData @ boxes,
            "ChatCode",
            "Input",
            Background           -> GrayLevel[ 1 ],
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            TranslationOptions   -> {
                "Enabled" -> Dynamic @ AbsoluteCurrentValue[ $FrontEnd, { TranslationOptions, "Enabled" } ]
            }
        ];
        handler = inlineInteractiveCodeCell[ display, Cell[ BoxData @ cachedBoxes @ expr, "Input" ] ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, expr ]
    ];

attachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachmentBoxes*)
attachmentBoxes // beginDefinition;
attachmentBoxes[ alt_, key_String, expr_ ] := markdownImageBoxes[ StringTrim @ alt, "attachment://" <> key, expr ];
attachmentBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownImageBoxes*)
markdownImageBoxes // beginDefinition;

markdownImageBoxes[ ""|None, url_String, expr_ ] := PaneBox[
    TagBox[
        cachedBoxes @ expr,
        "MarkdownImage",
        AutoDelete   -> True,
        TaggingRules -> <| "CellToStringData" -> toMIBoxURI @ url |>
    ],
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

markdownImageBoxes[ alt_String, url_String, expr_ ] := PaneBox[
    TagBox[
        TooltipBox[ cachedBoxes @ expr, ToString[ alt, InputForm ] ],
        "MarkdownImage",
        AutoDelete   -> True,
        TaggingRules -> <| "CellToStringData" -> "![" <> alt <> "](" <> url <> ")" |>
    ],
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

markdownImageBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toMIBoxURI*)
toMIBoxURI // beginDefinition;

toMIBoxURI[ uri_String ] := Enclose[
    Catch @ Module[ { expr },

        expr = ConfirmMatch[
            catchAlways @ Quiet @ GetExpressionURI[ uri, HoldComplete ],
            HoldComplete[ _ ] | _Failure,
            "GetExpression"
        ];

        Replace[
            expr,
            {
                HoldComplete[ e_ ] :> ConfirmBy[ MakeExpressionURI @ Unevaluated @ e, StringQ, "URI" ],
                _Failure :> If[ StringQ @ URLParse[ uri, "Scheme" ], uri, "expression://"<>uri ]
            }
        ]
    ],
    throwInternalFailure
];

toMIBoxURI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*importedImage*)
importedImage // beginDefinition;

importedImage[ alt_String, url_String ] :=
    importedImage[ alt, url, importImage @ url ];

importedImage[ alt_String, url_String, _? FailureQ | _String ] :=
    importedImage[ alt, url, $missingImage ];

importedImage[ alt_String, url_String, i_ ] :=
    Cell @ BoxData @ markdownImageBoxes[ StringTrim @ alt, url, tooltip[ resizeImage @ i, alt ] ];

importedImage // endDefinition;

$missingImage = RawBoxes @ TemplateBox[ { }, "ImageNotFound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importImage*)
importImage // beginDefinition;
importImage[ url_String ] := importImage[ url ] = importImage0 @ url;
importImage // endDefinition;

importImage0 // beginDefinition;
importImage0[ url_String ] := importImage0[ url, Quiet @ Import[ url, "Image" ] ];
importImage0[ url_, image: $$image ] := image;
importImage0[ url_String? cloudURLQ, _? FailureQ ] := Quiet @ Import[ CloudObject @ url, "Image" ];
importImage0[ _, failed_ ] := failed;
importImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*cloudURLQ*)
cloudURLQ // beginDefinition;
cloudURLQ[ url_String ] := URLParse[ url, "Domain" ] === URLParse[ $CloudBase, "Domain" ];
cloudURLQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tooltip*)
tooltip // beginDefinition;
tooltip[ expr_, ""|"result" ] := expr;
tooltip[ expr_, text_ ] := Tooltip[ expr, text ];
tooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeImage*)
resizeImage // beginDefinition;
resizeImage[ img_ ] := resizeImage[ img, $dynamicText ];
resizeImage[ img_, dynamic_ ] := resizeImage[ img, dynamic ] = resizeImage0 @ img;
resizeImage // endDefinition;


resizeImage0 // beginDefinition;

resizeImage0[ img: $$image ] :=
    resizeImage0[ img, ImageDimensions @ img ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] /; $dynamicText && Max @ dims > $maxDynamicImageSize :=
    showResized @ ImageResize[ img, { UpTo[ $maxDynamicImageSize ], UpTo[ $maxDynamicImageSize ] } ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] /; Max @ dims > $maxImageSize :=
    showResized @ ImageResize[ img, { UpTo @ $maxImageSize, UpTo @ $maxImageSize } ];

resizeImage0[ img: $$image, dims: { _Integer, _Integer } ] :=
    Show[ img, Options[ img, ImageSize ] ];

resizeImage0[ other_ ] :=
    other;

resizeImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showResized*)
showResized // beginDefinition;
showResized[ img: $$image ] := showResized[ img, targetImageSize @ img ];
showResized[ img_, { w_Integer, h_Integer } ] := Show[ img, ImageSize -> { UpTo @ w, UpTo @ h } ];
showResized[ img_ ] := img;
showResized // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*targetImageSize*)
targetImageSize // beginDefinition;
targetImageSize[ img: $$image ] /; $dynamicText := Ceiling[ (ImageDimensions @ img / 2) / $dynamicImageScale ];
targetImageSize[ img: $$image ] := Ceiling[ ImageDimensions @ img / 2 ];
targetImageSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedBoxes*)
cachedBoxes // beginDefinition;

cachedBoxes[ e_ ] :=
    With[ { h = Hash @ Unevaluated @ e },
        Lookup[ $boxCache, h, $boxCache[ h ] = checkBoxes @ MakeBoxes @ e ]
    ];

cachedBoxes // endDefinition;

$boxCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*checkBoxes*)
checkBoxes // beginDefinition;
checkBoxes[ e_ ] /; $CloudEvaluation && ! FreeQ[ e, _RasterBox ] := embeddedHTMLBoxes @ e;
checkBoxes[ e_ ] := e;
checkBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*embeddedHTMLBoxes*)
embeddedHTMLBoxes // beginDefinition;

embeddedHTMLBoxes[ boxes_ ] := Enclose[
    Module[ { id, dynamic },
        id = ConfirmBy[ createBoxCacheReference @ boxes, IntegerQ, "ID" ];

        dynamic = With[ { id = id, missing = $missingImage, waiting = $waiting },
            DynamicModule[ { b64, display },
                Dynamic @ Replace[ display, Except[ _RawBoxes ] -> waiting ],
                Initialization :> (
                    If[ TrueQ @ $dynamicText,
                        Null,
                        If[ ! StringQ @ b64, b64 = getBase64 @ id ];
                        display = Replace[ displayBase64Boxes @ b64, Except[ _RawBoxes ] :> missing ]
                    ]
                ),
                SynchronousInitialization -> False,
                UnsavedVariables :> { display }
            ]
        ];

        TagBox[ ToBoxes @ dynamic, "DynamicEmbeddedHTMLBoxes" ]
    ],
    throwInternalFailure
];

embeddedHTMLBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*createBoxCacheReference*)
createBoxCacheReference // beginDefinition;
createBoxCacheReference[ boxes_ ] := With[ { id = Hash @ boxes }, $boxQueueCache[ id ] = boxes; id ];
createBoxCacheReference // endDefinition;

$boxQueueCache = <| |>;
$base64Cache   = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getBase64*)
getBase64 // beginDefinition;

getBase64[ id_ ] := getBase64[ id, $base64Cache[ id ] ];
getBase64[ id_, b64_String ] := b64;
getBase64[ id_, m_Missing ] := getBase64[ id, m, $boxQueueCache[ id ] ];
getBase64[ id_, _, _Missing ] := Missing[ "NotAvailable" ];

getBase64[ id_, _, boxes_ ] :=
    With[ { b64 = BaseEncode @ BinarySerialize[ RawBoxes @ boxes, PerformanceGoal -> "Size" ] },
        $base64Cache[ id ] = b64;
        KeyDropFrom[ $boxQueueCache, id ];
        b64
    ];

getBase64 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*displayBase64Boxes*)
displayBase64Boxes // beginDefinition;

displayBase64Boxes[ b64_String ] /; $dynamicText := $waiting;

displayBase64Boxes[ b64_String ] := Enclose[
    Module[ { bytes, boxes, display },
        bytes = ConfirmBy[ BaseDecode @ b64, ByteArrayQ, "Bytes" ];
        boxes = ConfirmMatch[ BinaryDeserialize @ bytes, _RawBoxes, "Boxes" ];
        display = If[ TrueQ @ $CloudEvaluation, cloudEmbeddedHTMLImage @ boxes, boxes ];
        displayBase64Boxes[ b64 ] = ConfirmMatch[ display, _RawBoxes, "Display" ]
    ],
    throwInternalFailure
];

displayBase64Boxes[ _ ] := $waiting;

displayBase64Boxes // endDefinition;


$waiting := $waiting = RawBoxes @ ToBoxes @ Panel[
    ProgressIndicator[ Appearance -> "Necklace" ],
    ImageSize -> { 150, 150 },
    Alignment -> { Center, Center }
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudEmbeddedHTMLImage*)
cloudEmbeddedHTMLImage // beginDefinition;

cloudEmbeddedHTMLImage[ expr_ ] := Enclose[
    usingFrontEnd @ Module[ { raster, size, resized, b64, width, height, embedSize, html, boxes },

        raster = ConfirmBy[ rasterize[ expr, ImageResolution -> 144 ], image2DQ, "Raster" ];
        size = Max @ ConfirmMatch[ ImageDimensions @ raster, { _, _ }, "OriginalDimensions" ];
        resized = If[ size > 1000, ImageResize[ raster, { UpTo[ 1000 ], UpTo[ 1000 ] } ], raster ];
        b64 = ConfirmBy[ exportDataURI[ resized, "JPEG" ], StringQ, "Base64" ];
        { width, height } = Round[ ConfirmMatch[ ImageDimensions @ resized, { _, _ }, "Dimensions" ] / 2 ];
        embedSize = { width, height + 12 };

        html = ConfirmBy[
            TemplateApply[ $embeddedImageTemplate, { b64, width, height } ],
            StringQ,
            "HTML"
        ];

        boxes = ToBoxes @ EmbeddedHTML[ html, ImageSize -> embedSize ];
        RawBoxes @ TagBox[ boxes, "CloudEmbeddedHTMLImage" ]
    ],
    throwInternalFailure
];

cloudEmbeddedHTMLImage // endDefinition;


$embeddedImageTemplate = "<div style=\"margin: -8px;\"><img src=\"`1`\" width=\"`2`\" height=\"`3`\"></div>";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*hyperlink*)
hyperlink // beginDefinition;

hyperlink[ label_String, uri_String? expressionURIQ ] :=
    If[ TrueQ @ $dynamicText,
        StyleBox[ label, "Hyperlink" ],
        With[ { b = BaseEncode @ BinarySerialize[ GetExpressionURI @ uri, PerformanceGoal -> "Size" ] },
            Cell[
                BoxData @ TemplateBox[ { ToBoxes @ label, b }, "TextExpressionLink" ],
                Background -> None
            ]
        ]
    ];

hyperlink[ label_String | { label_String }, uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    Cell @ BoxData @ TemplateBox[
        {
            StringTrim[ label, (Whitespace|"`"|"\\").. ],
            uri,
            StringReplace[
                uri,
                StartOfString ~~ "paclet:" ~~ ref__ ~~ EndOfString :>
                    "https://reference.wolfram.com/language/"<>ref<>".html"
            ]
        },
        "TextRefLink"
    ];

hyperlink[ label_String, url_String ] := hyperlink[ formatTextString @ label, url ];

hyperlink[ { label: _String|_StyleBox }, url_ ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

hyperlink[ a_, ___ ] := a;

(* TODO: if the link contains a UUID that corresponds to a notebook object, create a link that selects that notebook *)

hyperlink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*External Languages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*contentLanguage*)
contentLanguage[ Cell[ __, "CellEvaluationLanguage" -> lang_String, ___ ] ] := lang;
contentLanguage[ Cell[ __, System`CellEvaluationLanguage -> lang_String, ___ ] ] := lang;
contentLanguage[ ___ ] := "Wolfram";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*externalLanguageQ*)
externalLanguageQ[ $$externalLanguage ] := True;

externalLanguageQ[ str_String? StringQ ] := externalLanguageQ[ str ] =
    StringMatchQ[
        StringReplace[ StringTrim @ str, $externalLanguageRules, IgnoreCase -> True ],
        $$externalLanguage,
        IgnoreCase -> True
    ];

externalLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$languageIcons*)
$languageIcons := $languageIcons = AssociationMap[
    chatbookExpression[ "ExternalLanguageIcon" <> StringDelete[ #, "-" ] ] &,
    $externalLanguages
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*joinAdjacentStrings*)
joinAdjacentStrings // beginDefinition;
joinAdjacentStrings[ { content___, "\n"|StyleBox[ "\n", ___ ] } ] := joinAdjacentStrings @ { content };
joinAdjacentStrings[ { "\n"|StyleBox[ "\n", ___ ], content___ } ] := joinAdjacentStrings @ { content };
joinAdjacentStrings[ content_List ] := trimWhitespace[ joinAdjacentStrings0 /@ SplitBy[ content, StringQ ] ];
joinAdjacentStrings // endDefinition;

joinAdjacentStrings0 // beginDefinition;

joinAdjacentStrings0[ { strings__String } ] :=
    StringReplace[ StringJoin @ strings, c: Except[ "\n" ]~~"\n"~~EndOfString :> c<>" \n" ];

joinAdjacentStrings0[ { other___ } ] := other;

joinAdjacentStrings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*trimWhitespace*)
trimWhitespace // beginDefinition;
trimWhitespace[ { } ] := { };
trimWhitespace[ { a_, b___, c_ } ] := { trimWhitespaceL @ a, b, trimWhitespaceR @ c };
trimWhitespace[ { a_ } ] := { trimWhitespaceB @ a };
trimWhitespace // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*trimWhitespaceB*)
trimWhitespaceB // beginDefinition;
trimWhitespaceB[ a_String ] := StringTrim @ a;
trimWhitespaceB[ other_ ] := trimWhitespaceR @ trimWhitespaceL @ other;
trimWhitespaceB // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*trimWhitespaceL*)
trimWhitespaceL // beginDefinition;
trimWhitespaceL[ a_String ] := StringDelete[ a, StartOfString ~~ WhitespaceCharacter.. ];
trimWhitespaceL[ (h: Cell|StyleBox|TextData|BoxData)[ a_, b___ ] ] := h[ trimWhitespaceL @ a, b ];
trimWhitespaceL[ { a_, b___ } ] := { trimWhitespaceL @ a, b };
trimWhitespaceL[ other_ ] := other;
trimWhitespaceL // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*trimWhitespaceR*)
trimWhitespaceR // beginDefinition;
trimWhitespaceR[ a_String ] := StringDelete[ a, WhitespaceCharacter.. ~~ EndOfString ];
trimWhitespaceR[ (h: Cell|StyleBox|TextData|BoxData)[ a_, b___ ] ] := h[ trimWhitespaceR @ a, b ];
trimWhitespaceR[ { a___, b_ } ] := { a, trimWhitespaceR @ b };
trimWhitespaceR[ other_ ] := other;
trimWhitespaceR // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*nameQ*)
nameQ[ "*"|"**" ] := False;
nameQ[ s_String? StringQ ] := StringFreeQ[ s, Verbatim[ "*" ] | Verbatim[ "@" ] ] && NameQ @ s;
nameQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineSyntaxQ*)
inlineSyntaxQ[ s_String ] := ! StringStartsQ[ s, "`" ] && Internal`SymbolNameQ[ unescapeInlineMarkdown @ s<>"x", True ];
inlineSyntaxQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*probablyMathQ*)
probablyMathQ[ s_String ] := And[
    StringFreeQ[ s, "\n" ],
    StringLength @ s < 100,
    Or[ StringMatchQ[ s, (LetterCharacter|DigitCharacter|"("|")").. ],
        StringContainsQ[ s, "+" | "-" | "=" | "^" | ("\\" ~~ WordCharacter..) ]
    ]
];

probablyMathQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*unescapeInlineMarkdown*)
unescapeInlineMarkdown // beginDefinition;
unescapeInlineMarkdown[ str_String ] := StringReplace[ str, { "\\`" -> "`", "\\$" -> "$" } ];
unescapeInlineMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;

stringToBoxes[ s_String ] /; $dynamicText := StringReplace[
    s,
    "InlinedExpression[\"" ~~ LetterCharacter.. ~~ "://" ~~ (LetterCharacter|DigitCharacter|"-").. ~~ "\"]" :>
        $expressionURIPlaceholder
];

stringToBoxes[ s_String /; StringMatchQ[ s, "\"" ~~ __ ~~ "\"" ] ] :=
    With[ { str = stringToBoxes @ StringTrim[ s, "\"" ] }, "\""<>str<>"\"" /; StringQ @ str ];

stringToBoxes[ s_String ] :=
    adjustBoxSpacing @ stringToBoxes0 @ reparseBoxStructurePacket @ s;

stringToBoxes // endDefinition;


stringToBoxes0 // beginDefinition;
stringToBoxes0[ boxes_? boxDataQ ] := boxes;
stringToBoxes0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reparseBoxStructurePacket*)
reparseBoxStructurePacket // beginDefinition;

reparseBoxStructurePacket[ string_String ] := Replace[
    usingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket @ StyleBox[
        string,
        ShowStringCharacters -> True
    ],
    StyleBox[ boxes_, ___ ] :> boxes
];

reparseBoxStructurePacket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boxDataQ*)
boxDataQ // beginDefinition;
boxDataQ[ _String? StringQ ] := True;
boxDataQ[ boxes_List ] := AllTrue[ boxes, boxDataQ ];
boxDataQ[ (_? boxSymbolQ)[ ___ ] ] := True;
boxDataQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boxSymbolQ*)
boxSymbolQ // beginDefinition;
boxSymbolQ[ RowBox ] := True;
boxSymbolQ[ s_Symbol ] := boxSymbolQ[ s ] = Context @ s === "System`" && StringEndsQ[ SymbolName @ s, "Box" ];
boxSymbolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adjustBoxSpacing*)
adjustBoxSpacing // beginDefinition;
adjustBoxSpacing[ row: RowBox @ { "(*", ___, "*)" } ] := row;
adjustBoxSpacing[ "\n" ] := "\[IndentingNewLine]";
adjustBoxSpacing[ s_String ] /; $CloudEvaluation := Lookup[ $autoOperatorRenderings, s, s ];
adjustBoxSpacing[ RowBox[ items_List ] ] := RowBox[ adjustBoxSpacing /@ adjustSequenceSpacing @ items ];
adjustBoxSpacing[ box_ ] := box;
adjustBoxSpacing // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adjustSequenceSpacing*)
adjustSequenceSpacing // beginDefinition;

adjustSequenceSpacing[ items_List ] := SequenceReplace[
    items,
    {
        { $space, op: $infixOperators, $space  } :> op,
        { $space, op: $infixOperators } :> op,
        { op: $infixOperators, $space } :> op,
        { ",", $space } -> ","
    }
];

adjustSequenceSpacing // endDefinition;

$space = " "|"  "|"   ";
$infixOperators = "+"|"-"|"*"|"/"|"^"|"&&"|"||"|"=="|"==="|"!="|"=!="|"<"|"<="|">"|">="|"->"|":>"|"="|":=";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Alternate Chat Mode Styles*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Template Boxes*)
$userMessageBoxTemplate := $userMessageBoxTemplate =
    Function @ Evaluate @ inlineTemplateBox @ TemplateBox[ { # }, "UserMessageBox" ];

$assistantMessageBoxTemplate := $assistantMessageBoxTemplate =
    Function @ Evaluate @ inlineTemplateBox @ TemplateBox[ { # }, "AssistantMessageBox" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageBox*)
assistantMessageBox // beginDefinition;

assistantMessageBox[ box_ ] :=
    assistantMessageBox[ box, $InlineChat ];

assistantMessageBox[ box_, True ] :=
    With[ { template = $assistantMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

assistantMessageBox[ box_, Except[ True ] ] :=
    TemplateBox[ { box }, "AssistantMessageBox" ];

assistantMessageBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*assistantMessageBoxActive*)
assistantMessageBoxActive // beginDefinition;

assistantMessageBoxActive[ box_ ] :=
    assistantMessageBoxActive[ box, $InlineChat ];

assistantMessageBoxActive[ box_, True ] :=
    With[ { template = $assistantMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

assistantMessageBoxActive[ box_, Except[ True ] ] :=
    TemplateBox[
        { Cell[ BoxData @ StyleBox[ box, "Text" ], Editable -> True ] },
        "AssistantMessageBox"
    ];

assistantMessageBoxActive // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*userMessageBox*)
userMessageBox // beginDefinition;

userMessageBox[ box_ ] :=
    userMessageBox[ box, $InlineChat ];

userMessageBox[ box_, True ] :=
    With[ { template = $userMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

userMessageBox[ box_, Except[ True ] ] :=
    TemplateBox[ { box }, "UserMessageBox" ];

userMessageBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $languageIcons;
    $userMessageBoxTemplate;
    $assistantMessageBoxTemplate;
];

End[ ];
EndPackage[ ];
