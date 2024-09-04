(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`Tools`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"        ];
Needs[ "Wolfram`Chatbook`Common`" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Specification*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icon*)
$wolframAlphaIcon = RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "FEBitmaps", "InsertionAlpha" ];

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Description*)
$wolframAlphaDescription = "\
Use natural language queries with Wolfram|Alpha to get up-to-date computational results about entities in chemistry, \
physics, geography, history, art, astronomy, and more.";

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Spec*)
$defaultChatTools0[ "WolframAlpha" ] = <|
    toolDefaultData[ "WolframAlpha" ],
    "ShortName"          -> "wa",
    "Icon"               -> $wolframAlphaIcon,
    "Description"        -> $wolframAlphaDescription,
    "DisplayName"        -> "Wolfram|Alpha",
    "Enabled"            :> ! TrueQ @ $AutomaticAssistance,
    "FormattingFunction" -> wolframAlphaResultFormatter,
    "Function"           -> getWolframAlphaText,
    "Origin"             -> "BuiltIn",
    "Parameters"         -> {
        "query" -> <|
            "Interpreter" -> "String",
            "Help"        -> "the input",
            "Required"    -> True
        |>,
        "steps" -> <|
            "Interpreter" -> "Boolean",
            "Help"        -> "whether to show step-by-step solution",
            "Required"    -> False
        |>(*,
        "assumption" -> <|
            "Interpreter" -> "String",
            "Help"        -> "the assumption to use, passed back from a previous query with the same input.",
            "Required"    -> False
        |>*)
    }
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$defaultPods           := toolOptionValue[ "WolframAlpha", "DefaultPods"     ];
$foldPods              := toolOptionValue[ "WolframAlpha", "FoldPods"        ];
$maximumWAPodByteCount := toolOptionValue[ "WolframAlpha", "MaxPodByteCount" ];

$moreDetailsPlusIcon  = RawBoxes @ TemplateBox[ { RGBColor[ "#678e9c" ] }, "DiscardedMaterialOpenerIcon" ];
$moreDetailsMinusIcon = RawBoxes @ TemplateBox[ { RGBColor[ "#678e9c" ] }, "DiscardedMaterialCloserIcon" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Wolfram Alpha Results*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*getWolframAlphaText*)
getWolframAlphaText // beginDefinition;

getWolframAlphaText[ as_Association ] :=
    getWolframAlphaText[ as[ "query" ], as[ "steps" ] ];

getWolframAlphaText[ query_String, steps: True|False|_Missing ] :=
    Module[ { result, data, string },
        result = wolframAlpha[ query, steps ];
        data = WolframAlpha[
            query,
            { All, { "Title", "Plaintext", "ComputableData", "Content" } },
            PodStates -> { If[ TrueQ @ steps, "Step-by-step solution", Nothing ] }
        ];
        string = getWolframAlphaText[ query, steps, data ];
        getWolframAlphaText[ query, steps ] = <| "Result" -> result, "String" -> string |>
    ];

getWolframAlphaText[ query_String, steps_, { } ] :=
    "No results returned";

(* cSpell: ignore deflatten *)
getWolframAlphaText[ query_String, steps_, info_List ] :=
    getWolframAlphaText[ query, steps, associationKeyDeflatten[ makeKeySequenceRule /@ info ] ];

getWolframAlphaText[ query_String, steps_, as_Association? AssociationQ ] :=
    getWolframAlphaText[ query, steps, waResultText @ as ];

getWolframAlphaText[ query_String, steps_, result_String ] :=
    result;

getWolframAlphaText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframAlpha*)
wolframAlpha // beginDefinition;
wolframAlpha[ args___ ] /; $defaultPods := defaultPods @ args;
wolframAlpha[ args___ ] := fasterWolframAlphaPods @ args;
wolframAlpha // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*defaultPods*)
defaultPods // beginDefinition;
defaultPods[ args___ ] := defaultPods[ args ] = WolframAlpha @ args;
defaultPods // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*fasterWolframAlphaPods*)
fasterWolframAlphaPods // beginDefinition;

fasterWolframAlphaPods[ query_String, steps: True|False|_Missing ] := Enclose[
    Catch @ Module[ { titlesAndCells, grouped },
        titlesAndCells = Confirm[
            WolframAlpha[
                query,
                { All, { "Title", "Cell" } },
                PodStates -> { If[ TrueQ @ steps, "Step-by-step solution", Nothing ] }
            ],
            "WolframAlpha"
        ];
        If[ titlesAndCells === { }, Throw @ Missing[ "NoResults" ] ];
        grouped = DeleteCases[ SortBy[ #1, podOrder ] & /@ GroupBy[ titlesAndCells, podKey ], CellSize -> _, Infinity ];
        fasterWolframAlphaPods[ query, steps ] = <| "Query" -> query, "Pods" -> grouped |>
    ],
    throwInternalFailure
];

fasterWolframAlphaPods // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*podOrder*)
podOrder // beginDefinition;
podOrder[ key_ -> _ ] := podOrder @ key;
podOrder[ { { _String, idx_Integer }, _String } ] := idx;
podOrder // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*podKey*)
podKey // beginDefinition;
podKey[ key_ -> _ ] := podKey @ key;
podKey[ { { key_String, _Integer }, _String } ] := key;
podKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*waResultText*)
waResultText // beginDefinition;
waResultText[ as_ ] := Block[ { $level = 1 }, StringRiffle[ Flatten @ Values[ waResultText0 /@ as ], "\n" ] ];
waResultText // endDefinition;


waResultText0 // beginDefinition;

waResultText0[ as: KeyValuePattern @ { "Title" -> title_String, "Data" -> data_ } ] :=
    StringRepeat[ "#", $level ] <> " " <> title <> "\n" <> waResultText0 @ data;

waResultText0[ as: KeyValuePattern[ _Integer -> _ ] ] :=
    waResultText0 /@ Values @ KeySort @ KeySelect[ as, IntegerQ ];

waResultText0[ as: KeyValuePattern @ { "Content"|"ComputableData" -> expr_ } ] /;
    ! FreeQ[ Unevaluated @ expr, _Missing ] :=
        Replace[ Lookup[ as, "Plaintext" ], Except[ _String ] :> Nothing ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> Hold[ expr_ ] } ] :=
    If[ ByteCount @ Unevaluated @ expr >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ expr ] <> "\n",
            escapeMarkdownString @ text <> "\n" <> makeExpressionURI[ Unevaluated @ expr ] <> "\n"
        ],
        escapeMarkdownString @ text <> "\n"
    ];

waResultText0[ as: KeyValuePattern @ { "Plaintext" -> text_String, "ComputableData" -> expr: Except[ _Hold ] } ] :=
    waResultText0 @ Append[ as, "ComputableData" -> Hold @ expr ];

waResultText0[ KeyValuePattern @ { "Plaintext" -> text_String, "Content" -> content_ } ] :=
    If[ ByteCount @ content >= 500,
        If[ StringFreeQ[ text, "["|"]"|"\n" ],
            makeExpressionURI[ text, Unevaluated @ content ] <> "\n",
            escapeMarkdownString @ text <> "\n" <> makeExpressionURI[ Unevaluated @ content ] <> "\n"
        ],
        escapeMarkdownString @ text <> "\n"
    ];

waResultText0[ as_Association ] /; Length @ as === 1 :=
    waResultText0 @ First @ as;

waResultText0[ as_Association ] :=
    KeyValueMap[
        Function[
            StringJoin[
                StringRepeat[ "#", $level ],
                " ",
                ToString[ #1 ],
                "\n",
                Block[ { $level = $level + 1 }, waResultText0[ #2 ] ]
            ]
        ],
        as
    ];

waResultText0[ expr_ ] :=
    With[ { s = ToString[ Unevaluated @ expr, InputForm ] },
        escapeMarkdownString @ s <> "\n" /; StringLength @ s <= 100
    ];

waResultText0[ expr_ ] :=
    makeExpressionURI @ Unevaluated @ expr <> "\n";

waResultText0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Formatting*)
FormatWolframAlphaPods = formatWolframAlphaPods;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*wolframAlphaResultFormatter*)
wolframAlphaResultFormatter // beginDefinition;

wolframAlphaResultFormatter[ query_String, "Parameters", "query" ] :=
    clickToCopy @ query;

wolframAlphaResultFormatter[ KeyValuePattern[ "Result" -> result_ ], "Result" ] :=
    wolframAlphaResultFormatter[ result, "Result" ];

wolframAlphaResultFormatter[ result_, "Result" ] :=
    formatWolframAlphaPods @ result;

wolframAlphaResultFormatter[ expr_, ___ ] :=
    expr;

wolframAlphaResultFormatter // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatWolframAlphaPods*)
formatWolframAlphaPods // beginDefinition;

formatWolframAlphaPods[ expr: _Missing|_Failure|$Failed ] :=
    expr;

formatWolframAlphaPods[ info_Association ] :=
    formatWolframAlphaPods[ info[ "Query" ], info[ "Pods" ], $dynamicText ];

formatWolframAlphaPods[ query_, grouped_Association, dynamic_ ] := Enclose[
    Module[ { formatted, framed  },
        formatted = ConfirmBy[ formatPods[ query, grouped ], ListQ, "Formatted" ];

        framed = Framed[
            Column[ formatted, Alignment -> Left, Spacings -> { { }, { { 1 }, -2 -> 0.5, -1 -> 0 } } ],
            Background     -> GrayLevel[ 1 ],
            FrameMargins   -> 0,
            FrameStyle     -> GrayLevel[ 1 ],
            RoundingRadius -> 0,
            TaggingRules   -> <| "WolframAlphaPods" -> True |>
        ];

        Verbatim[ formatWolframAlphaPods[ query, grouped, dynamic ] ] = framed
    ],
    throwInternalFailure
];

formatWolframAlphaPods // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*formatPods*)
formatPods // beginDefinition;
formatPods[ args__ ] := Block[ { $foldPods = toolOptionValue[ "WolframAlpha", "FoldPods" ] }, formatPods0 @ args ];
formatPods // endDefinition;

formatPods0 // beginDefinition;

formatPods0[ query_, as: KeyValuePattern @ { "Input" -> input_, "Result" -> result_ } ] /; $foldPods := Enclose[
    Module[ { rest },
        rest = Values @ KeyDrop[ as, { "Input", "Result" } ];
        Flatten @ {
            formatPod @ input,
            formatPod @ result,
            If[ rest === { },
                Nothing,
                podMoreDetailsOpener[
                    query,
                    Column[
                        formatPod /@ rest,
                        Alignment -> Left,
                        Spacings -> { { }, 1 }
                    ]
                ]
            ]
        }
    ],
    throwInternalFailure
];

formatPods0[ query_, as_Association ] /; $foldPods && Length @ as > 3 := Enclose[
    Module[ { show, hide },
        { show, hide } = ConfirmMatch[ TakeDrop[ as, 3 ], { _Association, _Association }, "TakeDrop" ];
        Flatten @ {
            formatPod /@ Values @ show,
            podMoreDetailsOpener[
                query,
                Column[
                    formatPod /@ Values @ hide,
                    Alignment -> Left,
                    Spacings -> { { }, 1 }
                ]
            ]
        }
    ],
    throwInternalFailure
];

formatPods0[ query_, grouped_Association ] :=
    Append[ Map[ formatPod, Values @ grouped ], waFooterMenu @ query ];

formatPods0 // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPod*)
formatPod // beginDefinition;

formatPod[ content_List ] := Framed[
    Column[ formatPodItem /@ content, Alignment -> Left ],
    Background     -> White,
    FrameMargins   -> 5,
    FrameStyle     -> GrayLevel[ 0.8 ],
    ImageSize      -> { Scaled[ 1 ], Automatic },
    ImageMargins   -> If[ $CloudEvaluation, { { 0, 25 }, { 0, 0 } }, 0 ],
    RoundingRadius -> 3
];

formatPod // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*formatPodItem*)
formatPodItem // beginDefinition;

formatPodItem[ key_ -> value_ ] :=
    formatPodItem[ key, value ];

formatPodItem[ { _, "Title" }, title_String ] :=
    Style[ StringTrim[ title, ":" ] <> ":", "Text", FontColor -> RGBColor[ "#678e9c" ], FontSize -> 12 ];

formatPodItem[ { _, "Cell" }, cell_ ] /; ByteCount @ cell > $maximumWAPodByteCount :=
    Pane[
        If[ TrueQ @ $dynamicText,
            $statelessProgressIndicator,
            compressUntilViewed[ cell, True ]
        ],
        ImageMargins -> { { 10, 0 }, { 0, 0 } }
    ];

formatPodItem[ { _, "Cell" }, cell_ ] :=
    Pane[ cell, ImageMargins -> { { 10, 0 }, { 0, 0 } } ];

formatPodItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*podMoreDetailsOpener*)
podMoreDetailsOpener // beginDefinition;
podMoreDetailsOpener // Attributes = { HoldAll };

podMoreDetailsOpener[ query_, hidden_ ] /; $dynamicText := "";

podMoreDetailsOpener[ query_, hidden_ ] :=
    DynamicModule[ { expand = False, menu },
        menu = waFooterMenu @ query;
        PaneSelector[
            {
                False -> Grid[
                    { { podShowMoreDetailsButton @ Dynamic @ expand, Item[ "", ItemSize -> Fit ], menu } },
                    Alignment -> { { Left, Right }, Baseline }
                ],
                True -> Column[
                    Flatten @ {
                        Grid[
                            { { podHideMoreDetailsButton @ Dynamic @ expand, Item[ "", ItemSize -> Fit ] } },
                            Alignment -> { { Left, Right }, Baseline }
                        ],
                        compressUntilViewed[ hidden, True ],
                        menu
                    },
                    Alignment -> Left
                ]
            },
            Dynamic @ expand,
            ImageSize -> Automatic
        ]
    ];

podMoreDetailsOpener // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*podShowMoreDetailsButton*)
podShowMoreDetailsButton // beginDefinition;

podShowMoreDetailsButton[ Dynamic[ expand_ ] ] := Button[
    MouseAppearance[
        Framed[
            Style[
                Row @ { $moreDetailsPlusIcon, " Show more details" },
                "Text",
                FontColor -> RGBColor[ "#678e9c" ],
                FontSize  -> 12
            ],
            FrameMargins   -> { { 6, 6 }, { 2, 2 } },
            FrameStyle     -> RGBColor[ "#678e9c" ],
            RoundingRadius -> 3
        ],
        "LinkHand"
    ],
    expand = True,
    Appearance   -> "Suppressed",
    ImageMargins -> { { 0, 0 }, { 0, 10 } }
];

podShowMoreDetailsButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*podHideMoreDetailsButton*)
podHideMoreDetailsButton // beginDefinition;

podHideMoreDetailsButton[ Dynamic[ expand_ ] ] := Button[
    MouseAppearance[
        Framed[
            Style[
                Row @ { $moreDetailsMinusIcon, " Hide more details" },
                "Text",
                FontColor -> RGBColor[ "#678e9c" ],
                FontSize  -> 12
            ],
            FrameMargins   -> { { 6, 6 }, { 2, 2 } },
            FrameStyle     -> RGBColor[ "#678e9c" ],
            RoundingRadius -> 3
        ],
        "LinkHand"
    ],
    expand = False,
    Appearance -> "Suppressed",
    ImageMargins -> { { 0, 0 }, { 10, 10 } }
];

podHideMoreDetailsButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Links Menu*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*waFooterMenu*)
waFooterMenu // beginDefinition;

(* cSpell: ignore Localizable *)
waFooterMenu[ query_String ] := Item[
    Style[
        DynamicModule[ { display },
            display = Button[
                Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "FEBitmaps", "CirclePlusIconScalable" ],
                Null,
                Appearance -> None
            ];
            Grid[
                {
                    {
                        Hyperlink[
                            Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "WALocalizableBitmaps", "WolframAlpha" ],
                            "https://www.wolframalpha.com",
                            Alignment -> Left
                        ],
                        Pane[
                            Dynamic @ display,
                            FrameMargins -> { { 0, If[ $CloudEvaluation, 23, 3 ] }, { 0, 0 } }
                        ]
                    }
                },
                Spacings -> 0.5
            ],
            SynchronousInitialization -> False,
            Initialization :>
                If[ ! MatchQ[ display, _Tooltip ],
                    Needs[ "Wolfram`Chatbook`" -> None ];
                    display = Replace[ makeWebLinksMenu @ query, Except[ _Tooltip ] :> "" ]
                ]
        ],
        "WolframAlphaLinksMenu"
    ],
    Alignment -> Right
];

waFooterMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeWebLinksMenu*)
makeWebLinksMenu // beginDefinition;

makeWebLinksMenu[ query_String ] /; $dynamicText :=
    Nothing;

makeWebLinksMenu[ query_String ] := Enclose[
    Module[ { sources, url, actions },

        sources = ConfirmMatch[ getWASources @ query, KeyValuePattern @ { } ];

        (* cSpell: ignore wolframalpha *)
        url = URLBuild @ <|
            "Scheme" -> "https",
            "Domain" -> "www.wolframalpha.com",
            "Path"   -> { "", "input" },
            "Query"  -> { "i" -> query }
        |>;

        actions = With[ { u = url },
            Flatten @ {
                "Web version" :> NotebookLocate @ { URL @ u, None },
                If[ sources === { },
                    Nothing,
                    {
                        Delimiter,
                        KeyValueMap[
                            Row @ { "Source information: " <> #1 } :> NotebookLocate @ { URL[ #2 ], None } &,
                            Association @ sources
                        ]
                    }
                ]
            }
        ];

        makeWebLinksMenu @ actions
    ],
    "" &
];

makeWebLinksMenu[ actions: { (_RuleDelayed|Delimiter).. } ] := Tooltip[
    ActionMenu[
        Dynamic @ RawBoxes @ FEPrivate`FrontEndResource[ "FEBitmaps", "CirclePlusIconScalable" ],
        actions,
        Appearance -> None
    ],
    tr[ "DefaultToolsLinks" ]
];

makeWebLinksMenu[ ___ ] := "";

makeWebLinksMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*getWASources*)
getWASources // beginDefinition;
getWASources[ query_String ] := getWASources[ query, WolframAlpha[ query, "Sources" ] ];
getWASources[ query_String, sources: KeyValuePattern @ { } ] := getWASources[ query ] = sources;
getWASources[ query_String, _ ] := $Failed;
getWASources // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Misc Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeKeySequenceRule*)
makeKeySequenceRule // beginDefinition;
makeKeySequenceRule[ { _, "Cell"|"Position"|"Scanner" } -> _ ] := Nothing;
makeKeySequenceRule[ key_ -> value_ ] := makeKeySequence @ key -> value;
makeKeySequenceRule // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeKeySequence*)
makeKeySequence // beginDefinition;

makeKeySequence[ { { path_String, n_Integer }, key_String } ] :=
    makeKeySequence @ Flatten @ { Reverse @ StringSplit[ path, ":" ], n, key };

makeKeySequence[ { path__String, 0, key_String } ] :=
    { path, key };

makeKeySequence[ { path__String, n_Integer, key_String } ] :=
    { path, "Data", n, key };

makeKeySequence // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
