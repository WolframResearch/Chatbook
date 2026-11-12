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
    notebookInformationStub[ nbo_NotebookObject ] := (
        $notebookInfoCount++;
        SelectFirst[ $notebooks, #[ "NotebookObject" ] === nbo &, Missing[ "NotebookClosed", nbo ] ]
    );
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
            $notebookInfoCount  = 0,
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
    TestID   -> "Definitions"
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
    TestID   -> "IncludedNotebookQ-MatchesSourceNotebookObjectInformation"
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
    TestID   -> "IncludedNotebookQ-MatchesSourceNotebookObjectInformation-FrontEndStubs"
]

VerificationTest[
    withFocusStubs @ Wolfram`Chatbook`ChatModes`Common`includedNotebookQ @ $closedNB,
    False,
    SameTest -> MatchQ,
    TestID   -> "IncludedNotebookQ-ClosedNotebook"
]

(* A notebook that closes while notebooks are being scanned gives Missing instead of an internal failure, through the
   real notebookInformation code. For a closed notebook, the front end gives $Failed from NotebookInformation and leaves
   AbsoluteCurrentValue unevaluated: *)
VerificationTest[
    Module[ { notebooks, acv },
        notebooks = { $userNB1, $closedNB };
        acv[ nbos_List, spec_ ] := acv[ #, spec ] & /@ nbos;
        acv[ nbo_NotebookObject, spec_ ] /; nbo === $closedNB := FrontEnd`AbsoluteCurrentValue[ nbo, spec ];
        acv[ nbo_NotebookObject, Visible ] := True;
        acv[ nbo_NotebookObject, WindowFrame ] := "Normal";
        acv[ nbo_NotebookObject, { TaggingRules, "ChatNotebookSettings" } ] := Inherited;
        acv[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] := { "Model" -> "DefaultModel" };
        Block[
            {
                Notebooks            = notebooks &,
                NotebookInformation  = If[ # === $closedNB, $Failed, { "WindowTitle" -> "Title" } ] &,
                AbsoluteCurrentValue = acv,
                SelectedNotebook     = $userNB1 &,
                InputNotebook        = $userNB1 &
            },
            {
                Wolfram`Chatbook`Common`notebookInformation @ notebooks,
                (* Runs under catchTop, where a fall through in combineNotebookInfo is a failure, not a retry: *)
                Lookup[ SourceNotebookObjectInformation[ ], "NotebookObject" ]
            }
        ]
    ],
    {
        { KeyValuePattern[ "NotebookObject" -> $userNB1 ], Missing[ "NotebookClosed", $closedNB ] },
        { $userNB1 }
    },
    SameTest -> MatchQ,
    TestID   -> "NotebookInformation-ClosedNotebook-FrontEndStubs-GH#1733"
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
    TestID   -> "SetFocusWindowTitle-Unchanged"
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
    TestID   -> "SetFocusWindowTitle-Changed"
]

VerificationTest[
    withFocusStubs[ Wolfram`Chatbook`ChatModes`NotebookFocus`Private`setFocusWindowTitle[ $chatNB, None ]; $writes ],
    { { $chatNB, { TaggingRules, "FocusWindowTitle" }, None } },
    SameTest -> MatchQ,
    TestID   -> "SetFocusWindowTitle-Unset"
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
    TestID   -> "SetFocusWindowTitle-UntrackedRead"
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
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TitleWrittenOnce"
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
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TitleChanged"
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
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-LockedNotebook"
]

VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ], $writes },
        { First @ $defaultNotebooks }
    ],
    { Spacer[ 0 ], { } },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-NoNotebooks"
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
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-TrackedSymbols"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Locked Notebook Not Included*)

(* A lock on an excluded or hidden notebook is treated as no lock: *)
VerificationTest[
    Table[
        withFocusStubs[
            Module[ { display },
                display = Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $chatNB, None ];
                {
                    $writes[[ All, 3 ]],
                    Cases[ display, Style[ "\[Checkmark] ", ShowContents -> True ], Infinity ],
                    Cases[
                        display,
                        Verbatim[ RuleDelayed ][ Row @ { Style[ "\[Checkmark] ", ShowContents -> True ], rest___ }, _ ] :>
                            Length @ { rest },
                        Infinity
                    ]
                }
            ],
            $defaultNotebooks,
            locked
        ],
        { locked, { $excludedNB, $hiddenNB } }
    ],
    ConstantArray[
        {
            { "Notebook A.nb" },
            { Style[ "\[Checkmark] ", ShowContents -> True ] },
            { 4 }
        },
        2
    ],
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-WorkspaceChat-LockedNotebookNotIncluded"
]

VerificationTest[
    Table[
        withFocusStubs[
            Block[
                {
                    CurrentChatSettings = Function[
                        Switch[ #2, "WorkspaceChat", True, "FocusedNotebook", locked, _, Inherited ]
                    ]
                },
                GetFocusedNotebook @ $chatNB
            ]
        ],
        { locked, { $excludedNB, $hiddenNB, $paletteNB, $userNB2, Inherited } }
    ],
    { $userNB1, $userNB1, $userNB1, $userNB2, $userNB1 },
    SameTest -> MatchQ,
    TestID   -> "GetFocusedNotebook-LockedNotebookNotIncluded"
]

VerificationTest[
    Table[
        withFocusStubs @ Block[
            {
                CurrentChatSettings = Function[
                    Switch[ #2, "WorkspaceChat", True, "FocusedNotebook", locked, _, Inherited ]
                ]
            },
            { GetFocusedNotebook @ $chatNB, $notebookInfoCount, $scanCount }
        ],
        { locked, { $excludedNB, $userNB2, Inherited } }
    ],
    { { $userNB1, 1, 1 }, { $userNB2, 1, 0 }, { $userNB1, 0, 1 } },
    SameTest -> MatchQ,
    TestID   -> "GetFocusedNotebook-ResolvesNotebookInformationOnce"
]

(* The context sent to the model never comes from an excluded or hidden locked notebook: *)
VerificationTest[
    Table[
        withFocusStubs @ Catch[
            Block[
                {
                    Wolfram`Chatbook`$WorkspaceChat = True,
                    Wolfram`Chatbook`ChatModes`Context`Private`getNotebookMetadataString =
                        Throw[ { #1, #2, $notebookInfoCount, $scanCount }, $contextSourceTag ] &
                },
                Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[
                    $chatNB,
                    <| "FocusedNotebook" -> locked |>
                ]
            ],
            $contextSourceTag
        ],
        { locked, { $excludedNB, $hiddenNB, $paletteNB, $userNB2, Inherited } }
    ],
    {
        { $userNB1, KeyValuePattern[ "NotebookObject" -> $userNB1 ], 1, 1 },
        { $userNB1, KeyValuePattern[ "NotebookObject" -> $userNB1 ], 1, 1 },
        { $userNB1, KeyValuePattern[ "NotebookObject" -> $userNB1 ], 1, 1 },
        { $userNB2, KeyValuePattern[ "NotebookObject" -> $userNB2 ], 1, 0 },
        { $userNB1, KeyValuePattern[ "NotebookObject" -> $userNB1 ], 0, 1 }
    },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-LockedNotebookNotIncluded"
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
    TestID   -> "FocusedNotebookDisplay-Sidebar-NoNotebookScan"
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
    TestID   -> "FocusedNotebookDisplay-Sidebar-SameDisplay"
]

(* If the sidebar's own notebook is excluded, the display still depends on whether any other notebook is included: *)
VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $excludedNB, $sidebarCell ], $scanCount },
        $defaultNotebooks
    ],
    { Pane[ _DynamicModule, Alignment -> { Center, Baseline }, ImageSize -> Scaled[ 1 ] ], 1 },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-OwnNotebookExcluded"
]

VerificationTest[
    withFocusStubs[
        { Wolfram`Chatbook`ChatModes`Common`focusedNotebookDisplay[ $excludedNB, $sidebarCell ], $scanCount },
        $defaultNotebooks[[ { 1, 3, 4, 5 } ]]
    ],
    { Spacer[ 0 ], 1 },
    SameTest -> MatchQ,
    TestID   -> "FocusedNotebookDisplay-Sidebar-NoIncludedNotebooks"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sources Overlay*)

(* The notebook list and its checkboxes read Chatbook symbols that change on every catchTop call, so they must only
   track front end values. Otherwise they re-trigger each other continuously while the overlay is open: *)
VerificationTest[
    Cases[
        ToBoxes @ Wolfram`Chatbook`ChatModes`UI`Private`notebookSources[ $chatNB, # ],
        DynamicBox[ content_, opts___ ] /; ! FreeQ[ HoldComplete @ content, SourceNotebookObjectInformation ] :>
            HoldForm @ { opts },
        Infinity
    ] & /@ { None, $sidebarCell },
    { { HoldForm @ { TrackedSymbols :> { } } }, { HoldForm @ { TrackedSymbols :> { } } } },
    SameTest -> MatchQ,
    TestID   -> "NotebookSources-TrackedSymbols"
]

VerificationTest[
    Cases[
        ToBoxes @ Wolfram`Chatbook`ChatModes`UI`Private`inclusionCheckbox @ $userNB1,
        CheckboxBox[ Dynamic[ _, _, opts___ ], ___ ] :> HoldForm @ { opts },
        { 0, Infinity }
    ],
    { HoldForm @ { TrackedSymbols :> { } } },
    SameTest -> MatchQ,
    TestID   -> "InclusionCheckbox-TrackedSymbols"
]

(* :!CodeAnalysis::EndBlock:: *)
