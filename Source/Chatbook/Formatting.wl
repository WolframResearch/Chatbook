(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDRESULT *)

Wolfram`Chatbook`FormatChatOutput;

`$dynamicSplitRules;
`$dynamicText;
`$reformattedCell;
`$resultCellCache;
`clickToCopy;
`floatingButtonGrid;
`makeInteractiveCodeCell;
`reformatTextData;
`toolAutoFormatter;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];
Needs[ "Wolfram`Chatbook`Tools`"    ];

(* FIXME: Use ParagraphSpacing to squeeze text closer together *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

$dynamicImageScale   = 0.25;
$maxImageSize        = 800;
$maxDynamicImageSize = Ceiling[ $maxImageSize * $dynamicImageScale ];

$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "Wolfram_Language_Evaluator",
    "Wolfram_Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica",
    "WL"
];

$resultCellCache = <| |>;

sectionStyle[ 1 ] := "Section";
sectionStyle[ 2 ] := "Subsection";
sectionStyle[ 3 ] := "Subsubsection";
sectionStyle[ 4 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

$tinyLineBreak = StyleBox[ "\n", "TinyLineBreak", FontSize -> 3 ];

$$externalLanguage = "Java"|"Julia"|"Jupyter"|"NodeJS"|"Octave"|"Python"|"R"|"Ruby"|"Shell"|"SQL"|"SQL-JDBC";

$externalLanguageRules = Replace[
    Flatten @ {
        "JS"         -> "NodeJS",
        "Javascript" -> "NodeJS",
        "NPM"        -> "NodeJS",
        "Node"       -> "NodeJS",
        "Bash"       -> "Shell",
        "SH"         -> "Shell",
        Cases[ $$externalLanguage, lang_ :> (lang -> lang) ]
    },
    HoldPattern[ lhs_ -> rhs_ ] :> (StartOfString~~lhs~~EndOfString -> rhs),
    { 1 }
];

$$mdRow   = Except[ "\n" ].. ~~ Repeated[ ("|" ~~ Except[ "\n" ]..), { 2, Infinity } ] ~~ ("\n"|EndOfString);
$$mdTable = $$mdRow ~~ $$mdRow ..;

$chatGeneratedCellTag = "ChatGeneratedCell";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Output Formatting*)
FormatChatOutput // beginDefinition;
FormatChatOutput[ output_ ] := FormatChatOutput[ output, <| "Status" -> "Finished" |> ];
FormatChatOutput[ output_, as_Association ] := formatChatOutput[ output, Lookup[ as, "Status", "Finished" ] ];
FormatChatOutput // endDefinition;
(* TODO: actual error handling for invalid arguments *)

formatChatOutput // beginDefinition;

formatChatOutput[ output_, "Waiting" ] := ProgressIndicator[ Appearance -> "Percolate" ];

formatChatOutput[ output_String, "Streaming" ] :=
    Block[ { $dynamicText = True }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput[ output_String, "Finished" ] :=
    Block[ { $dynamicText = False }, RawBoxes @ Cell @ TextData @ reformatTextData @ output ];

formatChatOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reformatTextData*)
reformatTextData // beginDefinition;

reformatTextData[ string_String ] := joinAdjacentStrings @ Flatten[
    makeResultCell /@ StringSplit[ string, $textDataFormatRules, IgnoreCase -> True ]
];

reformatTextData[ other_ ] := other;

reformatTextData // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeResultCell*)
makeResultCell // beginDefinition;

makeResultCell[ expr_ ] /; $dynamicText :=
    Lookup[ $resultCellCache,
            HoldComplete @ expr,
            $resultCellCache[ HoldComplete @ expr ] = makeResultCell0 @ expr
    ];

makeResultCell[ expr_ ] := makeResultCell0 @ expr;

makeResultCell // endDefinition;


makeResultCell0 // beginDefinition;

makeResultCell0[ str_String ] := formatTextString @ str;

makeResultCell0[ codeBlockCell[ language_String, code_String ] ] :=
    makeCodeBlockCell[
        StringReplace[ StringTrim @ language, $externalLanguageRules, IgnoreCase -> True ],
        StringTrim @ code
    ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := makeInlineCodeCell @ code;

makeResultCell0[ mathCell[ math_String ] ] /; StringMatchQ[ math, (DigitCharacter|"."|","|" ").. ] :=
    math;

makeResultCell0[ mathCell[ math_String ] ] :=
    With[ { boxes = Quiet @ InputAssistant`TeXAssistant @ StringTrim @ math },
        If[ MatchQ[ boxes, _RawBoxes ],
            Cell @ BoxData @ toTeXBoxes @ boxes,
            makeResultCell0 @ inlineCodeCell @ math
        ]
    ];

makeResultCell0[ imageCell[ alt_String, url_String ] ] := image[ alt, url ];

makeResultCell0[ hyperlinkCell[ label_String, url_String ] ] := hyperlink[ label, url ];

makeResultCell0[ bulletCell[ whitespace_String, item_String ] ] := Flatten @ {
    $tinyLineBreak,
    whitespace,
    StyleBox[ "\[Bullet]", FontColor -> GrayLevel[ 0.5 ] ],
    " ",
    reformatTextData @ item,
    $tinyLineBreak
};

makeResultCell0[ sectionCell[ n_, section_String ] ] := Flatten @ {
    "\n",
    styleBox[ formatTextString @ section, sectionStyle @ n, "InlineSection", FontSize -> .8*Inherited ],
    $tinyLineBreak
};

makeResultCell0[ inlineToolCallCell[ string_String ] ] := (
    $lastToolCallString = string;
    $lastFormattedToolCall = inlineToolCall @ string
);

makeResultCell0[ tableCell[ string_String ] ] :=
    makeTableCell @ string;

makeResultCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeTableCell*)
makeTableCell // beginDefinition;

makeTableCell[ table_String ] := Flatten @ {
    $tinyLineBreak,
    Map[
        makeTableCell0 @ StringRiffle[ #1, "\n" ] &,
        SplitBy[ StringSplit[ table, "\n" ], StringCount[ #1, "|" ] & ]
    ],
    $tinyLineBreak
};

makeTableCell // endDefinition;


makeTableCell0 // beginDefinition;

makeTableCell0[ string_String ] :=
    makeTableCell0[ StringTrim /@ StringSplit[ StringSplit[ string, "\n" ], "|" ] ];

makeTableCell0 @ { { __String? emptyTableItemQ }, { b__String? delimiterItemQ }, items__ } :=
    Cell[ BoxData @ alignTable[ ToBoxes @ textTableForm @ { items }, { b } ], "TextTableForm" ];

makeTableCell0[ { a_List, { b__String? delimiterItemQ }, c__ } ] :=
    Cell[
        BoxData @ alignTable[ ToBoxes @ textTableForm[ { c }, TableHeadings -> { None, formatRaw /@ a } ], { b } ],
        "TextTableForm"
    ];

makeTableCell0[ items_List? MatrixQ ] :=
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
delimiterAlignment[ ___               ] := Center;

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

textTableForm // endDefinition;


formatRaw // beginDefinition;
formatRaw[ "" ] := "";
formatRaw[ item_String ] := formatRaw[ item, styleBox @ item ];
formatRaw[ item_, { } ] := item;
formatRaw[ item_, StyleBox[ box_ ] ] := formatRaw[ item, box ];
formatRaw[ item_, box: _ButtonBox|_Cell|_StyleBox ] := RawBoxes @ box;
formatRaw[ item_, string_String ] := string;
formatRaw // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*Table Item String Patterns*)
$$ws            = WhitespaceCharacter...;
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
(*formatTextString*)
formatTextString // beginDefinition;

formatTextString[ str_String ] := StringSplit[
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
    $stringFormatRules,
    IgnoreCase -> True
];

formatTextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*floatingButtonGrid*)
floatingButtonGrid // beginDefinition;

floatingButtonGrid // Attributes = { HoldFirst };

floatingButtonGrid[ attached_, cell_, lang_ ] := RawBoxes @ TemplateBox[
    {
        ToBoxes @ Grid[
            {
                {
                    button[ evaluateLanguageLabel @ lang, insertCodeBelow[ cell, True ]; NotebookDelete @ attached ],
                    button[ $insertInputButtonLabel, insertCodeBelow[ cell, False ]; NotebookDelete @ attached ],
                    button[ $copyToClipboardButtonLabel, copyCode @ cell; NotebookDelete @ attached ]
                }
            },
            Alignment  -> Top,
            Spacings   -> 0.2,
            FrameStyle -> GrayLevel[ 0.85 ]
        ]
    },
    "ChatCodeBlockButtonPanel"
];

(* For cloud notebooks (no attached cell) *)
floatingButtonGrid[ string_, lang_ ] := RawBoxes @ TemplateBox[
    {
        ToBoxes @ Grid[
            {
                {
                    button[ evaluateLanguageLabel @ lang, insertCodeBelow[ string, True ] ],
                    button[ $insertInputButtonLabel, insertCodeBelow[ string, False ] ],
                    button[ $copyToClipboardButtonLabel, CopyToClipboard @ string ]
                }
            },
            Alignment  -> Top,
            Spacings   -> 0.2,
            FrameStyle -> GrayLevel[ 0.85 ]
        ]
    },
    "ChatCodeBlockButtonPanel"
];

floatingButtonGrid // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*evaluateLanguageLabel*)
evaluateLanguageLabel[ name_String ] :=
    With[ { icon = $languageIcons @ name },
        fancyTooltip[
            MouseAppearance[ buttonMouseover[ buttonFrameDefault @ icon, buttonFrameActive @ icon ], "LinkHand" ],
            "Insert content as new input cell below and evaluate"
        ] /; MatchQ[ icon, _Graphics | _Image ]
    ];

evaluateLanguageLabel[ ___ ] := $insertEvaluateButtonLabel;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Buttons*)
(* FIXME: move this stuff to the stylesheet *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Labels*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$copyToClipboardButtonLabel*)
$copyToClipboardButtonLabel := $copyToClipboardButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantCopyClipboard" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantCopyClipboard" ]
        ],
        "LinkHand"
    ],
    "Copy to clipboard"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertInputButtonLabel*)
$insertInputButtonLabel := $insertInputButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantCopyBelow" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantCopyBelow" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$insertEvaluateButtonLabel*)
$insertEvaluateButtonLabel := $insertEvaluateButtonLabel = fancyTooltip[
    MouseAppearance[
        buttonMouseover[
            buttonFrameDefault @ RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ],
            buttonFrameActive @ RawBoxes @ TemplateBox[ { }, "AssistantEvaluate" ]
        ],
        "LinkHand"
    ],
    "Insert content as new input cell below and evaluate"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertCodeBelow*)
insertCodeBelow // beginDefinition;

insertCodeBelow[ code_ ] := insertCodeBelow[ code, False ];

insertCodeBelow[ cell_CellObject, evaluate_ ] :=
    insertCodeBelow[ getCodeBlockContent @ cell, evaluate ];

insertCodeBelow[ cell_Cell, evaluate_ ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo  = parentNotebook @ cellObj;
        insertAfterChatGeneratedCells[ cellObj, cell ];
        If[ TrueQ @ evaluate,
            selectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_ ] :=
    insertCodeBelow[ reparseCodeBoxes @ Cell[ BoxData @ string, "Input" ], evaluate ];

insertCodeBelow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*insertAfterChatGeneratedCells*)
insertAfterChatGeneratedCells // beginDefinition;

insertAfterChatGeneratedCells[ cellObj_CellObject, cell_Cell ] := Enclose[
    Module[ { nbo, allCells, cellsAfter, tagged, inserted, insertionPoint },

        nbo = ConfirmMatch[ parentNotebook @ cellObj, _NotebookObject, "ParentNotebook" ];
        allCells = ConfirmMatch[ Cells @ nbo, { __CellObject }, "AllCells" ];
        cellsAfter = Replace[ allCells, { { ___, cellObj, after___ } :> { after }, _ :> { } } ];

        tagged = ConfirmBy[
            AssociationThread[ cellsAfter -> Flatten @* List /@ CurrentValue[ cellsAfter, CellTags ] ],
            AssociationQ,
            "Tagged"
        ];

        inserted = ConfirmBy[ TakeWhile[ tagged, MemberQ[ $chatGeneratedCellTag ] ], AssociationQ, "Inserted" ];
        insertionPoint = ConfirmMatch[ Last[ Keys @ inserted, cellObj ], _CellObject, "InsertionPoint" ];

        SelectionMove[ insertionPoint, After, Cell ];
        NotebookWrite[ nbo, preprocessInsertedCell @ cell, All ];
    ],
    throwInternalFailure
];

insertAfterChatGeneratedCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*copyCode*)
copyCode // beginDefinition;
copyCode[ cell_CellObject ] := copyCode @ getCodeBlockContent @ cell;
copyCode[ code: _Cell|_String ] := CopyToClipboard @ stripMarkdownBoxes @ code;
copyCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*preprocessInsertedCell*)
preprocessInsertedCell // beginDefinition;
preprocessInsertedCell[ cell_ ] := addInsertedCellTags @ stripMarkdownBoxes @ cell;
preprocessInsertedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*addInsertedCellTags*)
addInsertedCellTags // beginDefinition;

addInsertedCellTags[ Cell[ a__, CellTags -> tag_String, b___ ] ] :=
    addInsertedCellTags @ Cell[ a, CellTags -> { tag }, b ];

addInsertedCellTags[ Cell[ a__, CellTags -> { tags___String }, b___ ] ] :=
    Cell[ a, CellTags -> DeleteDuplicates @ { $chatGeneratedCellTag, tags }, b ];

addInsertedCellTags[ Cell[ a: Except[ CellTags -> _ ].. ] ] :=
    Cell[ a, CellTags -> { $chatGeneratedCellTag } ];

addInsertedCellTags // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripMarkdownBoxes*)
stripMarkdownBoxes // beginDefinition;

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ TooltipBox[ boxes_, _String ], "MarkdownImage", ___ ], ___ ], a___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ Cell[ BoxData[ TagBox[ boxes_, "MarkdownImage", ___ ], a___ ], ___ ] ] :=
    Cell[ BoxData @ boxes, a ];

stripMarkdownBoxes[ expr: _Cell|_String ] :=
    expr;

stripMarkdownBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getCodeBlockContent*)
getCodeBlockContent // beginDefinition;
getCodeBlockContent[ cell_CellObject ] := getCodeBlockContent @ NotebookRead @ cell;
getCodeBlockContent[ Cell[ BoxData[ boxes_, ___ ], ___, "ChatCodeBlock", ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ TemplateBox[ { boxes_ }, "ChatCodeBlockTemplate", ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ Cell[ BoxData[ boxes_, ___ ] ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ DynamicModuleBox[ _, boxes_, ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ TagBox[ boxes_, _EventHandlerTag, ___ ] ] := getCodeBlockContent @ boxes;
getCodeBlockContent[ Cell[ boxes_, "ChatCode", "Input", ___ ] ] := reparseCodeBoxes @ Cell[ boxes, "Input" ];

getCodeBlockContent[ Cell[ boxes_, "ExternalLanguage", ___, CellEvaluationLanguage -> lang_, ___ ] ] :=
    Cell[ boxes, "ExternalLanguage", CellEvaluationLanguage -> lang ];

getCodeBlockContent[ cell: Cell[ _, _String, ___ ] ] := cell;

getCodeBlockContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reparseCodeBoxes*)
reparseCodeBoxes // beginDefinition;

reparseCodeBoxes[ Cell[ BoxData[ s_String ], a___ ] ] /; $cloudNotebooks :=
    Cell[ BoxData @ UsingFrontEnd @ stringToBoxes @ s, a ];

reparseCodeBoxes[ cell_Cell ] :=
    cell;

reparseCodeBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*button*)
button // beginDefinition;
button // Attributes = { HoldRest };

button[ label_, code_, opts___ ] := Button[
    label, code, opts,
    Appearance -> Dynamic @ FEPrivate`FrontEndResource[ "FEExpressions", "SuppressMouseDownNinePatchAppearance" ]
];

button // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonMouseover*)
buttonMouseover[ a_, b_ ] := Mouseover[ a, b ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameDefault*)
buttonFrameDefault[ expr_ ] :=
    Framed[
        buttonPane @ expr,
        FrameStyle     -> GrayLevel[ 0.95 ],
        Background     -> GrayLevel[ 1 ],
        FrameMargins   -> 0,
        RoundingRadius -> 2
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonFrameActive*)
buttonFrameActive[ expr_ ] :=
    Framed[
        buttonPane @ expr,
        FrameStyle     -> GrayLevel[ 0.82 ],
        Background     -> GrayLevel[ 1 ],
        FrameMargins   -> 0,
        RoundingRadius -> 2
    ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*buttonPane*)
buttonPane[ expr_ ] :=
    Pane[ expr, ImageSize -> { 24, 24 }, ImageSizeAction -> "ShrinkToFit", Alignment -> { Center, Center } ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fancyTooltip*)
fancyTooltip[ expr_, tooltip_ ] := Tooltip[
    expr,
    Framed[
        Style[
            tooltip,
            "Text",
            FontColor    -> RGBColor[ 0.53725, 0.53725, 0.53725 ],
            FontSize     -> 12,
            FontWeight   -> "Plain",
            FontTracking -> "Plain"
        ],
        Background   -> RGBColor[ 0.96078, 0.96078, 0.96078 ],
        FrameStyle   -> RGBColor[ 0.89804, 0.89804, 0.89804 ],
        FrameMargins -> 8
    ],
    TooltipDelay -> 0.15,
    TooltipStyle -> { Background -> None, CellFrame -> 0 }
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Parsing Rules*)
$$endToolCall = Longest[ "ENDRESULT" ~~ (("(" ~~ HexadecimalCharacter.. ~~ ")") | "") ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$textDataFormatRules*)
$textDataFormatRules = {
    StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        ("```"|EndOfString)
    ] /; StringFreeQ[ code, "TOOLCALL:" ~~ ___ ~~ ($$endToolCall|EndOfString) ] :>
        codeBlockCell[ language, code ]
    ,
    "![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")" /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            imageCell[ alt, url ]
    ,
    tool: ("TOOLCALL:" ~~ Shortest[ ___ ] ~~ ($$endToolCall|EndOfString)) :> inlineToolCallCell @ tool,
    ("\n"|StartOfString) ~~ w:" "... ~~ "* " ~~ item: Longest[ Except[ "\n" ].. ] :> bulletCell[ w, item ],
    ("\n"|StartOfString) ~~ h:"#".. ~~ " " ~~ sec: Longest[ Except[ "\n" ].. ] :> sectionCell[ StringLength @ h, sec ],
    table: $$mdTable :> tableCell @ table
    ,
    "[`" ~~ label: Except[ "[" ].. ~~ "`](" ~~ url: Except[ ")" ].. ~~ ")" :> "[" <> label <> "]("<>url<>")",
    "\\`" :> "`",
    "\\$" :> "$",
    "``" ~~ code__ ~~ "``" /; StringFreeQ[ code, "``" ] :> inlineCodeCell @ code,
    "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`" /; inlineSyntaxQ @ code :> inlineCodeCell @ code,
    "`" ~~ code: Except[ "`"|"\n" ].. ~~ "`" :> inlineCodeCell @ code,
    "$$" ~~ math__ ~~ "$$" /; StringFreeQ[ math, "$$" ] :> mathCell @ math,
    "\\(" ~~ math__ ~~ "\\)" /; StringFreeQ[ math, "\\)" ] :> mathCell @ math,
    "\\[" ~~ math__ ~~ "\\]" /; StringFreeQ[ math, "\\]" ] :> mathCell @ math,
    "$" ~~ math: Except[ "$" ].. ~~ "$" /; probablyMathQ @ math :> mathCell @ math
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$dynamicSplitRules*)

(* Defines safe points to split content into static/dynamic parts. These patterns must be different from
   `$textDataFormatRules`, since there will be no additional formatting passes once static content is written.
   Therefore, some of the patterns that would match up to `EndOfString` must instead be explicitly terminated here.
*)
$dynamicSplitRules = {
    (* Code blocks *)
    s: StringExpression[
        Longest[ "```" ~~ language: Except[ "\n" ]... ] ~~ (" "...) ~~ "\n",
        Shortest[ code__ ],
        "```"
    ] /; StringFreeQ[ code, "TOOLCALL:" ~~ ___ ~~ ($$endToolCall|EndOfString) ] :> s
    ,
    (* Markdown image *)
    s: ("![" ~~ alt: Shortest[ ___ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")") /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            s
    ,
    (* Tool call *)
    s: ("TOOLCALL:" ~~ Shortest[ ___ ] ~~ $$endToolCall) :> s
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$stringFormatRules*)

(* cSpell: ignore textit, textbf *)
$stringFormatRules = {
    "***" ~~ text: Except[ "*" ].. ~~ "***" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    "___" ~~ text: Except[ "_" ].. ~~ "___" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],

    "**" ~~ text: Except[ "*" ].. ~~ "**" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold ],

    "__" ~~ text: Except[ "_" ].. ~~ "__" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontWeight -> Bold ],

    "*" ~~ text: Except[ "*" ].. ~~ "*" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "_" ~~ text: Except[ "_" ].. ~~ "_" /; StringFreeQ[ text, "\n" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :>
        hyperlink[ label, url ],

    "\\textit{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :>
        styleBox[ text, FontSlant -> Italic ],

    "\\textbf{" ~~ text__ ~~ "}" /; StringFreeQ[ text, "{"|"}" ] :>
        styleBox[ text, FontWeight -> Bold ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatted Boxes*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeCodeBlockCell*)
makeCodeBlockCell // beginDefinition;
makeCodeBlockCell[ _, code_String ] /; StringMatchQ[ code, "!["~~__~~"]("~~__~~")" ] := image @ code;
makeCodeBlockCell[ _, code_String ] /; StringStartsQ[ code, "TOOLCALL: " ] := inlineToolCall @ code;
makeCodeBlockCell[ language_String, code_String ] := makeInteractiveCodeCell[ language, code ];
makeCodeBlockCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineToolCall*)
inlineToolCall // beginDefinition;

inlineToolCall[ string_String ] := inlineToolCall[ string, parseToolCallString @ string ];

inlineToolCall[ string_String, as_Association ] := Cell[
    BoxData @ ToBoxes @ Panel[
        makeToolCallBoxLabel @ as,
        BaseStyle    -> "Text",
        Background   -> GrayLevel[ 0.95 ],
        ImageMargins -> 10
    ],
    "InlineToolCall",
    Background   -> None,
    TaggingRules -> KeyDrop[ as, { "Icon", "Result" } ]
];

inlineToolCall[ string_String, failed_Failure ] := Cell[
    BoxData @ ToBoxes @ failed,
    "FailedToolCall",
    Background   -> None,
    TaggingRules -> <| "ToolCall" -> string |>
];

inlineToolCall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseToolCallString*)
parseToolCallString // beginDefinition;
parseToolCallString[ string_String ] := parseToolCallString[ parseToolCallID @ string, string ];
parseToolCallString[ id_String, string_String ] := parseFullToolCallString[ id, string ];
parseToolCallString[ _Missing, string_String ] := parsePartialToolCallString @ string;
parseToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parsePartialToolCallString*)
parsePartialToolCallString // beginDefinition;

parsePartialToolCallString[ string_String ] /; StringMatchQ[ string, "TOOLCALL:"~~__~~"{"~~___ ] :=
    Module[ { noPrefix, noSuffix, name, tool, displayName, icon, query, result },

        noPrefix    = StringDelete[ string, StartOfString~~"TOOLCALL:" ];
        noSuffix    = StringTrim @ StringDelete[ noPrefix, "ENDRESULT"~~___~~EndOfString ];
        name        = StringTrim @ StringDelete[ noSuffix, ("\n"|"{")~~___~~EndOfString ];
        tool        = getToolByName @ name;
        displayName = getToolDisplayName[ tool, name ];
        icon        = getToolIcon @ tool;
        query       = First[ StringCases[ string, "TOOLCALL:" ~~ q___ ~~ "\nRESULT" :> q ], "" ];
        result      = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDRESULT" :> r ], "" ];

        <|
            "Name"        -> name,
            "DisplayName" -> displayName,
            "Icon"        -> icon,
            "ToolCall"    -> StringTrim @ string,
            "Parameters"  -> StringTrim @ query,
            "Result"      -> StringTrim @ result
        |>
    ];

parsePartialToolCallString[ string_String ] := <| "ToolCall" -> StringTrim @ string |>;

parsePartialToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseFullToolCallString*)
parseFullToolCallString // beginDefinition;

parseFullToolCallString[ id_String, string_String ] :=
    parseFullToolCallString[ id, $toolEvaluationResults[ id ], string ];

parseFullToolCallString[ id_, _Missing, string_String ] :=
    parsePartialToolCallString @ string;

parseFullToolCallString[ id_, failed_Failure, string_String ] :=
    failed;

parseFullToolCallString[ id_String, resp: HoldPattern[ _LLMToolResponse ], string_String ] :=
    parseFullToolCallString[
        id,
        resp[ "Tool" ],
        resp[ "InterpretedParameterValues" ],
        resp[ "Output" ],
        string
    ];

parseFullToolCallString[ id_String, tool: HoldPattern[ _LLMTool ], parameters_Association, output_, string_ ] :=
    $lastFullParsed = <|
        "ID"                 -> id,
        "Name"               -> toolName[tool],
        "DisplayName"        -> getToolDisplayName @ tool,
        "Icon"               -> getToolIcon @ tool,
        "FormattingFunction" -> getToolFormattingFunction @ tool,
        "ToolCall"           -> StringTrim @ string,
        "Parameters"         -> parameters,
        "Result"             -> output
    |>;

parseFullToolCallString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*parseToolCallID*)
parseToolCallID // beginDefinition;

parseToolCallID[ string_String? StringQ ] :=
    Replace[
        StringReplace[
            string,
            {
                StringExpression[
                    StartOfString,
                    WhitespaceCharacter...,
                    "TOOLCALL:",
                    ___,
                    "ENDRESULT(",
                    hex: HexadecimalCharacter..,
                    ")",
                    WhitespaceCharacter...,
                    EndOfString
                ] :> hex,
                StartOfString ~~ ___ ~~ EndOfString :> ""
            }
        ],
        "" -> Missing[ "NotAvailable" ]
    ];

parseToolCallID // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*fullToolCallStringQ*)
fullToolCallStringQ // beginDefinition;
fullToolCallStringQ[ string_String? StringQ ] := StringQ @ parseToolCallID @ string;
fullToolCallStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallBoxLabel*)
makeToolCallBoxLabel // beginDefinition;

makeToolCallBoxLabel[ as: KeyValuePattern[ "DisplayName" -> name_String ] ] :=
    makeToolCallBoxLabel[ as, name ];

makeToolCallBoxLabel[ as: KeyValuePattern[ "Name" -> name_String ] ] :=
    makeToolCallBoxLabel[
        as,
        StringRiffle @ Capitalize @ StringSplit[
            StringDelete[ StringTrim @ name, (Whitespace|"{") ~~ ___ ~~ EndOfString ],
            "_"
        ]
    ];

makeToolCallBoxLabel[ as_Association ] := "Using tool\[Ellipsis]";

makeToolCallBoxLabel[ as_Association, name_String ] :=
    makeToolCallBoxLabel[ as, name, getToolIcon @ as ];

makeToolCallBoxLabel[ as_, name_String, icon_ ] /; $dynamicText := makeToolCallBoxLabel0[ as, name, icon ];

makeToolCallBoxLabel[ as0_, name_String, icon_ ] :=
    With[ { as = resolveToolFormatter @ as0 },
        openerView[
            {
                makeToolCallBoxLabel0[ as, name, icon ],
                TabView[
                    {
                        "Raw"         -> makeToolCallRawView @ as,
                        "Interpreted" -> makeToolCallInterpretedView @ as
                    },
                    2,
                    ImageSize  -> Automatic,
                    LabelStyle -> { FontSize -> 12 }
                ]
            },
            Method -> "Active"
        ]
    ];

makeToolCallBoxLabel // endDefinition;


makeToolCallBoxLabel0 // beginDefinition;

makeToolCallBoxLabel0[ KeyValuePattern[ "Result" -> "" ], string_String, icon_ ] := Row @ Flatten @ {
    "Using ",
    Style[ string, FontWeight -> "DemiBold" ],
    If[ MissingQ @ icon,
        Nothing,
        {
            Spacer[ 5 ],
            toolCallIconPane @ icon
        }
    ]
};

makeToolCallBoxLabel0[ as_, string_String, icon_ ] := Row @ Flatten @ {
    "Used ",
    Style[ string, FontWeight -> "DemiBold" ],
    If[ MissingQ @ icon,
        Nothing,
        {
            Spacer[ 5 ],
            toolCallIconPane @ icon
        }
    ]
};

makeToolCallBoxLabel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolCallIconPane*)
toolCallIconPane // beginDefinition;

toolCallIconPane[ icon_ ] :=
    Dynamic[
        If[ TrueQ @ $CloudEvaluation,
            #1,
            Pane[ #1, ImageSize -> { 20, 20 }, ImageSizeAction -> "ShrinkToFit" ]
        ] &[ icon ],
        SingleEvaluation -> True,
        TrackedSymbols   :> { }
    ];

toolCallIconPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallRawView*)
makeToolCallRawView // beginDefinition;

makeToolCallRawView[ KeyValuePattern[ "ToolCall" -> raw_String ] ] :=
    Framed[
        Framed[
            RawBoxes @ Cell[
                BoxData @ ToBoxes @ wideScrollPane @ raw,
                "Text", "RawToolCall",
                FontSize   -> 11,
                Background -> None
            ],
            Background   -> White,
            FrameMargins -> 5,
            FrameStyle   -> None,
            ImageSize    -> { Scaled[ 1 ], Automatic },
            BaseStyle    -> "Text"
        ],
        Background   -> White,
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallRawView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*makeToolCallInterpretedView*)
makeToolCallInterpretedView // beginDefinition;

makeToolCallInterpretedView[ as_Association ] :=
    Framed[
        Column[
            {
                Item[
                    Pane[ Style[ "INPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> GrayLevel[ 0.95 ]
                ],
                Framed[
                    makeToolCallInputSection @ as,
                    Background   -> White,
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ],
                Item[
                    Pane[ Style[ "OUTPUT", FontSize -> 11 ], FrameMargins -> { { 5, 5 }, { 1, 1 } } ],
                    ItemSize   -> Fit,
                    Background -> GrayLevel[ 0.95 ]
                ],
                Framed[
                    makeToolCallOutputSection @ as,
                    Background   -> White,
                    FrameMargins -> 5,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            },
            Alignment -> Left
        ],
        Background   -> White,
        BaseStyle    -> { Editable -> False },
        FrameStyle   -> None,
        FrameMargins -> 10
    ];

makeToolCallInterpretedView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallInputSection*)
makeToolCallInputSection // beginDefinition;

makeToolCallInputSection[ as: KeyValuePattern[ "Parameters" -> params_Association ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        Grid[
            KeyValueMap[ { #1, formatter[ #2, "Parameters", #1 ] } &, params ],
            Alignment  -> Left,
            BaseStyle  -> "Text",
            Dividers   -> All,
            FrameStyle -> GrayLevel[ 0.9 ],
            Spacings   -> 1
        ]
    ],
    throwInternalFailure[ makeToolCallInputSection @ as, ## ] &
];

makeToolCallInputSection[ KeyValuePattern[ "Parameters" -> query_String ] ] :=
    TextCell[ query, "Program", FontSize -> 0.75 * Inherited, Background -> None ];

makeToolCallInputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resolveToolFormatter*)
resolveToolFormatter // beginDefinition;
resolveToolFormatter[ as_Association ] := Append[ as, "FormattingFunction" -> resolveToolFormatter0 @ as ];
resolveToolFormatter // endDefinition;

resolveToolFormatter0 // beginDefinition;
resolveToolFormatter0[ KeyValuePattern[ "FormattingFunction" -> f_ ] ] := resolveToolFormatter0 @ f;
resolveToolFormatter0[ Automatic ] := clickToCopy[ #1 ] &;
resolveToolFormatter0[ Inherited ] := toolAutoFormatter;
resolveToolFormatter0[ None      ] := #1 &;
resolveToolFormatter0[ f_        ] := f;
resolveToolFormatter0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*toolAutoFormatter*)
toolAutoFormatter // beginDefinition;

toolAutoFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    toolAutoFormatter[ result, "Result" ];

toolAutoFormatter[ result_String, "Result" ] := RawBoxes @ Cell[
    TextData @ reformatTextData @ result,
    "Text",
    Background -> None
];

toolAutoFormatter[ parameter_, "Parameters", ___ ] := clickToCopy @ parameter;

toolAutoFormatter[ result_, ___ ] := result;

toolAutoFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*clickToCopy*)
clickToCopy // beginDefinition;
clickToCopy[ ClickToCopy[ args__ ] ] := clickToCopy @ args;
clickToCopy[ HoldForm[ expr_ ], a___ ] := clickToCopy[ Defer @ expr, a ];
clickToCopy[ expr_, a___ ] := Grid[ { { ClickToCopy[ expr, a ], "" } }, Spacings -> 0, BaseStyle -> "Text" ];
clickToCopy // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeToolCallOutputSection*)
makeToolCallOutputSection // beginDefinition;

makeToolCallOutputSection[ as: KeyValuePattern[ "Result" -> result_ ] ] := Enclose[
    Module[ { formatter },
        formatter = Confirm[ as[ "FormattingFunction" ], "FormattingFunction" ];
        TextCell[ wideScrollPane @ formatter[ result, "Result" ], "Text", Background -> None ]
    ],
    throwInternalFailure[ makeToolCallOutputSection @ as, ## ] &
];

makeToolCallOutputSection // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*wideScrollPane*)
wideScrollPane // beginDefinition;

wideScrollPane[ expr_ ] := Pane[
    expr,
    ImageSize          -> { Scaled[ 1 ], UpTo[ 400 ] },
    Scrollbars         -> Automatic,
    AppearanceElements -> None
];

wideScrollPane // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

(* TODO: define template boxes for these *)
makeInteractiveCodeCell[ language_, code_String ] /; $dynamicText :=
    If[ TrueQ @ wolframLanguageQ @ language,
        codeBlockFrame[ Cell[ BoxData @ code, "ChatCodeActive" ], code, language ],
        codeBlockFrame[ Cell[ code, "ChatPreformatted" ], code, language ]
    ];

(* Wolfram Language code blocks *)
makeInteractiveCodeCell[ lang_String? wolframLanguageQ, code_ ] :=
    Module[ { display, handler },
        display = RawBoxes @ Cell[
            BoxData @ If[ StringQ @ code, stringToBoxes @ code, code ],
            "ChatCode",
            "Input",
            Background -> GrayLevel[ 1 ]
        ];
        handler = inlineInteractiveCodeCell[ display, code ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code ]
    ];

(* Supported external language code blocks *)
makeInteractiveCodeCell[ lang_String? externalLanguageQ, code_String ] :=
    Module[ { cell, display, handler },
        cell = Cell[ code, "ExternalLanguage", FontSize -> 14, System`CellEvaluationLanguage -> lang ];
        display = RawBoxes @ Cell[
            code,
            "ExternalLanguage",
            System`CellEvaluationLanguage -> lang,
            FontSize   -> 13,
            Background -> None,
            CellFrame  -> None
        ];
        handler = inlineInteractiveCodeCell[ display, cell ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code, lang ]
    ];

(* Code blocks for any other languages *)
makeInteractiveCodeCell[ language_String, code_String ] :=
    codeBlockFrame[
        Cell[
            code,
            "ChatPreformatted",
            Background   -> GrayLevel[ 1 ],
            TaggingRules -> <| "CellToStringType" -> "InlineCodeCell", "CodeLanguage" -> language |>
        ],
        code,
        language
    ];

makeInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageQ*)
wolframLanguageQ // ClearAll;
wolframLanguageQ[ language_String ] := StringMatchQ[ StringTrim @ language, $wlCodeString, IgnoreCase -> True ];
wolframLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineInteractiveCodeCell*)
inlineInteractiveCodeCell // beginDefinition;

inlineInteractiveCodeCell[ display_, string_ ] /; $dynamicText := display;

(* TODO: make this switch dynamically depending on $cloudNotebooks (likely as a TemplateBox)*)
inlineInteractiveCodeCell[ display_, string_ ] :=
    inlineInteractiveCodeCell[ display, string, contentLanguage @ string ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] /; $cloudNotebooks :=
    cloudInlineInteractiveCodeCell[ display, string, lang ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] :=
    DynamicModule[ { $CellContext`attached, $CellContext`cell },
        EventHandler[
            display,
            {
                "MouseEntered" :> (
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "AttachCodeButtons",
                        Dynamic[ $CellContext`attached ],
                        $CellContext`cell,
                        string,
                        lang
                    ]
                )
            }
        ],
        TaggingRules     -> <| "CellToStringType" -> "InlineInteractiveCodeCell", "CodeLanguage" -> lang |>,
        UnsavedVariables :> { $CellContext`attached, $CellContext`cell },
        Initialization   :> { $CellContext`cell = (FinishDynamic[ ]; EvaluationCell[ ]) }
    ];

inlineInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cloudInlineInteractiveCodeCell*)
cloudInlineInteractiveCodeCell // beginDefinition;

cloudInlineInteractiveCodeCell[ display_, string_, lang_ ] :=
    Module[ { padded, buttons },

        padded = Pane[ display, ImageSize -> { { 100, Automatic }, { 30, Automatic } } ];

        buttons = Framed[
            floatingButtonGrid[ string, lang ],
            Background     -> White,
            FrameMargins   -> { { 1, 0 }, { 0, 1 } },
            FrameStyle     -> White,
            ImageMargins   -> 1,
            RoundingRadius -> 3
        ];

        Mouseover[
            buttonOverlay[ padded, Invisible @ buttons ],
            buttonOverlay[ padded, buttons ],
            ContentPadding -> False,
            FrameMargins   -> 0,
            ImageMargins   -> 0,
            ImageSize      -> All
        ]
    ];

cloudInlineInteractiveCodeCell // endDefinition;

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
(* ::Subsection::Closed:: *)
(*makeInlineCodeCell*)
makeInlineCodeCell // beginDefinition;

makeInlineCodeCell[ s_String? nameQ ] /; Context @ s === "System`" :=
    hyperlink[ s, "paclet:ref/" <> Last @ StringSplit[ s, "`" ] ];

makeInlineCodeCell[ s_String? LowerCaseQ ] := StyleBox[ unescapeInlineMarkdown @ s, "TI" ];

makeInlineCodeCell[ code_String ] /; $dynamicText := Cell[
    BoxData @ TemplateBox[ { stringToBoxes @ unescapeInlineMarkdown @ code }, "ChatCodeInlineTemplate" ],
    "ChatCodeActive"
];

makeInlineCodeCell[ code0_String ] :=
    With[ { code = unescapeInlineMarkdown @ code0 },
        If[ SyntaxQ @ code,
            Cell[
                BoxData @ TemplateBox[ { stringToBoxes @ code }, "ChatCodeInlineTemplate" ],
                "ChatCode",
                Background -> None
            ],
            Cell[
                BoxData @ TemplateBox[ { Cell[ code, Background -> None ] }, "ChatCodeInlineTemplate" ],
                "ChatCodeActive",
                Background -> None
            ]
        ]
    ];

makeInlineCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeBlockFrame*)
codeBlockFrame // beginDefinition;

codeBlockFrame[ cell_, string_ ] := codeBlockFrame[ cell, string, "Wolfram" ];

codeBlockFrame[ cell_, string_, lang_ ] := Cell[
    BoxData @ TemplateBox[ { cell }, "ChatCodeBlockTemplate" ],
    "ChatCodeBlock",
    Background -> None
];

codeBlockFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*styleBox*)
styleBox // beginDefinition;

styleBox[ text_String, a___ ] := styleBox[ formatTextString @ text, a ];
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
(*image*)
image // beginDefinition;

image[ str_String ] := First @ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> image[ alt, url ] ];

image[ alt_String, url_String ] := Enclose[
    Module[ { keys, key },
        keys = ConfirmMatch[ Keys @ $attachments, { ___String? StringQ }, "Keys" ];
        key  = SelectFirst[ keys, StringContainsQ[ url, #1, IgnoreCase -> True ] & ];
        If[ StringQ @ key,
            attachment[ alt, key ],
            image[ alt, url, URLParse @ url ]
        ]
    ],
    throwInternalFailure[ image[ alt, url ], ## ] &
];

image[ alt_, url_, KeyValuePattern @ { "Scheme" -> "attachment"|"expression", "Domain" -> key_String } ] :=
    attachment[ alt, key ];

image[ alt_, url_, _ ] := importedImage[ alt, url ];

image // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachment*)
attachment // beginDefinition;
attachment[ alt_String, key_String ] := attachment[ alt, key, $attachments[ key ] ];
attachment[ alt_String, key_String, HoldComplete[ expr_ ] ] := attachment[ alt, key, Defer @ expr ];
attachment[ alt_String, key_String, _Missing ] := attachment[ alt, key, $missingImage ];

attachment[ alt_String, key_String, Defer[ img_Image ] ] /; ImageQ @ Unevaluated @ img :=
    Cell[ BoxData @ PaneBox[ attachmentBoxes[ alt, key, resizeImage @ img ], ImageMargins -> 10 ], Background -> None ];

attachment[ alt_String, key_String, expr_ ] /; $dynamicText :=
    codeBlockFrame[ Cell[ BoxData @ attachmentBoxes[ alt, key, expr ], "ChatCodeActive" ], expr ];

attachment[ alt_String, key_String, expr_ ] :=
    Module[ { boxes, display, handler },
        boxes = attachmentBoxes[ alt, key, expr ];
        display = RawBoxes @ Cell[
            BoxData @ boxes,
            "ChatCode",
            "Input",
            Background -> GrayLevel[ 1 ]
        ];
        handler = inlineInteractiveCodeCell[ display, Cell[ BoxData @ cachedBoxes @ expr, "Input" ] ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, expr ]
    ];

attachment // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*attachmentBoxes*)
attachmentBoxes // beginDefinition;
attachmentBoxes[ alt_, key_String, expr_ ] := markdownImageBoxes[ StringTrim @ alt, "attachment://" <> key, expr ];
attachmentBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownImageBoxes*)
markdownImageBoxes // beginDefinition;

markdownImageBoxes[ "", url_String, expr_ ] := TagBox[
    cachedBoxes @ expr,
    "MarkdownImage",
    AutoDelete   -> True,
    TaggingRules -> <| "CellToStringData" -> "![]("<>url<>")" |>
];

markdownImageBoxes[ alt_String, url_String, expr_ ] := TagBox[
    TooltipBox[ cachedBoxes @ expr, ToString[ alt, InputForm ] ],
    "MarkdownImage",
    AutoDelete   -> True,
    TaggingRules -> <| "CellToStringData" -> "!["<>alt<>"]("<>url<>")" |>
];

markdownImageBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*importedImage*)
importedImage // beginDefinition;

importedImage[ alt_String, url_String ] :=
    importedImage[ alt, url, importImage @ url ];

importedImage[ alt_String, url_String, _? FailureQ | _String ] :=
    importedImage[ alt, url, $missingImage ];

importedImage[ alt_String, url_String, i_ ] :=
    Cell @ BoxData @ markdownImageBoxes[ StringTrim @ alt, url, tooltip[ resizeImage @ i, alt ] ];

importedImage // endDefinition;

$missingImage = RawBoxes @ TemplateBox[ { }, "ImageNotFound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*importImage*)
importImage // beginDefinition;
importImage[ url_String ] := importImage[ url ] = Quiet @ Import[ url, "Image" ];
importImage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tooltip*)
tooltip // beginDefinition;
tooltip[ expr_, ""|"result" ] := expr;
tooltip[ expr_, text_ ] := Tooltip[ expr, text ];
tooltip // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*resizeImage*)
resizeImage // beginDefinition;
resizeImage[ img_ ] := resizeImage[ img, $dynamicText ];
resizeImage[ img_, dynamic_ ] := resizeImage[ img, dynamic ] = resizeImage0 @ img;
resizeImage // endDefinition;


resizeImage0 // beginDefinition;

resizeImage0[ img_Image? ImageQ ] :=
    resizeImage0[ img, ImageDimensions @ img ];

resizeImage0[ img_Image? ImageQ, dims: { _Integer, _Integer } ] /; $dynamicText && Max @ dims > $maxDynamicImageSize :=
    showResized @ ImageResize[ img, { UpTo[ $maxDynamicImageSize ], UpTo[ $maxDynamicImageSize ] } ];

resizeImage0[ img_Image? ImageQ, dims: { _Integer, _Integer } ] /; Max @ dims > $maxImageSize :=
    showResized @ ImageResize[ img, { UpTo @ $maxImageSize, UpTo @ $maxImageSize } ];

resizeImage0[ img_Image? ImageQ, dims: { _Integer, _Integer } ] :=
    Show[ img, ImageSize -> dims / 2 ];

resizeImage0[ other_ ] :=
    other;

resizeImage0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*showResized*)
showResized // beginDefinition;
showResized[ img_Image? ImageQ ] := showResized[ img, targetImageSize @ img ];
showResized[ img_, { w_Integer, h_Integer } ] := Show[ img, ImageSize -> { UpTo @ w, UpTo @ h } ];
showResized[ img_ ] := img;
showResized // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsubsection::Closed:: *)
(*targetImageSize*)
targetImageSize // beginDefinition;
targetImageSize[ img_Image? ImageQ ] /; $dynamicText := Ceiling[ (ImageDimensions @ img / 2) / $dynamicImageScale ];
targetImageSize[ img_Image? ImageQ ] := Ceiling[ ImageDimensions @ img / 2 ];
targetImageSize // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedBoxes*)
cachedBoxes // beginDefinition;
cachedBoxes[ e_ ] := With[ { h = Hash @ Unevaluated @ e }, Lookup[ $boxCache, h, $boxCache[ h ] = MakeBoxes @ e ] ];
cachedBoxes // endDefinition;

$boxCache = <| |>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*hyperlink*)
hyperlink // beginDefinition;

hyperlink[ label_String | { label_String }, uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    Cell @ BoxData @ TemplateBox[ { StringTrim[ label, (Whitespace|"`"|"\\").. ], uri }, "TextRefLink" ];

hyperlink[ label_String, url_String ] := hyperlink[ formatTextString @ label, url ];

hyperlink[ { label: _String|_StyleBox }, url_ ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

hyperlink[ a_, ___ ] := a;

(* TODO: if the link contains a UUID that corresponds to a notebook object, create a link that selects that notebook *)

hyperlink // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*External Languages*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*contentLanguage*)
contentLanguage[ Cell[ __, "CellEvaluationLanguage" -> lang_String, ___ ] ] := lang;
contentLanguage[ Cell[ __, System`CellEvaluationLanguage -> lang_String, ___ ] ] := lang;
contentLanguage[ ___ ] := "Wolfram";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*externalLanguageQ*)
externalLanguageQ[ $$externalLanguage ] := True;

externalLanguageQ[ str_String? StringQ ] := externalLanguageQ[ str ] =
    StringMatchQ[
        StringReplace[ StringTrim @ str, $externalLanguageRules, IgnoreCase -> True ],
        $$externalLanguage,
        IgnoreCase -> True
    ];

externalLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$languageIcons*)
$languageIcons := $languageIcons = Enclose[
    ExternalEvaluate;
    Select[
        AssociationMap[
            ReleaseHold @ ExternalEvaluate`Private`GetLanguageRules[ #1, "Icon" ] &,
            ConfirmMatch[ ExternalEvaluate`Private`GetLanguageRules[ ], _List ]
        ],
        MatchQ[ _Graphics|_Image ]
    ],
    <| |> &
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*joinAdjacentStrings*)
joinAdjacentStrings // beginDefinition;
joinAdjacentStrings[ { content___, "\n"|StyleBox[ "\n", ___ ] } ] := joinAdjacentStrings @ { content };
joinAdjacentStrings[ { "\n"|StyleBox[ "\n", ___ ], content___ } ] := joinAdjacentStrings @ { content };
joinAdjacentStrings[ content_List ] := joinAdjacentStrings0 /@ SplitBy[ content, StringQ ];
joinAdjacentStrings // endDefinition;

joinAdjacentStrings0 // beginDefinition;

joinAdjacentStrings0[ { strings__String } ] :=
    StringReplace[ StringJoin @ strings, c: Except[ "\n" ]~~"\n"~~EndOfString :> c<>" \n" ];

joinAdjacentStrings0[ { other___ } ] := other;

joinAdjacentStrings0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*nameQ*)
nameQ[ "*"|"**" ] := False;
nameQ[ s_String? StringQ ] := StringFreeQ[ s, Verbatim[ "*" ] | Verbatim[ "@" ] ] && NameQ @ s;
nameQ[ ___ ] := False;

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
(* ::Subsection::Closed:: *)
(*unescapeInlineMarkdown*)
unescapeInlineMarkdown // beginDefinition;
unescapeInlineMarkdown[ str_String ] := StringReplace[ str, { "\\`" -> "`", "\\$" -> "$" } ];
unescapeInlineMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;
stringToBoxes[ s_String ] /; $dynamicText := s;
stringToBoxes[ s_String ] := adjustBoxSpacing @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket @ s;
stringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adjustBoxSpacing*)
adjustBoxSpacing // beginDefinition;
adjustBoxSpacing[ row: RowBox @ { "(*", ___, "*)" } ] := row;
adjustBoxSpacing[ RowBox[ items_List ] ] := RowBox[ adjustBoxSpacing /@ DeleteCases[ items, " " ] ];
adjustBoxSpacing[ "\n" ] := "\[IndentingNewLine]";
adjustBoxSpacing[ box_ ] := box;
adjustBoxSpacing // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`ChatbookInternal`$BuildingMX,
    $copyToClipboardButtonLabel;
    $insertInputButtonLabel;
    $insertEvaluateButtonLabel;
    $languageIcons;
];

End[ ];
EndPackage[ ];
