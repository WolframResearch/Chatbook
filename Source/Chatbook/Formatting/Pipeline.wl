(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reformatTextData*)
reformatTextData // beginDefinition;

(* The rules only look for "\n", so "\r\n" and a lone "\r" (both line endings in CommonMark) become "\n" first: *)
reformatTextData[ string_String ] := reformatTextData0 @ autoCorrect @ StringReplace[ string, "\r\n" | "\r" -> "\n" ];

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

(* Thoughts are decoded with the rest of the text, so formatThoughts sets this to avoid decoding them twice: *)
importHTMLEntities[ string_String ] /; $htmlEntitiesDecoded := string;

(* Named entities (case-sensitive, as in HTML) and numeric ones are decoded in a single pass, so "&amp;lt;" gives
   "&lt;". Anything else is left as it is: *)
importHTMLEntities[ string_String ] := StringReplace[
    string,
    {
        e: ("&#" ~~ ("x"|"X") ~~ hex: HexadecimalCharacter.. ~~ ";") :> codePointString[ FromDigits[ hex, 16 ], e ],
        e: ("&#" ~~ decimal: CharacterRange[ "0", "9" ].. ~~ ";")    :> codePointString[ FromDigits @ decimal, e ],
        e: ("&" ~~ name: WordCharacter.. ~~ ";")                    :> Lookup[ $htmlEntities, name, e ]
    }
];

importHTMLEntities // endDefinition;

$htmlEntitiesDecoded = False;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*codePointString*)
codePointString // beginDefinition;

(* Numbers that aren't Unicode characters (zero, surrogates and anything above U+10FFFF) are left as entities: *)
codePointString[ code_Integer, entity_String ] :=
    If[ 0 < code < 16^^D800 || 16^^DFFF < code <= 16^^10FFFF, FromCharacterCode @ code, entity ];

codePointString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*$htmlEntities*)

(* The named entities of HTML 4 (with the HTML5 code points for &lang; and &rang;), plus the HTML5 names of ASCII
   characters and the uppercase forms that HTML5 has for the most common ones: *)
$htmlEntities = FromCharacterCode /@ Join[
    (* Latin-1 Supplement, U+00A0 to U+00FF: *)
    AssociationThread[
        {
            "nbsp", "iexcl", "cent", "pound", "curren", "yen", "brvbar", "sect", "uml", "copy", "ordf", "laquo",
            "not", "shy", "reg", "macr", "deg", "plusmn", "sup2", "sup3", "acute", "micro", "para", "middot",
            "cedil", "sup1", "ordm", "raquo", "frac14", "frac12", "frac34", "iquest", "Agrave", "Aacute", "Acirc",
            "Atilde", "Auml", "Aring", "AElig", "Ccedil", "Egrave", "Eacute", "Ecirc", "Euml", "Igrave", "Iacute",
            "Icirc", "Iuml", "ETH", "Ntilde", "Ograve", "Oacute", "Ocirc", "Otilde", "Ouml", "times", "Oslash",
            "Ugrave", "Uacute", "Ucirc", "Uuml", "Yacute", "THORN", "szlig", "agrave", "aacute", "acirc", "atilde",
            "auml", "aring", "aelig", "ccedil", "egrave", "eacute", "ecirc", "euml", "igrave", "iacute", "icirc",
            "iuml", "eth", "ntilde", "ograve", "oacute", "ocirc", "otilde", "ouml", "divide", "oslash", "ugrave",
            "uacute", "ucirc", "uuml", "yacute", "thorn", "yuml"
        },
        Range[ 160, 255 ]
    ],
    (* Greek, U+0391 to U+03A9 (there is no capital final sigma at U+03A2) and U+03B1 to U+03C9: *)
    AssociationThread[
        {
            "Alpha", "Beta", "Gamma", "Delta", "Epsilon", "Zeta", "Eta", "Theta", "Iota", "Kappa", "Lambda", "Mu",
            "Nu", "Xi", "Omicron", "Pi", "Rho", "Sigma", "Tau", "Upsilon", "Phi", "Chi", "Psi", "Omega"
        },
        DeleteCases[ Range[ 913, 937 ], 930 ]
    ],
    AssociationThread[
        {
            "alpha", "beta", "gamma", "delta", "epsilon", "zeta", "eta", "theta", "iota", "kappa", "lambda", "mu",
            "nu", "xi", "omicron", "pi", "rho", "sigmaf", "sigma", "tau", "upsilon", "phi", "chi", "psi", "omega"
        },
        Range[ 945, 969 ]
    ],
    <|
        "excl" -> 33, "quot" -> 34, "num" -> 35, "dollar" -> 36, "percnt" -> 37, "amp" -> 38, "apos" -> 39,
        "lpar" -> 40, "rpar" -> 41, "ast" -> 42, "midast" -> 42, "plus" -> 43, "comma" -> 44, "period" -> 46,
        "sol" -> 47, "colon" -> 58, "semi" -> 59, "lt" -> 60, "equals" -> 61, "gt" -> 62, "quest" -> 63,
        "commat" -> 64, "lsqb" -> 91, "lbrack" -> 91, "bsol" -> 92, "rsqb" -> 93, "rbrack" -> 93, "Hat" -> 94,
        "lowbar" -> 95, "grave" -> 96, "lcub" -> 123, "lbrace" -> 123, "verbar" -> 124, "vert" -> 124,
        "rcub" -> 125, "rbrace" -> 125,
        "QUOT" -> 34, "AMP" -> 38, "LT" -> 60, "GT" -> 62, "COPY" -> 169, "REG" -> 174,
        "OElig" -> 338, "oelig" -> 339, "Scaron" -> 352, "scaron" -> 353, "Yuml" -> 376, "fnof" -> 402,
        "circ" -> 710, "tilde" -> 732, "thetasym" -> 977, "upsih" -> 978, "piv" -> 982,
        "ensp" -> 8194, "emsp" -> 8195, "thinsp" -> 8201, "zwnj" -> 8204, "zwj" -> 8205, "lrm" -> 8206,
        "rlm" -> 8207, "ndash" -> 8211, "mdash" -> 8212, "lsquo" -> 8216, "rsquo" -> 8217, "sbquo" -> 8218,
        "ldquo" -> 8220, "rdquo" -> 8221, "bdquo" -> 8222, "dagger" -> 8224, "Dagger" -> 8225, "bull" -> 8226,
        "hellip" -> 8230, "permil" -> 8240, "prime" -> 8242, "Prime" -> 8243, "lsaquo" -> 8249,
        "rsaquo" -> 8250, "oline" -> 8254, "frasl" -> 8260, "euro" -> 8364, "image" -> 8465, "weierp" -> 8472,
        "real" -> 8476, "trade" -> 8482, "alefsym" -> 8501,
        "larr" -> 8592, "uarr" -> 8593, "rarr" -> 8594, "darr" -> 8595, "harr" -> 8596, "crarr" -> 8629,
        "lArr" -> 8656, "uArr" -> 8657, "rArr" -> 8658, "dArr" -> 8659, "hArr" -> 8660,
        "forall" -> 8704, "part" -> 8706, "exist" -> 8707, "empty" -> 8709, "nabla" -> 8711, "isin" -> 8712,
        "notin" -> 8713, "ni" -> 8715, "prod" -> 8719, "sum" -> 8721, "minus" -> 8722, "lowast" -> 8727,
        "radic" -> 8730, "prop" -> 8733, "infin" -> 8734, "ang" -> 8736, "and" -> 8743, "or" -> 8744,
        "cap" -> 8745, "cup" -> 8746, "int" -> 8747, "there4" -> 8756, "sim" -> 8764, "cong" -> 8773,
        "asymp" -> 8776, "ne" -> 8800, "equiv" -> 8801, "le" -> 8804, "ge" -> 8805, "sub" -> 8834,
        "sup" -> 8835, "nsub" -> 8836, "sube" -> 8838, "supe" -> 8839, "oplus" -> 8853, "otimes" -> 8855,
        "perp" -> 8869, "sdot" -> 8901, "lceil" -> 8968, "rceil" -> 8969, "lfloor" -> 8970, "rfloor" -> 8971,
        "lang" -> 10216, "rang" -> 10217, "loz" -> 9674, "spades" -> 9824, "clubs" -> 9827, "hearts" -> 9829,
        "diams" -> 9830
    |>
];

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
   characters (inline code and math replace their own placeholders first, see $codeUnescapeRules and
   $texUnescapeRules). This is done for each part, since some of them are compressed until they're viewed: *)
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
    makeInlineWL @ StringReplace[ code, $codeUnescapeRules ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := ReplaceAll[
    makeInlineCodeCell @ StringReplace[ code, $codeUnescapeRules ],
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

makeResultCell0[ bulletCell[ whitespace_String, item_String ] ] :=
    makeBulletCell[ whitespace, item ];

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

makeResultCell0[ blockQuoteCell[ quote_String ] ] :=
    makeBlockQuoteCell @ quote;

makeResultCell0 // endDefinition;

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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
