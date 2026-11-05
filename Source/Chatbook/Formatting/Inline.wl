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
                StartOfString ~~ "paclet:" ~~ ref: Except[ "#" ].. ~~ fragment___ ~~ EndOfString :>
                    "https://reference.wolfram.com/language/"<>ref<>".html"<>fragment
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
(*unescapeInlineMarkdown*)
unescapeInlineMarkdown // beginDefinition;
unescapeInlineMarkdown[ str_String ] := StringReplace[ str, { "\\`" -> "`", "\\$" -> "$" } ];
unescapeInlineMarkdown // endDefinition;

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
(* ::Subsubsection::Closed:: *)
(*toTeXBoxes*)
toTeXBoxes // beginDefinition;

toTeXBoxes[ RawBoxes[ boxes_ ] ] := toTeXBoxes @ boxes;

toTeXBoxes[ a: TemplateBox[ KeyValuePattern[ "boxes" -> b_ ], "TeXAssistantTemplate" ] ] :=
    FormBox[ If[ TrueQ @ $dynamicText, StyleBox[ b, "TeXAssistantBoxes" ], a ], TraditionalForm ];

toTeXBoxes[ boxes_TemplateBox ] := FormBox[ boxes, TraditionalForm ];

toTeXBoxes // endDefinition;

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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
