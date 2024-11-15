(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`TeXBoxes`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Rules*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$preprocessTeXRules*)
(* Applied before TeX formatting: *)
$preprocessTeXRules = {
    (* Remove commas from large numbers: *)
    n: (Repeated[ DigitCharacter, { 3 } ] ~~ ("," ~~ Repeated[ DigitCharacter, { 3 } ])..) :> StringDelete[ n, "," ],
    (* Add missing brackets to superscripts: *)
    "^\\text{" ~~ s: LetterCharacter.. ~~ "}" :> "^{\\text{"<>s<>"}}",
    (* Format superscript text: *)
    n: DigitCharacter ~~ "^{" ~~ s: "st"|"nd"|"rd"|"th" ~~ "}" :> n<>"^{\\text{"<>s<>"}}"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*$extraTeXRules*)
(* Only applied if TeX formatting fails: *)
$extraTeXRules = {
    Shortest[ "\\text{" ~~ text___ ~~ "}" ] :> escapeTextMathSymbols @ text
};

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*$$texMathSymbol*)
(* cSpell: disable *)
$$texMathSymbol = Alternatives[
    "\\aleph",
    "\\alpha",
    "\\Alpha",
    "\\amalg",
    "\\angle",
    "\\approx",
    "\\arccos",
    "\\arccot",
    "\\arccsc",
    "\\arcsec",
    "\\arcsin",
    "\\arctan",
    "\\ast",
    "\\asymp",
    "\\beta",
    "\\Beta",
    "\\beth",
    "\\bigcirc",
    "\\bigtriangledown",
    "\\bigtriangleup",
    "\\bot",
    "\\bowtie",
    "\\Box",
    "\\bullet",
    "\\C",
    "\\cap",
    "\\cdot",
    "\\chi",
    "\\Chi",
    "\\circ",
    "\\cong",
    "\\cos",
    "\\cosh",
    "\\cot",
    "\\coth",
    "\\csc",
    "\\cup",
    "\\dagger",
    "\\dashv",
    "\\ddagger",
    "\\delta",
    "\\Delta",
    "\\diamond",
    "\\digamma",
    "\\Digamma",
    "\\div",
    "\\doteq",
    "\\downarrow",
    "\\Downarrow",
    "\\ell",
    "\\emptyset ",
    "\\epsilon",
    "\\Epsilon ",
    "\\equiv",
    "\\eta",
    "\\Eta",
    "\\eth",
    "\\exists",
    "\\exists!",
    "\\forall",
    "\\frown",
    "\\gamma",
    "\\Gamma",
    "\\geq",
    "\\geqslant",
    "\\gets",
    "\\gg",
    "\\ggg",
    "\\gimel",
    "\\gnapprox",
    "\\gneq",
    "\\gneqq",
    "\\gnsim",
    "\\gvertneqq",
    "\\hbar",
    "\\iff",
    "\\imath",
    "\\implies",
    "\\in",
    "\\infty",
    "\\iota",
    "\\Iota",
    "\\jmath",
    "\\kappa",
    "\\Kappa ",
    "\\lambda",
    "\\Lambda",
    "\\land",
    "\\langle",
    "\\lceil",
    "\\leftarrow",
    "\\Leftarrow",
    "\\Leftrightarrow",
    "\\leq",
    "\\leqslant",
    "\\lfloor",
    "\\ll",
    "\\llcorner",
    "\\lll",
    "\\lnapprox",
    "\\lneq",
    "\\lneqq",
    "\\lnsim",
    "\\longleftarrow",
    "\\Longleftarrow",
    "\\longmapsto",
    "\\longrightarrow",
    "\\Longrightarrow",
    "\\lor",
    "\\lrcorner",
    "\\lvertneqq",
    "\\mapsto",
    "\\measuredangle",
    "\\mid",
    "\\models",
    "\\mp",
    "\\mu",
    "\\Mu",
    "\\N",
    "\\nabla",
    "\\ncong",
    "\\ne",
    "\\neg",
    "\\neq",
    "\\nexists",
    "\\ngeq",
    "\\ngeqq",
    "\\ngeqslant",
    "\\ngtr",
    "\\ni",
    "\\nleq",
    "\\nleqq",
    "\\nleqslant",
    "\\nless",
    "\\nmid",
    "\\notin",
    "\\not\\perp",
    "\\not\\subset",
    "\\not\\supset",
    "\\nparallel",
    "\\nprec",
    "\\npreceq",
    "\\nshortmid",
    "\\nshortparallel",
    "\\nsim",
    "\\nsubseteq",
    "\\nsubseteqq",
    "\\nsucc",
    "\\nsucceq",
    "\\nsupseteq",
    "\\nsupseteqq",
    "\\ntriangleleft",
    "\\ntrianglelefteq",
    "\\ntriangleright",
    "\\ntrianglerighteq",
    "\\nu",
    "\\Nu",
    "\\nvdash",
    "\\nvDash",
    "\\nVdash",
    "\\nVDash",
    "\\odot",
    "\\omega",
    "\\Omega",
    "\\omicron",
    "\\Omicron",
    "\\ominus",
    "\\oplus",
    "\\oslash",
    "\\otimes",
    "\\parallel",
    "\\partial",
    "\\perp",
    "\\phi",
    "\\Phi ",
    "\\pi",
    "\\Pi ",
    "\\pm",
    "\\prec",
    "\\preceq",
    "\\precnapprox",
    "\\precneqq",
    "\\precnsim",
    "\\propto",
    "\\psi",
    "\\Psi",
    "\\Q",
    "\\R",
    "\\rangle",
    "\\rceil",
    "\\rfloor",
    "\\rho",
    "\\Rho ",
    "\\rightarrow",
    "\\Rightarrow",
    "\\sec",
    "\\sigma",
    "\\Sigma ",
    "\\sim",
    "\\simeq",
    "\\sin",
    "\\sinh",
    "\\smile",
    "\\sqcap",
    "\\sqcup",
    "\\sqsubset",
    "\\sqsubseteq",
    "\\sqsupset",
    "\\sqsupseteq",
    "\\square",
    "\\star",
    "\\subset",
    "\\subseteq",
    "\\subsetneq",
    "\\subsetneqq",
    "\\succ",
    "\\succeq",
    "\\succnapprox",
    "\\succneqq",
    "\\succnsim",
    "\\supset",
    "\\supseteq",
    "\\supsetneq",
    "\\supsetneqq",
    "\\tan",
    "\\tanh",
    "\\tau",
    "\\Tau",
    "\\theta",
    "\\Theta ",
    "\\times",
    "\\to",
    "\\top",
    "\\triangle",
    "\\triangleleft",
    "\\triangleright",
    "\\ulcorner",
    "\\uparrow",
    "\\Uparrow",
    "\\updownarrow",
    "\\Updownarrow",
    "\\uplus",
    "\\upsilon",
    "\\Upsilon",
    "\\urcorner",
    "\\varepsilon",
    "\\varkappa",
    "\\varphi",
    "\\varpi",
    "\\varrho",
    "\\varsigma",
    "\\varsubsetneq",
    "\\varsubsetneqq",
    "\\varsupsetneq",
    "\\varsupsetneqq",
    "\\vartheta",
    "\\vdash",
    "\\vee",
    "\\wedge",
    "\\wp",
    "\\wr",
    "\\xi",
    "\\Xi",
    "\\Z",
    "\\zeta",
    "\\Zeta",
    "\\mathbb{" ~~ LetterCharacter.. ~~ "}",
    "\\overline{" ~~ Except[ "}" ].. ~~ "}"
];
(* cSpell: enable *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*escapeTextMathSymbols*)
escapeTextMathSymbols // beginDefinition;

escapeTextMathSymbols[ text_String ] := StringJoin[
    "\\text{",
    StringReplace[
        text,
        {
            escaped: Shortest[ "$" ~~ Except[ "$" ].. ~~ "$" ] :> escaped,
            symbol: $$texMathSymbol :> "$"<>symbol<>"$"
        }
    ],
    "}"
];

escapeTextMathSymbols // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeTeXBoxes*)
makeTeXBoxes // beginDefinition;

makeTeXBoxes[ input0_String ] := Enclose[
    makeTeXBoxes[ input0 ] =
        Catch @ Module[ { input, tex, retry, new },
            input = ConfirmBy[ preprocessTeXString @ input0, StringQ, "Input" ];
            tex = ConfirmMatch[ Quiet @ InputAssistant`TeXAssistant @ input, _RawBoxes, "TeX" ];
            If[ validTeXQ @ tex, Throw @ tex ];
            retry = ConfirmBy[ applyExtraTeXRules @ input, StringQ, "Retry" ];
            new = Quiet @ InputAssistant`TeXAssistant @ retry;
            If[ TrueQ @ validTeXQ @ new, new, tex ]
        ],
    throwInternalFailure
];

makeTeXBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*preprocessTeXString*)
preprocessTeXString // beginDefinition;

preprocessTeXString[ tex_String ] := FixedPoint[
    StringReplace @ $preprocessTeXRules,
    texUTF8Convert @ StringTrim @ tex,
    3
];

preprocessTeXString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*texUTF8Convert*)
texUTF8Convert // beginDefinition;

texUTF8Convert[ string_String ] := Enclose[
    Catch @ Module[ { chars, texChars, rules },
        chars    = Select[ Union @ Characters @ string, Max @ ToCharacterCode[ # ] > 255 & ];
        texChars = ConfirmMatch[ texUTF8Convert0 /@ chars, { ___String }, "Characters" ];
        rules    = DeleteCases[ Thread[ chars -> texChars ], _ -> "" ];
        texUTF8Convert[ string ] = ConfirmBy[ StringReplace[ string, rules ], StringQ, "Converted" ]
    ],
    throwInternalFailure
];

texUTF8Convert // endDefinition;


texUTF8Convert0 // beginDefinition;

texUTF8Convert0[ c_String ] := texUTF8Convert0[ c ] = StringReplace[
    StringTrim @ Replace[ Quiet @ ExportString[ c, "TeXFragment" ], Except[ _String ] :> "" ],
    {
        StartOfString ~~ "\\[" ~~ tex: ("\\" ~~ WordCharacter..) ~~ "\\]" ~~ EndOfString :> tex,
        StartOfString ~~ __ ~~ EndOfString :> ""
    }
];

texUTF8Convert0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*validTeXQ*)
validTeXQ // beginDefinition;
validTeXQ[ RawBoxes[ tex_ ] ] := validTeXQ0 @ tex;
validTeXQ[ _ ] := False;
validTeXQ // endDefinition;

validTeXQ0 // beginDefinition;
validTeXQ0[ TemplateBox[ as_, "TeXAssistantTemplate", ___ ] ] := validTeXQ0 @ as;
validTeXQ0[ KeyValuePattern[ "state" -> "Error" ] ] := False;
validTeXQ0[ KeyValuePattern[ { } ] ] := True;
validTeXQ0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*applyExtraTeXRules*)
applyExtraTeXRules // beginDefinition;
applyExtraTeXRules[ tex_String ] := FixedPoint[ StringReplace @ $extraTeXRules, StringTrim @ tex, 3 ];
applyExtraTeXRules // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
