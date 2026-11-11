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
    Context @ CurrentChatSettings,
    "Wolfram`Chatbook`",
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettingsContext"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*CurrentChatSettings*)
VerificationTest[
    CurrentChatSettings[ ],
    KeyValuePattern[ (Rule|RuleDelayed)[ "Model", _ ] ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings"
]

VerificationTest[
    CurrentChatSettings[ "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String | Automatic } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scoped*)
VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEnd, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String | Automatic } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings"
]

VerificationTest[
    UsingFrontEnd @ CurrentChatSettings[ $FrontEndSession, "Model" ],
    KeyValuePattern @ { "Service" -> _String, "Name" -> _String | Automatic } | _String | Automatic,
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings"
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
    TestID   -> "CurrentChatSettings-Notebooks"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Chat Blocks*)
VerificationTest[
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        Missing[ "TestSkipped" ],
        WithTestNotebook[
            CurrentChatSettings[ #, "Model" ] & /@ Cells @ $TestNotebook,
            { { "Hello", { Delimiter, "Model" -> "BlockModel" }, "Hello2" } }
        ]
    ],
    Alternatives[
        Missing[ "TestSkipped" ],
        {
            Except[ "BlockModel", KeyValuePattern @ { "Service" -> _String, "Name" -> _String | Automatic } ],
            "BlockModel",
            "BlockModel"
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-ChatBlocks"
]

VerificationTest[
    If[ StringQ @ Environment[ "GITHUB_ACTIONS" ],
        Missing[ "TestSkipped" ],
        WithTestNotebook[
            CurrentChatSettings[ #, "Model" ] & /@ Cells @ $TestNotebook,
            { { "Hello", { Delimiter, "Model" -> "BlockModel" }, "Hello2" }, "Model" -> "NotebookModel" }
        ]
    ],
    Missing[ "TestSkipped" ] | { "NotebookModel", "BlockModel", "BlockModel" },
    SameTest -> MatchQ,
    TestID   -> "CurrentChatSettings-ChatBlocks"
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
    TestID   -> "CurrentChatSettings-Regression#426"
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
    TestID   -> "CurrentChatSettings-Regression#592"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*#1750*)
(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* An Ollama model with an Automatic name has no specific model to query for its context length: *)
VerificationTest[
    Wolfram`Chatbook`Settings`Private`autoMaxContextTokens @ <|
        "Model" -> <| "Service" -> "Ollama", "Name" -> Automatic |>
    |>,
    _Integer? Positive,
    SameTest -> MatchQ,
    TestID   -> "AutoMaxContextTokens-OllamaAutomaticModel-GH#1750"
]
(* :!CodeAnalysis::EndBlock:: *)