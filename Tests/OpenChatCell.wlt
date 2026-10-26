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

(* These tests simulate streamed chunks going through writeChunk0 with the front end calls replaced by stubs that record
   each call, to check when the output cell gets opened. Opening the cell is a no-op after the first time, so untagged
   responses should only make the front end calls once, while severity tagged responses behave as before. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $testInputCell  = CellObject[ "OpenChatCellTestInput"  ];
    $testOutputCell = CellObject[ "OpenChatCellTestOutput" ];

    (* Evaluates `eval` with front end calls replaced by stubs that sow a description of the call: *)
    withFrontEndStubs // Attributes = { HoldFirst };
    withFrontEndStubs[ eval_ ] := Block[
        {
            PreviousCell   = Function[ Sow[ { "PreviousCell", # }, $frontEndCall ]; $testInputCell ],
            Cells          = Function[ Sow[ { "Cells", { ## } }, $frontEndCall ]; { } ],
            NotebookDelete = Function[ Sow[ { "NotebookDelete", # }, $frontEndCall ]; Null ],
            SetOptions     = Function[ Sow[ { "SetOptions", { ## } }, $frontEndCall ]; Null ],
            Wolfram`Chatbook`Common`setCurrentValue = Function[ Sow[ { "setCurrentValue", { ## } }, $frontEndCall ]; Null ]
        },
        eval
    ];

    (* Returns the list of recorded front end calls made while evaluating `eval`: *)
    frontEndCalls // Attributes = { HoldFirst };
    frontEndCalls[ eval_ ] := Flatten[ Last @ Reap[ withFrontEndStubs @ eval, $frontEndCall, #2 & ], 1 ];

    (* Streams the chunks through writeChunk0 and returns the final content along with the front end calls per chunk: *)
    streamChunks[ chunks: { ___String }, alwaysOpen_, autoOpen_ ] :=
        Module[ { container, calls },
            container = <|
                "DynamicContent" -> ProgressIndicator[ Appearance -> "Percolate" ],
                "FullContent"    -> ProgressIndicator[ Appearance -> "Percolate" ],
                "UUID"           -> CreateUUID[ ]
            |>;
            Block[
                {
                    Wolfram`Chatbook`Common`$alwaysOpen             = alwaysOpen,
                    Wolfram`Chatbook`Common`$autoOpen               = autoOpen,
                    Wolfram`Chatbook`SendChat`Private`$dynamicSplit = False
                },
                calls = Function[
                    chunk,
                    frontEndCalls @ Wolfram`Chatbook`SendChat`Private`writeChunk0[
                        Dynamic @ container,
                        $testOutputCell,
                        chunk,
                        chunk
                    ]
                ] /@ chunks
            ];
            { container[ "FullContent" ], calls }
        ];

    (* The front end calls made by openChatCell: *)
    openCalls[ cell_ ] := {
        { "PreviousCell", cell },
        { "Cells", { $testInputCell, AttachedCell -> True, CellStyle -> "MinimizedChatIcon" } },
        { "NotebookDelete", { } },
        {
            "SetOptions",
            {
                cell,
                CellMargins     -> Inherited,
                CellOpen        -> Inherited,
                CellFrame       -> Inherited,
                ShowCellBracket -> Inherited,
                Initialization  -> Inherited
            }
        }
    };

    (* The front end calls made by processErrorCell, processWarningCell, and processInfoCell before opening: *)
    tagCalls[ cell_, tag_, style_ ] := {
        { "setCurrentValue", { cell, { TaggingRules, "MessageTag" }, tag } },
        { "SetOptions", { cell, style } }
    };
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Untagged Responses*)
VerificationTest[
    streamChunks[ { "Hello", " world", ", this", " is a", " test." }, True, True ],
    { "Hello world, this is a test.", { openCalls @ $testOutputCell, { }, { }, { }, { } } },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-Untagged"
]

VerificationTest[
    Module[ { content, calls },
        { content, calls } = streamChunks[ Characters[ "Hello world, this is a test." ], True, True ];
        { content, Length @ calls, First @ calls, Flatten[ Rest @ calls, 1 ] }
    ],
    { "Hello world, this is a test.", 28, openCalls @ $testOutputCell, { } },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-Untagged-ManyChunks"
]

(* A leading "[" could be the start of a severity tag, so the cell is only opened once the response is known to be
   untagged: *)
VerificationTest[
    streamChunks[ { "[", "Note", ": hello", " there" }, True, True ],
    { "[Note: hello there", { { }, { }, openCalls @ $testOutputCell, { } } },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-Untagged-AmbiguousStart"
]

(* Automatic assistance responses that are not always opened stay minimized unless they are tagged: *)
VerificationTest[
    streamChunks[ { "Hello", " world" }, False, False ],
    { "Hello world", { { }, { } } },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-Untagged-NotAlwaysOpen"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tagged Responses*)
VerificationTest[
    streamChunks[ { "[ERROR]", " Something", " went", " wrong" }, True, True ],
    {
        "Something went wrong",
        {
            Join[ tagCalls[ $testOutputCell, "[ERROR]", "AssistantOutputError" ], openCalls @ $testOutputCell ],
            openCalls @ $testOutputCell,
            { },
            { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-ErrorTagged"
]

VerificationTest[
    streamChunks[ { "[WARNING]", " Be", " careful" }, False, False ],
    {
        "Be careful",
        {
            Join[ tagCalls[ $testOutputCell, "[WARNING]", "AssistantOutputWarning" ], openCalls @ $testOutputCell ],
            { },
            { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-WarningTagged-NotAlwaysOpen"
]

VerificationTest[
    streamChunks[ { "[INFO]", " Some", " info" }, False, False ],
    { "Some info", { tagCalls[ $testOutputCell, "[INFO]", "AssistantOutput" ], { }, { } } },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-InfoTagged-NoAutoOpen"
]

VerificationTest[
    streamChunks[ { "[INFO]", " Some", " info" }, True, False ],
    {
        "Some info",
        { tagCalls[ $testOutputCell, "[INFO]", "AssistantOutput" ], openCalls @ $testOutputCell, { } }
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-InfoTagged-AlwaysOpen"
]

VerificationTest[
    streamChunks[ { "[INFO]", " Some", " info" }, True, True ],
    {
        "Some info",
        {
            Join[ tagCalls[ $testOutputCell, "[INFO]", "AssistantOutput" ], openCalls @ $testOutputCell ],
            openCalls @ $testOutputCell,
            { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-InfoTagged-AutoOpen"
]

(* Auto-correction can remove leading text, so a response that started out untagged can still become tagged later,
   which should be processed the same way as before even though the cell has already been opened: *)
VerificationTest[
    streamChunks[ { "<|image_", "sentinel|>[ERROR] Oops", " more", " text" }, True, True ],
    {
        "Oops more text",
        {
            openCalls @ $testOutputCell,
            Join[ tagCalls[ $testOutputCell, "[ERROR]", "AssistantOutputError" ], openCalls @ $testOutputCell ],
            { },
            { }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCell-TaggedAfterOpened"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*openChatCellOnce*)
VerificationTest[
    Module[ { container = <| "FullContent" -> "Hello" |>, other = CellObject[ "OpenChatCellTestOther" ], calls },
        calls = {
            frontEndCalls @ Wolfram`Chatbook`SendChat`Private`openChatCellOnce[ container, $testOutputCell ],
            frontEndCalls @ Wolfram`Chatbook`SendChat`Private`openChatCellOnce[ container, $testOutputCell ],
            frontEndCalls @ Wolfram`Chatbook`SendChat`Private`openChatCellOnce[ container, other ],
            frontEndCalls @ Wolfram`Chatbook`SendChat`Private`openChatCellOnce[ container, other ]
        };
        { calls, container }
    ],
    {
        { openCalls @ $testOutputCell, { }, openCalls @ CellObject[ "OpenChatCellTestOther" ], { } },
        <| "FullContent" -> "Hello", "OpenedCell" -> CellObject[ "OpenChatCellTestOther" ] |>
    },
    SameTest -> MatchQ,
    TestID   -> "OpenChatCellOnce-DifferentCells"
]

(* :!CodeAnalysis::EndBlock:: *)
