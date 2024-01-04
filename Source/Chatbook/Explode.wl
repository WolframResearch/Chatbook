(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Explode`" ];

`explodeCell;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

$$newCellStyle = "Section"|"Subsection"|"Subsubsection"|"Subsubsubsection"|"Item"|"Input"|"ExternalLanguage"|"Program";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Explode Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*explodeCell*)
explodeCell // beginDefinition;

explodeCell[ cellObject_CellObject ] := explodeCell @ NotebookRead @ cellObject;
explodeCell[ Cell[ content_, ___ ] ] := explodeCell @ content;
explodeCell[ string_String ] := Cell[ #, "Text" ] & /@ StringSplit[ string, Longest[ "\n".. ] ];
explodeCell[ (BoxData|TextData)[ textData_, ___ ] ] := explodeCell @ Flatten @ List @ textData;

explodeCell[ textData_List ] := Enclose[
    Module[ { processed },
        processed = ConfirmMatch[ ReplaceRepeated[ textData, $preprocessingRules ], $$textDataList, "Preprocessing" ];
        ConfirmMatch[ regroupCells @ processed, $$textDataList, "RegroupCells" ]
    ],
    throwInternalFailure[ explodeCell @ textData, ## ] &
];

explodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$preprocessingRules*)
$preprocessingRules := $preprocessingRules = Dispatch @ {
    (* Convert TextRefLink to plain hyperlink: *)
    Cell @ BoxData[ TemplateBox[ { label_, uri_ }, "TextRefLink" ], ___ ] :>
        Cell @ BoxData @ ButtonBox[
            StyleBox[ label, "Text" ],
            BaseStyle  -> "Link",
            ButtonData -> uri,
            ButtonNote -> uri
        ],

    (* Convert interactive code blocks to input cells: *)
    DynamicModuleBox[
        _,
        TagBox[ cell_Cell, ___ ],
        ___,
        TaggingRules -> Association @ OrderlessPatternSequence[
            "CellToStringType" -> "InlineInteractiveCodeCell",
            ___
        ],
        ___
    ] :> cell,

    (* Convert "ChatCodeInlineTemplate" to "InlineCode" cells: *)
    Cell[ BoxData[ TemplateBox[ { boxes_ }, "ChatCodeInlineTemplate" ], "ChatCode"|"ChatCodeActive", ___ ], ___ ] :>
        Cell[ BoxData @ boxes, "InlineCode" ],

    (* Remove "ChatCode" styling from inputs: *)
    Cell[ boxes_, "ChatCode", "Input", ___ ] :> Cell[ boxes, "Input" ],

    (* Remove "ChatCodeBlock" styling: *)
    Cell[ BoxData[ cell_Cell, ___ ], "ChatCodeBlock", ___ ] :> cell,

    (* Language-agnostic code blocks: *)
    Cell[ text_, "ChatPreformatted", ___ ] :> Cell[ text, "Program" ],

    (* Remove "ChatCodeBlockTemplate" template boxes: *)
    TemplateBox[ { cell_Cell }, "ChatCodeBlockTemplate" ] :> cell,

    (* Remove nested cells: *)
    Cell @ BoxData[ cell_Cell, ___ ] :> cell,

    (* Remove extra style overrides from external language cells: *)
    Cell[ content_, "ExternalLanguage", OrderlessPatternSequence[ System`CellEvaluationLanguage -> lang_, __ ] ] :>
        Cell[ content, "ExternalLanguage", System`CellEvaluationLanguage -> lang ],

    (* Inline tool calls: *)
    Cell[ _, "InlineToolCall", TaggingRules -> tags: KeyValuePattern[ { } ], ___ ] :>
        Cell[
            BoxData @ ToBoxes @ Iconize[
                tags, (* FIXME: iconize an actual tool response object here *)
                "Used " <> Lookup[ tags, "DisplayName", Lookup[ tags, "Name", "LLMTool" ] ]
            ],
            "Input"
        ],

    (* Nested text data cells: *)
    { a___, b: StyleBox[ _, $$newCellStyle, ___ ], c___ } :>
        { a, Cell @@ b, c },

    (* Tiny line breaks: *)
    StyleBox[ "\n", "TinyLineBreak", ___ ] :> "\n"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*regroupCells*)
regroupCells // beginDefinition;

regroupCells[ textData_List ] :=
    regroupCells[ { }, { }, textData ];

regroupCells[ { grouped___ }, { grouping___ }, { cell: Cell[ _BoxData ], rest___ } ] :=
    regroupCells[ { grouped }, { grouping, cell }, { rest } ];

regroupCells[ { grouped___ }, { grouping___ }, { box: _StyleBox|_ButtonBox|Cell[ _, "InlineCode", ___ ], rest___ } ] :=
    regroupCells[ { grouped }, { grouping, box }, { rest } ];

regroupCells[ { grouped___ }, { grouping___ }, { cell: (Cell|StyleBox)[ _, $$newCellStyle, ___ ], rest___ } ] :=
    regroupCells[
        { grouped, Cell[ TextData @ { grouping }, "Text" ], DeleteCases[ Cell @@ cell, FontSize -> _ ] },
        { },
        { rest }
    ];

regroupCells[ { grouped___ }, { grouping___ }, { string_String, rest___ } ] /; StringFreeQ[ string, "\n" ] :=
    regroupCells[ { grouped }, { grouping, string }, { rest } ];

regroupCells[ { grouped___ }, { grouping___ }, { string_String, rest___ } ] :=
    Replace[
        StringSplit[ StringTrim[ string, Longest[ "\n".. ] ], Longest[ "\n".. ] ],
        {
            { a_String, b___String, c_String } :>
                regroupCells[
                    Flatten @ { grouped, Cell[ TextData @ { grouping, a }, "Text" ], Cell[ #, "Text" ] & /@ { b } },
                    { c },
                    { rest }
                ]
            ,
            { a_String } :>
                regroupCells[ { grouped }, { grouping, a }, { rest } ]
            ,
            { } :>
                regroupCells[ { grouped }, { grouping }, { rest } ]
            ,
            ___ :>
                throwInternalFailure @ regroupCells[ { grouped }, { grouping }, { string, rest } ]
        }
    ];

regroupCells[ { grouped___ }, { grouping___ }, { } ] :=
    DeleteCases[ { grouped, Cell[ TextData @ { grouping }, "Text" ] }, Cell[ TextData @ { }, ___ ] ];

regroupCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $preprocessingRules;
];

End[ ];
EndPackage[ ];
