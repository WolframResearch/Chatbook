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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
