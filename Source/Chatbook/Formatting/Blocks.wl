(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"           ];
Needs[ "Wolfram`Chatbook`Common`"    ];
Needs[ "Wolfram`Chatbook`CodeCheck`" ];

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
        { $textDataFormatRules = $thoughtsFormatRules, $htmlEntitiesDecoded = True },
        TextData @ reformatTextData @ trimmed
    ];

formatThoughts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*shortThoughtsText*)

(* Thoughts that are a single short line, such as the titles that OpenAI's reasoning summaries are often made of
   ("**Planning the tests**"), are shown as that line with the "ShortThoughts" template instead of an opener that
   reveals one line. Chatbook's own chat output and the ACP window (ACP/Rendering.wl) both decide with this. Gives the
   line to show (trimmed, without a bold wrapper that covers the whole line, since the template has its own font) or
   None. The length limit keeps the line on one line in an ACP window of the default width (480 points at
   Magnification 0.85, measured with the template's italic Source Sans Pro, 13.5 points, whose characters are 0.40 to
   0.45 em wide on average: about 80 to 90 characters of text fit inside the "Worked for" opener). *)
$shortThoughtsLength = 75;

(* Full-width (East Asian) characters are 1 em wide, more than twice an average character of the label font, so each
   counts as 2.5 characters: a line of up to 30 of them is short, and 36 would fit. These are the wide ranges of Markus
   Kuhn's wcwidth. *)
$wideCharacterWidth = 2.5;
$wideCharacter = RegularExpression @ StringJoin[
    "[\\x{1100}-\\x{115F}\\x{2E80}-\\x{303E}\\x{3040}-\\x{A4CF}\\x{AC00}-\\x{D7A3}\\x{F900}-\\x{FAFF}\\x{FE30}-\\x{FE4F}",
    "\\x{FF00}-\\x{FF60}\\x{FFE0}-\\x{FFE6}\\x{20000}-\\x{3FFFD}]"
];

shortThoughtsText // beginDefinition;

shortThoughtsText[ thoughts_String ] := shortThoughtsText0 @ StringTrim @ StringReplace[
    StringTrim @ thoughts,
    {
        StartOfString ~~ "**" ~~ line: Except[ "*" | "\n" ].. ~~ "**" ~~ EndOfString :> line,
        StartOfString ~~ "__" ~~ line: Except[ "_" | "\n" ].. ~~ "__" ~~ EndOfString :> line
    }
];

shortThoughtsText[ _ ] := None;

shortThoughtsText // endDefinition;


shortThoughtsText0 // beginDefinition;
shortThoughtsText0[ "" ] := None;
(* An unterminated bold title ("**Planning the", from a thought that was cut off by a stop or an error) keeps the
   opener, which hides its raw asterisks: *)
shortThoughtsText0[ line_String ] /; unclosedBoldQ @ line := None;
shortThoughtsText0[ line_String ] /; thoughtsLineWidth @ line <= $shortThoughtsLength && StringFreeQ[ line, "\n" | "\r" ] := line;
shortThoughtsText0[ _String ] := None;
shortThoughtsText0 // endDefinition;


unclosedBoldQ // beginDefinition;
unclosedBoldQ[ line_String ] := AnyTrue[ { "**", "__" }, StringStartsQ[ line, # ] && StringFreeQ[ StringDrop[ line, 2 ], # ] & ];
unclosedBoldQ // endDefinition;


(* The width of a line, in average characters of the label font: *)
thoughtsLineWidth // beginDefinition;
thoughtsLineWidth[ line_String ] := StringLength @ line + ( $wideCharacterWidth - 1 ) * StringCount[ line, $wideCharacter ];
thoughtsLineWidth // endDefinition;

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
(*makeBulletCell*)
makeBulletCell // beginDefinition;

makeBulletCell[ "", item_String ] := {
    "\n",
    Cell[
        TextData @ Flatten @ {
            StyleBox[ "\[Bullet]", FontColor -> color @ "Gray50_75" ],
            " ",
            formatTextString @ item
        },
        "InlineItem"
    ]
};

makeBulletCell[ whitespace_String, item_String ] := {
    "\n",
    Cell[
        TextData @ Flatten @ {
            whitespace,
            StyleBox[ "\[Bullet]", FontColor -> color @ "Gray50_75" ],
            " ",
            formatTextString @ item
        },
        "InlineSubitem"
    ]
};

makeBulletCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeBlockQuoteCell*)
makeBlockQuoteCell // beginDefinition;

makeBlockQuoteCell[ quote_String ] := Cell[
    BoxData @ GridBox[
        {
            {
                PaneBox[
                    formatTextToBoxes @ StringDelete[ StringTrim @ quote, StartOfLine ~~ ">" ~~ " "... ],
                    ImageMargins -> 5,
                    ImageSize    -> { Full, Automatic },
                    BaseStyle    -> { "Text", FontColor -> color @ "Gray35_86" }
                ]
            }
        },
        AutoDelete        -> False,
        GridBoxBackground -> { "Columns" -> { { color @ "Gray100_28" } } },
        GridBoxDividers   -> {
            "ColumnsIndexed" -> { 1 -> Directive[ LightDarkSwitched[ RGBColor[ "#DEF0FF" ], RGBColor[ "#40546C" ] ], AbsoluteThickness[ 4 ] ] },
            "Rows"           -> { { False } }
        },
        GridBoxItemSize -> { "Columns" -> { { Automatic } }, "Rows" -> { { Automatic } } }
    ],
    "BlockQuote",
    Background -> None
];

makeBlockQuoteCell // endDefinition;

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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
