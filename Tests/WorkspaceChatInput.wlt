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
   has no input cell yet), and windows closed with NotebookClose are stored in $testClosed: *)
$testNewNotebook = NotebookObject[ "ChatbookTestWorkspaceChatNew" ];

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
            Wolfram`Chatbook`ChatModes`ShowNotebookAssistance`Private`setNotebookAssistanceEvaluator[ _ ] := Null;
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
    TestID   -> "AttachedInputCell-InitialText"
]

(* Typing must not need the kernel, so nothing in the cell may refer to the kernel symbol: *)
VerificationTest[
    FreeQ[ $workspaceInputCell, HoldPattern @ $WorkspaceChatInput ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell-NoKernelSymbol"
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
    TestID   -> "AttachedInputCell-FrontEndStorage"
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
    TestID   -> "AttachedInputCell-InitialBoxes"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*workspaceChatInput*)
VerificationTest[
    withTestInputCell[ { $testInputCell }, Wolfram`Chatbook`ChatModes`Common`workspaceChatInput @ $testNotebook ],
    Dynamic @ CurrentValue[ CellObject[ "ChatbookTestWorkspaceChatInput" ], { TaggingRules, "ChatInputString" } ],
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInput-AttachedCell"
]

(* Before the input cell is attached, the text is kept in $WorkspaceChatInput, which the new cell starts with: *)
VerificationTest[
    withTestInputCell[ { }, Wolfram`Chatbook`ChatModes`Common`workspaceChatInput @ $testNotebook ],
    Dynamic @ $WorkspaceChatInput,
    SameTest -> MatchQ,
    TestID   -> "WorkspaceChatInput-NoCell"
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
    TestID   -> "SaveWorkspaceChatInput-String"
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
    TestID   -> "SaveWorkspaceChatInput-Boxes"
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
    TestID   -> "SaveWorkspaceChatInput-NotStored"
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
    TestID   -> "SaveWorkspaceChatInput-NoCell"
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
    TestID   -> "SetWindowInput-AttachedCell"
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
    TestID   -> "SetWindowInput-NoCell"
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
    TestID   -> "SetWindowInput-NoInput"
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
    TestID   -> "SetWindowInput-Evaluate-AttachedCell"
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
    TestID   -> "SetWindowInput-Evaluate-NoCell"
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
    TestID   -> "NewChatWindow-KeepsInput"
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
    TestID   -> "NewChatWindow-Input"
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
    TestID   -> "NewChatWindow-NoWindow"
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
    TestID   -> "NewChatWindow-ReuseWindow"
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
    TestID   -> "EvaluateWorkspaceChat-CurrentValue-Blank"
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
    TestID   -> "EvaluateWorkspaceChat-CurrentValue"
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
    TestID   -> "EvaluateWorkspaceChat-Symbol-Blank"
]

(* :!CodeAnalysis::EndBlock:: *)
