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
(*Markdown Escapes*)
esc[ c_ ] := "\[EntityStart]" <> IntegerString @ FromDigits[ ToCharacterCode[ c, "UTF-8" ], 255 ] <> "\[EntityEnd]";

$mdEscapedCharacters = { "\\", "`", "$", "*", "_", "#", "|", "[", "]" };
$$mdEscapedCharacter = Alternatives @@ Map[ "\\"<># &, $mdEscapedCharacters ];

$mdEscapeRules    = "\\" <> # -> esc @ # & /@ $mdEscapedCharacters;
$mdUnescapeRules  = esc @ # -> # & /@ $mdEscapedCharacters;
$texUnescapeRules = esc @ # -> "\\" <> # & /@ $mdEscapedCharacters;

(* Inline code keeps the backslash of \\, \[ and \] (as in "\\d" or \[Alpha]), since CommonMark has no escapes in code
   spans. The other escapes are removed: models often escape ` and $ in inline code too (e.g. `\$Failed`), and
   serialization currently escapes ` $ * _ # | in inline code (a known quirk, see "Inline code content is
   markdown-escaped when serialized" in Developer/FormatterHarness/QUIRKS.md), so removing them keeps round trips
   stable: *)
$codeUnescapeRules = esc @ # -> If[ MemberQ[ { "\\", "[", "]" }, # ], "\\" <> #, # ] & /@ $mdEscapedCharacters;

(* Parts of the text that keep their raw text, including any escapes (see makeResultCell1): *)
$$rawTextToken = codeBlockCell | inlineToolCallCell | thoughtsOpener | thinkingOpener | speechCell;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Patterns*)
$$wsShortest = Shortest[ WhitespaceCharacter... ];
$$ws         = WhitespaceCharacter...;

(* Table rows and quote lines don't include the "\n" at the end of their line, so the text after a table or quote
   starts with its line break, as it does after the other blocks: *)
$$mdRow1  = $$wsShortest ~~ "|" ~~ Except[ "\n" ]... ~~ "|" ~~ $$wsShortest ~~ EndOfLine;
(* The same rows as Except[ "\n" ].. ~~ Repeated[ "|" ~~ Except[ "\n" ]..., { 2, Infinity } ] ~~ EndOfLine:
   a character, then at least two "|" before the end of the line. That pattern backtracks through the rest of the line
   at every position the split tries it (1.8 s for a 10 KB line without "|"). This one can't backtrack (40 ms): *)
$$mdRow2  = RegularExpression[ "[^\\n][^\\n|]*+\\|[^\\n|]*+\\|[^\\n]*+" ];
$$mdRow   = $$mdRow1 | $$mdRow2;
$$mdTable = $$mdRow ~~ ("\n" ~~ $$mdRow)..;

$$blockQuoteLine = StartOfLine ~~ ">" ~~ $$wsShortest ~~ Except[ "\n" ]..;
$$blockQuote     = Longest[ $$blockQuoteLine ~~ ("\n" ~~ $$blockQuoteLine)... ];

$$hyphenDelimiter     = Repeated[ "-", { 3, Infinity } ];
$$asteriskDelimiter   = Repeated[ "*", { 3, Infinity } ];
$$underscoreDelimiter = Repeated[ "_", { 3, Infinity } ];
$$delimiter           = StartOfLine ~~ ($$hyphenDelimiter|$$asteriskDelimiter|$$underscoreDelimiter) ~~ EndOfLine;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing Rules*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Named Patterns*)

(* The pieces of the rules below. Each one names the parts that the rules use (code, math, text, url, ...). Names in a
   pattern are replaced by their values when a rule is defined, but a condition's test and a right-hand side are held,
   so names there (like $$ws in the simple tool call rule) stay symbols in the rule. *)

(* Tool calls end with ENDRESULT or ENDRESULT(id), and can be written inside a code fence. The marker is case-sensitive
   even though the rules are used with IgnoreCase -> True, so that words like "sendResult" don't end a tool call: *)
$$toolCallEnd       = Longest[
    RegularExpression[ "(?-i:ENDRESULT)" ] ~~ (("(" ~~ (LetterCharacter|DigitCharacter).. ~~ ")") | "")
];
$$toolCall          = "TOOLCALL:" ~~ Shortest[ ___ ] ~~ ($$toolCallEnd|EndOfString);
$$eol               = " "... ~~ "\n";
$$cmd               = Repeated[ Except[ WhitespaceCharacter ], { 1, 80 } ];
$$simpleToolCommand = StartOfLine ~~ $$ws ~~ ("/" ~~ $$cmd) ~~ $$eol;
$$simpleToolCall    = Shortest[ $$simpleToolCommand ~~ ___ ~~ ($$toolCallEnd|EndOfString) ];
$$toolCallFence     = ("```" ~~ Except[ "\n" ]... ~~ (" "...) ~~ "\n") | "";

(* TODO:
    Maybe it would be simpler to use a regex here? The command string part would need to be dynamically generated.
    RegularExpression["(?m)^(\\/wl|\\/wa)\\n(((?!\\/).*\\n)*?)\\/exec$"] :> simpleToolCallCell["$1", "$2"]
*)

(* The opening tag of a think tag with attributes, e.g. <think type='summary' id='...'>: *)
$$thinkTagWithAttributes = "<think" ~~ attributes: $$thinkTagAttributes ~~ ">";

(* A code fence opens with ``` and takes the rest of its line as the language, so it can open in the middle of a
   line: *)
$$codeFenceOpen = Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n";
$$codeFenceBody = Shortest[ code__ ];

$$markdownImage = "![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")";

(* Bullets and headings take every newline before them: *)
$$newlinesBefore = ("\n"|StartOfString)..;
$$bulletLine     = $$newlinesBefore ~~ w: " "... ~~ ("* "|"- ") ~~ item: Longest[ Except[ "\n" ].. ];
$$headingLine    = $$newlinesBefore ~~ h: "#".. ~~ " " ~~ sec: Longest[ Except[ "\n" ].. ];

$$resourceFunctionLink = "[`ResourceFunction[" ~~ name: Except[ "[" ].. ~~ "]`](" ~~ Except[ ")" ].. ~~ ")";
$$codeLink             = "[`" ~~ label: Except[ "[" ].. ~~ "`](" ~~ url: Except[ ")" ].. ~~ ")";

(* Inline code and math, which are in both $textDataFormatRules and $stringFormatRules. autoCorrect rewrites ```x``` on
   one line as ``x``, and ````x```` as ```x```, so the triple backtick rules are for code in four backticks: *)
$$tripleBacktickCode = "```" ~~ code: Except[ "\n" ].. ~~ "```";
$$doubleBacktickCode = "``" ~~ code__ ~~ "``";
$$backtickName       = "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`";
$$backtickCode       = "`" ~~ code: Except[ "`"|"\n" ].. ~~ "`";
$$dollarDisplayMath  = "$$" ~~ math__ ~~ "$$";
$$parenMath          = "\\(" ~~ math__ ~~ "\\)";
$$bracketMath        = "\\[" ~~ math__ ~~ "\\]";
$$dollarMath         = "$" ~~ math: Except[ "$" ].. ~~ "$";

(* Emphasis. The text can't contain the marker character (and the rules check that it has no newline). Underscores only
   mark emphasis at word boundaries, so names like `snake_case_name` are left as-is: *)
$$boldItalic            = "***" ~~ text: Except[ "*" ].. ~~ "***";
$$boldItalicUnderscores = WordBoundary ~~ "___" ~~ text: Except[ "_" ].. ~~ "___" ~~ WordBoundary;
$$bold                  = "**" ~~ text: Except[ "*" ].. ~~ "**";
$$boldUnderscores       = WordBoundary ~~ "__" ~~ text: Except[ "_" ].. ~~ "__" ~~ WordBoundary;
$$strikethrough         = "~~" ~~ text: Except[ "~" ].. ~~ "~~";
$$italic                = "*" ~~ text: Except[ "*" ].. ~~ "*";
$$italicUnderscores     = WordBoundary ~~ "_" ~~ text: Except[ "_" ].. ~~ "_" ~~ WordBoundary;

(* An expression URI such as <!attachment://content-xxxxx!>: *)
$$contentURI = StringExpression[
    "<!",
    uri: (Repeated[ LetterCharacter, { 1, 20 } ] ~~ "://content-" ~~ Repeated[ LetterCharacter|DigitCharacter, 5 ]),
    "!>"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$toolCallFormatRules*)

(* The rules for tool calls in $textDataFormatRules: *)
$toolCallFormatRules = {
    Longest[ $$toolCallFence ~~ tool: $$toolCall ] :> inlineToolCallCell @ tool,
    Longest[ $$toolCallFence ~~ tool: $$simpleToolCall ] /;
        ! StringStartsQ[ tool, $$ws ~~ "/retry" ~~ $$eol ] && simpleToolCallStringQ @ tool :> inlineToolCallCell @ tool,
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

(* StringSplit scans the text from left to right. The match that starts first wins, and of the rules that match at the
   same position, the first one in the list wins. This is why fences shield their content, a bullet beats "* * *", a
   table beats "> | a |", a bullet line that starts before "TOOLCALL:" swallows it, and "$$a\n\nb$$" stays one span.

   #      Rule                                       Token                       Notes
   1-5    think tags: with attributes, <think>,      thoughtsOpener,             Shortest, so the first closing tag wins
          <thinking>, then the unclosed forms        thinkingOpener (unclosed)   (no nesting); swallow fences
   6      <speech-input>...</speech-input>           speechCell
   7      escaped \[...\] between whitespace         mathCell                    only when the text has escapes
   8      code fence                                 codeBlockCell, tableCell    can open mid-line; closes at the next
                                                                                 ``` or the end; a body that is all
                                                                                 table becomes a table; not when the
                                                                                 body has a tool call (then 9-10 match)
   9-11   TOOLCALL:, simple /cmd, /retry             inlineToolCallCell,         see $toolCallFormatRules;
                                                     $discardPreviousToolCall    simpleToolCallStringQ reads
                                                                                 ToolShortNames
   12     ![alt](url)                                imageCell
   13     bullet line                                bulletCell                  the indent is kept as is
   14     heading line                               sectionCell                 more than 6 "#" look like 6
   15     thematic break                             delimiterCell               the whole line, one unbroken run
   16     table                                      tableCell                   not anchored to the start of a line;
                                                                                 can start with blank lines
   17     block quote                                blockQuoteCell              as many lines as possible
   18-19  [`ResourceFunction[...]`](url),            inlineCodeCell,
          [`label`](url)                             "[label](url)"
   20-23  ```code``` (one line), ``code``,           inlineCodeCell              code wins over emphasis and link
          `name` (inlineSyntaxQ), `code`                                         labels in plain text
   24-27  $$...$$, \(...\), \[...\],                 mathCell                    $$...$$ can span blank lines; \[...\]
          $...$ (probablyMathQ)                                                  is only reachable through &#92;

   Newlines that the rules take (the others stay in the text around them):
   bullet line, heading line   every "\n" before it, and makeResultCell0 gives { "\n", cell }
   /retry                      all whitespace before it
   table                       the blank lines before it
   block quote, thematic break none
   Then formatTextString turns a "\n\n" at either end of a text part into "\n", and joinAdjacentStrings adds " \n"
   before a cell and trims both ends. *)
$textDataFormatRules = {
    Shortest[ $$thinkTagWithAttributes ~~ thoughts___ ~~ "</think>" ] :> thoughtsOpener[ thoughts, attributes ],
    Shortest[ "<think>"~~thoughts___~~"</think>" ] :> thoughtsOpener @ thoughts,
    Shortest[ "<thinking>"~~thoughts___~~"</thinking>" ] :> thoughtsOpener @ thoughts,
    Shortest[ $$thinkTagWithAttributes ~~ thoughts___ ~~ EndOfString ] :> thinkingOpener[ thoughts, attributes ],
    Shortest[ ("<think>"|"<thinking>")~~thoughts___~~EndOfString ] :> thinkingOpener @ thoughts,
    speech: Shortest[ "<speech-input>"~~__~~"</speech-input>" ] :> speechCell @ speech,
    math: $$escapedDisplayMath :> mathCell @ StringTake[ math, { 5, -5 } ],
    $$codeFenceOpen ~~ $$codeFenceBody ~~ ("```"|EndOfString) /; toolCallStringFreeQ @ code :>
        If[ StringMatchQ[ code, $$mdTable ~~ ("\n"|"") ], tableCell @ code, codeBlockCell[ language, code ] ],
    Sequence @@ $toolCallFormatRules,
    $$markdownImage /; StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :> imageCell[ alt, url ],
    $$bulletLine :> bulletCell[ w, item ],
    $$headingLine :> sectionCell[ StringLength @ h, sec ],
    $$delimiter :> delimiterCell[ ],
    table: $$mdTable :> tableCell @ table,
    quote: $$blockQuote :> blockQuoteCell @ quote,
    $$resourceFunctionLink :> inlineCodeCell[ "ResourceFunction[" <> name <> "]" ],
    $$codeLink :> "[" <> label <> "]("<>url<>")",
    $$tripleBacktickCode :> inlineCodeCell @ code,
    $$doubleBacktickCode /; StringFreeQ[ code, "``" ] :> inlineCodeCell @ code,
    $$backtickName /; inlineSyntaxQ @ code :> inlineCodeCell @ code,
    $$backtickCode :> inlineCodeCell @ code,
    $$dollarDisplayMath /; StringFreeQ[ math, "$$" ] :> mathCell @ math,
    $$parenMath /; StringFreeQ[ math, "\\)" ] :> mathCell @ math,
    $$bracketMath /; StringFreeQ[ math, "\\]" ] :> mathCell @ math,
    $$dollarMath /; probablyMathQ @ math :> mathCell @ math
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
simpleToolCallStringQ0[ string_String ] /; StringContainsQ[ string, $$toolCallEnd ] := True;
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
    StringFreeQ[ string, "TOOLCALL:" ~~ ___ ~~ ($$toolCallEnd|EndOfString) ] &&
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

   The rules are built from the same pieces as $textDataFormatRules. The code block and image rules differ only in how
   they end: a match has to be complete (there's no EndOfString alternative). The tool call rules also leave out the
   code fence line that can come before a tool call (it stays in the static part, where formatTextString drops it) and
   the /retry check, and the TOOLCALL rule adds a newline after its match. The other block rules aren't here, so a
   match can also be found inside a think tag, list item, heading, table, block quote or unclosed code block, where
   $textDataFormatRules gives no split (see the Consistency tests in Tests/DynamicSplit.wlt). splitDynamicContent
   declines a split in a think tag (see `thinkTagSplitQ` in SendChat.wl).
*)
$dynamicSplitRules = {
    s: ($$codeFenceOpen ~~ $$codeFenceBody ~~ "```") /; toolCallStringFreeQ @ code :> s,
    s: $$markdownImage /; StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :> s,
    s: Shortest[ "TOOLCALL:" ~~ ___ ~~ $$toolCallEnd ] :> s <> "\n",
    s: Shortest[ $$simpleToolCommand ~~ ___ ~~ $$toolCallEnd ] /; simpleToolCallStringQ @ s :> s
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$stringFormatRules*)

(* The inline rules, for each text part and for the text of list items, headings, quotes and table cells. The order
   works as in $textDataFormatRules: the first match wins, and then the first rule. *)
$stringFormatRules = {
    $$tripleBacktickCode :> makeResultCell @ inlineCodeCell @ code,
    $$boldItalic /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    $$boldItalicUnderscores /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    $$bold /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontWeight -> Bold ],
    $$boldUnderscores /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontWeight -> Bold ],
    $$strikethrough /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontVariations -> { "StrikeThrough" -> True } ],
    $$doubleBacktickCode /; StringFreeQ[ code, "``" ] :> makeResultCell @ inlineCodeCell @ code,
    $$backtickName /; inlineSyntaxQ @ code :> makeResultCell @ inlineCodeCell @ code,
    $$backtickCode :> makeResultCell @ inlineCodeCell @ code,
    $$italic /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontSlant -> Italic ],
    $$italicUnderscores /; StringFreeQ[ text, "\n" ] :> styleBox[ text, FontSlant -> Italic ],
    $$dollarDisplayMath /; StringFreeQ[ math, "$$" ] :> makeResultCell @ mathCell @ math,
    $$parenMath /; StringFreeQ[ math, "\\)" ] :> makeResultCell @ mathCell @ math,
    $$bracketMath /; StringFreeQ[ math, "\\]" ] :> makeResultCell @ mathCell @ math,
    (* Escaped \[...\] in a list item, heading, table cell, ... (see $$escapedDisplayMath). The start of the text
       doesn't count as whitespace here, so that e.g. the label in [\[x\]](url) is not math: *)
    math: $$escapedDisplayMathInline :> makeResultCell @ mathCell @ StringTake[ math, { 5, -5 } ],
    $$dollarMath /; probablyMathQ @ math :> makeResultCell @ mathCell @ math,
    $$markdownImage /; StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :> makeResultCell @ imageCell[ alt, url ],
    "[" ~~ label: Shortest[ ___ ] ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlink[ label, url ],
    "\\textit{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :> styleBox[ text, FontSlant -> Italic ],
    "\\textbf{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :> styleBox[ text, FontWeight -> Bold ],
    "\[FreeformPrompt]" :> Cell @ BoxData @ TemplateBox[
        { $freeformPromptBox, "paclet:guide/KnowledgeRepresentationAndAccess#203374175" },
        "HyperlinkPaclet"
    ],
    $$contentURI :> image[ None, uri ]
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
(*Package Footer*)
End[ ];
EndPackage[ ];
