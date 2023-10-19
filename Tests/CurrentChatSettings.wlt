(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" },
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/CurrentChatSettings.wlt:4,1-9,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
VerificationTest[
    CurrentChatSettings[ ],
    KeyValuePattern[ "Model" -> _ ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:14,1-19,2"
]

VerificationTest[
    CurrentChatSettings[ "Model" ],
    _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:21,1-26,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoped*)
VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEnd, "Model" ],
    _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:31,1-36,2"
]

VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEndSession, "Model" ],
    _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings@@Tests/CurrentChatSettings.wlt:38,1-43,2"
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
    TestID   -> "CurrentChatSettings-Notebooks@@Tests/CurrentChatSettings.wlt:48,1-56,2"
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
    { Except[ "BlockModel", _String ], "BlockModel", "BlockModel" },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:61,1-75,2"
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
    TestID   -> "CurrentChatSettings-ChatBlocks@@Tests/CurrentChatSettings.wlt:77,1-92,2"
]
