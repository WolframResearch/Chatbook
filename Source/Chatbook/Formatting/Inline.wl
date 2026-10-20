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
(*neutralizeLinearSyntax*)

(* Text that the formatter shows (the model's answers, tool results such as fetched web pages, an external agent's
   answers) ends up as strings in boxes, and its code is turned into boxes by the front end (reparseBoxStructurePacket).
   The private-use characters U+F7C0 to U+F7CD of the front end's linear syntax would make the front end turn such a
   string into boxes chosen by whoever wrote the text, and their box constructor (U+F7C8) makes it evaluate a box
   expression in the kernel, with any code in it, so they are replaced with U+FFFD in all text that is formatted
   (reformatTextData, makeInteractiveCodeCell, reparseBoxStructurePacket), in the characters that the formatter makes
   from the text afterwards (HTML entities, TeX), and in what a tool call shows (the model's parameters, the raw tool
   call, toolAutoFormatter's results). The same backslash sequences typed as text (ASCII) are not linear syntax and need
   nothing. Some genuine text has these characters: results of the sandbox in a form such as TraditionalForm, and
   CellToString of a string or message cell with linear syntax. A model that repeats such text in its answer or code
   now shows U+FFFD and the box text instead of the formatted expression (the tool call's own output, formatted by
   sandboxFormatter from the result, is unchanged). Also used by the ACP window for any text from the agent or the
   repository (acpNeutralizeLinearSyntax). *)
neutralizeLinearSyntax // beginDefinition;

(* A search for each character as a literal string is fast (megabytes are checked in milliseconds); a pattern of
   alternatives would be much slower. *)
neutralizeLinearSyntax[ s_String ] := If[ linearSyntaxQ @ s,
    StringReplace[ s, Alternatives @@ $linearSyntaxCharacters -> "\:fffd" ],
    s
];

(* Any other expression (boxes, a tool's parameters or result) has every string in it replaced: *)
neutralizeLinearSyntax[ expr_ ] := ReplaceAll[
    expr,
    s_String? linearSyntaxQ :> RuleCondition @ neutralizeLinearSyntax @ s
];

neutralizeLinearSyntax // endDefinition;


linearSyntaxQ // beginDefinition;
linearSyntaxQ[ s_String ] := AnyTrue[ $linearSyntaxCharacters, StringContainsQ[ s, # ] & ];
linearSyntaxQ // endDefinition;

$linearSyntaxCharacters = Characters @ FromCharacterCode @ Range[ 63424, 63437 ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*withUntrustedContent*)

(* Formats text that comes from an untrusted source (an LLM tool result, an external agent's answer, the notebook
   tools' markdown). For a chat answer the formatter loads and evaluates things that such text must not make it do in
   the user's kernel: it imports markdown images from their URL, file or cloud object (with no time limit), and its
   special forms of Wolfram Language code (formatSpecialBoxes, for code blocks and inline code) query Wolfram|Alpha,
   the resource system and the paclet repository, and evaluate DateObject expressions (whose options can be any code).
   Under this switch, none of that happens: markdown images become links to their sources (untrustedImageLink), code is
   kept as it is written, nothing is imported or looked up online, and HTML entities are not decoded. Callers outside
   `Formatting/` reach this through `Wolfram`Chatbook`Common`` (see ACP/Rendering.wl and ACP/NotebookTools.wl). *)
withUntrustedContent // beginDefinition;
withUntrustedContent // Attributes = { HoldFirst };

withUntrustedContent[ eval_ ] := Block[
    {
        image              = untrustedImageLink,
        formatSpecialBoxes = Identity,
        importHTMLEntities = Identity
    },
    eval
];

withUntrustedContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*untrustedImageLink*)

(* A markdown image as a text cell with a link to its URL or file, labeled with its alt text (or the URL if it has
   none), instead of the imported image. A cell of its own, as the image would be. The formatter calls `image` with the
   image's alt text and URL (alt is None for an expression URI), or with the markdown of a code block that is only an
   image. *)
untrustedImageLink // beginDefinition;

untrustedImageLink[ markdown_String ] := Replace[
    StringCases[
        StringTrim @ markdown,
        StartOfString ~~ "![" ~~ alt___ ~~ "](" ~~ url__ ~~ ")" ~~ EndOfString :> untrustedImageLink[ alt, url ]
    ],
    { { link_Cell } :> link, _ :> markdown }
];

untrustedImageLink[ alt_, url_String ] := Cell[
    TextData @ {
        ButtonBox[
            If[ StringQ @ alt && StringTrim @ alt =!= "", StringTrim @ alt, url ],
            BaseStyle  -> "Hyperlink",
            ButtonData -> { URL @ url, None },
            ButtonNote -> url
        ]
    },
    "Text"
];

untrustedImageLink // endDefinition;

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
    StyleBox[ s, "TI" ];

makeInlineCodeCell[ code_String ] := Cell[
    BoxData @ TemplateBox[ { Cell[ code, Background -> None ] }, "ChatCodeInlineTemplate" ],
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
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
