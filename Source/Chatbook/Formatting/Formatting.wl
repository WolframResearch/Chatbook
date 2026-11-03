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
$$ws         = WhitespaceCharacter...;

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
(* ::Section::Closed:: *)
(*Load Files*)
Get[ "Wolfram`Chatbook`Formatting`Pipeline`"         ];
Get[ "Wolfram`Chatbook`Formatting`Blocks`"           ];
Get[ "Wolfram`Chatbook`Formatting`Tables`"           ];
Get[ "Wolfram`Chatbook`Formatting`Inline`"           ];
Get[ "Wolfram`Chatbook`Formatting`CodeBlocks`"       ];
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
