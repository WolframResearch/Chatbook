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
(*Test Definitions*)
VerificationTest[
    $chatInputCell = CellObject[ "InlineReferencesChatInputCell" ];
    $inlineCell    = CellObject[ "InlineReferencesInlineCell" ];
    $testNotebook  = NotebookObject[ "InlineReferencesTestNotebook" ];

    (* Gives { inserted, writes }: the arguments passed to insertInlineReference and to NotebookWrite: *)
    insertionResult[ type_, cell_ ] := Module[ { inserted = None, writes = { } },
        Internal`InheritedBlock[
            { Wolfram`Chatbook`Common`parentNotebook },
            Wolfram`Chatbook`Common`parentNotebook[ cell ] = $testNotebook;
            Block[
                {
                    Developer`CellInformation = Replace[
                        {
                            $chatInputCell -> { "Style" -> "ChatInput" },
                            $inlineCell    -> { "InlineCellPosition" -> { 3 }, "Style" -> "InheritFromParent" }
                        }
                    ],
                    NotebookWrite = Function[ AppendTo[ writes, { ## } ]; Null ],
                    Wolfram`Chatbook`Actions`Private`$definitionNotebookLoaded = True,
                    Wolfram`Chatbook`Actions`Private`insertInlineReference = Function[ inserted = { ## }; Null ]
                },
                Wolfram`Chatbook`ChatbookAction[ "InsertInlineReference", type, cell ]
            ]
        ];
        { inserted, writes }
    ];

    Null,
    Null,
    SameTest -> SameQ,
    TestID   -> "InlineReferences-TestDefinitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Cells*)
VerificationTest[
    insertionResult[ "WLTemplate", $inlineCell ],
    { None, { { $testNotebook, "\\" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Backslash-GH#566"
]

VerificationTest[
    insertionResult[ "PersonaTemplate", $inlineCell ],
    { None, { { $testNotebook, "@" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-At-GH#566"
]

VerificationTest[
    insertionResult[ "FunctionTemplate", $inlineCell ],
    { None, { { $testNotebook, "!" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Exclamation-GH#566"
]

VerificationTest[
    insertionResult[ "ModifierTemplate", $inlineCell ],
    { None, { { $testNotebook, "#" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Hash-GH#566"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Input Cells*)
VerificationTest[
    insertionResult[ "WLTemplate", $chatInputCell ],
    { { "WLTemplate", $chatInputCell }, { } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-ChatInputCell-InsertsTemplate-GH#566"
]

(* :!CodeAnalysis::EndBlock:: *)
