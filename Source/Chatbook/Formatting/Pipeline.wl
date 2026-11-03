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

importHTMLEntities[ string_String ] := StringReplace[
    string,
    entity: ("&" ~~ Repeated[ Except[ "\n" ], { 1, 6 } ] ~~ ";") :> importHTMLEntity @ entity
];

importHTMLEntities // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importHTMLEntity*)
importHTMLEntity // beginDefinition;

importHTMLEntity[ entity_String ] := Lookup[
    $htmlEntityCache,
    entity,
    addToCache[
        $htmlEntityCache,
        $maxHTMLEntityCacheSize,
        entity,
        With[ { str = Quiet @ ImportString[ ToLowerCase @ entity, "HTML" ] },
            If[ StringQ @ str, str, entity ]
        ]
    ]
];

importHTMLEntity // endDefinition;

$htmlEntityCache        = <| |>;
$maxHTMLEntityCacheSize = 1000;

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
