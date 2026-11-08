(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/InlineReferences.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/InlineReferences.wlt:11,1-16,2"
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
    TestID   -> "InlineReferences-TestDefinitions@@Tests/InlineReferences.wlt:24,1-56,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Cells*)
VerificationTest[
    insertionResult[ "WLTemplate", $inlineCell ],
    { None, { { $testNotebook, "\\" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Backslash-GH#566@@Tests/InlineReferences.wlt:61,1-66,2"
]

VerificationTest[
    insertionResult[ "PersonaTemplate", $inlineCell ],
    { None, { { $testNotebook, "@" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-At-GH#566@@Tests/InlineReferences.wlt:68,1-73,2"
]

VerificationTest[
    insertionResult[ "FunctionTemplate", $inlineCell ],
    { None, { { $testNotebook, "!" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Exclamation-GH#566@@Tests/InlineReferences.wlt:75,1-80,2"
]

VerificationTest[
    insertionResult[ "ModifierTemplate", $inlineCell ],
    { None, { { $testNotebook, "#" } } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-InlineCell-Hash-GH#566@@Tests/InlineReferences.wlt:82,1-87,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Chat Input Cells*)
VerificationTest[
    insertionResult[ "WLTemplate", $chatInputCell ],
    { { "WLTemplate", $chatInputCell }, { } },
    SameTest -> SameQ,
    TestID   -> "InlineReferences-ChatInputCell-InsertsTemplate-GH#566@@Tests/InlineReferences.wlt:92,1-97,2"
]

(* :!CodeAnalysis::EndBlock:: *)
