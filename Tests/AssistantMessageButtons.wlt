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

(* Evaluates eval with the front end calls made by the hover action replaced by stubs, and returns the result together
   with the list of front end lookups that were made. The "Inherited" values are what AbsoluteCurrentValue gives for
   ChatNotebookSettings keys, "TaggingRules" are the cell's own tagging rules, and "Settings" is what the full
   CurrentChatSettings resolution gives. *)
VerificationTest[
    SetAttributes[ hoverTestStubs, HoldRest ];
    hoverTestStubs[ config_Association, eval_ ] :=
        Module[ { inherited, rules, settings, tags, calls, result },
            inherited = Lookup[ config, "Inherited"   , <| |> ];
            rules     = Lookup[ config, "TaggingRules", <| |> ];
            settings  = Lookup[ config, "Settings"    , <| |> ];
            tags      = Lookup[ config, "CellTags"    , { } ];
            calls     = { };
            result    = Block[
                {
                    AbsoluteCurrentValue = Function[
                        AppendTo[ calls, { "ACV", #2 } ];
                        Replace[
                            #2,
                            {
                                { TaggingRules, "ChatNotebookSettings", key_ } :> Lookup[ inherited, key, Inherited ],
                                Magnification -> 1.0,
                                _ -> Inherited
                            }
                        ]
                    ],
                    CurrentValue = Function[
                        AppendTo[ calls, { "CV", #2 } ];
                        Replace[ #2, { { TaggingRules, key_ } :> Lookup[ rules, key, Inherited ], _ -> Inherited } ]
                    ],
                    Wolfram`Chatbook`CurrentChatSettings = Function[ AppendTo[ calls, "CurrentChatSettings" ]; settings ],
                    Wolfram`Chatbook`Common`topParentCell = Identity,
                    Wolfram`Chatbook`Common`cellTaggedQ = Function[ MemberQ[ tags, #2 ] ],
                    Cells = Function[ AppendTo[ calls, "Cells" ]; { } ],
                    NotebookDelete = Function[ AppendTo[ calls, "NotebookDelete" ]; Null ],
                    AttachCell = Function[ AppendTo[ calls, { "AttachCell", { ## } } ]; CellObject[ "attached" ] ]
                },
                eval
            ];
            { result, calls }
        ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "HoverTestStubs-Definition"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*workspaceOrSidebarChatQ*)

(* In the notebook assistant window, WorkspaceChat is inherited from the notebook, so one lookup is enough: *)
VerificationTest[
    hoverTestStubs[
        <| "Inherited" -> <| "WorkspaceChat" -> True |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceOrSidebarChatQ @ CellObject[ "test" ]
    ],
    { True, { { "ACV", { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } } } },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOrSidebarChatQ-Workspace"
]

VerificationTest[
    hoverTestStubs[
        <| "Inherited" -> <| "SidebarChat" -> True |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceOrSidebarChatQ @ CellObject[ "test" ]
    ],
    {
        True,
        {
            { "ACV", { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } },
            { "ACV", { TaggingRules, "ChatNotebookSettings", "SidebarChat" } }
        }
    },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOrSidebarChatQ-Sidebar"
]

(* Regular chat notebooks fall back to resolving the full settings: *)
VerificationTest[
    hoverTestStubs[
        <| "Inherited" -> <| |>, "Settings" -> <| "WorkspaceChat" -> False |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceOrSidebarChatQ @ CellObject[ "test" ]
    ],
    { False, { { "ACV", _ }, { "ACV", _ }, "CurrentChatSettings" } },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOrSidebarChatQ-ChatNotebook"
]

(* A value that is not inherited (e.g. from a chat delimiter) is still found by the full settings resolution: *)
VerificationTest[
    hoverTestStubs[
        <| "Inherited" -> <| "WorkspaceChat" -> Inherited |>, "Settings" -> <| "SidebarChat" -> True |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`workspaceOrSidebarChatQ @ CellObject[ "test" ]
    ],
    { True, { { "ACV", _ }, { "ACV", _ }, "CurrentChatSettings" } },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOrSidebarChatQ-Fallback"
]

(* The result is the same as the full settings resolution that was used before, for every combination of values where
   an inherited True value is also True in the full settings (the full settings only differ from the inherited value if
   a chat delimiter overrides it): *)
VerificationTest[
    Module[ { values, configs },
        values  = { True, False, Inherited, $Failed };
        configs = Select[
            Flatten[
                Table[
                    <|
                        "Inherited" -> <| "WorkspaceChat" -> ws, "SidebarChat" -> sb |>,
                        "Settings"  -> DeleteCases[ <| "WorkspaceChat" -> fws, "SidebarChat" -> fsb |>, Missing ]
                    |>,
                    { ws, values }, { sb, values }, { fws, { True, False, Missing } }, { fsb, { True, False, Missing } }
                ],
                3
            ],
            And @@ Table[
                Implies[ TrueQ @ #[ "Inherited" ][ key ], TrueQ @ Lookup[ #[ "Settings" ], key ] ],
                { key, { "WorkspaceChat", "SidebarChat" } }
            ] &
        ];
        {
            Length @ configs,
            Union @ Map[
                Function[
                    config,
                    SameQ[
                        First @ hoverTestStubs[
                            config,
                            Wolfram`Chatbook`ChatModes`UI`Private`workspaceOrSidebarChatQ @ CellObject[ "test" ]
                        ],
                        First @ hoverTestStubs[
                            config,
                            Or @@ Lookup[
                                Wolfram`Chatbook`CurrentChatSettings @ CellObject[ "test" ],
                                { "WorkspaceChat", "SidebarChat" },
                                False,
                                TrueQ
                            ]
                        ]
                    ]
                ],
                configs
            ]
        }
    ],
    { _Integer? (# > 50 &), { True } },
    SameTest -> MatchQ,
    TestID   -> "WorkspaceOrSidebarChatQ-SameAsFullSettings"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*chatDataQ*)

(* Output cells written by reformatCell have a small flag, so the chat data itself is not read: *)
VerificationTest[
    hoverTestStubs[
        <| "TaggingRules" -> <| "ChatData" -> "abc", "HasChatData" -> True |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`chatDataQ @ CellObject[ "test" ]
    ],
    { True, { { "CV", { TaggingRules, "HasChatData" } } } },
    SameTest -> MatchQ,
    TestID   -> "ChatDataQ-Flag"
]

(* Cells written before the flag was added: *)
VerificationTest[
    hoverTestStubs[
        <| "TaggingRules" -> <| "ChatData" -> "abc" |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`chatDataQ @ CellObject[ "test" ]
    ],
    { True, { { "CV", { TaggingRules, "HasChatData" } }, { "CV", { TaggingRules, "ChatData" } } } },
    SameTest -> MatchQ,
    TestID   -> "ChatDataQ-NoFlag"
]

(* Cells that were restored from chat history have neither: *)
VerificationTest[
    hoverTestStubs[
        <| "TaggingRules" -> <| |> |>,
        Wolfram`Chatbook`ChatModes`UI`Private`chatDataQ @ CellObject[ "test" ]
    ],
    { False, { { "CV", { TaggingRules, "HasChatData" } }, { "CV", { TaggingRules, "ChatData" } } } },
    SameTest -> MatchQ,
    TestID   -> "ChatDataQ-NoChatData"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeReformattedCellTaggingRules*)
VerificationTest[
    $testReformattedRules = Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
        <| "Data" -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "Hello" |> } |> |>,
        "Hi there",
        Inherited,
        TextData[ "Hi there" ],
        Inherited
    ],
    KeyValuePattern @ { "CellToStringData" -> "Hi there", "ChatData" -> _String, "HasChatData" -> True },
    SameTest -> MatchQ,
    TestID   -> "ReformattedCellTaggingRules-HasChatData"
]

VerificationTest[
    BinaryDeserialize @ BaseDecode @ $testReformattedRules[ "ChatData" ],
    KeyValuePattern[ "Data" -> KeyValuePattern[ "Messages" -> { _, KeyValuePattern @ { "Role" -> "Assistant", "Content" -> "Hi there" } } ] ],
    SameTest -> MatchQ,
    TestID   -> "ReformattedCellTaggingRules-ChatData"
]

VerificationTest[
    Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
        <| "Data" -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "Hello" |> } |> |>,
        "Hi there",
        "[WARNING]",
        TextData[ "Hi there" ],
        <| "Pages" -> <| 1 -> "abc" |>, "PageCount" -> 1, "CurrentPage" -> 1 |>
    ],
    KeyValuePattern @ {
        "MessageTag"  -> "[WARNING]",
        "ChatData"    -> _String,
        "HasChatData" -> True,
        "PageData"    -> KeyValuePattern @ { "PageCount" -> 2, "CurrentPage" -> 2 }
    },
    SameTest -> MatchQ,
    TestID   -> "ReformattedCellTaggingRules-HasChatData-Pages"
]

(* No flag is written when there's no chat data: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$cloudNotebooks = True },
        Wolfram`Chatbook`SendChat`Private`makeReformattedCellTaggingRules[
            <| "Data" -> <| "Messages" -> { <| "Role" -> "User", "Content" -> "Hello" |> } |> |>,
            "Hi there",
            Inherited,
            TextData[ "Hi there" ],
            Inherited
        ]
    ],
    <| "CellToStringData" -> "Hi there" |>,
    SameTest -> MatchQ,
    TestID   -> "ReformattedCellTaggingRules-NoChatData"
]

(* The flag gives the same answer as checking the chat data directly: *)
VerificationTest[
    {
        First @ hoverTestStubs[
            <| "TaggingRules" -> $testReformattedRules |>,
            Wolfram`Chatbook`ChatModes`UI`Private`chatDataQ @ CellObject[ "test" ]
        ],
        StringQ @ $testReformattedRules[ "ChatData" ]
    },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ReformattedCellTaggingRules-ChatDataQ"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*assistantMessageButtons*)
VerificationTest[
    Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ],
    _DynamicModuleBox,
    SameTest -> MatchQ,
    TestID   -> "AssistantMessageButtons-Boxes"
]

(* The boxes are cached: *)
VerificationTest[
    MemberQ[
        DownValues @ Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons,
        HoldPattern[ Verbatim[ HoldPattern ][ Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ] ] :> _DynamicModuleBox ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AssistantMessageButtons-Cached"
]

(* The cached boxes are the same as freshly generated ones: *)
VerificationTest[
    Module[ { cached },
        cached = Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ];
        Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ] =.;
        SameQ[ cached, Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AssistantMessageButtons-CachedSameAsFresh"
]

(* Each combination of arguments gives its own buttons: *)
VerificationTest[
    Module[ { boxes, ids },
        boxes = Association @ Table[
            { feedback, sidebar } -> Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ feedback, sidebar ],
            { feedback, { True, False } },
            { sidebar, { True, False } }
        ];
        ids = Cases[ #, HoldPattern[ BoxID -> id_String ] :> id, Infinity, Heads -> True ] & /@ boxes;
        {
            CountDistinct @ Values @ boxes,
            Sort /@ ids,
            Cases[ #, HoldPattern @ ChatbookAction[ "RegenerateAssistantMessage", _, sidebar_ ] :> sidebar, Infinity ] & /@ boxes
        }
    ],
    {
        4,
        <|
            { True , True  } -> { "NARegenerateAssistantMessageButton", "NAThumbsDownButton", "NAThumbsUpButton" },
            { True , False } -> { "NARegenerateAssistantMessageButton", "NAThumbsDownButton", "NAThumbsUpButton" },
            { False, True  } -> { "NARegenerateAssistantMessageButton" },
            { False, False } -> { "NARegenerateAssistantMessageButton" }
        |>,
        <|
            { True , True  } -> { True },
            { True , False } -> { False },
            { False, True  } -> { True },
            { False, False } -> { False }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "AssistantMessageButtons-Arguments"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*attachAssistantMessageButtons*)

(* Notebook assistant window: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = None, Wolfram`Chatbook`Common`$dynamicText = False },
        hoverTestStubs[
            <|
                "Inherited"    -> <| "WorkspaceChat" -> True |>,
                "TaggingRules" -> <| "ChatData" -> "abc", "HasChatData" -> True |>
            |>,
            Wolfram`Chatbook`Common`attachAssistantMessageButtons @ CellObject[ "test" ]
        ]
    ],
    {
        CellObject[ "attached" ],
        {
            { "ACV", { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } },
            { "CV", { TaggingRules, "HasChatData" } },
            "Cells",
            "NotebookDelete",
            { "ACV", Magnification },
            {
                "AttachCell",
                {
                    CellObject[ "test" ],
                    Cell[ BoxData[ b_ ], "ChatOutputTrayButtons", Magnification -> 1.0 ],
                    { Left, Bottom },
                    Offset[ { 8, 0 }, Automatic ],
                    { Left, Top },
                    RemovalConditions -> "MouseExit"
                }
            } /; b === Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ True, False ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "AttachAssistantMessageButtons-Workspace"
]

(* Sidebar, chat restored from history: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = None, Wolfram`Chatbook`Common`$dynamicText = False },
        hoverTestStubs[
            <|
                "Inherited"    -> <| "SidebarChat" -> True |>,
                "TaggingRules" -> <| |>,
                "CellTags"     -> { "SidebarTopCell" }
            |>,
            Wolfram`Chatbook`Common`attachAssistantMessageButtons @ CellObject[ "test" ]
        ]
    ],
    {
        CellObject[ "attached" ],
        {
            { "ACV", { TaggingRules, "ChatNotebookSettings", "WorkspaceChat" } },
            { "ACV", { TaggingRules, "ChatNotebookSettings", "SidebarChat" } },
            { "CV", { TaggingRules, "HasChatData" } },
            { "CV", { TaggingRules, "ChatData" } },
            "Cells",
            "NotebookDelete",
            { "ACV", Magnification },
            {
                "AttachCell",
                {
                    CellObject[ "test" ],
                    Cell[ BoxData[ b_ ], "ChatOutputTrayButtons", Magnification -> 1.0 ],
                    { Left, Bottom },
                    Offset[ { 23, 30 }, Automatic ],
                    { Left, Top },
                    RemovalConditions -> "MouseExit"
                }
            } /; b === Wolfram`Chatbook`ChatModes`UI`Private`assistantMessageButtons[ False, True ]
        }
    },
    SameTest -> MatchQ,
    TestID   -> "AttachAssistantMessageButtons-Sidebar"
]

(* Regular chat notebooks don't get hover buttons: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = None, Wolfram`Chatbook`Common`$dynamicText = False },
        hoverTestStubs[
            <| "Settings" -> <| "WorkspaceChat" -> False, "SidebarChat" -> False |> |>,
            Wolfram`Chatbook`Common`attachAssistantMessageButtons @ CellObject[ "test" ]
        ]
    ],
    { Null, { { "ACV", _ }, { "ACV", _ }, "CurrentChatSettings" } },
    SameTest -> MatchQ,
    TestID   -> "AttachAssistantMessageButtons-ChatNotebook"
]

(* Nothing is attached while a chat is in progress: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatEvaluationCell = CellObject[ "evaluating" ], Wolfram`Chatbook`Common`$dynamicText = False },
        hoverTestStubs[
            <| "Inherited" -> <| "WorkspaceChat" -> True |> |>,
            Wolfram`Chatbook`Common`attachAssistantMessageButtons @ CellObject[ "test" ]
        ]
    ],
    { Null, { } },
    SameTest -> MatchQ,
    TestID   -> "AttachAssistantMessageButtons-ChatInProgress"
]

(* :!CodeAnalysis::EndBlock:: *)
