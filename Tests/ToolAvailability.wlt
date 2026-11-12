(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
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

VerificationTest[
    Needs[ "Wolfram`Chatbook`Tools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadToolsContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FileReader Definitions*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$DefaultTools, "FileReader" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FileReader-DefaultToolDefinition"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$ToolFunctions, "FileReader" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FileReader-ToolFunctionMap"
]

VerificationTest[
    Wolfram`Chatbook`Tools`Private`$toolNameAliases[ "ReadFile" ],
    "FileReader",
    SameTest -> SameQ,
    TestID   -> "FileReader-Alias"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FileReader Version Gating*)
VerificationTest[
    Wolfram`Chatbook`$DefaultTools[ "FileReader" ][ "Data" ][ "Enabled" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-Enabled"
]

VerificationTest[
    Wolfram`Chatbook`$DefaultTools[ "FileReader" ][ "Data" ][ "Hidden" ],
    ! TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-Hidden"
]

VerificationTest[
    MemberQ[ #[ "Name" ] & /@ Wolfram`Chatbook`ToolManager`Private`getFullToolList[ ], "file_reader" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-ToolManagerListing"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FileReader Tool Function*)
(* These tests require FormatUtilities`LLM`ReadFile (15.1+) and the ExampleData files that ship with documentation. *)
VerificationTest[
    If[ TrueQ[ $VersionNumber >= 15.1 ] && StringQ @ FindFile[ "ExampleData/50states.txt" ],
        Wolfram`Chatbook`Tools`Private`readFile @ <|
            "Path"             -> FindFile[ "ExampleData/50states.txt" ],
            "IncludePageImage" -> False,
            "DataOffset"       -> 1,
            "ElementIndex"     -> 1
        |>,
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | KeyValuePattern @ {
        "Result" -> _Association,
        "String" -> _String? (StringContainsQ[ #, "1: Alabama" ] && StringContainsQ[ #, "50: Wyoming" ] &)
    },
    SameTest -> MatchQ,
    TestID   -> "FileReader-ReadTextFile"
]

VerificationTest[
    If[ TrueQ[ $VersionNumber >= 15.1 ] && StringQ @ FindFile[ "ExampleData/50states.txt" ],
        Wolfram`Chatbook`Tools`Private`readFile @ <|
            "Path"       -> FindFile[ "ExampleData/50states.txt" ],
            "DataOffset" -> 48
        |>,
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | KeyValuePattern @ {
        "String" -> _String? (StringFreeQ[ #, "1: Alabama" ] && StringContainsQ[ #, "50: Wyoming" ] &)
    },
    SameTest -> MatchQ,
    TestID   -> "FileReader-DataOffset"
]

(* Optional parameters may be omitted entirely or arrive as empty strings/Missing (e.g. via the "Simple" tool method)
   and must not produce messages or change the result: *)
VerificationTest[
    If[ TrueQ[ $VersionNumber >= 15.1 ] && StringQ @ FindFile[ "ExampleData/50states.txt" ],
        Wolfram`Chatbook`Tools`Private`readFile @ <|
            "Path"             -> FindFile[ "ExampleData/50states.txt" ],
            "IncludePageImage" -> "",
            "DataOffset"       -> Missing[ "NoInput" ],
            "ElementIndex"     -> ""
        |>,
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | KeyValuePattern @ { "String" -> _String? (StringContainsQ[ "50: Wyoming" ]) },
    SameTest -> MatchQ,
    TestID   -> "FileReader-InvalidOptionalParameters"
]

(* The cell string budget can be Infinity, which must not break the byte budget passed to ReadFile: *)
VerificationTest[
    If[ TrueQ[ $VersionNumber >= 15.1 ] && StringQ @ FindFile[ "ExampleData/50states.txt" ],
        Block[ { Wolfram`Chatbook`Common`$initialCellStringBudget = Infinity },
            Wolfram`Chatbook`Tools`Private`readFile @ <| "Path" -> FindFile[ "ExampleData/50states.txt" ] |>
        ],
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | KeyValuePattern @ { "String" -> _String? (StringContainsQ[ "50: Wyoming" ]) },
    SameTest -> MatchQ,
    TestID   -> "FileReader-UnboundedBudget"
]

VerificationTest[
    If[ TrueQ[ $VersionNumber >= 15.1 ],
        Wolfram`Chatbook`Tools`Private`readFile @ <|
            "Path" -> FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] <> ".txt" }
        |>,
        Missing[ "TestSkipped" ]
    ],
    Missing[ "TestSkipped" ] | KeyValuePattern @ {
        "Result" -> _Failure,
        "String" -> _String? (StringStartsQ[ "Failure[" ])
    },
    SameTest -> MatchQ,
    TestID   -> "FileReader-MissingFile"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*NotebookReader*)
VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$DefaultTools, "NotebookReader" ],
    True,
    SameTest -> SameQ,
    TestID   -> "NotebookReader-DefaultToolDefinition"
]

(* Only sidebar and Notebook Assistant window chats have a user notebook to read: *)
VerificationTest[
    Table[
        Block[ { Wolfram`Chatbook`$WorkspaceChat = workspace, Wolfram`Chatbook`$SidebarChat = sidebar },
            Wolfram`Chatbook`$DefaultTools[ "NotebookReader" ][ "Data" ][ "Enabled" ]
        ],
        { workspace, { True, False } },
        { sidebar, { True, False } }
    ],
    { { True, True }, { True, False } },
    SameTest -> SameQ,
    TestID   -> "NotebookReader-Enabled"
]

VerificationTest[
    {
        Wolfram`Chatbook`$DefaultTools[ "NotebookReader" ][ "Data" ][ "Hidden" ],
        MemberQ[ #[ "Name" ] & /@ Wolfram`Chatbook`ToolManager`Private`getFullToolList[ ], "notebook_reader" ]
    },
    { True, False },
    SameTest -> SameQ,
    TestID   -> "NotebookReader-Hidden"
]

(* The tool is selected for the Notebook Assistant window and the sidebar, but not for chat notebooks, and not when
   notebook content is turned off (the sidebar's "Ignore notebook content" is checked by default): *)
VerificationTest[
    Map[
        Function[
            settings,
            Block[
                {
                    Wolfram`Chatbook`$ChatHandlerData       = Wolfram`Chatbook`$ChatHandlerData,
                    Wolfram`Chatbook`Common`$lastCellObject = Wolfram`Chatbook`Common`$lastCellObject,
                    Wolfram`Chatbook`Common`$lastTask       = Wolfram`Chatbook`Common`$lastTask,
                    Wolfram`Chatbook`Common`$tokenBudgetLog = Wolfram`Chatbook`Common`$tokenBudgetLog
                },
                MemberQ[
                    #[ "Data" ][ "CanonicalName" ] & /@ Wolfram`Chatbook`Common`withChatState[
                        Wolfram`Chatbook`Common`resolveAutoSettings[
                            <| Wolfram`Chatbook`Common`$defaultChatSettings, settings |>
                        ][ "Tools" ]
                    ],
                    "NotebookReader"
                ]
            ]
        ],
        {
            Wolfram`Chatbook`ChatModes`Common`$notebookAssistanceWorkspaceSettings,
            <|
                Wolfram`Chatbook`ChatModes`Common`$notebookAssistanceWorkspaceSettings,
                "AllowSelectionContext" -> False
            |>,
            Wolfram`Chatbook`NotebookAssistanceSidebarSettings[ ],
            <| Wolfram`Chatbook`NotebookAssistanceSidebarSettings[ ], "AllowSelectionContext" -> True |>,
            <| |>
        }
    ],
    { True, False, False, True, False },
    SameTest -> SameQ,
    TestID   -> "NotebookReader-SelectedTools"
]
(* :!CodeAnalysis::EndBlock:: *)
