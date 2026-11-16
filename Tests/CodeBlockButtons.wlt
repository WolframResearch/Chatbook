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
    (*
        A minimal simulated front end, so the code block button grid can be rendered without one.
        Each model lists cells and notebooks with their explicit "ChatNotebookSettings" tagging rules, and
        AbsoluteCurrentValue inherits them from the cell, its style, its notebook, and then the front end.
        Calls to Cells (the chat delimiter search) and GetFocusedNotebook (which scans all open notebooks)
        are counted in $calls.
    *)
    $calls = <| |>;
    countCall[ name_ ] := $calls[ name ] = Lookup[ $calls, name, 0 ] + 1;

    toSettings[ as_Association ] := as;
    toSettings[ _ ] := <| |>;

    explicitSettings[ cell_CellObject ] := toSettings @ $model[ "Cells", cell, "Settings" ];
    explicitSettings[ nbo_NotebookObject ] := toSettings @ $model[ "Notebooks", nbo, "Settings" ];

    styleSettings[ cell_CellObject ] := toSettings @ Lookup[ $styleSettings, $model[ "Cells", cell, "Style" ] ];
    $styleSettings = <| "ChatDelimiter" -> <| "ChatDelimiter" -> True |> |>;

    settingsChain[ cell_CellObject ] := Join[
        { explicitSettings @ cell, styleSettings @ cell },
        settingsChain @ $model[ "Cells", cell, "Notebook" ]
    ];
    settingsChain[ nbo_NotebookObject ] := { explicitSettings @ nbo, <| "InheritanceTest" -> True |> };

    ancestors[ cell_CellObject ] := DeleteCases[
        Rest @ NestWhileList[ Lookup[ $model[ "Cells", # ], "Parent", None ] &, cell, MatchQ[ _CellObject ] ],
        None
    ];

    withFakeFrontEnd // Attributes = { HoldRest };
    withFakeFrontEnd[ model_, eval_ ] := Block[
        {
            $model = model,
            AbsoluteCurrentValue, Cells, CurrentValue, Developer`CellInformation, EvaluationCell, EvaluationNotebook,
            GetFocusedNotebook, Notebooks, ParentCell
        },
        EvaluationCell[ ] := $model[ "EvaluationCell" ];
        EvaluationNotebook[ ] := $model[ "Cells", $model[ "EvaluationCell" ], "Notebook" ];
        ParentCell[ cell_CellObject ] := Lookup[ $model[ "Cells", cell ], "Parent", None ];
        ParentCell[ cell_CellObject, All ] := ancestors @ cell;
        Cells[ nbo_NotebookObject ] := ( countCall[ "Cells" ]; $model[ "Notebooks", nbo, "Cells" ] );
        Notebooks[ cell_CellObject ] := $model[ "Cells", cell, "Notebook" ];
        CurrentValue[ objs_List, spec_ ] := CurrentValue[ #, spec ] & /@ objs;
        CurrentValue[ obj_, { TaggingRules, "ChatNotebookSettings", key_ } ] := Lookup[ explicitSettings @ obj, key, Inherited ];
        CurrentValue[ obj_, { TaggingRules, "ChatNotebookSettings" } ] := explicitSettings @ obj;
        CurrentValue[ _, CellAutoOverwrite ] := False;
        CurrentValue[ _, DefaultNewCellStyle ] := "Input";
        AbsoluteCurrentValue[ objs_List, spec_ ] := AbsoluteCurrentValue[ #, spec ] & /@ objs;
        AbsoluteCurrentValue[ obj_, { TaggingRules, "ChatNotebookSettings", key_ } ] :=
            FirstCase[ Lookup[ settingsChain @ obj, key, Inherited ], Except[ Inherited ], Inherited ];
        AbsoluteCurrentValue[ obj_, { TaggingRules, "ChatNotebookSettings" } ] := Association @ Reverse @ settingsChain @ obj;
        AbsoluteCurrentValue[ nbo_NotebookObject, WindowTitle ] := $model[ "Notebooks", nbo, "Title" ];
        Developer`CellInformation[ cells_List ] := Developer`CellInformation /@ cells;
        Developer`CellInformation[ cell_CellObject ] := { "Style" -> $model[ "Cells", cell, "Style" ] };
        GetFocusedNotebook[ _NotebookObject ] := ( countCall[ "GetFocusedNotebook" ]; $model[ "FocusedNotebook" ] );
        eval
    ];

    (* Notebook assistant window with another notebook open: *)
    $workspaceModel = <|
        "Notebooks" -> <|
            NotebookObject[ "na" ]   -> <| "Settings" -> <| "WorkspaceChat" -> True |>, "Cells" -> { CellObject[ "na1" ], CellObject[ "na2" ] } |>,
            NotebookObject[ "user" ] -> <| "Settings" -> Inherited, "Cells" -> { }, "Title" -> "My Notebook" |>
        |>,
        "Cells" -> <|
            CellObject[ "na1" ]  -> <| "Style" -> "ChatInput", "Notebook" -> NotebookObject[ "na" ] |>,
            CellObject[ "na2" ]  -> <| "Style" -> "ChatOutput", "Notebook" -> NotebookObject[ "na" ] |>,
            CellObject[ "code" ] -> <| "Style" -> "ChatCodeBlock", "Notebook" -> NotebookObject[ "na" ], "Parent" -> CellObject[ "na2" ] |>
        |>,
        "EvaluationCell"  -> CellObject[ "code" ],
        "FocusedNotebook" -> NotebookObject[ "user" ]
    |>;

    (* Notebook assistant sidebar in a user notebook: *)
    $sidebarModel = <|
        "Notebooks" -> <|
            NotebookObject[ "user" ] -> <| "Settings" -> Inherited, "Cells" -> { CellObject[ "u1" ] }, "Title" -> "My Notebook" |>
        |>,
        "Cells" -> <|
            CellObject[ "u1" ]      -> <| "Style" -> "Input", "Notebook" -> NotebookObject[ "user" ] |>,
            CellObject[ "sidebar" ] -> <|
                "Style"    -> "NotebookAssistant`Sidebar`NotebookAssistantSidebarCell",
                "Notebook" -> NotebookObject[ "user" ],
                "Settings" -> <| "SidebarChat" -> True |>
            |>,
            CellObject[ "scroll" ] -> <|
                "Style"    -> "NotebookAssistant`Sidebar`ScrollingContentCell",
                "Notebook" -> NotebookObject[ "user" ],
                "Parent"   -> CellObject[ "sidebar" ]
            |>,
            CellObject[ "sbOut" ] -> <|
                "Style"    -> "NotebookAssistant`Sidebar`ChatOutput",
                "Notebook" -> NotebookObject[ "user" ],
                "Parent"   -> CellObject[ "scroll" ]
            |>,
            CellObject[ "code" ] -> <| "Style" -> "ChatCodeBlock", "Notebook" -> NotebookObject[ "user" ], "Parent" -> CellObject[ "sbOut" ] |>
        |>,
        "EvaluationCell"  -> CellObject[ "code" ],
        "FocusedNotebook" -> NotebookObject[ "user" ]
    |>;

    (* Chat notebook with a chat delimiter that has its own settings: *)
    $chatNotebookModel = <|
        "Notebooks" -> <|
            NotebookObject[ "chat" ] -> <|
                "Settings" -> <| "LLMEvaluator" -> "CodeAssistant" |>,
                "Cells"    -> { CellObject[ "c1" ], CellObject[ "c2" ], CellObject[ "c3" ], CellObject[ "c4" ] }
            |>
        |>,
        "Cells" -> <|
            CellObject[ "c1" ]   -> <| "Style" -> "ChatInput", "Notebook" -> NotebookObject[ "chat" ] |>,
            CellObject[ "c2" ]   -> <| "Style" -> "ChatDelimiter", "Notebook" -> NotebookObject[ "chat" ], "Settings" -> <| "Model" -> "gpt-4o" |> |>,
            CellObject[ "c3" ]   -> <| "Style" -> "ChatInput", "Notebook" -> NotebookObject[ "chat" ] |>,
            CellObject[ "c4" ]   -> <| "Style" -> "ChatOutput", "Notebook" -> NotebookObject[ "chat" ] |>,
            CellObject[ "code" ] -> <| "Style" -> "ChatCodeBlock", "Notebook" -> NotebookObject[ "chat" ], "Parent" -> CellObject[ "c4" ] |>
        |>,
        "EvaluationCell"  -> CellObject[ "code" ],
        "FocusedNotebook" -> NotebookObject[ "chat" ]
    |>;

    (* Renders the button grid for a Wolfram Language code block: *)
    renderGrid[ ] := Wolfram`Chatbook`Common`floatingButtonGrid[ Cell[ "Plot[Sin[x], {x, 0, 10}]", "ChatCode" ], "Wolfram" ];

    buttonActions[ grid_ ] := Cases[ grid, Button[ _, action_, ___ ] :> HoldForm @ action, Infinity ];

    containerSettings[ ] :=
        With[ { cell = Wolfram`Chatbook`Common`topParentCell @ EvaluationCell[ ] },
            Wolfram`Chatbook`Common`currentChatContainerSetting[ cell, # ] & /@ { "WorkspaceChat", "SidebarChat" }
        ];

    fullSettings[ ] :=
        With[ { cell = Wolfram`Chatbook`Common`topParentCell @ EvaluationCell[ ] },
            CurrentChatSettings[ cell, # ] & /@ { "WorkspaceChat", "SidebarChat" }
        ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Workspace Chat*)

(* Rendering a code block must not scan all open notebooks for the "insert and evaluate" tooltip: *)
VerificationTest[
    Block[ { $calls = <| |> },
        withFakeFrontEnd[ $workspaceModel, ToBoxes @ renderGrid[ ] ];
        Lookup[ $calls, "GetFocusedNotebook", 0 ]
    ],
    0,
    SameTest -> MatchQ,
    TestID   -> "Workspace-Render-Does-Not-Find-Focused-Notebook"
]

(* Instead, the tooltip is a dynamic for the assistant window that is evaluated when the tooltip is shown: *)
VerificationTest[
    withFakeFrontEnd[
        $workspaceModel,
        Cases[ renderGrid[ ], Dynamic[ label_Wolfram`Chatbook`Formatting`Private`targetNotebookLabel, ___ ] :> HoldForm @ label, Infinity ]
    ],
    { HoldForm @ Wolfram`Chatbook`Formatting`Private`targetNotebookLabel @ NotebookObject[ "na" ] },
    SameTest -> MatchQ,
    TestID   -> "Workspace-Tooltip-Is-Dynamic"
]

(* The label reads Chatbook symbols that change on every catchTop call, so it must only track front end values: *)
VerificationTest[
    withFakeFrontEnd[
        $workspaceModel,
        Cases[
            renderGrid[ ],
            Dynamic[ _Wolfram`Chatbook`Formatting`Private`targetNotebookLabel, opts___ ] :> HoldForm @ { opts },
            Infinity
        ]
    ],
    { HoldForm @ { TrackedSymbols :> { } } },
    SameTest -> MatchQ,
    TestID   -> "Workspace-Tooltip-TrackedSymbols"
]

(* At that point, it gives the same label as before, naming the focused notebook: *)
VerificationTest[
    Block[ { $calls = <| |> },
        withFakeFrontEnd[
            $workspaceModel,
            {
                FirstCase[ renderGrid[ ], Dynamic[ label_Wolfram`Chatbook`Formatting`Private`targetNotebookLabel, ___ ] :> label, $Failed, Infinity ],
                Lookup[ $calls, "GetFocusedNotebook", 0 ]
            }
        ]
    ],
    {
        Row[ { ___, Style[ "My Notebook", FontWeight -> Bold ], ___ } ],
        1
    },
    SameTest -> MatchQ,
    TestID   -> "Workspace-Tooltip-Names-Focused-Notebook"
]

VerificationTest[
    withFakeFrontEnd[
        <| $workspaceModel, "FocusedNotebook" -> None |>,
        FirstCase[ renderGrid[ ], Dynamic[ label_Wolfram`Chatbook`Formatting`Private`targetNotebookLabel, ___ ] :> label, $Failed, Infinity ]
    ],
    Wolfram`Chatbook`Common`tr[ "FormattingInsertContentAndEvaluateWorkspaceChatTooltipNew" ],
    SameTest -> MatchQ,
    TestID   -> "Workspace-Tooltip-Without-Focused-Notebook"
]

VerificationTest[
    withFakeFrontEnd[ $workspaceModel, buttonActions @ renderGrid[ ] ],
    {
        HoldForm @ Wolfram`Chatbook`Formatting`Private`copyCodeBlock @ CellObject[ "code" ],
        HoldForm @ Wolfram`Chatbook`Common`insertCodeBelow[ CellObject[ "code" ], True ]
    },
    SameTest -> MatchQ,
    TestID   -> "Workspace-Button-Actions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sidebar Chat*)
VerificationTest[
    Block[ { $calls = <| |> },
        withFakeFrontEnd[
            $sidebarModel,
            {
                buttonActions @ renderGrid[ ],
                Cases[ renderGrid[ ], Dynamic[ label_Wolfram`Chatbook`Formatting`Private`targetNotebookLabel, ___ ] :> HoldForm @ label, Infinity ],
                $calls
            }
        ]
    ],
    {
        {
            HoldForm @ Wolfram`Chatbook`Formatting`Private`copyCodeBlock @ CellObject[ "code" ],
            HoldForm @ Wolfram`Chatbook`Common`insertCodeBelow[ CellObject[ "code" ], "Sidebar" ]
        },
        { HoldForm @ Wolfram`Chatbook`Formatting`Private`targetNotebookLabel @ NotebookObject[ "user" ] },
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "Sidebar-Button-Actions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Notebooks*)

(* Deciding which buttons to show does not search the notebook for a chat delimiter: *)
VerificationTest[
    Block[ { $calls = <| |> },
        withFakeFrontEnd[ $chatNotebookModel, { buttonActions @ renderGrid[ ], $calls } ]
    ],
    {
        {
            HoldForm @ Wolfram`Chatbook`Common`insertCodeBelow[ CellObject[ "code" ], True ],
            HoldForm @ Wolfram`Chatbook`Common`insertCodeBelow[ CellObject[ "code" ], False ],
            HoldForm @ Wolfram`Chatbook`Formatting`Private`copyCodeBlock @ CellObject[ "code" ]
        },
        <| |>
    },
    SameTest -> MatchQ,
    TestID   -> "ChatNotebook-Button-Actions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*currentChatContainerSetting*)

(* Gives the same values as CurrentChatSettings for cells in each kind of chat container: *)
VerificationTest[
    Table[
        withFakeFrontEnd[ model, containerSettings[ ] === fullSettings[ ] ],
        {
            model,
            {
                $workspaceModel,
                $sidebarModel,
                $chatNotebookModel,
                (* Explicit values on the cell itself take precedence: *)
                <| $workspaceModel, "Cells" -> <| $workspaceModel[ "Cells" ], CellObject[ "na2" ] -> <| "Style" -> "ChatOutput", "Notebook" -> NotebookObject[ "na" ], "Settings" -> <| "WorkspaceChat" -> False |> |> |> |>,
                <| $sidebarModel, "Cells" -> <| $sidebarModel[ "Cells" ], CellObject[ "sbOut" ] -> <| $sidebarModel[ "Cells", CellObject[ "sbOut" ] ], "Settings" -> <| "SidebarChat" -> False |> |> |> |>,
                (* A notebook can also mark itself as a sidebar chat: *)
                <| $chatNotebookModel, "Notebooks" -> <| NotebookObject[ "chat" ] -> <| $chatNotebookModel[ "Notebooks", NotebookObject[ "chat" ] ], "Settings" -> <| "SidebarChat" -> True |> |> |> |>
            }
        }
    ],
    { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatContainerSetting-Matches-CurrentChatSettings"
]

VerificationTest[
    withFakeFrontEnd[ #, containerSettings[ ] ] & /@ { $workspaceModel, $sidebarModel, $chatNotebookModel },
    { { True, Inherited }, { Inherited, True }, { Inherited, Inherited } },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatContainerSetting-Values"
]

VerificationTest[
    Block[ { $calls = <| |> },
        withFakeFrontEnd[ $chatNotebookModel, containerSettings[ ] ];
        $calls
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatContainerSetting-No-Delimiter-Search"
]

(* :!CodeAnalysis::EndBlock:: *)
