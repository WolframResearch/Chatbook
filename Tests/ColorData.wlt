(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ColorData.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ColorData.wlt:11,1-16,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Color Names*)
VerificationTest[
    $pacletDir = PacletObject[ "Wolfram/Chatbook" ][ "Location" ];
    $colorNameCounts = Counts @ Flatten @ Map[
        StringCases[ ReadString @ #, "color" ~~ WhitespaceCharacter... ~~ ("@" | "[") ~~ WhitespaceCharacter... ~~ "\"" ~~ name: Except[ "\"" ].. ~~ "\"" :> name ] &,
        Select[ FileNames[ "*.wl", FileNameJoin @ { $pacletDir, # } & /@ { "Source", "Developer" }, Infinity ], FileNameTake @ # =!= "ColorData.wl" & ]
    ];
    $usedColorNames = Keys @ $colorNameCounts,
    { __String },
    SameTest -> MatchQ,
    TestID   -> "UsedColorNames@@Tests/ColorData.wlt:21,1-31,2"
]

(* Every name used in the sources and resource definitions is defined: *)
VerificationTest[
    Select[ $usedColorNames, ! MatchQ[ Wolfram`Chatbook`Common`color @ #, _LightDarkSwitched ] & ],
    { },
    SameTest -> MatchQ,
    TestID   -> "UsedColorNamesDefined@@Tests/ColorData.wlt:34,1-39,2"
]

(* The palette stays minimal: every defined color is used in more than one place (single uses are written as literals): *)
VerificationTest[
    Select[ Keys @ Wolfram`Chatbook`ColorData`Private`$colorData, Lookup[ $colorNameCounts, #, 0 ] < 2 & ],
    { },
    SameTest -> MatchQ,
    TestID   -> "DefinedColorNamesUsedMoreThanOnce@@Tests/ColorData.wlt:42,1-47,2"
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
    TestID   -> "FocusedNotebookDisplayResolvedColors@@Tests/ColorData.wlt:55,1-63,2"
]
