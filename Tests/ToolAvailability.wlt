(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ToolAvailability.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ToolAvailability.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`Tools`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadToolsContext@@Tests/ToolAvailability.wlt:18,1-23,2"
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
    TestID   -> "FileReader-DefaultToolDefinition@@Tests/ToolAvailability.wlt:30,1-35,2"
]

VerificationTest[
    KeyExistsQ[ Wolfram`Chatbook`$ToolFunctions, "FileReader" ],
    True,
    SameTest -> SameQ,
    TestID   -> "FileReader-ToolFunctionMap@@Tests/ToolAvailability.wlt:37,1-42,2"
]

VerificationTest[
    Wolfram`Chatbook`Tools`Private`$toolNameAliases[ "ReadFile" ],
    "FileReader",
    SameTest -> SameQ,
    TestID   -> "FileReader-Alias@@Tests/ToolAvailability.wlt:44,1-49,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*FileReader Version Gating*)
VerificationTest[
    Wolfram`Chatbook`$DefaultTools[ "FileReader" ][ "Data" ][ "Enabled" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-Enabled@@Tests/ToolAvailability.wlt:54,1-59,2"
]

VerificationTest[
    Wolfram`Chatbook`$DefaultTools[ "FileReader" ][ "Data" ][ "Hidden" ],
    ! TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-Hidden@@Tests/ToolAvailability.wlt:61,1-66,2"
]

VerificationTest[
    MemberQ[ #[ "Name" ] & /@ Wolfram`Chatbook`ToolManager`Private`getFullToolList[ ], "file_reader" ],
    TrueQ @ ( $VersionNumber >= 15.1 ),
    SameTest -> SameQ,
    TestID   -> "FileReader-ToolManagerListing@@Tests/ToolAvailability.wlt:68,1-73,2"
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
    TestID   -> "FileReader-ReadTextFile@@Tests/ToolAvailability.wlt:79,1-95,2"
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
    TestID   -> "FileReader-DataOffset@@Tests/ToolAvailability.wlt:97,1-110,2"
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
    TestID   -> "FileReader-InvalidOptionalParameters@@Tests/ToolAvailability.wlt:114,1-127,2"
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
    TestID   -> "FileReader-UnboundedBudget@@Tests/ToolAvailability.wlt:130,1-140,2"
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
    TestID   -> "FileReader-MissingFile@@Tests/ToolAvailability.wlt:142,1-155,2"
]
(* :!CodeAnalysis::EndBlock:: *)
