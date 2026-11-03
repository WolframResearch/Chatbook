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
(*Load Files*)
Get[ "Wolfram`Chatbook`Formatting`Pipeline`"         ];
Get[ "Wolfram`Chatbook`Formatting`Blocks`"           ];
Get[ "Wolfram`Chatbook`Formatting`CodeBlockButtons`" ];
Get[ "Wolfram`Chatbook`Formatting`ToolCalls`"        ];
Get[ "Wolfram`Chatbook`Formatting`WLBoxes`"          ];
Get[ "Wolfram`Chatbook`Formatting`Images`"           ];
Get[ "Wolfram`Chatbook`Formatting`MessageBoxes`"     ];

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
