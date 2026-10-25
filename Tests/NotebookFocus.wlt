(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/NotebookFocus.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/NotebookFocus.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $testFE      = FrontEndObject @ LinkObject[ "ChatbookNotebookFocusTests", 1, 1 ];
    $chatNB      = NotebookObject[ $testFE, 1 ]; (* the notebook assistant window *)
    $userNB1     = NotebookObject[ $testFE, 2 ];
    $userNB2     = NotebookObject[ $testFE, 3 ];
    $paletteNB   = NotebookObject[ $testFE, 4 ];
    $hiddenNB    = NotebookObject[ $testFE, 5 ];
    $excludedNB  = NotebookObject[ $testFE, 6 ];
    $closedNB    = NotebookObject[ $testFE, 7 ];
    $sidebarCell = CellObject[ $testFE, 8 ];

    testNotebookInfo[ nbo_, title_, settings_: <| |>, visible_: True, windowFrame_: "Normal" ] := <|
        "NotebookObject"       -> nbo,
        "ChatNotebookSettings" -> settings,
        "Visible"              -> visible,
        "WindowFrame"          -> windowFrame,
        "WindowTitle"          -> title
    |>;

    (* Information for all open notebooks, front-most first: *)
    $defaultNotebooks = {
        testNotebookInfo[ $chatNB    , "Notebook Assistant", <| "WorkspaceChat" -> True |> ],
        testNotebookInfo[ $userNB1   , "Notebook A.nb" ],
        testNotebookInfo[ $paletteNB , "Palette", <| |>, True, "Palette" ],
        testNotebookInfo[ $hiddenNB  , "Hidden", <| |>, False ],
        testNotebookInfo[ $excludedNB, "Excluded.nb", <| "ExcludeFromChat" -> True |> ],
        testNotebookInfo[ $userNB2   , "Notebook B.nb" ]
    };

    notebookInformationStub[ All ] := ($scanCount++; $notebooks);
    notebookInformationStub[ { nbo_NotebookObject } ] := {
        SelectFirst[ $notebooks, #[ "NotebookObject" ] === nbo &, Missing[ "NotebookClosed", nbo ] ]
    };

    currentValueStub[ _NotebookObject, ExpressionUUID ] := "test-uuid";
    currentValueStub[ nbo_, { TaggingRules, "FocusWindowTitle" } ] := Lookup[ $focusWindowTitles, nbo, Inherited ];

    (* Evaluates eval with the front end calls used by focusedNotebookDisplay replaced by stubs: *)
    withFocusStubs // Attributes = { HoldFirst };
    withFocusStubs[ eval_, notebooks_: $defaultNotebooks, focusedNotebook_: Inherited, titles_: <| |> ] := Block[
        {
            $notebooks          = notebooks,
            $focusWindowTitles  = titles,
            $scanCount          = 0,
            $writes             = { },
            CurrentValue        = currentValueStub,
            CurrentChatSettings = Function[
                Switch[ #2,
                    "FocusedNotebook"      , focusedNotebook,
                    "AllowSelectionContext", True,
                    _                      , Inherited
                ]
            ],
            Wolfram`Chatbook`Common`notebookInformation = notebookInformationStub,
            Wolfram`Chatbook`Common`setCurrentValue     = Function[
                AppendTo[ $writes, { ## } ];
                If[ #2 === { TaggingRules, "FocusWindowTitle" }, $focusWindowTitles[ #1 ] = #3 ];
                #3
            ]
        },
        eval
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/NotebookFocus.wlt:25,1-91,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*includedNotebookQ*)

(* includedNotebookQ must agree with the "Included" value from SourceNotebookObjectInformation: *)
VerificationTest[
    withFocusStubs @ {
        Wolfram`Chatbook`ChatModes`Common`includedNotebookQ /@ $defaultNotebooks[[ All, "NotebookObject" ]],
        Lookup[
            Association[ #NotebookObject -> #Included & /@ SourceNotebookObjectInformation[ ] ],
            $defaultNotebooks[[ All, "NotebookObject" ]],
            False
        ]
    },
    { { False, True, False, False, False, True }, { False, True, False, False, False, True } },
    SameTest -> MatchQ,
    TestID   -> "IncludedNotebookQ-MatchesSourceNotebookObjectInformation@@Tests/NotebookFocus.wlt:98,1-110,2"
]

(* Same check through the real notebookInformation code, with only the front end primitives stubbed: *)
VerificationTest[
    Module[ { notebooks, settings, acv },
        notebooks = $defaultNotebooks[[ All, "NotebookObject" ]];
        settings  = <|
            $chatNB     -> <| "WorkspaceChat" -> True |>,
            $excludedNB -> { "ExcludeFromChat" -> True },
            $userNB2    -> <| "Model" -> "TestModel" |>
        |>;
        acv[ nbos_List, spec_ ] := acv[ #, spec ] & /@ nbos;
        acv[ nbo_NotebookObject, Visible ] := nbo =!= $hiddenNB;
        acv[ nbo_NotebookObject, WindowFrame ] := If[ nbo === $paletteNB, "Palette", "Normal" ];
        acv[ nbo_NotebookObject, { TaggingRules, "ChatNotebookSettings" } ] := Lookup[ settings, nbo, Inherited ];
        acv[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] := { "Model" -> "DefaultModel" };
        Block[
            {
                Notebooks            = notebooks &,
                NotebookInformation  = { "WindowTitle" -> "Title", "ModifiedInMemory" -> False } &,
                AbsoluteCurrentValue = acv,
                SelectedNotebook     = $userNB1 &,
                InputNotebook        = $userNB1 &
            },
            {
                Wolfram`Chatbook`ChatModes`Common`includedNotebookQ /@ notebooks,
                Lookup[ Association[ #NotebookObject -> #Included & /@ SourceNotebookObjectInformation[ ] ], notebooks, False ]
            }
        ]
    ],
    { { False, True, False, False, False, True }, { False, True, False, False, False, True } },
    SameTest -> MatchQ,
    TestID   -> "IncludedNotebookQ-MatchesSourceNotebookObjectInformation-FrontEndStubs@@Tests/NotebookFocus.wlt:113,1-143,2"
]

VerificationTest[
    withFocusStubs @ Wolfram`Chatbook`ChatModes`Common`includedNotebookQ @ $closedNB,
    False,
    SameTest -> MatchQ,
    TestID   -> "IncludedNotebookQ-ClosedNotebook@@Tests/NotebookFocus.wlt:145,1-150,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*setFocusWindowTitle*)
VerificationTest[
    withFocusStubs[
        Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, "Notebook A.nb" ];
        $writes,
        $defaultNotebooks,
        Inherited,
        <| $chatNB -> "Notebook A.nb" |>
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "SetFocusWindowTitle-Unchanged@@Tests/NotebookFocus.wlt:155,1-166,2"
]

VerificationTest[
    withFocusStubs[
        Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, "Notebook B.nb" ];
        $writes,
        $defaultNotebooks,
        Inherited,
        <| $chatNB -> "Notebook A.nb" |>
    ],
    { { $chatNB, { TaggingRules, "FocusWindowTitle" }, "Notebook B.nb" } },
    SameTest -> MatchQ,
    TestID   -> "SetFocusWindowTitle-Changed@@Tests/NotebookFocus.wlt:168,1-179,2"
]

VerificationTest[
    withFocusStubs[ Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, None ]; $writes ],
    { { $chatNB, { TaggingRules, "FocusWindowTitle" }, None } },
    SameTest -> MatchQ,
    TestID   -> "SetFocusWindowTitle-Unset@@Tests/NotebookFocus.wlt:181,1-186,2"
]

(* The current title is only read inside Refresh[ ..., None ], so the focus indicator's Dynamic doesn't depend on it: *)
VerificationTest[
    withFocusStubs[
        Module[ { reads = { }, untracked = False },
            Block[
                {
                    Refresh      = Function[ Null, If[ #2 === None, Block[ { untracked = True }, #1 ], #1 ], HoldAll ],
                    CurrentValue = Function[ AppendTo[ reads, { #2, untracked } ]; currentValueStub[ ## ] ]
                },
                Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, "Notebook A.nb" ];
                Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, "Notebook B.nb" ]
            ];
            { reads, $writes[[ All, 3 ]] }
        ],
        $defaultNotebooks,
        Inherited,
        <| $chatNB -> "Notebook A.nb" |>
    ],
    {
        { { { TaggingRules, "FocusWindowTitle" }, True }, { { TaggingRules, "FocusWindowTitle" }, True } },
        { "Notebook B.nb" }
    },
    SameTest -> MatchQ,
    TestID   -> "SetFocusWindowTitle-UntrackedRead@@Tests/NotebookFocus.wlt:189,1-212,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*focusedNotebookDisplay*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook Assistant Window*)

(* Repeated updates only write the window title of the focused notebook when it changes: *)
VerificationTest[
    withFocusStubs @ Module[ { results },
        results = Table[ Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ], 3 ];
        { Head /@ results, $writes, $scanCount }
    ],
    {
        { Pane, Pane, Pane },
        { { $chatNB, { TaggingRules, "FocusWindowTitle" }, "Notebook A.nb" } },
        3
    },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TitleWrittenOnce@@Tests/NotebookFocus.wlt:223,1-235,2"
]

(* Switching notebooks updates the title: *)
VerificationTest[
    withFocusStubs[
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
        $notebooks = $defaultNotebooks[[ { 1, 6, 2, 3, 4, 5 } ]];
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
        $writes[[ All, 3 ]],
        $defaultNotebooks,
        Inherited,
        <| $chatNB -> "Notebook A.nb" |>
    ],
    { "Notebook B.nb" },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TitleChanged@@Tests/NotebookFocus.wlt:238,1-252,2"
]

(* A notebook selected in the focus menu takes precedence over the current notebook: *)
VerificationTest[
    withFocusStubs[
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
        $writes[[ All, 3 ]],
        $defaultNotebooks,
        $userNB2,
        <| $chatNB -> "Notebook A.nb" |>
    ],
    { "Notebook B.nb" },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-LockedNotebook@@Tests/NotebookFocus.wlt:255,1-267,2"
]

VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ], $writes },
        { First @ $defaultNotebooks }
    ],
    { Spacer[ 0 ], { } },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-NoNotebooks@@Tests/NotebookFocus.wlt:269,1-277,2"
]

(* The Dynamic in the attached input cell only tracks its notebook variable in the kernel: *)
VerificationTest[
    Cases[
        Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell /@ { "Top", "Bottom" },
        DynamicBox[
            ToBoxes[ Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ nbo_Symbol, None ], StandardForm ],
            TrackedSymbols :> { nbo_Symbol }
        ] :> True,
        Infinity
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TrackedSymbols@@Tests/NotebookFocus.wlt:280,1-292,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Sidebar*)

(* The sidebar does not scan all notebooks when its own notebook is included: *)
VerificationTest[
    withFocusStubs @ {
        Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $userNB1, $sidebarCell ],
        $scanCount,
        $writes
    },
    { Pane[ _DynamicModule, Alignment -> { Center, Baseline }, ImageSize -> Scaled[ 1 ] ], 0, { } },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-NoNotebookScan@@Tests/NotebookFocus.wlt:299,1-308,2"
]

(* Skipping the scan gives the same display as the full scan: *)
VerificationTest[
    withFocusStubs @ Module[ { fast, full },
        fast = Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $userNB1, $sidebarCell ];
        full = Block[ { Wolfram`Chatbook`ChatModes`Common`includedNotebookQ = False & },
            Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $userNB1, $sidebarCell ]
        ];
        { fast === full, $scanCount, $writes }
    ],
    { True, 1, { } },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-SameDisplay@@Tests/NotebookFocus.wlt:311,1-322,2"
]

(* If the sidebar's own notebook is excluded, the display still depends on whether any other notebook is included: *)
VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $excludedNB, $sidebarCell ], $scanCount },
        $defaultNotebooks
    ],
    { Pane[ _DynamicModule, Alignment -> { Center, Baseline }, ImageSize -> Scaled[ 1 ] ], 1 },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-OwnNotebookExcluded@@Tests/NotebookFocus.wlt:325,1-333,2"
]

VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $excludedNB, $sidebarCell ], $scanCount },
        $defaultNotebooks[[ { 1, 3, 4, 5 } ]]
    ],
    { Spacer[ 0 ], 1 },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-NoIncludedNotebooks@@Tests/NotebookFocus.wlt:335,1-343,2"
]

(* :!CodeAnalysis::EndBlock:: *)
