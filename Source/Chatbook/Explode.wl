(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Explode`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

$$newCellStyle = Alternatives[
    "Abstract",
    "Affiliation",
    "Author",
    "BlockQuote",
    "Chapter",
    "Code",
    "CodeText",
    "DisplayFormula",
    "DisplayFormulaNumbered",
    "Echo",
    "EchoAfter",
    "EchoBefore",
    "EchoTiming",
    "ExternalLanguage",
    "Input",
    "InputOnly",
    "Item",
    "ItemNumbered",
    "ItemParagraph",
    "MarkdownDelimiter",
    "Message",
    "Output",
    "Picture",
    "Print",
    "Program",
    "Reference",
    "Section",
    "SideCaption",
    "SideCaptionArray",
    "SmallText",
    "Subchapter",
    "Subitem",
    "SubitemNumbered",
    "SubitemParagraph",
    "Subsection",
    "Subsubitem",
    "SubsubitemNumbered",
    "SubsubitemParagraph",
    "Subsubsection",
    "Subsubsubsection",
    "Subsubsubsubsection",
    "Subsubtitle",
    "Subtitle",
    "Text",
    "TextTableForm",
    "Title"
];

$$ws = _String? (StringMatchQ[ WhitespaceCharacter... ]);

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*ExplodeCell*)
ExplodeCell // beginDefinition;
ExplodeCell[ cell_Cell ] := catchMine @ LogChatTiming @ explodeCell @ cell;
ExplodeCell[ RawBoxes[ cell_Cell ] ] := catchMine @ ExplodeCell @ cell;
ExplodeCell // endExportedDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*explodeCell*)
explodeCell // beginDefinition;

explodeCell[ cellObject_CellObject ] := explodeCell @ NotebookRead @ cellObject;
explodeCell[ Cell[ content_, ___ ] ] := explodeCell @ content;
explodeCell[ string_String ] := Cell[ #, "Text" ] & /@ StringSplit[ string, Longest[ "\n".. ] ];
explodeCell[ (BoxData|TextData)[ textData_, ___ ] ] := explodeCell @ Flatten @ List @ textData;

explodeCell[ textData_List ] := Enclose[
    Module[ { processed, grouped, post },
        processed = ConfirmMatch[ preprocessExplodedCells @ textData, $$textDataList, "Preprocessing" ];
        grouped = ConfirmMatch[ regroupCells @ processed, $$textDataList, "RegroupCells" ];
        post = ConfirmMatch[ Flatten[ postProcessExplodedCells /@ grouped ], { __Cell }, "PostProcessing" ];
        SequenceReplace[
            post,
            { Cell[ caption_? captionQ, "Text", a___ ], input: Cell[ __, "Input"|"Code", ___ ] } :>
                Sequence[ Cell[ caption, "CodeText", a ], input ]
        ]
    ],
    throwInternalFailure
];

explodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*captionQ*)
captionQ // beginDefinition;
captionQ[ text_String ] := StringEndsQ[ text, ":"~~WhitespaceCharacter... ];
captionQ[ (ButtonBox|Cell|StyleBox|TextData)[ text_, ___ ] ] := captionQ @ text;
captionQ[ { ___, text_ } ] := captionQ @ text;
captionQ[ _ ] := False;
captionQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessExplodedCells*)
preprocessExplodedCells // beginDefinition;
preprocessExplodedCells[ text_List ] := preprocessExplodedCells0 @ ReplaceRepeated[ text, $preprocessingRules ];
preprocessExplodedCells // endDefinition;

preprocessExplodedCells0 // beginDefinition;
preprocessExplodedCells0[ TextData[ text_ ] ] := preprocessExplodedCells0 @ Flatten @ { text };
preprocessExplodedCells0[ { text_TextData } ] := preprocessExplodedCells0 @ text;
preprocessExplodedCells0[ text_List ] := Flatten @ text;
preprocessExplodedCells0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*postProcessExplodedCells*)
postProcessExplodedCells // beginDefinition;

postProcessExplodedCells[
    Cell[ BoxData @ RowBox @ { RowBox @ { "In", "[", n__String, "]" }, "="|":=", boxes__ }, "Input", a___ ]
] := Cell[ BoxData @ RowBox @ { boxes }, "Input", CellLabel -> "In["<>n<>"]:=", a ];

postProcessExplodedCells[
    Cell[ BoxData @ RowBox @ { RowBox @ { "Out", "[", n__String, "]" }, "="|":=", boxes__ }, "Input", a___ ]
] := Cell[ BoxData @ RowBox @ { boxes }, "Output", CellLabel -> "Out["<>n<>"]=", a ];

postProcessExplodedCells[ Cell[
    BoxData @ RowBox @ {
        RowBox @ { RowBox @ { "In", "[", nIn__String, "]" }, ":=", in___ },
        $$ws...,
        RowBox @ { RowBox @ { "Out", "[", nOut__String, "]" }, "=", out___ }
    },
    "Input"
] ] := postProcessExplodedCells /@ {
    Cell[ BoxData @ RowBox @ { in }, "Input", CellLabel -> "In["<>nIn<>"]:=" ],
    Cell[ BoxData @ RowBox @ { out }, "Output", CellLabel -> "Out["<>nOut<>"]=" ]
};

postProcessExplodedCells[ cell: Cell[ __, "Input", ___ ] ] := DeleteCases[
    cell /. { RowBox @ { RowBox @ { "In", "[", __, "]" }, "="|":=", boxes__ } :> RowBox @ { boxes } },
    RowBox @ { RowBox @ { "Out", "[", __, "]" }, "="|":=", __ },
    Infinity
];

postProcessExplodedCells[ Cell[ BoxData @ TooltipBox[ TemplateBox[ { }, "ImageNotFound" ], ___ ], "Picture", ___ ] ] :=
    Nothing;

postProcessExplodedCells[ Cell[ BoxData @ TemplateBox[ { }, "ImageNotFound" ], "Picture", ___ ] ] :=
    Nothing;

postProcessExplodedCells[ cell_Cell ] :=
    cell;

postProcessExplodedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$preprocessingRules*)
$preprocessingRules := $preprocessingRules = Dispatch @ {
    (* Workspace/Inline chat template boxes: *)
    Cell[ BoxData @ TemplateBox[ { Cell[ text_, ___ ] }, "AssistantMessageBox", ___ ], ___ ] :>
        text,

    (* Remove "InlineSection" styling: *)
    Cell[
        BoxData @ PaneBox[
            StyleBox[ Cell[ text_, Background -> None ], style_, ___ ], ___ ],
            "InlineSection",
            ___
    ] :> Cell[ text, style ],

    Cell[ BoxData @ PaneBox[ StyleBox[ text_, style_, ___ ], ___ ], "InlineSection", ___ ] :>
        RuleCondition @ StyleBox[ extractText @ text, style ],

    (* Inline code cell groups: *)
    Cell[ BoxData @ GridBox[ grid_List, ___ ], "CellGroupBlock", ___ ] :>
        Sequence @@ Replace[
            Cases[ grid, { _, a_ } :> a ],
            box: TemplateBox[ _, "MessageTemplate", ___ ] :> Cell[ BoxData @ box, "Message" ],
            { 1 }
        ],

    (* Convert TextRefLink to plain hyperlink: *)
    Cell @ BoxData[ TemplateBox[ { label_, uri_, ___ }, "TextRefLink" ], ___ ] :>
        ButtonBox[ label, BaseStyle -> "Link", ButtonData -> uri ],

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
    Cell[ BoxData[ TemplateBox[ { boxes_ }, "ChatCodeInlineTemplate", ___ ], ___ ], "ChatCode"|"ChatCodeActive", ___ ] :>
        Cell[ BoxData @ boxes, "InlineCode" ],

    (* Remove "ChatCode" styling: *)
    Cell[ boxes_, "ChatCode", style___String, OptionsPattern[ ] ] :> Cell[ boxes, style ],

    (* Remove "ChatCodeBlock" styling: *)
    Cell[ BoxData[ cell_Cell, ___ ], "ChatCodeBlock", ___ ] :> cell,

    (* Language-agnostic code blocks: *)
    Cell[ text_, "ChatPreformatted", ___ ] :> Cell[ text, "Program" ],

    (* Remove "ChatCodeBlockTemplate" template boxes: *)
    TemplateBox[ { cell_Cell }, "ChatCodeBlockTemplate", ___ ] :> cell,

    (* Remove nested cells: *)
    Cell @ BoxData[ cell_Cell, ___ ] :> cell,

    Cell[ TextData @ { StyleBox[ "\[Bullet]", ___ ], " ", content___ }, "InlineItem", ___ ] :>
        Cell[ TextData @ content, "Item" ],

    Cell[ TextData @ { _String, StyleBox[ "\[Bullet]", ___ ], " ", content___ }, "InlineSubitem", ___ ] :>
        Cell[ TextData @ content, "Subitem" ],

    (* Format text tables: *)
    Cell[ content__, "TextTableForm", opts: OptionsPattern[ ] ] :>
        Cell[ content, "TextTableForm", "Text", opts ],

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
    StyleBox[ "\n", "TinyLineBreak", ___ ] :> "\n",

    Cell[ boxes_, style: "MarkdownDelimiter"|"BlockQuote", a___ ] :>
        Cell[ boxes, "Text", style, a ],

    (* Fix cases where the LLM tried to manually create MarkdownImageBoxes: *)
    RowBox @ { "\\!", RowBox @ { "\\(", RowBox @ { "*MarkdownImageBox", "[", uri_, "]" }, "\\)" } } :>
        With[ { expr = Quiet @ catchAlways @ GetExpressionURI @ StringTrim[ uri, "\"" ] },
            If[ FailureQ @ expr,
                "\[LeftSkeleton]Removed\[RightSkeleton]",
                ToBoxes @ expr
            ]
        ],

    (* Markdown images: *)
    Cell[ BoxData @ PaneBox[ TagBox[ box_, "MarkdownImage", ___ ], ___ ], "Input", ___ ] :>
        Cell[ BoxData @ box, "Picture" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*extractText*)
extractText // beginDefinition;
extractText[ text_String ] := If[ StringMatchQ[ text, "\"" ~~ ___ ~~ "\"" ], ToExpression @ text, text ];
extractText[ (Cell|StyleBox)[ text_, ___ ] ] := extractText @ text;
extractText[ text_ ] := extractText[ text ] = CellToString @ text;
extractText // endDefinition;

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

regroupCells[ { grouped___ }, { grouping___ }, { other_, rest___ } ] :=
    regroupCells[ { grouped }, { grouping, other }, { rest } ];

regroupCells[ { grouped___ }, { grouping___ }, { } ] :=
    DeleteCases[ { grouped, Cell[ TextData @ { grouping }, "Text" ] }, Cell[ TextData @ { }, ___ ] ];

regroupCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    $preprocessingRules;
];

End[ ];
EndPackage[ ];
