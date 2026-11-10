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
            StyleBox[ "\[Bullet]", FontColor -> color @ "NA_ChatOutputResultCellBulletFont" ],
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
            StyleBox[ "\[Bullet]", FontColor -> color @ "NA_ChatOutputResultCellBulletFont" ],
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
