(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Color Names*)
VerificationTest[
    (* The repository, not the paclet being tested: a built paclet has no Developer directory, which has the
       stylesheet and front end resource sources. *)
    $repositoryDir = ParentDirectory @ DirectoryName @ $TestFileName;
    $colorNameCounts = Counts @ Flatten @ Map[
        StringCases[ ReadString @ #, "color" ~~ WhitespaceCharacter... ~~ ("@" | "[") ~~ WhitespaceCharacter... ~~ "\"" ~~ name: Except[ "\"" ].. ~~ "\"" :> name ] &,
        Select[ FileNames[ "*.wl", FileNameJoin @ { $repositoryDir, # } & /@ { "Source", "Developer" }, Infinity ], FileNameTake @ # =!= "ColorData.wl" & ]
    ];
    $usedColorNames = Keys @ $colorNameCounts,
    { __String },
    SameTest -> MatchQ,
    TestID   -> "UsedColorNames"
]

(* Every name used in the sources and resource definitions is defined: *)
VerificationTest[
    Select[ $usedColorNames, ! MatchQ[ Wolfram`Chatbook`Common`color @ #, _LightDarkSwitched ] & ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UsedColorNamesDefined"
]

(* The palette stays minimal: every defined color is used in more than one place (single uses are written as literals): *)
VerificationTest[
    Select[ Keys @ Wolfram`Chatbook`ColorData`Private`$colorData, Lookup[ $colorNameCounts, #, 0 ] < 2 & ],
    { },
    SameTest -> MatchQ,
    TestID   -> "DefinedColorNamesUsedMoreThanOnce"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dynamic Content*)

(* Colors inside dynamic content are resolved before the front end sees them, so it never calls the kernel for them
   (the front end calls made while building the display aren't relevant here, so their messages are suppressed): *)
VerificationTest[
    FreeQ[
        Quiet @ Wolfram`Chatbook`ChatModes`NotebookFocus`Private`focusedNotebookDisplay0 @ CellObject[ 0 ],
        Wolfram`Chatbook`Common`color
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplayResolvedColors"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Hover States*)

(* In dark mode, hovering over an inline reference chip lightens it, the same as in light mode: *)
VerificationTest[
    Module[ { lightness, dark, light, colorOf, static, chosen, states },
        lightness[ c_ ] := First @ ColorConvert[ c, "LAB" ];
        dark[ LightDarkSwitched[ _, d_ ] ] := d;
        light[ LightDarkSwitched[ l_, _ ] ] := l;
        colorOf[ expr_, opt_ ] := FirstCase[ expr, ( opt -> c_LightDarkSwitched ) :> c, None, Infinity ];
        (* static chips switch backgrounds with Mouseover[ default, hover ] *)
        static = Cases[
            Quiet @ {
                Wolfram`Chatbook`InlineReferences`Private`staticModifierBox[ { "x" } ],
                Wolfram`Chatbook`InlineReferences`Private`staticPersonaBox[ "Wolfie" ]
            },
            Mouseover[ d_, h_ ] :> { colorOf[ d, Background ], colorOf[ h, Background ] },
            Infinity
        ];
        (* chosen chips switch backgrounds and frames with PaneSelector[ { "Default" -> _, "Hover" -> _, "Down" -> _ } ] *)
        chosen = Flatten[
            Cases[
                Quiet @ {
                    Wolfram`Chatbook`Common`personaTemplateBoxes[ 1, "Wolfie", "Chosen", "u" ],
                    Wolfram`Chatbook`Common`modifierTemplateBoxes[ 1, "x", { }, "Chosen", "u" ],
                    Wolfram`Chatbook`Common`functionTemplateBoxes[ 1, "x", { }, "Chosen", "u" ],
                    Wolfram`Chatbook`Common`wlTemplateBoxes[ 1, "x", "Chosen", "u" ]
                },
                PaneSelector[ { "Default" -> d_, "Hover" -> h_, ___ }, ___ ] :>
                    { { colorOf[ d, Background ], colorOf[ h, Background ] }, { colorOf[ d, FrameStyle ], colorOf[ h, FrameStyle ] } },
                Infinity
            ],
            1
        ];
        states = Join[ static, chosen ];
        {
            Length @ static,
            Length @ chosen,
            (* when hover is lighter than the default in light mode, it is lighter in dark mode too *)
            Select[ states, lightness[ light @ #[[ 2 ]] ] > lightness[ light @ #[[ 1 ]] ] && lightness[ dark @ #[[ 2 ]] ] <= lightness[ dark @ #[[ 1 ]] ] & ]
        }
    ],
    { 2, 8, { } },
    SameTest -> MatchQ,
    TestID   -> "InlineReferenceHoverLighterInDarkMode"
]
