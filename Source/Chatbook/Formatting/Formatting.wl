(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

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

$resultCellCache         = <| |>;
$staticCodeBlockCache    = <| |>;
$useStaticCodeBlockCache = False;

sectionStyle[ 1 ] := "Title";
sectionStyle[ 2 ] := "Section";
sectionStyle[ 3 ] := "Subsection";
sectionStyle[ 4 ] := "Subsubsection";
sectionStyle[ 5 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

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

$$wsShortest = Shortest[ WhitespaceCharacter... ];

$$mdRow1  = $$wsShortest ~~ "|" ~~ Except[ "\n" ]... ~~ "|" ~~ $$wsShortest ~~ ("\n"|EndOfString);
(* The same rows as Except[ "\n" ].. ~~ Repeated[ "|" ~~ Except[ "\n" ]..., { 2, Infinity } ] ~~ ("\n"|EndOfString):
   a character, then at least two "|" before the end of the line. That pattern backtracks through the rest of the line
   at every position the split tries it (1.8 s for a 10 KB line without "|"). This one can't backtrack (40 ms): *)
$$mdRow2  = RegularExpression[ "[^\\n][^\\n|]*+\\|[^\\n|]*+\\|[^\\n]*+(?:\\n|\\z)" ];
$$mdRow   = $$mdRow1 | $$mdRow2;
$$mdTable = $$mdRow ~~ $$mdRow ..;

$$blockQuoteLine = StartOfLine ~~ ">" ~~ $$wsShortest ~~ Except[ "\n" ].. ~~ ("\n"|EndOfString);
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
 $freeformPromptBox        = StyleBox[ "\[FreeformPrompt]", FontColor -> color @ "NA_ChatOutputFreeFormFont", FontSize -> 9 ];


 $delimiterCell = Cell[
    BoxData @ TagBox[
        GridBox[
            { { TemplateBox[ { 0 }, "Spacer1" ] }, { TemplateBox[ { 0 }, "Spacer1" ] } },
            AutoDelete      -> False,
            GridBoxDividers -> { "Columns" -> { False, { True }, False }, "Rows" -> { False, { True }, False } },
            GridBoxItemSize -> { "Columns" -> { { Fit } }, "Rows" -> { { Automatic } } },
            FrameStyle      -> Directive[ color @ "ChatDelimiterCellFrame", AbsoluteThickness[ 1 ] ]
        ],
        "Grid"
    ],
    "MarkdownDelimiter",
    Background           -> None,
    ShowStringCharacters -> False
];


esc[ c_ ] := "\[EntityStart]" <> IntegerString @ FromDigits[ ToCharacterCode[ c, "UTF-8" ], 255 ] <> "\[EntityEnd]";

$mdEscapedCharacters = { "\\", "`", "$", "*", "_", "#", "|", "[", "]" };
$$mdEscapedCharacter = Alternatives @@ Map[ "\\"<># &, $mdEscapedCharacters ];

$mdEscapeRules    = "\\" <> # -> esc @ # & /@ $mdEscapedCharacters;
$mdUnescapeRules  = esc @ # -> # & /@ $mdEscapedCharacters;
$texUnescapeRules = esc @ # -> "\\" <> # & /@ $mdEscapedCharacters;

(* Parts of the text that keep their raw text, including any escapes (see makeResultCell1): *)
$$rawTextToken = codeBlockCell | inlineToolCallCell | thoughtsOpener | thinkingOpener | speechCell;

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
    Background   -> color @ "NA_ChatOutputToolCallFailureBackground",
    BaseStyle    -> "Output",
    FrameMargins -> 10,
    FrameStyle   -> color @ "NA_ChatOutputToolCallFailureFrame",
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

formatToolCall0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reformatTextData*)
reformatTextData // beginDefinition;
reformatTextData[ string_String ] := reformatTextData0 @ autoCorrect @ string;
reformatTextData // endDefinition;


reformatTextData0 // beginDefinition;

(* Markdown escapes (e.g. \* or \$) are replaced with placeholders before HTML entities are decoded and the text is
   split, so the escaped characters are not seen as markdown, and an entity such as &#92; never acts as an escape. The
   placeholders are removed again for each part in makeResultCell1: *)
reformatTextData0[ string_String ] :=
    Block[ { $markdownEscapes = StringContainsQ[ string, $$mdEscapedCharacter ] },
        joinAdjacentStrings @ Flatten[
            makeResultCell /@ discardBadToolCalls @ DeleteCases[
                Quiet[
                    StringSplit[
                        importHTMLEntities @ If[ $markdownEscapes, StringReplace[ string, $mdEscapeRules ], string ],
                        $textDataFormatRules,
                        IgnoreCase -> True
                    ],
                    RegularExpression::maxrec
                ],
                ""
            ]
        ]
    ];

reformatTextData0 // endDefinition;

(* Whether the text that is being formatted contains markdown escapes (set by reformatTextData0): *)
$markdownEscapes = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*restoreRawText*)
restoreRawText // beginDefinition;

(* The placeholders become the original escapes again, which gives back the exact raw text: *)
restoreRawText[ (h: $$rawTextToken)[ args___String ] ] := h @@ StringReplace[ { args }, $texUnescapeRules ];

restoreRawText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*unescapeMarkdownStrings*)
unescapeMarkdownStrings // beginDefinition;
unescapeMarkdownStrings[ expr_ ] := ReplaceAll[ expr, s_String :> RuleCondition @ StringReplace[ s, $mdUnescapeRules ] ];
unescapeMarkdownStrings // endDefinition;

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
            $resultCellCache[ HoldComplete @ expr ] = makeResultCell1 @ expr
    ];

makeResultCell[ expr_ ] := makeResultCell1 @ expr;

makeResultCell // endDefinition;


makeResultCell1 // beginDefinition;

(* When the text has markdown escapes, the parts that keep their raw text (code blocks, tool calls, think tags and
   speech) get their escapes back, and every other part has the placeholders in its output replaced with the plain
   characters. This is done for each part, since some of them are compressed until they're viewed: *)
makeResultCell1[ expr: $$rawTextToken[ ___ ] ] /; $markdownEscapes := makeResultCell0 @ restoreRawText @ expr;
makeResultCell1[ expr_ ] /; $markdownEscapes := unescapeMarkdownStrings @ makeResultCell0 @ expr;
makeResultCell1[ expr_ ] := makeResultCell0 @ expr;

makeResultCell1 // endDefinition;


makeResultCell0 // beginDefinition;

(* The third template box argument holds metadata that determines how the box is serialized, e.g.
   <| "Type" -> "Literal" |> for literal <think> tags, or <| "Type" -> "Summary", "ID" -> ..., "Signature" -> ... |>
   for reasoning summaries (see Reasoning.wl) *)
makeResultCell0[ thinkingOpener[ thoughts_String ] ] :=
    makeResultCell0 @ thinkingOpener[ thoughts, <| "Type" -> "Literal" |> ];

makeResultCell0[ thinkingOpener[ thoughts_String, attributes_String ] ] :=
    makeResultCell0 @ thinkingOpener[ thoughts, reasoningMetadata @ attributes ];

makeResultCell0[ thinkingOpener[ thoughts_String, meta_Association ] ] := (
    If[ $thinkingStart === None, $thinkingStart = AbsoluteTime[ ] ];
    Cell[
        BoxData @ templateBox[
            { formatThoughts @ thoughts, ToBoxes @ tr @ "FormattingThinkingActive", meta },
            "ThinkingOpener"
        ],
        "ThinkingOpener",
        Background -> None
    ]
);

makeResultCell0[ thoughtsOpener[ thoughts_String ] ] :=
    makeResultCell0 @ thoughtsOpener[ thoughts, <| "Type" -> "Literal" |> ];

makeResultCell0[ thoughtsOpener[ thoughts_String, attributes_String ] ] :=
    makeResultCell0 @ thoughtsOpener[ thoughts, reasoningMetadata @ attributes ];

makeResultCell0[ thoughtsOpener[ thoughts_String, meta_Association ] ] :=
    Module[ { label, box },
        label = ToBoxes @ thoughtsLabel @ meta;
        box = If[ StringTrim @ thoughts === "",
                  templateBox[ { "", label, meta }, "EmptyThoughts" ], (* no summary available, so only show label *)
                  templateBox[ { formatThoughts @ thoughts, label, meta }, "ThoughtsOpener" ]
              ];
        {
            Cell[ BoxData @ box, "ThoughtsOpener", Background -> None ],
            "\n"
        }
    ];

makeResultCell0[ speechCell[ speech_String ] ] :=
    formatSpeechInput @ speech;

makeResultCell0[ discardedMaterial[ stuff___ ] ] :=
    makeDiscardedMaterialCell @ stuff;

makeResultCell0[ str_String ] := formatTextString @ str;

makeResultCell0[ codeBlockCell[ language_String, code_String ] ] := {
    makeCodeBlockCell[
        StringReplace[ StringDelete[ StringTrim @ language, StartOfString~~"```" ], $externalLanguageRules, IgnoreCase -> True ],
        StringDelete[ code, { StartOfString~~Whitespace~~StartOfLine, Whitespace~~EndOfString } ]
    ]
};

makeResultCell0[ inlineCodeCell[ code_String? almostCertainlyWLCodeQ ] ] :=
    makeInlineWL @ StringReplace[ code, $mdUnescapeRules ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := ReplaceAll[
    makeInlineCodeCell @ StringReplace[ code, $mdUnescapeRules ],
    "\[FreeformPrompt]" :> RuleCondition @ $freeformPromptBox
];

makeResultCell0[ mathCell[ math_String ] ] /; StringMatchQ[ math, (DigitCharacter|"."|","|" ").. ] :=
    math;

makeResultCell0[ mathCell[ name_String ] ] /; systemNameQ @ name && StringLength @ name > 1 :=
    makeResultCell0 @ inlineCodeCell @ name;

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = makeTeXBoxes @ StringReplace[ math, $texUnescapeRules ] },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ toTeXBoxes @ boxes,
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ imageCell[ alt_, url_String ] ] := image[ alt, url ];

makeResultCell0[ bulletCell[ "", item_String ] ] := {
    "\n",
    Cell[
        TextData @ Flatten @ {
            StyleBox[ "\[Bullet]", FontColor -> color @ "NA_ChatOutputResultCellBulletFont" ],
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
            StyleBox[ "\[Bullet]", FontColor -> color @ "NA_ChatOutputResultCellBulletFont" ],
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
                    BaseStyle    -> { "Text", FontColor -> color @ "NA_ChatOutputResultCellBlockQuoteFont" }
                ]
            }
        },
        AutoDelete        -> False,
        GridBoxBackground -> { "Columns" -> { { color @ "NA_ChatOutputResultCellBlockQuoteBackground" } } },
        GridBoxDividers   -> {
            "ColumnsIndexed" -> { 1 -> Directive[ color @ "NA_ChatOutputResultCellBlockQuoteFrame", AbsoluteThickness[ 4 ] ] },
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
(*thoughtsLabel*)
thoughtsLabel // beginDefinition;

(* Reasoning summaries store the time spent on each reasoning item: *)
thoughtsLabel[ KeyValuePattern @ { "Type" -> "Summary", "Duration" -> seconds_? NumberQ } ] :=
    thoughtsLabel @ Max[ 1, Round @ seconds ];

thoughtsLabel[ KeyValuePattern[ "Type" -> "Summary" ] ] :=
    tr @ "FormattingThinkingCompleteFallback";

(* Literal think tags are timed from when they're first displayed: *)
thoughtsLabel[ _Association ] := (
    If[ $thinkingEnd === None, $thinkingEnd = AbsoluteTime[ ] ];
    thoughtsLabel @ If[ NumberQ @ $thinkingStart && NumberQ @ $thinkingEnd,
                        Max[ 1, Round[ $thinkingEnd - $thinkingStart ] ],
                        None
                    ]
);

thoughtsLabel[ 1 ] :=
    tr[ "FormattingThinkingCompleteSingular" ];

thoughtsLabel[ seconds_Integer ] :=
    trStringTemplate[ "FormattingThinkingComplete" ][ <| "time" -> ToString @ seconds |> ];

thoughtsLabel[ None ] :=
    tr @ "FormattingThinkingCompleteFallback";

thoughtsLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatThoughts*)
formatThoughts // beginDefinition;

formatThoughts[ thoughts_String ] :=
    formatThoughts[ thoughts, StringTrim @ thoughts ];

formatThoughts[ thoughts_, "" ] :=
    "";

formatThoughts[ thoughts_, trimmed_String ] :=
    Block[
        { $textDataFormatRules = $thoughtsFormatRules },
        TextData @ reformatTextData @ trimmed
    ];

formatThoughts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*inlineSection*)
inlineSection // beginDefinition;

inlineSection[ content_, style_String ] :=
    inlineSection[ content, style, sectionMargins @ style, sectionFontSize @ style ];

inlineSection[ content_, style_String, margins: { { _, _ }, { _, _ } }, size_ ] := Cell[
    BoxData @ PaneBox[
        StyleBox[
            formatTextToBoxes @ content,
            style,
            CellFrame            -> 0,
            FontSize             -> size,
            ShowStringCharacters -> False
        ],
        ImageMargins -> margins
    ],
    "InlineSection",
    Background -> None
];

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
(* ::Subsubsubsection::Closed:: *)
(*sectionFontSize*)
sectionFontSize // beginDefinition;
sectionFontSize[ "Title"   ] := 26;
sectionFontSize[ "Section" ] := 22;
sectionFontSize[ _String   ] := Inherited;
sectionFontSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeDiscardedMaterialCell*)
makeDiscardedMaterialCell // beginDefinition;

makeDiscardedMaterialCell[ stuff___ ] :=
    makeDiscardedMaterialCell0 @ joinAdjacentStrings @ Flatten[ makeResultCell /@ { stuff } ];

makeDiscardedMaterialCell // endDefinition;


makeDiscardedMaterialCell0 // beginDefinition;

makeDiscardedMaterialCell0[ _List ] /; $dynamicText := {
    Cell[
        BoxData @ ToBoxes @ fakeOpenerView @ tr @ "FormattingDiscardedMaterial",
        "DiscardedMaterial",
        Background -> None
    ],
    "\n"
};

makeDiscardedMaterialCell0[ textData_List ] := {
    Cell[
        BoxData @ ToBoxes @ openerView[
            { tr @ "FormattingDiscardedMaterial", compressUntilViewed @ discardedMaterialColumn @ textData, "Discarded" },
            False
        ],
        "DiscardedMaterial",
        Background -> None
    ],
    "\n"
};

makeDiscardedMaterialCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*discardedMaterialColumn*)
$$discardedToolCallCell = Cell[ _, "InlineToolCall" | "FailedToolCall", ___ ];

discardedMaterialColumn // beginDefinition;

discardedMaterialColumn[ textData_List ] := Column[
    discardedMaterialRow /@ discardedMaterialGroups @ textData,
    Spacings -> 0.5
];

discardedMaterialColumn // endDefinition;


discardedMaterialRow // beginDefinition;

discardedMaterialRow[ group_List ] := RawBoxes @ Cell[
    TextData @ group,
    "Text",
    Background  -> None,
    FontOpacity -> 0.5
];

discardedMaterialRow // endDefinition;


discardedMaterialGroups // beginDefinition;

discardedMaterialGroups[ textData_List ] := Split[ textData, ! MatchQ[ #2, $$discardedToolCallCell ] & ];

discardedMaterialGroups // endDefinition;

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
delimiterAlignment[ ___               ] := Left;

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

formatTextString[ code_String? almostCertainlyWLCodeQ ] :=
    { makeInlineWL @ code };

formatTextString[ str_String ] := dropEmptyEnds @ Replace[ StringSplit[
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
    $stringFormatRulesDeferred,
    IgnoreCase -> True
], deferredFormat[ e_ ] :> e, { 1 } ];

formatTextString // endDefinition;

(* StringSplit drops "" from both ends of its result, including "" given by a right-hand side (styleBox gives "" for
   "**```**"). The deferred right-hand sides are evaluated after the split, so their "" is dropped here instead: *)
dropEmptyEnds // beginDefinition;
dropEmptyEnds[ { "", rest___ } ] := dropEmptyEnds @ { rest };
dropEmptyEnds[ { rest___, "" } ] := dropEmptyEnds @ { rest };
dropEmptyEnds[ list_List ] := list;
dropEmptyEnds // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*almostCertainlyWLCodeQ*)
almostCertainlyWLCodeQ // beginDefinition;

almostCertainlyWLCodeQ[ wl_String ] := almostCertainlyWLCodeQ[ wl, False ];

almostCertainlyWLCodeQ[ wl_String, inline_ ] := TrueQ @ Or[
    If[ TrueQ @ inline, StringContainsQ, StringStartsQ ][ wl, "\[FreeformPrompt]" ],
    (* A System name followed by [...] or by -> or :>. No System name contains "[", whitespace, "-" or ":", so the only
       candidate name is the text before the first of these, and systemNameQ is only called once the rest matches: *)
    StringMatchQ[
        wl,
        (name: Repeated[ Except[ "["|WhitespaceCharacter|"-"|":" ], { 1, 50 } ] ~~ Alternatives[
            "[" ~~ ___ ~~ "]",
            $$ws ~~ ("->"|":>") ~~ __
        ]) /; systemNameQ @ name
    ],
    TrueQ @ inline && StringMatchQ[ wl, "\"" ~~ ___ ~~ "\"" ]
];

almostCertainlyWLCodeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeInlineWL*)
makeInlineWL // beginDefinition;

makeInlineWL[ code_String ] := Cell[
    BoxData @ wlStringToBoxes @ code,
    "InlineWL", "Input",
    LanguageCategory     -> "Input",
    ShowAutoStyles       -> True,
    ShowStringCharacters -> True,
    ShowSyntaxStyles     -> True
];

makeInlineWL // endDefinition;

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
(*$toolCallFormatRules*)

(* The rules for tool calls in $textDataFormatRules: *)
$toolCallFormatRules = {
    Longest @ StringExpression[
        (("```" ~~ Except[ "\n" ]... ~~ (" "...) ~~ "\n"))|"",
        tool: ("TOOLCALL:" ~~ Shortest[ ___ ] ~~ ($$endToolCall|EndOfString))
    ] :> inlineToolCallCell @ tool
    ,
    Longest @ StringExpression[
        (("```" ~~ Except[ "\n" ]... ~~ (" "...) ~~ "\n"))|"",
        tool: $$simpleToolCall
     ] /; ! StringStartsQ[ tool, $$ws ~~ "/retry" ~~ $$eol ] && simpleToolCallStringQ @ tool :> inlineToolCallCell @ tool
    ,
    $$ws ~~ "/retry" ~~ (WhitespaceCharacter|EndOfString) :> $discardPreviousToolCall
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$textDataFormatRules*)

(* Display math written as \[...\], with whitespace (or the start or end of the text) around it. The brackets are
   markdown escapes, so at this point they are the placeholders esc[ "[" ] and esc[ "]" ] (4 characters each): *)
$$escapedDisplayMath = RegularExpression[ "(?s)(?<!\\S)" <> esc[ "[" ] <> ".+?" <> esc[ "]" ] <> "(?!\\S)" ];

(* The same in a text fragment, where it needs whitespace before it (see $stringFormatRules): *)
$$escapedDisplayMathInline = RegularExpression[ "(?s)(?<=\\s)" <> esc[ "[" ] <> ".+?" <> esc[ "]" ] <> "(?!\\S)" ];

$textDataFormatRules = {
    Shortest[ "<think"~~attributes: $$thinkTagAttributes~~">"~~thoughts___~~"</think>" ] :>
        thoughtsOpener[ thoughts, attributes ],
    Shortest[ "<think>"~~thoughts__~~"</think>" ] :> thoughtsOpener @ thoughts,
    Shortest[ "<thinking>"~~thoughts__~~"</thinking>" ] :> thoughtsOpener @ thoughts,
    Shortest[ "<think"~~attributes: $$thinkTagAttributes~~">"~~thoughts___~~EndOfString ] :>
        thinkingOpener[ thoughts, attributes ],
    Shortest[ ("<think>"|"<thinking>")~~thoughts__~~EndOfString ] :> thinkingOpener @ thoughts,

    speech: Shortest[ "<speech-input>"~~__~~"</speech-input>" ] :> speechCell @ speech,

    (* Whitespace-delimited \[...\] is display math (only possible when the text has escapes): *)
    math: $$escapedDisplayMath :> mathCell @ StringTake[ math, { 5, -5 } ],

    StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        ("```"|EndOfString)
    ] /; toolCallStringFreeQ @ code :>
        If[ StringMatchQ[ code, $$mdTable ],
            tableCell @ code,
            codeBlockCell[ language, code ]
        ]
    ,
    Sequence @@ $toolCallFormatRules
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
    "[`ResourceFunction[" ~~ name: Except[ "[" ].. ~~ "]`](" ~~ Except[ ")" ].. ~~ ")" :>
        inlineCodeCell[ "ResourceFunction[" <> name <> "]" ]
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
(* ::Subsection::Closed:: *)
(*$thoughtsFormatRules*)

(* Markdown in the contents of think tags is formatted, but anything that looks like a tool call or another think tag is
   left as plain text: *)
$$thoughtsExcludedRule = HoldPattern @ RuleDelayed[
    _,
    _thoughtsOpener | _thinkingOpener | _inlineToolCallCell | $discardPreviousToolCall
];

$thoughtsFormatRules = DeleteCases[ $textDataFormatRules, $$thoughtsExcludedRule ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolShortNameQ*)
toolShortNameQ // beginDefinition;
toolShortNameQ[ cmd_String ] := MatchQ[ $ChatHandlerData[ "ToolShortNames" ][ cmd ], _LLMTool ];
toolShortNameQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*simpleToolCallStringQ*)
simpleToolCallStringQ // beginDefinition;
simpleToolCallStringQ[ string_String ] := StringMatchQ[ string, $$simpleToolCall ] && simpleToolCallStringQ0 @ string;
simpleToolCallStringQ[ ___ ] := False;
simpleToolCallStringQ // endDefinition;

simpleToolCallStringQ0 // beginDefinition;
simpleToolCallStringQ0[ string_String ] /; StringContainsQ[ string, $$endToolCall ] := True;
simpleToolCallStringQ0[ string_String ] := MatchQ[
    StringCases[ string, StartOfString ~~ $$ws ~~ "/" ~~ cmd: $$cmd ~~ $$eol ~~ ___ :> cmd, 1 ],
    { _String? toolShortNameQ }
];
simpleToolCallStringQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*toolCallStringFreeQ*)
toolCallStringFreeQ // beginDefinition;
toolCallStringFreeQ[ string_String ] :=
    StringFreeQ[ string, "TOOLCALL:" ~~ ___ ~~ ($$endToolCall|EndOfString) ] &&
    ! simpleToolCallStringQ[ string ];
toolCallStringFreeQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$dynamicSplitRules*)

(* Defines safe points to split content into static/dynamic parts. These patterns must be different from
   `$textDataFormatRules`, since there will be no additional formatting passes once static content is written.
   Therefore, some of the patterns that would match up to `EndOfString` must instead be explicitly terminated here.

   While streaming, the split is skipped if new text can't complete a match (see `dynamicSplitSkipQ` in SendChat.wl).
   That relies on all of the following, so it needs to be updated if any of them change:
   - Every match ends with "```", "ENDRESULT", or ")", and no delimiter that ends a match is longer than
     `$dynamicSplitOverlap + 1` characters.
   - A match that ends with ")" is only possible when the content contains "![" or "ENDRESULT(".
   - No pattern looks past the end of its match, and conditions only depend on the matched text. The exceptions are
     the conditions of the code block and simple tool call rules, which also depend on
     `$ChatHandlerData[ "ToolShortNames" ]`. If that changed while a response streams, a split could be delayed, which
     only affects the streaming display.
*)
$dynamicSplitRules = {
    (* Code blocks *)
    s: StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        "```"
    ] /; toolCallStringFreeQ @ code :> s
    ,
    (* Markdown image *)
    s: ("![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")") /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            s
    ,
    (* Tool call *)
    s: Shortest[ "TOOLCALL:" ~~ ___ ~~ $$endToolCall ] :> s <> "\n",
    s: Shortest[ $$simpleToolCommand ~~ ___ ~~ $$endToolCall ] /; simpleToolCallStringQ @ s :> s
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$stringFormatRules*)

(* Underscores only mark emphasis at word boundaries, so names like `snake_case_name` are left as-is: *)
$stringFormatRules = {
    "```" ~~ code: Except[ "\n" ].. ~~ "```" :> inlineCodeCell @ code,

    "***" ~~ text: Except[ "*" ].. ~~ "***" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    WordBoundary ~~ "___" ~~ text: Except[ "_" ].. ~~ "___" ~~ WordBoundary /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    "**" ~~ text: Except[ "*" ].. ~~ "**" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold ],

    WordBoundary ~~ "__" ~~ text: Except[ "_" ].. ~~ "__" ~~ WordBoundary /; StringFreeQ[ text, "\n" ] :>
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

    WordBoundary ~~ "_" ~~ text: Except[ "_" ].. ~~ "_" ~~ WordBoundary /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "$$" ~~ math__ ~~ "$$" /; StringFreeQ[ math, "$$" ] :>
        makeResultCell @ mathCell @ math,

    "\\(" ~~ math__ ~~ "\\)" /; StringFreeQ[ math, "\\)" ] :>
        makeResultCell @ mathCell @ math,

    "\\[" ~~ math__ ~~ "\\]" /; StringFreeQ[ math, "\\]" ] :>
        makeResultCell @ mathCell @ math,

    (* Escaped \[...\] in a list item, heading, table cell, ... (see $$escapedDisplayMath). The start of the text
       doesn't count as whitespace here, so that e.g. the label in [\[x\]](url) is not math: *)
    math: $$escapedDisplayMathInline :>
        makeResultCell @ mathCell @ StringTake[ math, { 5, -5 } ],

    "$" ~~ math: Except[ "$" ].. ~~ "$" /; probablyMathQ @ math :>
        makeResultCell @ mathCell @ math,

    "![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")" /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            makeResultCell @ imageCell[ alt, url ],

    "[" ~~ label: Shortest[ ___ ] ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :>
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

(* styleBox and hyperlink format their text with formatTextString, which splits it with these same rules. Starting a
   StringSplit with a rule list from inside one of that list's right-hand sides is slow (about 8 ms each time for this
   list, with or without IgnoreCase), so formatTextString uses a copy whose right-hand sides are held until the split
   has finished. The patterns and conditions are unchanged, and the right-hand sides are evaluated in the same order: *)
SetAttributes[ deferredFormat, HoldAllComplete ];
$stringFormatRulesDeferred = Replace[ $stringFormatRules, (l_ :> r_) :> (l :> deferredFormat @ r), { 1 } ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatted Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCodeBlockCell*)
makeCodeBlockCell // beginDefinition;
makeCodeBlockCell[ _, code_String ] /; StringMatchQ[ StringTrim @ code, "!["~~__~~"]("~~__~~")" ] := image @ code;
makeCodeBlockCell[ language_String, code_String ] /; $useStaticCodeBlockCache && ! TrueQ @ $dynamicText :=
    cachedCodeBlockCell[ language, code ];
makeCodeBlockCell[ language_String, code_String ] /; plaintextLanguageQ @ language :=
    makeInteractiveCodeCell[ "Plaintext", unescapePlainTextCodeBlock @ stripCodePadding @ code ];
makeCodeBlockCell[ language_String, code_String ] := makeInteractiveCodeCell[ language, stripCodePadding @ code ];
makeCodeBlockCell // endDefinition;

unescapePlainTextCodeBlock // beginDefinition;
unescapePlainTextCodeBlock[ string_String ] := StringReplace[ string, "\\\\" -> "\\" ];
unescapePlainTextCodeBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedCodeBlockCell*)
cachedCodeBlockCell // beginDefinition;

(* Code blocks are formatted when they're written as static content during streaming, and again when the final cell is
   written. The non-dynamic formatting (which includes a front end round trip for Wolfram Language code) gives the same
   result both times, so it's cached for the current response. The key includes the globals that formatting uses: *)
cachedCodeBlockCell[ language_String, code_String ] :=
    With[ { key = { language, code, $SidebarChat, $WorkspaceChat, $InlineChat, $cloudNotebooks } },
        Lookup[
            $staticCodeBlockCache,
            Key @ key,
            $staticCodeBlockCache[ key ] =
                Block[ { $useStaticCodeBlockCache = False }, makeCodeBlockCell[ language, code ] ]
        ]
    ];

cachedCodeBlockCell // endDefinition;

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
    TaggingRules -> KeyDrop[ as, { "Icon", "CallIcon", "Result" } ]
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
    Catch @ Module[ { command, argString, tool, name, paramNames, params, result },
        command = First @ ConfirmMatch[
            StringCases[
                string,
                StartOfString ~~ $$ws ~~ ("/" ~~ cmd: $$cmd) ~~ $$eol ~~ ___ :> cmd,
                1
            ],
            { _String },
            "Command"
        ];

        If[ ! toolShortNameQ @ command,
            Throw @ Failure[
                "InvalidToolCall",
                <|
                    "MessageTemplate"   -> "No tool found that uses the command \"`1`\".",
                    "MessageParameters" -> { command }
                |>
            ]
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
            "CallIcon"    -> getToolCallIcon @ tool,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> params,
            "Result"      -> result
        |>
    ],
    throwInternalFailure
];

parsePartialToolCallString[ string_String ] /; StringMatchQ[ string, "TOOLCALL:"~~__~~"{"~~___ ] :=
    Module[ { noPrefix, noSuffix, name, tool, displayName, icon, callIcon, query, result },

        noPrefix    = StringDelete[ string, StartOfString~~"TOOLCALL:" ];
        noSuffix    = StringTrim @ StringDelete[ noPrefix, "ENDRESULT"~~___~~EndOfString ];
        name        = StringTrim @ StringDelete[ noSuffix, ("\n"|"{")~~___~~EndOfString ];
        tool        = getToolByName @ name;
        displayName = getToolDisplayName[ tool, name ];
        icon        = getToolIcon @ tool;
        callIcon    = getToolCallIcon @ tool;
        query       = First[ StringCases[ string, "TOOLCALL:" ~~ q___ ~~ "\nRESULT" :> q ], "" ];
        result      = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        <|
            "Name"        -> name,
            "DisplayName" -> displayName,
            "Icon"        -> icon,
            "CallIcon"    -> callIcon,
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
        "CallIcon"           -> getToolCallIcon @ tool,
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

makeToolCallBoxLabel[ as_Association, name_String ] /; $dynamicText :=
    fakeOpenerView @ makeToolCallBoxLabel0[ as, name, toolCallIcon[ as, $fakeOpenerColor ] ];

makeToolCallBoxLabel[ as0_Association, name_String ] :=
    With[ { as = resolveToolFormatter @ as0 },
        openerView[
            {
                Function[ col, makeToolCallBoxLabel0[ as, name, toolCallIcon[ as, col ] ] ],
                (*TODO: custom interface LLM 667 *)
                TabView[
                    {
                        "Raw"         -> makeToolCallRawView @ as,
                        "Interpreted" -> makeToolCallInterpretedView @ as
                    },
                    2,
                    ImageSize  -> Automatic,
                    LabelStyle -> { FontSize -> 12 }
                ],
                "Tool"
            },
            TrueQ @ as0[ "Open" ]
        ]
    ];

makeToolCallBoxLabel // endDefinition;


makeToolCallBoxLabel0 // beginDefinition;

makeToolCallBoxLabel0[ KeyValuePattern[ "Result" -> "" ], string_String, icon_ ] :=
With[ { col = $fakeOpenerColor },
    Flatten @ {
        toolCallIconPane @ icon,
        Style[ tr[ "FormattingToolUsing" ], FontColor -> col ],
        Style[ string, FontWeight -> "Plain", FontColor -> col ],
        activeToolProgressIndicator[ ]
    }
];

makeToolCallBoxLabel0[ as_, string_String, icon_ ] := Flatten @ {
    toolCallIconPane @ icon,
    tr[ "FormattingToolUsed" ],
    Style[ string, FontWeight -> "Plain" ]
};

makeToolCallBoxLabel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIcon*)
$fakeOpenerColor = RGBColor[ 0.53214525, 0.6238195470000001, 0.67275 ];

toolCallIcon // beginDefinition;
toolCallIcon[ KeyValuePattern[ "CallIcon" -> icon_Function ], color_ ] := icon @ color;
toolCallIcon[ _, color_ ] := getToolCallIcon[ None ][ color ];
toolCallIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*activeToolProgressIndicator*)
activeToolProgressIndicator // beginDefinition;

activeToolProgressIndicator[ ] :=
    RawBoxes @ TagBox[ ToBoxes @ chatbookIcon[ "PercolateProgressAnimation", False ], "ChatbookActiveToolProgress" ];

activeToolProgressIndicator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIconPane*)
toolCallIconPane // beginDefinition;

toolCallIconPane[ icon_ ] := Pane[
    icon,
    Alignment        -> { Left, Center },
    BaselinePosition -> Scaled[ 0.27 ],
    ContentPadding   -> False,
    FrameMargins     -> { { 0, 0 }, { 0, 0 } },
    ImageMargins     -> { { 0, 2}, { 2, 2 } },
    ImageSize        -> { 20, 20 },
    ImageSizeAction  -> "ShrinkToFit"
];

toolCallIconPane // endDefinition;


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
            Background   -> color @ "NA_ChatOutputToolCallBackground",
            FrameMargins -> 5,
            FrameStyle   -> None,
            ImageSize    -> { Scaled[ 1 ], Automatic },
            BaseStyle    -> "Text"
        ],
        Background   -> color @ "NA_ChatOutputToolCallBackground",
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
                    Pane[ Style[ (*FIXME:TR*)"INPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> color @ "NA_ChatOutputToolCallHeaderBackground"
                ],
                Framed[
                    makeToolCallInputSection @ as,
                    Background   -> color @ "NA_ChatOutputToolCallBackground",
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ],
                Item[
                    Pane[ Style[ (*FIXME:TR*)"OUTPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> color @ "NA_ChatOutputToolCallHeaderBackground"
                ],
                Framed[
                    makeToolCallOutputSection @ as,
                    Background   -> color @ "NA_ChatOutputToolCallBackground",
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            },
            Alignment -> Left
        ],
        Background   -> color @ "NA_ChatOutputToolCallBackground",
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
            BaseStyle  -> { "Text", LineBreakWithin -> Automatic },
            Dividers   -> All,
            FrameStyle -> color @ "NA_ChatOutputToolCallInputFrame",
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
            wideScrollPane @ ReplaceAll[ formatter[ result, "Result" ], Cell[ bd_BoxData, a___, "Input", b___ ] :> Cell[ bd, a, "Output", b ] ],
            "Text",
            Background      -> None,
            FrameBoxOptions -> { BaselinePosition -> Automatic },
            LineBreakWithin -> Automatic,
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

(* This definition is similar to WorkspaceStyles.wl: "ChatCodeBlockTemplate" but has a wider minimum because it has more room initially *)
wideScrollPane[ expr_ ] := Pane[
    Pane[ expr, ImageSize -> Dynamic[ Function[ If[ # > 600, #, 600 ] ][ 0.9*AbsoluteCurrentValue[ { WindowSize, 1 } ] ] ] ],
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
    Catch @ Module[ { sl, split, trimmed, rows },

        sl = StartOfLine ~~ # &;

        split = StringSplit[
            code,
            {
                l: sl @ $$inLabel         :> label[ "Input"     , StringTrim @ l ],
                l: sl @ $$outLabel        :> label[ "Output"    , StringTrim @ l ],
                l: sl @ $$echoLabel       :> label[ "Echo"      , StringTrim @ l ],
                l: sl @ $$echoTimingLabel :> label[ "EchoTiming", StringTrim @ l ],
                l: sl @ $$messageLabel    :> label[ "Message"   , StringTrim @ l ],
                l: sl @ $$printLabel      :> label[ "Print"     , StringTrim @ l ]
            }
        ];

        trimmed = DeleteCases[ Replace[ split, s_String :> StringTrim @ s, { 1 } ], "" ];

        (* No labels: *)
        Replace[ trimmed, { _ } :> Throw @ code ];

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
$$echoLabel       = ">>";
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
makeBlockLabel[ label_, "Print" ] := "";

makeBlockLabel[ label_String, "Echo" ] := StyleBox[
    StringReplace[ label, { ">>" -> "\[RightGuillemet]", "<<" -> "\[LeftGuillemet]" } ],
    "EchoDingbat"
];

makeBlockLabel // endDefinition;

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

makeInlineCodeCell[ s_String? systemNameQ ] :=
    hyperlink[ s, "paclet:ref/" <> Last @ StringSplit[ s, "`" ] ];

makeInlineCodeCell[ refLink_String ] /; StringMatchQ[ refLink, "[" ~~ name__ ~~ "](paclet:ref/" ~~ name__ ~~ ")" ] :=
    formatTextString @ refLink;

makeInlineCodeCell[ code_String /; almostCertainlyWLCodeQ[ code, True ] ] :=
    makeInlineWL @ code;

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
    BoxData @ templateBox[ { cell, lang }, If[ $SidebarChat, "NotebookAssistant`Sidebar`ChatCodeBlockTemplate", "ChatCodeBlockTemplate" ] ],
    "ChatCodeBlock"
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

cachedBoxes[ e: _Manipulate|_DynamicModule|_Dynamic ] :=
    checkBoxes @ MakeBoxes @ e;

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

hyperlink[ rf_String, uri_ ] /; StringMatchQ[ rf, ("`"|"")~~"ResourceFunction[" ~~ ___ ~~ "]"~~("`"|"") ] :=
    makeInlineWL @ rf;

hyperlink[ label_String, uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
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

hyperlink[ { label: _String|_StyleBox|_Cell }, url_ ] := ButtonBox[
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
(*systemNameQ*)
systemNameQ // beginDefinition;
systemNameQ[ name_String? nameQ ] := Context @ name === "System`";
systemNameQ[ ___ ] := False;
systemNameQ // endDefinition;

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
    assistantMessageBoxActive[ box, "Inline" ];

assistantMessageBoxActive[ box_, "Inline" ] :=
    With[ { template = $assistantMessageBoxTemplate @ box },
        template /; MatchQ[ template, TemplateBox[ __, DisplayFunction -> _, ___ ] ]
    ];

assistantMessageBoxActive[ box_, "Workspace" ] :=
    TemplateBox[
        { Cell[ BoxData @ StyleBox[ box, "Text" ], Editable -> True ] },
        "AssistantMessageBoxActive"
    ];

assistantMessageBoxActive[ box_, "Sidebar" ] :=
    TemplateBox[
        { Cell[ BoxData @ StyleBox[ box, "Text" ], Editable -> True ] },
        "NotebookAssistant`Sidebar`AssistantMessageBoxActive"
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
(*Load Files*)
Get[ "Wolfram`Chatbook`Formatting`CodeBlockButtons`" ];
Get[ "Wolfram`Chatbook`Formatting`WLBoxes`"          ];

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
