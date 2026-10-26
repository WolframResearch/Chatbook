(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WorkspaceChatInput.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WorkspaceChatInput.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
$testNotebook      = NotebookObject[ "ChatbookTestWorkspaceChat" ];
$testInputCell     = CellObject[ "ChatbookTestWorkspaceChatInput" ];
$testChatInputCell = CellObject[ "ChatbookTestWorkspaceChatMessage" ];

(* Evaluates eval with a stubbed front end: $testNotebook has the given attached input cells, and the input text of
   $testInputCell is stored in $testInputCellValue. Note: stubs use Clear rather than ClearAll, since ClearAll inside
   Internal`InheritedBlock does not restore the original definitions. *)
Attributes[ withTestInputCell ] = { HoldRest };
withTestInputCell[ cells_List, eval_ ] :=
    With[ { nbo = $testNotebook, cell = $testInputCell },
        Internal`InheritedBlock[ { CurrentValue, Cells },
            Unprotect[ CurrentValue, Cells ];
            DownValues[ CurrentValue ] = Prepend[
                DownValues @ CurrentValue,
                HoldPattern @ CurrentValue[ cell, { TaggingRules, "ChatInputString" } ] :> $testInputCellValue
            ];
            (* the cell may be given as a symbol, as in the DynamicModule of the input cell: *)
            CurrentValue /: Set[ CurrentValue[ c_, { TaggingRules, "ChatInputString" } ], value_ ] :=
                ($testInputCellValue = value) /; c === cell;
            Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ] := cells;
            eval
        ]
    ];

(* Like withTestInputCell, but the current assistant window is the given one, a new window is $testNewNotebook (which
   has no input cell yet), and windows closed with NotebookClose are stored in $testClosed. $testSourceNotebook is the
   user notebook that the notebook toolbar button and the Window menu command give, and the current window has no
   chat cells: *)
$testNewNotebook    = NotebookObject[ "ChatbookTestWorkspaceChatNew" ];
$testSourceNotebook = NotebookObject[ "ChatbookTestUserNotebook" ];

Attributes[ withTestNewWindow ] = { HoldRest };
withTestNewWindow[ current_, cells_List, eval_ ] :=
    withTestInputCell[
        cells,
        Internal`InheritedBlock[
            {
                Wolfram`Chatbook`ChatModes`Common`createWorkspaceChat,
                Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat,
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setNotebookAssistanceEvaluator
            },
            Clear[
                Wolfram`Chatbook`ChatModes`Common`createWorkspaceChat,
                Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat,
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setNotebookAssistanceEvaluator
            ];
            Wolfram`Chatbook`ChatModes`Common`findCurrentWorkspaceChat[ "NotebookAssistance" ] := current;
            Wolfram`Chatbook`ChatModes`Common`createWorkspaceChat[ ] := $testNewNotebook;
            Wolfram`Chatbook`ChatModes`Common`createWorkspaceChat[ $testSourceNotebook ] := $testNewNotebook;
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setNotebookAssistanceEvaluator[ _ ] := Null;
            Cells[ current ] := { };
            Cells[ $testNewNotebook, AttachedCell -> True, CellStyle -> "ChatInputField" ] := { };
            Block[ { NotebookClose = ($testClosed = #1;) & }, eval ]
        ]
    ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*attachedWorkspaceChatInputCell*)
VerificationTest[
    $workspaceInputCell = Block[
        { $WorkspaceChatInput = "Hello" },
        Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ]
    ],
    Cell[ BoxData[ _DynamicModuleBox ], "ChatInputField", ___, TaggingRules -> <| "ChatInputString" -> "Hello" |>, ___ ],
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell-InitialText@@Tests/WorkspaceChatInput.wlt:83,1-91,2"
]

(* Typing must not need the kernel, so nothing in the cell may refer to the kernel symbol: *)
VerificationTest[
    FreeQ[ $workspaceInputCell, HoldPattern @ $WorkspaceChatInput ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell-NoKernelSymbol@@Tests/WorkspaceChatInput.wlt:94,1-99,2"
]

(* The input field, the field hint, and both ways of submitting use the cell's TaggingRules through the same
   DynamicModule variable, which is set to the cell in the Initialization: *)
VerificationTest[
    Module[ { field, hint, submit, init, vars },
        field = Cases[
            $workspaceInputCell,
            InputFieldBox[ Dynamic @ CurrentValue[ s_Symbol, { TaggingRules, "ChatInputString" } ], Boxes, ___ ] :>
                HoldForm @ s,
            Infinity
        ];
        hint = Cases[
            $workspaceInputCell,
            DynamicBox[ If[ CurrentValue[ s_Symbol, { TaggingRules, "ChatInputString" } ] === "", _, "" ], ___ ] :>
                HoldForm @ s,
            Infinity
        ];
        submit = Cases[
            $workspaceInputCell,
            HoldPattern @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][
                "EvaluateWorkspaceChat",
                _,
                Dynamic @ CurrentValue[ s_Symbol, { TaggingRules, "ChatInputString" } ]
            ] :> HoldForm @ s,
            Infinity
        ];
        init = Cases[ $workspaceInputCell, HoldPattern[ s_Symbol = EvaluationCell[ ] ] :> HoldForm @ s, Infinity ];
        vars = Cases[ Extract[ $workspaceInputCell, { 1, 1, 1 }, Hold ], s_Symbol :> HoldForm @ s, { 2 } ];
        {
            Length /@ { field, hint, submit, init },
            Length @ Union[ field, hint, submit, init ],
            SubsetQ[ vars, field ]
        }
    ],
    { { 1, 1, 2, 1 }, 1, True },
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell-FrontEndStorage@@Tests/WorkspaceChatInput.wlt:103,1-137,2"
]

VerificationTest[
    Cases[
        Block[
            { $WorkspaceChatInput = RowBox @ { "Hello", " ", "there" } },
            Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Bottom" ]
        ],
        HoldPattern[ TaggingRules -> tags_ ] :> tags
    ],
    { <| "ChatInputString" -> RowBox @ { "Hello", " ", "there" } |> },
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell-InitialBoxes@@Tests/WorkspaceChatInput.wlt:139,1-150,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*workspaceChatInput*)
VerificationTest[
    withTestInputCell[ { $testInputCell }, Wolfram`Chatbook`ChatModes`Common`workspaceChatInput @ $testNotebook ],
    Dynamic @ CurrentValue[ CellObject[ "ChatbookTestWorkspaceChatInput" ], { TaggingRules, "ChatInputString" } ],
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInput-AttachedCell@@Tests/WorkspaceChatInput.wlt:155,1-160,2"
]

(* Before the input cell is attached, the text is kept in $WorkspaceChatInput, which the new cell starts with: *)
VerificationTest[
    withTestInputCell[ { }, Wolfram`Chatbook`ChatModes`Common`workspaceChatInput @ $testNotebook ],
    Dynamic @ $WorkspaceChatInput,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInput-NoCell@@Tests/WorkspaceChatInput.wlt:163,1-168,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*saveWorkspaceChatInput*)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft" },
            Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ $testNotebook;
            $WorkspaceChatInput
        ]
    ],
    "Draft",
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-String@@Tests/WorkspaceChatInput.wlt:173,1-184,2"
]

VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = RowBox @ { "Draft", " ", "text" } },
            Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ { $testInputCell };
            $WorkspaceChatInput
        ]
    ],
    RowBox @ { "Draft", " ", "text" },
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-Boxes@@Tests/WorkspaceChatInput.wlt:186,1-197,2"
]

(* An input cell without stored text (e.g. attached by an older version) leaves $WorkspaceChatInput unchanged: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "Draft", $testInputCellValue = Inherited },
            Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ $testNotebook;
            $WorkspaceChatInput
        ]
    ],
    "Draft",
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-NotStored@@Tests/WorkspaceChatInput.wlt:200,1-211,2"
]

VerificationTest[
    withTestInputCell[
        { },
        Block[ { $WorkspaceChatInput = "Draft" },
            Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ $testNotebook;
            $WorkspaceChatInput
        ]
    ],
    "Draft",
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-NoCell@@Tests/WorkspaceChatInput.wlt:213,1-224,2"
]

(* A failed lookup is not copied, since new input cells would show it: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "Draft", $testInputCellValue = $Failed },
            Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ $testNotebook;
            $WorkspaceChatInput
        ]
    ],
    "Draft",
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-Failed@@Tests/WorkspaceChatInput.wlt:227,1-238,2"
]

VerificationTest[
    Block[ { $WorkspaceChatInput = "Draft" },
        Wolfram`Chatbook`ChatModes`Common`saveWorkspaceChatInput @ $Failed;
        $WorkspaceChatInput
    ],
    "Draft",
    SameTest -> MatchQ,
    TestID   -> "SaveWorkspaceChatInput-CellsFailed@@Tests/WorkspaceChatInput.wlt:240,1-248,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*setWindowInputAndEvaluate*)

(* The "Input" option of ShowNotebookAssistance writes into the input cell: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft" },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                    $testNotebook,
                    "Hello",
                    False
                ],
                $testInputCellValue,
                $WorkspaceChatInput
            }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChat" ], "Hello", "Hello" },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-AttachedCell@@Tests/WorkspaceChatInput.wlt:255,1-273,2"
]

(* If the input cell is not attached yet (e.g. a new window), the attached cell starts with $WorkspaceChatInput: *)
VerificationTest[
    withTestInputCell[
        { },
        Block[ { $WorkspaceChatInput = "" },
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                $testNotebook,
                "Hello",
                False
            ];
            {
                $WorkspaceChatInput,
                Cases[
                    Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ],
                    HoldPattern[ TaggingRules -> tags_ ] :> tags
                ]
            }
        ]
    ],
    { "Hello", { <| "ChatInputString" -> "Hello" |> } },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-NoCell@@Tests/WorkspaceChatInput.wlt:276,1-297,2"
]

VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "Draft", $testInputCellValue = "Draft" },
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                $testNotebook,
                "",
                False
            ];
            { $testInputCellValue, $WorkspaceChatInput }
        ]
    ],
    { "Draft", "Draft" },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-NoInput@@Tests/WorkspaceChatInput.wlt:299,1-314,2"
]

(* Opening a window without input does not look up the input cell, which would need the front end: *)
VerificationTest[
    Internal`InheritedBlock[ { Cells },
        Unprotect @ Cells;
        Cells[ ___ ] := ($testCellsCalls++; { });
        Block[ { $WorkspaceChatInput = "Draft", $testCellsCalls = 0 },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                    $testNotebook,
                    "",
                    False
                ],
                $testCellsCalls,
                $WorkspaceChatInput
            }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChat" ], 0, "Draft" },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-NoInput-NoLookup@@Tests/WorkspaceChatInput.wlt:317,1-336,2"
]

(* "EvaluateInput" -> True submits the text of the input cell: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Common`evaluateWorkspaceChat },
            Clear @ Wolfram`Chatbook`Common`evaluateWorkspaceChat;
            Wolfram`Chatbook`Common`evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input_ ] ] :=
                ($testSubmitted = { nbo, Hold @ input, input };);
            Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft", $testSubmitted = None },
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                    $testNotebook,
                    "Hello",
                    True
                ];
                $testSubmitted
            ]
        ]
    ],
    {
        NotebookObject[ "ChatbookTestWorkspaceChat" ],
        Hold @ CurrentValue[ CellObject[ "ChatbookTestWorkspaceChatInput" ], { TaggingRules, "ChatInputString" } ],
        "Hello"
    },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-Evaluate-AttachedCell@@Tests/WorkspaceChatInput.wlt:339,1-363,2"
]

VerificationTest[
    withTestInputCell[
        { },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Common`evaluateWorkspaceChat },
            Clear @ Wolfram`Chatbook`Common`evaluateWorkspaceChat;
            Wolfram`Chatbook`Common`evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input_ ] ] :=
                ($testSubmitted = { nbo, Hold @ input, input };);
            Block[ { $WorkspaceChatInput = "", $testSubmitted = None },
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                    $testNotebook,
                    "Hello",
                    True
                ];
                $testSubmitted
            ]
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChat" ], Hold @ $WorkspaceChatInput, "Hello" },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-Evaluate-NoCell@@Tests/WorkspaceChatInput.wlt:365,1-385,2"
]

(* "EvaluateInput" -> True without "Input" submits the unsent text of the input cell: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Common`evaluateWorkspaceChat },
            Clear @ Wolfram`Chatbook`Common`evaluateWorkspaceChat;
            Wolfram`Chatbook`Common`evaluateWorkspaceChat[ nbo_NotebookObject, Dynamic[ input_ ] ] :=
                ($testSubmitted = { nbo, Hold @ input, input };);
            Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft", $testSubmitted = None },
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setWindowInputAndEvaluate[
                    $testNotebook,
                    "",
                    True
                ];
                $testSubmitted
            ]
        ]
    ],
    {
        NotebookObject[ "ChatbookTestWorkspaceChat" ],
        Hold @ CurrentValue[ CellObject[ "ChatbookTestWorkspaceChatInput" ], { TaggingRules, "ChatInputString" } ],
        "Draft"
    },
    SameTest -> MatchQ,
    TestID   -> "SetWindowInput-Evaluate-NoInput@@Tests/WorkspaceChatInput.wlt:388,1-412,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*showNotebookAssistanceWindow*)

(* Replacing the open window with a new one ("NewChat") keeps the unsent text for the input cell of the new window: *)
VerificationTest[
    withTestNewWindow[
        $testNotebook,
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft", $testClosed = None },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                    None,
                    "",
                    False,
                    True
                ],
                $testClosed,
                $WorkspaceChatInput,
                Cases[
                    Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ],
                    HoldPattern[ TaggingRules -> tags_ ] :> tags
                ]
            }
        ]
    ],
    {
        NotebookObject[ "ChatbookTestWorkspaceChatNew" ],
        NotebookObject[ "ChatbookTestWorkspaceChat" ],
        "Draft",
        { <| "ChatInputString" -> "Draft" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-KeepsInput@@Tests/WorkspaceChatInput.wlt:419,1-448,2"
]

(* The "Input" option still replaces the unsent text: *)
VerificationTest[
    withTestNewWindow[
        $testNotebook,
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft", $testClosed = None },
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                None,
                "Hello",
                False,
                True
            ];
            { $testClosed, $WorkspaceChatInput }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChat" ], "Hello" },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-Input@@Tests/WorkspaceChatInput.wlt:451,1-468,2"
]

(* Without an open window there is nothing to keep: *)
VerificationTest[
    withTestNewWindow[
        Missing[ "NotFound" ],
        { },
        Block[ { $WorkspaceChatInput = "Earlier", $testClosed = None },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                    None,
                    "",
                    False,
                    True
                ],
                $WorkspaceChatInput
            }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChatNew" ], "Earlier" },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-NoWindow@@Tests/WorkspaceChatInput.wlt:471,1-490,2"
]

(* Reusing the open window leaves $WorkspaceChatInput alone: *)
VerificationTest[
    withTestNewWindow[
        $testNotebook,
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "Earlier", $testInputCellValue = "Draft", $testClosed = None },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                    None,
                    "",
                    False,
                    False
                ],
                $testClosed,
                $WorkspaceChatInput,
                $testInputCellValue
            }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChat" ], None, "Earlier", "Draft" },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-ReuseWindow@@Tests/WorkspaceChatInput.wlt:493,1-514,2"
]

(* The same with a source notebook, as given by the notebook toolbar button and the Window menu command: *)
VerificationTest[
    withTestNewWindow[
        $testNotebook,
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft", $testClosed = None },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                    $testSourceNotebook,
                    "",
                    False,
                    True
                ],
                $testClosed,
                $WorkspaceChatInput,
                Cases[
                    Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Top" ],
                    HoldPattern[ TaggingRules -> tags_ ] :> tags
                ]
            }
        ]
    ],
    {
        NotebookObject[ "ChatbookTestWorkspaceChatNew" ],
        NotebookObject[ "ChatbookTestWorkspaceChat" ],
        "Draft",
        { <| "ChatInputString" -> "Draft" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-SourceNotebook-KeepsInput@@Tests/WorkspaceChatInput.wlt:517,1-546,2"
]

VerificationTest[
    withTestNewWindow[
        Missing[ "NotFound" ],
        { },
        Block[ { $WorkspaceChatInput = "Earlier", $testClosed = None },
            {
                Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`showNotebookAssistanceWindow[
                    $testSourceNotebook,
                    "",
                    False,
                    True
                ],
                $WorkspaceChatInput
            }
        ]
    ],
    { NotebookObject[ "ChatbookTestWorkspaceChatNew" ], "Earlier" },
    SameTest -> MatchQ,
    TestID   -> "NewChatWindow-SourceNotebook-NoWindow@@Tests/WorkspaceChatInput.wlt:548,1-567,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Re-attaching the input cell*)

(* Like withTestInputCell, but $testInputCell is attached at the given location ("Top" or "Bottom") until it's deleted
   with NotebookDelete, and the cell given to AttachCell is stored in $testAttached together with its location: *)
Attributes[ withTestAttachedInput ] = { HoldRest };
withTestAttachedInput[ location_String, eval_ ] :=
    withTestInputCell[
        { },
        Block[
            {
                $testAttachedCells = { $testInputCell },
                $testAttached      = None,
                NotebookDelete     = Function[
                    $testAttachedCells = Complement[ $testAttachedCells, Flatten @ { # } ];
                    If[ ListQ @ #, Null & /@ #, Null ]
                ],
                AttachCell = Function[
                    $testAttached = { #2, #3 };
                    CellObject[ "ChatbookTestWorkspaceChatInputNew" ]
                ]
            },
            Cells[ $testNotebook, AttachedCell -> True, CellStyle -> "ChatInputField" ] := $testAttachedCells;
            Cells[ $testNotebook, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> location ] :=
                $testAttachedCells;
            Cells[ $testNotebook, AttachedCell -> True, CellStyle -> "ChatInputField", CellTags -> _String ] := { };
            DownValues[ CurrentValue ] = Prepend[
                DownValues @ CurrentValue,
                HoldPattern @ CurrentValue[ cells: { ___CellObject }, CellTags ] :>
                    ConstantArray[ { location }, Length @ cells ]
            ];
            eval
        ]
    ];

(* New Chat moves the input cell to the top, which keeps the unsent text: *)
VerificationTest[
    withTestAttachedInput[
        "Bottom",
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft" },
            {
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToTop @ $testNotebook,
                $testAttachedCells,
                $WorkspaceChatInput,
                $testAttached
            }
        ]
    ],
    {
        CellObject[ "ChatbookTestWorkspaceChatInputNew" ],
        { },
        "Draft",
        { Cell[ ___, CellTags -> "Top", ___, TaggingRules -> <| "ChatInputString" -> "Draft" |>, ___ ], Top }
    },
    SameTest -> MatchQ,
    TestID   -> "MoveChatInputToTop-KeepsInput@@Tests/WorkspaceChatInput.wlt:606,1-626,2"
]

(* The first message moves the input cell to the bottom, which keeps any text typed after submitting: *)
VerificationTest[
    withTestAttachedInput[
        "Top",
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft" },
            {
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom @ $testNotebook,
                $testAttachedCells,
                $WorkspaceChatInput,
                $testAttached
            }
        ]
    ],
    {
        CellObject[ "ChatbookTestWorkspaceChatInputNew" ],
        { },
        "Draft",
        { Cell[ ___, CellTags -> "Bottom", ___, TaggingRules -> <| "ChatInputString" -> "Draft" |>, ___ ], Bottom }
    },
    SameTest -> MatchQ,
    TestID   -> "MoveChatInputToBottom-KeepsInput@@Tests/WorkspaceChatInput.wlt:629,1-649,2"
]

(* Attaching the input cell at a new location (e.g. from the Initialization of the docked cell) keeps the text: *)
VerificationTest[
    withTestAttachedInput[
        "Top",
        Block[ { $WorkspaceChatInput = "", $testInputCellValue = "Draft" },
            {
                Wolfram`Chatbook`Common`attachWorkspaceChatInput[ $testNotebook, Bottom ],
                $testAttachedCells,
                $WorkspaceChatInput,
                $testAttached
            }
        ]
    ],
    {
        CellObject[ "ChatbookTestWorkspaceChatInputNew" ],
        { },
        "Draft",
        { Cell[ ___, CellTags -> "Bottom", ___, TaggingRules -> <| "ChatInputString" -> "Draft" |>, ___ ], Bottom }
    },
    SameTest -> MatchQ,
    TestID   -> "AttachWorkspaceChatInput-KeepsInput@@Tests/WorkspaceChatInput.wlt:652,1-672,2"
]

(* Loading a chat from history replaces the input cell, which keeps the unsent text: *)
VerificationTest[
    withTestAttachedInput[
        "Top",
        Internal`InheritedBlock[
            {
                Wolfram`Chatbook`Common`moveToChatInputField,
                Wolfram`Chatbook`Common`setCurrentValue,
                Wolfram`Chatbook`Common`writeWorkspaceChatTitleDockedCell,
                Wolfram`Chatbook`ChatModes`UI`Private`withLoadingOverlay
            },
            Clear[
                Wolfram`Chatbook`Common`moveToChatInputField,
                Wolfram`Chatbook`Common`setCurrentValue,
                Wolfram`Chatbook`Common`writeWorkspaceChatTitleDockedCell,
                Wolfram`Chatbook`ChatModes`UI`Private`withLoadingOverlay
            ];
            Wolfram`Chatbook`Common`moveToChatInputField[ ___ ] := Null;
            Wolfram`Chatbook`Common`setCurrentValue[ ___ ] := Null;
            Wolfram`Chatbook`Common`writeWorkspaceChatTitleDockedCell[ ___ ] := Null;
            Wolfram`Chatbook`ChatModes`UI`Private`withLoadingOverlay[ _ ] := Identity;
            Cells[ $testNotebook ] := { };
            Block[
                {
                    LoadChat = <|
                        "ConversationUUID"  -> "ChatbookTestConversation",
                        "ConversationTitle" -> "Test",
                        "Messages"          -> { <| "Role" -> "User", "Content" -> "Hello" |> }
                    |> &,
                    ChatMessageToCell   = { Cell[ "Hello", "ChatInput" ] } &,
                    CurrentChatSettings,
                    SelectionMove       = Null &,
                    NotebookWrite       = Null &,
                    $WorkspaceChatInput = "",
                    $testInputCellValue = "Draft"
                },
                {
                    Wolfram`Chatbook`ChatModes`UI`Private`loadConversation[
                        $testNotebook,
                        None,
                        "ChatbookTestConversation"
                    ],
                    $testAttachedCells,
                    $WorkspaceChatInput,
                    $testAttached
                }
            ]
        ]
    ],
    {
        Null,
        { },
        "Draft",
        { Cell[ ___, CellTags -> "Bottom", ___, TaggingRules -> <| "ChatInputString" -> "Draft" |>, ___ ], Bottom }
    },
    SameTest -> MatchQ,
    TestID   -> "LoadConversation-KeepsInput@@Tests/WorkspaceChatInput.wlt:675,1-731,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*evaluateWorkspaceChat*)

(* Blank input clears the input cell and $WorkspaceChatInput without writing anything: *)
VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Block[ { $WorkspaceChatInput = "Stale", $testInputCellValue = "   " },
            {
                Wolfram`Chatbook`Common`evaluateWorkspaceChat[
                    $testNotebook,
                    Dynamic @ CurrentValue[ $testInputCell, { TaggingRules, "ChatInputString" } ]
                ],
                $testInputCellValue,
                $WorkspaceChatInput
            }
        ]
    ],
    { Null, "", "" },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-CurrentValue-Blank@@Tests/WorkspaceChatInput.wlt:738,1-755,2"
]

VerificationTest[
    withTestInputCell[
        { $testInputCell },
        Internal`InheritedBlock[
            {
                ChatCellEvaluate,
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom,
                Wolfram`Chatbook`Common`setCurrentValue
            },
            Unprotect @ ChatCellEvaluate;
            Clear[
                ChatCellEvaluate,
                Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom,
                Wolfram`Chatbook`Common`setCurrentValue
            ];
            Cells[ $testNotebook, CellTags -> _String ] := { $testChatInputCell };
            (* the input is cleared before the input cell is moved to the bottom of the window: *)
            Wolfram`Chatbook`ChatModes`Common`moveChatInputToBottom[ $testNotebook ] :=
                ($testInputAtMove = $testInputCellValue;);
            Wolfram`Chatbook`Common`setCurrentValue[ ___ ] := Null;
            ChatCellEvaluate[ cell_, nbo_ ] := ($testEvaluated = { cell, nbo };);
            Block[
                {
                    NotebookWrite        = ($testWritten = #2;) &,
                    SelectionMove        = Null &,
                    $WorkspaceChatInput  = "Stale",
                    $testInputCellValue  = "Hello",
                    $testWritten         = None,
                    $testInputAtMove     = None,
                    $testEvaluated       = None
                },
                {
                    Wolfram`Chatbook`Common`evaluateWorkspaceChat[
                        $testNotebook,
                        Dynamic @ CurrentValue[ $testInputCell, { TaggingRules, "ChatInputString" } ]
                    ],
                    $testInputCellValue,
                    $WorkspaceChatInput,
                    $testInputAtMove,
                    $testWritten,
                    $testEvaluated
                }
            ]
        ]
    ],
    {
        Null,
        "",
        "",
        "",
        Cell[ BoxData @ TemplateBox[ { Cell[ "Hello", ___ ] }, "UserMessageBox" ], "ChatInput", ___ ],
        { CellObject[ "ChatbookTestWorkspaceChatMessage" ], NotebookObject[ "ChatbookTestWorkspaceChat" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-CurrentValue@@Tests/WorkspaceChatInput.wlt:757,1-812,2"
]

(* Submitting with the kernel symbol still works: *)
VerificationTest[
    Block[ { $WorkspaceChatInput = "   " },
        {
            Wolfram`Chatbook`Common`evaluateWorkspaceChat[ $testNotebook, Dynamic @ $WorkspaceChatInput ],
            $WorkspaceChatInput
        }
    ],
    { Null, "" },
    SameTest -> MatchQ,
    TestID   -> "EvaluateWorkspaceChat-Symbol-Blank@@Tests/WorkspaceChatInput.wlt:815,1-825,2"
]

(* :!CodeAnalysis::EndBlock:: *)
