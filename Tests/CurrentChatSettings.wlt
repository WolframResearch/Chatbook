(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" },
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CurrentChatSettings.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/CurrentChatSettings.wlt:11,1-16,2"
]

VerificationTest[
    Context @ CurrentChatSettings,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettingsContext@@Tests/CurrentChatSettings.wlt:18,1-23,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
VerificationTest[
    CurrentChatSettings[ ],
    KeyValuePattern[ (Rule|RuleDelayed)[ "Model", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:28,1-33,2"
]

VerificationTest[
    CurrentChatSettings[ "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:35,1-40,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoped*)
VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEnd, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:45,1-50,2"
]

VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEndSession, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:52,1-57,2"
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
    TestID   -> "CurrentChatSettings-Notebooks@@Tests/CurrentChatSettings.wlt:62,1-70,2"
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
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:75,1-93,2"
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
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:95,1-110,2"
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
    TestID   -> "CurrentChatSettings-Regression@@Tests/CurrentChatSettings.wlt:119,1-133,2"
]
