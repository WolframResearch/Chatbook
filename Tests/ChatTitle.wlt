(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ChatTitle.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ChatTitle.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*postProcessChatTitle*)

(* The length of a title is its number of characters, in any script: *)
VerificationTest[
    Wolfram`Chatbook`ChatTitle`Private`postProcessChatTitle[ 50, #, <| "StatusCode" -> 200 |> ] & /@ {
        "Plotting Sine and Cosine Functions with Fixed Axes",
        "Plotting Sine and Cosine Functions with Custom Axes",
        (* "Solving differential equations" in Russian (34 characters): *)
        "\:0420\:0435\:0448\:0435\:043d\:0438\:0435 \:0434\:0438\:0444\:0444\:0435\:0440\:0435\:043d\:0446\:0438\:0430\:043b\:044c\:043d\:044b\:0445 \:0443\:0440\:0430\:0432\:043d\:0435\:043d\:0438\:0439"
    },
    {
        "Plotting Sine and Cosine Functions with Fixed Axes",
        Failure[ "TitleLength", _ ],
        _String? (StringLength @ # === 34 &)
    },
    SameTest -> MatchQ,
    TestID   -> "PostProcessChatTitle-Length@@Tests/ChatTitle.wlt:26,1-40,2"
]

(* :!CodeAnalysis::EndBlock:: *)
