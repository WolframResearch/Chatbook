(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Formatting`" ];

(* cSpell: ignore TOOLCALL, ENDARGUMENTS, ENDTOOLCALL *)

`$dynamicText;
`$reformattedCell;
`$resultCellCache;
`floatingButtonGrid;
`reformatTextData;

Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"          ];
Needs[ "Wolfram`Chatbook`Common`"   ];
Needs[ "Wolfram`Chatbook`FrontEnd`" ];
Needs[ "Wolfram`Chatbook`Tools`"    ];

(* FIXME: Use ParagraphSpacing to squeeze text closer together *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Config*)

$wlCodeString = Longest @ Alternatives[
    "Wolfram Language",
    "WolframLanguage",
    "Wolfram",
    "Mathematica"
];

$resultCellCache = <| |>;

sectionStyle[ 1 ] := "Section";
sectionStyle[ 2 ] := "Subsection";
sectionStyle[ 3 ] := "Subsubsection";
sectionStyle[ 4 ] := "Subsubsubsection";
sectionStyle[ _ ] := "Subsubsubsubsection";

$tinyLineBreak = StyleBox[ "\n", "TinyLineBreak", FontSize -> 3 ];

$$externalLanguage = "Java"|"Julia"|"Jupyter"|"NodeJS"|"Octave"|"Python"|"R"|"Ruby"|"Shell"|"SQL"|"SQL-JDBC";

$externalLanguageRules = Flatten @ {
    "JS"         -> "NodeJS",
    "Javascript" -> "NodeJS",
    "NPM"        -> "NodeJS",
    "Node"       -> "NodeJS",
    "Bash"       -> "Shell",
    "SH"         -> "Shell",
    Cases[ $$externalLanguage, lang_ :> (lang -> lang) ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Output Formatting*)

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

makeResultCell0[ codeCell[ code0_String ] ] :=
    With[ { code = StringTrim @ code0 },
        If[ StringMatchQ[ code, "!["~~__~~"]("~~__~~")" ],
            image @ code,
            makeInteractiveCodeCell @ StringTrim @ code
        ]
    ];

makeResultCell0[ externalCodeCell[ lang_String, code_String ] ] :=
    makeInteractiveCodeCell[
        StringReplace[ StringTrim @ lang, $externalLanguageRules, IgnoreCase -> True ],
        StringTrim @ code
    ];

makeResultCell0[ inlineCodeCell[ code_String ] ] := makeInlineCodeCell @ code;

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
    StyleBox[ formatTextString @ section, sectionStyle @ n, "InlineSection", FontSize -> .8*Inherited ],
    $tinyLineBreak
};

makeResultCell0[ inlineToolCallCell[ string_String ] ] := (
    $lastToolCallString = string;
    $lastFormattedToolCall = inlineToolCall @ string
);

makeResultCell0 // endDefinition;

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
    StringReplace[ str, { StartOfString~~"\n\n" -> "\n", "\n\n"~~EndOfString -> "\n" } ],
    $stringFormatRules,
    IgnoreCase -> True
];

formatTextString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*floatingButtonGrid*)
floatingButtonGrid // beginDefinition;

floatingButtonGrid // Attributes = { HoldFirst };
floatingButtonGrid[ attached_, string_, lang_ ] := RawBoxes @ TemplateBox[
    {
        ToBoxes @ Grid[
            {
                {
                    button[ evaluateLanguageLabel @ lang, insertCodeBelow[ string, True ]; NotebookDelete @ attached ],
                    button[ $insertInputButtonLabel, insertCodeBelow[ string, False ]; NotebookDelete @ attached ],
                    button[ $copyToClipboardButtonLabel, NotebookDelete @ attached; CopyToClipboard @ string ]
                }
            },
            Alignment -> Top,
            Spacings -> 0.2,
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

insertCodeBelow[ cell_Cell, evaluate_: False ] :=
    Module[ { cellObj, nbo },
        cellObj = topParentCell @ EvaluationCell[ ];
        nbo  = parentNotebook @ cellObj;
        SelectionMove[ cellObj, After, Cell ];
        NotebookWrite[ nbo, cell, All ];
        If[ TrueQ @ evaluate,
            SelectionEvaluateCreateCell @ nbo,
            SelectionMove[ nbo, After, CellContents ]
        ]
    ];

insertCodeBelow[ string_String, evaluate_: False ] := insertCodeBelow[ Cell[ BoxData @ string, "Input" ], evaluate ];

insertCodeBelow // endDefinition;

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

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$textDataFormatRules*)
$textDataFormatRules = {
    StringExpression[
        Longest[ "```" ~~ lang: Except[ WhitespaceCharacter ].. /; externalLanguageQ @ lang ],
        Shortest[ code__ ] ~~ ("```"|EndOfString)
    ] :> externalCodeCell[ lang, code ]
    ,
    Longest[ "```" ~~ ($wlCodeString|"") ] ~~ Shortest[ code__ ] ~~ ("```"|EndOfString) :>
        If[ nameQ[ "System`"<>code ], inlineCodeCell @ code, codeCell @ code ]
    ,
    "![" ~~ alt: Shortest[ __ ] ~~ "](" ~~ url: Shortest[ Except[ ")" ].. ] ~~ ")" /;
        StringFreeQ[ alt, "["~~___~~"]("~~__~~")" ] :>
            imageCell[ alt, url ]
    ,
    tool: ("TOOLCALL:" ~~ Shortest[ ___ ] ~~ ("ENDTOOLCALL"|EndOfString)) :> inlineToolCallCell @ tool,
    "\n" ~~ w:" "... ~~ "* " ~~ item: Longest[ Except[ "\n" ].. ] :> bulletCell[ w, item ],
    "\n" ~~ h:"#".. ~~ " " ~~ sec: Longest[ Except[ "\n" ].. ] :> sectionCell[ StringLength @ h, sec ]
    ,
    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlinkCell[ label, url ],
    "\\`" :> "`",
    "\\$" :> "$",
    "``" ~~ code__ ~~ "``" /; StringFreeQ[ code, "``" ] :> inlineCodeCell @ code,
    "`" ~~ code: Except[ WhitespaceCharacter ].. ~~ "`" /; inlineSyntaxQ @ code :> inlineCodeCell @ code,
    "`" ~~ code: Except[ "`"|"\n" ].. ~~ "`" :> inlineCodeCell @ code,
    "$$" ~~ math: Except[ "$" ].. ~~ "$$" :> mathCell @ math,
    "$" ~~ math: Except[ "$" ].. ~~ "$" :> mathCell @ math
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$stringFormatRules*)
$stringFormatRules = {
    "[" ~~ label: Except[ "[" ].. ~~ "](" ~~ url: Except[ ")" ].. ~~ ")" :> hyperlink[ label, url ],
    "***" ~~ text: Except[ "*" ].. ~~ "***" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "___" ~~ text: Except[ "_" ].. ~~ "___" :> styleBox[ text, FontWeight -> Bold, FontSlant -> Italic ],
    "**" ~~ text: Except[ "*" ].. ~~ "**" :> styleBox[ text, FontWeight -> Bold ],
    "__" ~~ text: Except[ "_" ].. ~~ "__" :> styleBox[ text, FontWeight -> Bold ],
    "*" ~~ text: Except[ "*" ].. ~~ "*" :> styleBox[ text, FontSlant -> Italic ],
    "_" ~~ text: Except[ "_" ].. ~~ "_" :> styleBox[ text, FontSlant -> Italic ]
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatted Boxes*)

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
    TaggingRules -> as
];

inlineToolCall // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseToolCallString*)
parseToolCallString // beginDefinition;

parseToolCallString[ string_String ] /; StringMatchQ[ string, "TOOLCALL:"~~__~~"{"~~___ ] :=
    Module[ { noPrefix, noSuffix, name, tool, toolData, displayName, icon, query, result },

        noPrefix    = StringDelete[ string, StartOfString~~"TOOLCALL:" ];
        noSuffix    = StringTrim @ StringDelete[ noPrefix, "ENDTOOLCALL"~~___~~EndOfString ];
        name        = StringTrim @ StringDelete[ noSuffix, ("\n"|"{")~~___~~EndOfString ];
        tool        = $defaultChatTools[ name ];
        toolData    = Replace[ tool, { HoldPattern @ LLMTool[ as_Association, ___ ] :> as, _ :> <| |> } ];
        displayName = Lookup[ toolData, "DisplayName", name ];
        icon        = Lookup[ toolData, "Icon" ];
        query       = First[ StringCases[ string, "TOOLCALL:" ~~ q___ ~~ "\nRESULT" :> q ], "" ];
        result      = First[ StringCases[ string, "RESULT\n" ~~ r___ ~~ "\nENDTOOLCALL" :> r ], "" ];

        <|
            "Name"            -> name,
            "DisplayName"     -> displayName,
            "Icon"            -> icon,
            "ToolCall"        -> StringTrim @ string,
            "Query"           -> StringTrim @ query,
            "Result"          -> StringTrim @ result
        |>
    ];

parseToolCallString[ string_String ] := <| "ToolCall" -> StringTrim @ string |>;

parseToolCallString // endDefinition;

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
    makeToolCallBoxLabel[ as, name, Lookup[ as, "Icon" ] ];

makeToolCallBoxLabel[ as_, name_String, icon_ ] /; $dynamicText := makeToolCallBoxLabel0[ as, name, icon ];

makeToolCallBoxLabel[ as_, name_String, icon_ ] :=
    OpenerView @ {
        makeToolCallBoxLabel0[ as, name, icon ],
        Column[
            {
                Framed[
                    TextCell[ as[ "Query" ], "Program", FontSize -> 0.75 * Inherited, Background -> None ],
                    Background   -> White,
                    FrameMargins -> 10,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ],
                Framed[
                    TextCell[
                        as[ "Result" ],
                        "Program",
                        FontSize -> 0.75 * Inherited,
                        Background -> None
                    ],
                    Background   -> White,
                    FrameMargins -> 10,
                    FrameStyle   -> None,
                    ImageSize    -> { Scaled[ 1 ], Automatic }
                ]
            },
            Alignment -> Left
        ]
    };

makeToolCallBoxLabel // endDefinition;


makeToolCallBoxLabel0 // beginDefinition;

makeToolCallBoxLabel0[ KeyValuePattern[ "Result" -> "" ], string_String, icon_ ] := Row @ Flatten @ {
    "Using ",
    string,
    "\[Ellipsis]",
    If[ MissingQ @ icon,
        Nothing,
        {
            Spacer[ 5 ],
            Pane[ icon, ImageSize -> { 20, 20 }, ImageSizeAction -> "ShrinkToFit" ]
        }
    ]
};

makeToolCallBoxLabel0[ as_, string_String, icon_ ] := Row @ Flatten @ {
    "Used ",
    string,
    If[ MissingQ @ icon,
        Nothing,
        {
            Spacer[ 5 ],
            Pane[ icon, ImageSize -> { 20, 20 }, ImageSizeAction -> "ShrinkToFit" ]
        }
    ]
};

makeToolCallBoxLabel0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

(* TODO: define template boxes for these *)
makeInteractiveCodeCell[ string_String ] /; $dynamicText :=
    codeBlockFrame[ Cell[ BoxData @ string, "ChatCodeActive" ], string ];

makeInteractiveCodeCell[ string_String ] :=
    Module[ { display, handler },
        display = RawBoxes @ Cell[
            BoxData @ stringToBoxes @ string,
            "ChatCode",
            "Input",
            Background -> GrayLevel[ 1 ]
        ];
        handler = inlineInteractiveCodeCell[ display, string ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, string ]
    ];

makeInteractiveCodeCell[ lang_String, code_String ] :=
    Module[ { cell, display, handler },
        cell = Cell[ code, "ExternalLanguage", FontSize -> 14, System`CellEvaluationLanguage -> lang ];
        display = RawBoxes @ Cell[
            code,
            "ExternalLanguage",
            System`CellEvaluationLanguage -> lang,
            FontSize   -> 14,
            Background -> None,
            CellFrame  -> None
        ];
        handler = inlineInteractiveCodeCell[ display, cell ];
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code, lang ]
    ];

makeInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*inlineInteractiveCodeCell*)
inlineInteractiveCodeCell // beginDefinition;

inlineInteractiveCodeCell[ display_, string_ ] /; $dynamicText := display;

inlineInteractiveCodeCell[ display_, string_String ] /; $cloudNotebooks :=
    Button[ display, CellPrint @ Cell[ BoxData @ string, "Input" ], Appearance -> None ];

inlineInteractiveCodeCell[ display_, cell_Cell ] /; $cloudNotebooks :=
    Button[ display, CellPrint @ cell, Appearance -> None ];

inlineInteractiveCodeCell[ display_, string_ ] :=
    inlineInteractiveCodeCell[ display, string, contentLanguage @ string ];

inlineInteractiveCodeCell[ display_, string_, lang_ ] :=
    DynamicModule[ { $CellContext`attached },
        EventHandler[
            display,
            {
                "MouseEntered" :> (
                    Quiet @ Needs[ "Wolfram`Chatbook`" -> None ];
                    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                        "AttachCodeButtons",
                        Dynamic[ $CellContext`attached ],
                        EvaluationCell[ ],
                        string,
                        lang
                    ]
                )
            }
        ],
        TaggingRules -> <| "CellToStringType" -> "InlineInteractiveCodeCell", "CodeLanguage" -> lang |>,
        UnsavedVariables :> { $CellContext`attached }
    ];

inlineInteractiveCodeCell // endDefinition;

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
styleBox[ { (h: Cell|StyleBox)[ text_, a___ ] }, b___ ] := DeleteDuplicates @ StyleBox[ text, a, b ];

styleBox[ { a___, b: Except[ _ButtonBox|_Cell|_String|_StyleBox ], c___ }, d___ ] :=
    styleBox[ { a, Cell @ BoxData @ b, c }, d ];

styleBox[ a_, ___ ] := a;

styleBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*image*)
image // beginDefinition;

image[ str_String ] := First @ StringSplit[ str, "![" ~~ alt__ ~~ "](" ~~ url__ ~~ ")" :> image[ alt, url ] ];

image[ alt_String, url_String ] := image[ alt, url, URLParse @ url ];

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
attachmentBoxes[ alt_, key_String, expr_ ] := markdownImageBoxes[ alt, "attachment://" <> key, expr ];
attachmentBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*markdownImageBoxes*)
markdownImageBoxes // beginDefinition;

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
importedImage[ alt_String, url_String ] := importedImage[ alt, url ] = importedImage[ alt, url, Quiet @ Import[ url, "Image" ] ];
importedImage[ alt_String, url_String, _? FailureQ | _String ] := importedImage[ alt, url, $missingImage ];
importedImage[ alt_String, url_String, i_ ] := Cell @ BoxData @ markdownImageBoxes[ alt, url, tooltip[ i, alt ] ];
importedImage // endDefinition;

$missingImage = RawBoxes @ TemplateBox[ { }, "ImageNotFound" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*tooltip*)
tooltip // beginDefinition;
tooltip[ expr_, ""|"result" ] := expr;
tooltip[ expr_, text_ ] := Tooltip[ expr, text ];
tooltip // endDefinition;

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

hyperlink[ label_String, uri_String ] /; StringStartsQ[ uri, "paclet:" ] :=
    Cell @ BoxData @ TemplateBox[ { StringTrim[ label, (Whitespace|"`"|"\\").. ], uri }, "TextRefLink" ];

hyperlink[ label_String, url_String ] := hyperlink[ formatTextString @ label, url ];

hyperlink[ { label: _String|_StyleBox }, url_ ] := ButtonBox[
    label,
    BaseStyle  -> "Hyperlink",
    ButtonData -> { URL @ url, None },
    ButtonNote -> url
];

hyperlink[ a_, ___ ] := a;

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
(*unescapeInlineMarkdown*)
unescapeInlineMarkdown // beginDefinition;
unescapeInlineMarkdown[ str_String ] := StringReplace[ str, { "\\`" -> "`", "\\$" -> "$" } ];
unescapeInlineMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;
stringToBoxes[ s_String ] /; $dynamicText := s;
stringToBoxes[ s_String ] := removeExtraBoxSpaces @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket @ s;
stringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*removeExtraBoxSpaces*)
removeExtraBoxSpaces // beginDefinition;
removeExtraBoxSpaces[ row: RowBox @ { "(*", ___, "*)" } ] := row;
removeExtraBoxSpaces[ RowBox[ items_List ] ] := RowBox[ removeExtraBoxSpaces /@ DeleteCases[ items, " " ] ];
removeExtraBoxSpaces[ other_ ] := other;
removeExtraBoxSpaces // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
If[ Wolfram`Chatbook`Internal`$BuildingMX,
    $copyToClipboardButtonLabel;
    $insertInputButtonLabel;
    $insertEvaluateButtonLabel;
    $languageIcons;
];

End[ ];
EndPackage[ ];
