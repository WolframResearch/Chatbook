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
(*makeCodeBlockCell*)
makeCodeBlockCell // beginDefinition;
makeCodeBlockCell[ _, code_String ] /; StringMatchQ[ StringTrim @ code, "!["~~__~~"]("~~__~~")" ] := image @ code;
makeCodeBlockCell[ language_String, code_String ] /; $useStaticCodeBlockCache && ! TrueQ @ $dynamicText :=
    cachedCodeBlockCell[ language, code ];
makeCodeBlockCell[ language_String, code_String ] /; plaintextLanguageQ @ language :=
    makeInteractiveCodeCell[ "Plaintext", unescapePlainTextCodeBlock @ stripCodePadding @ code ];
makeCodeBlockCell[ language_String, code_String ] := makeInteractiveCodeCell[ language, stripCodePadding @ code ];
makeCodeBlockCell // endDefinition;

unescapePlainTextCodeBlock // beginDefinition;
unescapePlainTextCodeBlock[ string_String ] := StringReplace[ string, "\\\\" -> "\\" ];
unescapePlainTextCodeBlock // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*cachedCodeBlockCell*)
cachedCodeBlockCell // beginDefinition;

(* Code blocks are formatted when they're written as static content during streaming, and again when the final cell is
   written. The non-dynamic formatting (which includes a front end round trip for Wolfram Language code) gives the same
   result both times, so it's cached for the current response. The key includes the globals that formatting uses: *)
cachedCodeBlockCell[ language_String, code_String ] :=
    With[ { key = { language, code, $SidebarChat, $WorkspaceChat, $InlineChat, $cloudNotebooks } },
        Lookup[
            $staticCodeBlockCache,
            Key @ key,
            $staticCodeBlockCache[ key ] =
                Block[ { $useStaticCodeBlockCache = False }, makeCodeBlockCell[ language, code ] ]
        ]
    ];

cachedCodeBlockCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*stripCodePadding*)
stripCodePadding // beginDefinition;

stripCodePadding[ code_String ] :=
    Catch @ Module[ { padding, split },
        padding = First[ StringCases[ code, StartOfString~~Whitespace, 1 ], Throw @ code ];
        split = StringSplit[ code, "\n" ];
        If[ AllTrue[ split, StringMatchQ[ #, WhitespaceCharacter... ] || StringStartsQ[ #, padding ] & ],
            StringDelete[ code, StartOfLine~~padding ],
            code
        ]
    ];

stripCodePadding // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeInteractiveCodeCell*)
makeInteractiveCodeCell // beginDefinition;

(* TODO: define template boxes for these *)
makeInteractiveCodeCell[ language_, code_String ] /; $dynamicText :=
    If[ TrueQ @ wolframLanguageQ @ language,
        codeBlockFrame[ Cell[ BoxData @ wlStringToBoxes @ code, "ChatCodeActive" ], code, language ],
        codeBlockFrame[ Cell[ code, "ChatPreformatted" ], code, language ]
    ];

(* Wolfram Language code blocks *)
makeInteractiveCodeCell[ lang_String? wolframLanguageQ, code0_ ] := Enclose[
    Catch @ Module[ { code, display, handler },
        code = ConfirmMatch[ parseCellGroupBlock @ code0, _Cell | _? boxDataQ, "Code" ];
        If[ MatchQ[ code, _Cell ], Throw @ code ];
        display = RawBoxes @ Cell[
            BoxData @ If[ StringQ @ code, wlStringToBoxes @ code, code ],
            "ChatCode",
            "Input",
            LanguageCategory     -> "Input",
            ShowAutoStyles       -> True,
            ShowStringCharacters -> True,
            ShowSyntaxStyles     -> True,
            TranslationOptions   -> {
                "Enabled" -> Dynamic @ AbsoluteCurrentValue[ $FrontEnd, { TranslationOptions, "Enabled" } ]
            }
        ];
        handler = inlineInteractiveCodeCell[ display, code ];
        codeBlockFrame[ ToBoxes @ handler, code ]
    ],
    throwInternalFailure
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
        codeBlockFrame[ Cell @ BoxData @ ToBoxes @ handler, code, lang ] (* TODO: unclear if we need Cell[BoxData[...]] for non-Wolfram code *)
    ];

(* Code blocks for any other languages *)
makeInteractiveCodeCell[ language_String, code_String ] :=
    codeBlockFrame[
        Cell[
            code,
            "ChatPreformatted",
            TaggingRules -> <| "CellToStringType" -> "InlineCodeCell", "CodeLanguage" -> language |>
        ],
        code,
        language
    ];

makeInteractiveCodeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*parseCellGroupBlock*)
parseCellGroupBlock // beginDefinition;

parseCellGroupBlock[ code_String ] := Enclose[
    Catch @ Module[ { sl, split, trimmed, rows },

        sl = StartOfLine ~~ # &;

        split = StringSplit[
            code,
            {
                l: sl @ $$inLabel         :> label[ "Input"     , StringTrim @ l ],
                l: sl @ $$outLabel        :> label[ "Output"    , StringTrim @ l ],
                l: sl @ $$echoLabel       :> label[ "Echo"      , StringTrim @ l ],
                l: sl @ $$echoTimingLabel :> label[ "EchoTiming", StringTrim @ l ],
                l: sl @ $$messageLabel    :> label[ "Message"   , StringTrim @ l ],
                l: sl @ $$printLabel      :> label[ "Print"     , StringTrim @ l ]
            }
        ];

        trimmed = DeleteCases[ Replace[ split, s_String :> StringTrim @ s, { 1 } ], "" ];

        (* No labels: *)
        Replace[ trimmed, { _ } :> Throw @ code ];

        rows = Replace[
            SequenceReplace[
                trimmed,
                { label[ style_, l_ ], s_String } :> makeLabeledBlockCell[ s, style, l ]
            ],
            s_String :> { "", makeInteractiveCodeCell[ "Plaintext", s ] },
            { 1 }
        ];

        Cell[
            BoxData @ GridBox[
                rows,
                GridBoxAlignment -> { "Columns" -> { Right, Left }, "Rows" -> { { Baseline } } }(*,
                GridBoxItemSize -> { "Columns" -> { 4, Automatic }, "Rows" -> { { Automatic } } }*)
            ],
            "CellGroupBlock"
        ]
    ],
    throwInternalFailure
];

parseCellGroupBlock[ boxes_ ] := boxes;

parseCellGroupBlock // endDefinition;


$$equals          = ":=" | "=";
$$inLabel         = "In" ~~ "[" ~~ Except["]"] ... ~~ "]" ~~ $$equals;
$$outLabel        = "Out" ~~ "[" ~~ Except["]"] ... ~~ "]" ~~ $$equals;
$$echoLabel       = ">>";
$$echoTimingLabel = "\[WatchIcon]";
$$messageLabel    = Except[ WhitespaceCharacter ].. ~~ "::" ~~ (LetterCharacter|DigitCharacter) .. ~~ ":";
$$printLabel      = "During evaluation of " ~~ $$inLabel;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeLabeledBlockCell*)
makeLabeledBlockCell // beginDefinition;

makeLabeledBlockCell[ text_String, "Message", label_String ] :=
    makeBlockMessage[ StringSplit[ StringTrim[ label, ":" ], "::" ], text ];

makeLabeledBlockCell[ code_, style_, label_ ] := {
    makeBlockLabel[ label, style ],
    makeLabeledBlockCell0[ code, style ]
};

makeLabeledBlockCell // endDefinition;


makeLabeledBlockCell0 // beginDefinition;

makeLabeledBlockCell0[ code_String, "Input" ] :=
    makeInteractiveCodeCell[ "Wolfram", code ];

makeLabeledBlockCell0[ code_String, style_String ] :=
    Cell[ BoxData @ StringToBoxes[ code, "WL" ], style ];

makeLabeledBlockCell0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeBlockMessage*)
makeBlockMessage // beginDefinition;

makeBlockMessage[ { sym_String, tag_String }, text_String ] :=
    { "", TemplateBox[ { sym, tag, text, 2, 0, 0, 0, "Local" }, "MessageTemplate", BaseStyle -> "MSG" ] };

makeBlockMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*makeBlockLabel*)
makeBlockLabel // beginDefinition;

makeBlockLabel[ label_String, "Input"  ] := StyleBox[ label, "CellLabelExpired" ];
makeBlockLabel[ label_String, "Output" ] := StyleBox[ label, "CellLabelExpired" ];
makeBlockLabel[ label_, "EchoTiming" ] := StyleBox[ "\[WatchIcon]", "EchoDingbat" ];
makeBlockLabel[ label_, "Print" ] := "";

makeBlockLabel[ label_String, "Echo" ] := StyleBox[
    StringReplace[ label, { ">>" -> "\[RightGuillemet]", "<<" -> "\[LeftGuillemet]" } ],
    "EchoDingbat"
];

makeBlockLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*wolframLanguageQ*)
wolframLanguageQ // ClearAll;
wolframLanguageQ[ language_String ] := StringMatchQ[ StringTrim @ language, $wlCodeString, IgnoreCase -> True ];
wolframLanguageQ[ ___ ] := False;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*codeBlockFrame*)
codeBlockFrame // beginDefinition;

codeBlockFrame[ cell_, string_ ] := codeBlockFrame[ cell, string, "Wolfram" ];

codeBlockFrame[ cell_, string_, lang_ ] := Cell[
    BoxData @ templateBox[ { cell, lang }, If[ $SidebarChat, "NotebookAssistant`Sidebar`ChatCodeBlockTemplate", "ChatCodeBlockTemplate" ] ],
    "ChatCodeBlock"
];

codeBlockFrame // endDefinition;

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
$languageIcons := $languageIcons = AssociationMap[
    chatbookExpression[ "ExternalLanguageIcon" <> StringDelete[ #, "-" ] ] &,
    $externalLanguages
];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
