(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    If[ ! TrueQ @ Wolfram`ChatbookTests`$TestDefinitionsLoaded,
        Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" }
    ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CurrentChatSettings.wlt:4,1-11,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CurrentChatSettings.wlt:13,1-18,2"
]

VerificationTest[
    Context @ CurrentChatSettings,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettingsContext@@Tests/CurrentChatSettings.wlt:20,1-25,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
VerificationTest[
    CurrentChatSettings[ ],
    KeyValuePattern[ (Rule|RuleDelayed)[ "Model", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:30,1-35,2"
]

VerificationTest[
    CurrentChatSettings[ "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:37,1-42,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoped*)
VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEnd, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:47,1-52,2"
]

VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEndSession, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:54,1-59,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebook Settings*)
VerificationTest[
    WithTestNotebook[
        CurrentChatSettings[ $TestNotebook, "Model" ],
        { "Model" -> "MyModelName" }
    ],
    "MyModelName",
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-Notebooks@@Tests/CurrentChatSettings.wlt:64,1-72,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chat Blocks*)
VerificationTest[
    WithTestNotebook[
        CurrentChatSettings[ #1, "Model" ] & /@ Cells @ $TestNotebook,
        {
            {
                "Hello",
                { Delimiter, "Model" -> "BlockModel" },
                "Hello2"
            }
        }
    ],
    {
        Except[ "BlockModel", KeyValuePattern @ { "Service" -> _String, "Name" -> _String } ],
        "BlockModel",
        "BlockModel"
    },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:77,1-95,2"
]

VerificationTest[
    WithTestNotebook[
        CurrentChatSettings[ #1, "Model" ] & /@ Cells @ $TestNotebook,
        {
            {
                "Hello",
                { Delimiter, "Model" -> "BlockModel" },
                "Hello2"
            },
            "Model" -> "NotebookModel"
        }
    ],
    { "NotebookModel", "BlockModel", "BlockModel" },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:97,1-112,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Regression Tests*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*#426*)
VerificationTest[
    Module[ { model = None, nbo },
        WithCleanup[
            nbo = CreateNotebook[
                DockedCells -> { Cell @ BoxData @ ToBoxes @ Dynamic[ model = CurrentChatSettings[ "Model" ] ] }
            ],
            TimeConstrained[ While[ model === None, Pause[ 0.1 ] ], 5 ];
            model,
            NotebookClose @ nbo
        ]
    ],
    Except[ _? FailureQ ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-Regression#426@@Tests/CurrentChatSettings.wlt:121,1-135,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*#592*)
VerificationTest[
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        Missing[ "TestSkipped" ],
        CloudEvaluate[ CurrentChatSettings[ "Model" ] ]
    ],
    Except[ _? FailureQ ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-Regression#592@@Tests/CurrentChatSettings.wlt:140,1-148,2"
]