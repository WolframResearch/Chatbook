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
(*wlStringToBoxes*)
wlStringToBoxes // beginDefinition;

wlStringToBoxes[ string_String ] /; $dynamicText := formatSpecialBoxes @ string;

wlStringToBoxes[ string_String ] :=
    string // RightComposition[
        preprocessSandboxString,
        autoCorrectWLCodeBlock,
        stringToBoxes,
        inlineExpressionURIs,
        formatSpecialBoxes
    ];

wlStringToBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*autoCorrectWLCodeBlock*)
autoCorrectWLCodeBlock // beginDefinition;

autoCorrectWLCodeBlock[ code_String ] := Lookup[
    $correctedCodeCache,
    code,
    Enclose[
        Module[ { checked, corrected },
            checked = ConfirmBy[
                LogChatTiming @ CodeCheckFix[ code, "Target" -> "Assistant" ],
                AssociationQ,
                "CodeCheckFix"
            ];
            corrected = ConfirmBy[ autoCorrectWLCodeBlock @ checked, StringQ, "Result" ];
            addToCache[ $correctedCodeCache, $maxCorrectedCodeCacheSize, code, corrected ]
        ],
        throwInternalFailure
    ]
];

autoCorrectWLCodeBlock[ KeyValuePattern @ { "OriginalCode" -> code_String, "FixedCode" -> _Missing } ] := code;
autoCorrectWLCodeBlock[ KeyValuePattern[ "FixedCode" -> fixed_String ] ] := fixed;

autoCorrectWLCodeBlock // endDefinition;

$correctedCodeCache        = <| |>;
$maxCorrectedCodeCacheSize = 500;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatSpecialBoxes*)
formatSpecialBoxes // beginDefinition;

formatSpecialBoxes[ string_String ] :=
    StringReplace[
        string,
        {
            "\[FreeformPrompt][\"" ~~ q: Except[ "]" ].. ~~ ("]"|EndOfString) :>
                ToString[ RawBoxes @ formatNLInputFast @ q, StandardForm ],
            "ResourceFunction[\"" ~~ name: Except[ "\"" ].. ~~ ("\"]"|EndOfString) :>
                ToString[ RawBoxes @ formatResourceFunctionFast @ name, StandardForm ],
            ps: ("PacletSymbol[" ~~ Except[ "]" ].. ~~ ("]"|EndOfString)) :>
                ToString[ RawBoxes @ formatPacletSymbol @ ps, StandardForm ],
            "Placeholder[\"" ~~ p: (("\\\""|Except[ "\"" ])..) ~~ ("\"]"|EndOfString) :>
                ToString[ RawBoxes @ formatPlaceholderFast @ p, StandardForm ]
        }
    ];

formatSpecialBoxes[ boxes_ ] :=
    boxes /. {
        RowBox @ { "\[FreeformPrompt]", "[", q_String? quotedStringQ, "]" } :>
            RuleCondition @ If[ TrueQ[ $dynamicText || $useFastNLInputFormatting ],
                                formatNLInputFast @ q,
                                formatNLInputSlow @ q
                            ]
        ,
        RowBox @ { "\[FreeformPrompt]", "[", RowBox @ { q_String? quotedStringQ, ",", _ }, "]" } :>
            RuleCondition @ If[ TrueQ[ $dynamicText || $useFastNLInputFormatting ],
                                formatNLInputFast @ q,
                                formatNLInputSlow @ q
                            ]
        ,
        RowBox @ { "\[FreeformPrompt]", "[", q_String } /; StringMatchQ[ q, "\""~~Except[ "\""]..~~("\""|"") ] :>
            RuleCondition @ formatNLInputFast @ q
        ,
        RowBox @ { "ResourceFunction", "[", name_String? quotedStringQ, "]" } :>
            RuleCondition @ If[ TrueQ @ $dynamicText,
                                formatResourceFunctionFast @ name,
                                formatResourceFunctionSlow @ name
                            ]
        ,
        box: RowBox @ { "PacletSymbol", "[", ___, "]" } :>
            RuleCondition @ formatPacletSymbol @ box
        ,
        box: RowBox @ { "DateObject", "[", ___, "]" } :>
            RuleCondition @ formatDateObjectBoxes @ box
        ,
        box: RowBox @ { $$colorConstructor, "[", ___, "]" } :>
            With[ { swatch = Quiet @ ToExpression[ box, StandardForm, MakeBoxes ] },
                swatch /; MatchQ[ swatch, _TemplateBox ]
            ]
        ,
        RowBox @ { "Placeholder", "[", label: Except[ RowBox @ { ___, ",", ___ } ], "]" } :>
            RuleCondition @ formatPlaceholderBoxes @ label
        ,
        box: RowBox @ { h: "Entity"|"EntityClass"|"EntityProperty", "[", a_, "]" } :>
            With[ { b = formatEntityBoxes @ RowBox @ { h, "[", formatSpecialBoxes @ a, "]" } },
                  b /; b =!= box
            ]
    };

formatSpecialBoxes // endDefinition;

(* Color constructors that render as interactive color pickers in notebooks: *)
$$colorConstructor = Alternatives[
    "CMYKColor",
    "GrayLevel",
    "Hue",
    "LABColor",
    "LCHColor",
    "LightDarkSwitched",
    "LUVColor",
    "RGBColor",
    "ThemeColor",
    "XYZColor"
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*quotedStringQ*)
quotedStringQ // beginDefinition;
quotedStringQ[ q_String ] := StringMatchQ[ q, "\""~~Except[ "\""]..~~"\"" ];
quotedStringQ[ ___ ] := False;
quotedStringQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPacletSymbol*)
formatPacletSymbol // beginDefinition;

formatPacletSymbol[ ps_String ] /; StringEndsQ[ ps, "]" ] :=
    With[ { held = Quiet @ ToExpression[ ps, InputForm, HoldComplete ] },
        If[ MatchQ[ held, HoldComplete @ PacletSymbol[ _String, _String ] ],
            formatPacletSymbol @ held,
            ps
        ]
    ];

formatPacletSymbol[ ps_String ] :=
    If[ StringContainsQ[ ps, "," ],
        formatPacletSymbol[ ps <> "]" ],
        ps
    ];

formatPacletSymbol[ box_RowBox ] :=
    With[ { held = Quiet @ ToExpression[ box, StandardForm, HoldComplete ] },
        If[ MatchQ[ held, HoldComplete @ PacletSymbol[ _String, _String ] ],
            formatPacletSymbol @ held,
            box
        ]
    ];

formatPacletSymbol[ HoldComplete @ PacletSymbol[ paclet_String, symbol_String ] ] :=
    formatPacletSymbol[ paclet, symbol ];

formatPacletSymbol[ paclet_String, symbol_String ] :=
    If[ StringContainsQ[ paclet, "/" ],
        (* Only use paclet repository formatting for publisher/name style paclets: *)
        $pacletRepositoryPacletSymbolBoxes[ paclet, symbol ],
        MakeBoxes @ PacletSymbol[ paclet, symbol ]
    ];

formatPacletSymbol // endDefinition;

(* TODO: This has a temporary fallback mechanism until PacletResource is updated. *)
$pacletRepositoryPacletSymbolBoxes := $pacletRepositoryPacletSymbolBoxes = (
    Needs[ "PacletResource`" -> None ];
    If[ ToExpression[ "PacletResource`PacletRepositoryPacletSymbolBoxes", InputForm, DownValues ] === { },
        With[ { s = Symbol[ "PacletResource`Private`fancyPacletSymbolBoxes" ] },
            s[ HoldComplete[ #1 ], #1, #2 ] &
        ],
        Symbol[ "PacletResource`PacletRepositoryPacletSymbolBoxes" ]
    ]
);

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatEntityBoxes*)
formatEntityBoxes // beginDefinition;

formatEntityBoxes[ boxes_RowBox ] := Lookup[
    $entityBoxesCache,
    boxes,
    Quiet @ Module[ { new },
        new = Quiet @ ToExpression[ boxes, StandardForm, MakeBoxes ];
        addToCache[
            $entityBoxesCache,
            $maxEntityBoxesCacheSize,
            boxes,
            If[ MatchQ[ new, _TemplateBox ], new, boxes ]
        ]
    ]
];

formatEntityBoxes // endDefinition;

$entityBoxesCache        = <| |>;
$maxEntityBoxesCacheSize = 500;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatDateObjectBoxes*)
formatDateObjectBoxes // beginDefinition;

formatDateObjectBoxes[ boxes_RowBox ] :=
    Quiet @ Module[ { held, date },
        held = ToExpression[ boxes, StandardForm, HoldComplete ];
        If[ MatchQ[ held, _[ $$possibleDateObject ] ],
            date = Quiet @ ReleaseHold @ held;
            If[ DateObjectQ @ date,
                ToBoxes @ date,
                boxes
            ],
            boxes
        ]
    ];

formatDateObjectBoxes // endDefinition;


$$possibleDateObject = HoldPattern @ DateObject[
    { (_Real|_Integer).. },
    ___String,
    (_Real|_Integer)...,
    OptionsPattern[ ]
];

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPlaceholderBoxes*)

(* Wraps the already-parsed label boxes directly instead of going through MakeBoxes, since parsing the label with
   ToExpression could create symbols and typeset them with unwanted context qualifications: *)
formatPlaceholderBoxes // beginDefinition;
formatPlaceholderBoxes[ label_ ] := TagBox[ FrameBox @ label, "Placeholder" ];
formatPlaceholderBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPlaceholderFast*)
formatPlaceholderFast // beginDefinition;
formatPlaceholderFast[ p_String ] := formatPlaceholderBoxes[ "\"" <> p <> "\"" ];
formatPlaceholderFast // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatResourceFunctionFast*)
formatResourceFunctionFast // beginDefinition;

formatResourceFunctionFast[ name_String ] := (
    Needs[ "FunctionResource`" -> None ];
    FunctionResource`InertResourceFunctionBoxes[ "Published", StringTrim[ name, "\"" ] ]
);

formatResourceFunctionFast // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatResourceFunctionSlow*)
formatResourceFunctionSlow // beginDefinition;

formatResourceFunctionSlow[ name_String ] := (
    Needs[ "FunctionResource`" -> None ];
    FunctionResource`MakeResourceFunctionBoxes @ StringTrim[ name, "\"" ]
);

formatResourceFunctionSlow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNLInputFast*)
formatNLInputFast // beginDefinition;

formatNLInputFast[ q_String ] := OverlayBox[
    {
        FrameBox[
            StyleBox[ q, ShowStringCharacters -> False, FontWeight -> Plain ],
            BaseStyle      -> { "CalculateInput", LineBreakWithin -> False },
            FrameStyle     -> color @ "NA_ChatOutputFreeFormFrame",
            RoundingRadius -> 3,
            ImageMargins   -> { { 5, 0 }, { 0, 0 } },
            FrameMargins   -> { { 6, 3 }, { 3, 3 } },
            StripOnInput   -> False
        ],
        Append[ $freeformPromptBox, Background -> color @ "NA_ChatOutputFreeFormBackground" ]
    },
    Alignment -> { Left, Baseline }
];

formatNLInputFast // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatNLInputSlow*)
formatNLInputSlow // beginDefinition;

formatNLInputSlow[ query_String ] :=
    With[
        {
            h = If[ StringMatchQ[ query, "\""~~__~~"\"" ],
                    ToExpression[ query, InputForm, HoldComplete ],
                    query
                ]
        },
        Lookup[
            $freeformBoxesCache,
            query,
            addToCache[
                $freeformBoxesCache,
                $maxFreeformBoxesCacheSize,
                query,
                ReplaceAll[
                    ToBoxes @ WolframAlpha[ ReleaseHold @ h, "LinguisticAssistant" ],
                    as: KeyValuePattern[ "open" -> { 1, 2 } ] :> RuleCondition @ <| as, "open" -> { 1 } |>
                ]
            ]
        ] /; MatchQ[ h, HoldComplete[ _String ] ]
    ];

formatNLInputSlow // endDefinition;

$freeformBoxesCache        = <| |>;
$maxFreeformBoxesCacheSize = 100;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*stringToBoxes*)
stringToBoxes // beginDefinition;

stringToBoxes[ s_String ] /; $dynamicText := StringReplace[
    s,
    "InlinedExpression[\"" ~~ LetterCharacter.. ~~ "://" ~~ (LetterCharacter|DigitCharacter|"-").. ~~ "\"]" :>
        $expressionURIPlaceholder
];

stringToBoxes[ s_String /; StringMatchQ[ s, "\"" ~~ __ ~~ "\"" ] ] :=
    With[ { str = stringToBoxes @ StringTrim[ s, "\"" ] }, "\""<>str<>"\"" /; StringQ @ str ];

stringToBoxes[ s_String ] :=
    adjustBoxSpacing @ stringToBoxes0 @ reparseBoxStructurePacket @ s;

stringToBoxes // endDefinition;


stringToBoxes0 // beginDefinition;
stringToBoxes0[ boxes_? boxDataQ ] := boxes;
stringToBoxes0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reparseBoxStructurePacket*)
reparseBoxStructurePacket // beginDefinition;

reparseBoxStructurePacket[ string_String ] := Replace[
    usingFrontEnd @ MathLink`CallFrontEnd @ FrontEnd`ReparseBoxStructurePacket @ StyleBox[
        string,
        ShowStringCharacters -> True
    ],
    StyleBox[ boxes_, ___ ] :> boxes
];

reparseBoxStructurePacket // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boxDataQ*)
boxDataQ // beginDefinition;
boxDataQ[ _String? StringQ ] := True;
boxDataQ[ boxes_List ] := AllTrue[ boxes, boxDataQ ];
boxDataQ[ (_? boxSymbolQ)[ ___ ] ] := True;
boxDataQ[ _ ] := False;
boxDataQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*boxSymbolQ*)
boxSymbolQ // beginDefinition;
boxSymbolQ[ RowBox ] := True;
boxSymbolQ[ s_Symbol ] := boxSymbolQ[ s ] = Context @ s === "System`" && StringEndsQ[ SymbolName @ s, "Box" ];
boxSymbolQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*adjustBoxSpacing*)
adjustBoxSpacing // beginDefinition;
adjustBoxSpacing[ row: RowBox @ { "(*", ___, "*)" } ] := row;
adjustBoxSpacing[ "\n" ] := "\[IndentingNewLine]";
adjustBoxSpacing[ s_String ] /; $CloudEvaluation := Lookup[ $autoOperatorRenderings, s, s ];
adjustBoxSpacing[ RowBox[ items_List ] ] := RowBox[ adjustBoxSpacing /@ adjustSequenceSpacing @ items ];
adjustBoxSpacing[ box_ ] := box;
adjustBoxSpacing // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*adjustSequenceSpacing*)
adjustSequenceSpacing // beginDefinition;

adjustSequenceSpacing[ items_List ] := SequenceReplace[
    items,
    {
        { $space, op: $infixOperators, $space  } :> op,
        { $space, op: $infixOperators } :> op,
        { op: $infixOperators, $space } :> op,
        { ",", $space } -> ","
    }
];

adjustSequenceSpacing // endDefinition;

$space = " "|"  "|"   ";
$infixOperators = "+"|"-"|"*"|"/"|"^"|"&&"|"||"|"=="|"==="|"!="|"=!="|"<"|"<="|">"|">="|"->"|":>"|"="|":=";

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
