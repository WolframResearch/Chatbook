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
(*Empty Content*)

(* Content with no cells explodes to no cells instead of an internal failure: *)
VerificationTest[
    ExplodeCell @ Cell[ TextData @ { }, "ChatOutput" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ExplodeCell-EmptyTextData-GH#1583"
]

(* What FormatChatOutput gives for newline-only text, which is how the CreateNotebook tool calls ExplodeCell: *)
VerificationTest[
    ExplodeCell @ FormatChatOutput[ "\n", <| "Status" -> "Finished" |> ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ExplodeCell-NewlineOnly-GH#1583"
]

(* Cells removed in post-processing (missing images) can also leave nothing: *)
VerificationTest[
    ExplodeCell @ Cell[ TextData @ { Cell[ BoxData @ TemplateBox[ { }, "ImageNotFound" ], "Picture" ] }, "ChatOutput" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ExplodeCell-OnlyMissingImage-GH#1583"
]

VerificationTest[
    Block[ { NotebookPut = Identity },
        Wolfram`Chatbook`Tools`Private`createNotebook @ <| "content" -> "" |>
    ],
    KeyValuePattern[ "Result" -> Notebook[ { } ] ],
    SameTest -> MatchQ,
    TestID   -> "CreateNotebook-EmptyContent-GH#1583"
]

(* Non-empty content still explodes as before: *)
VerificationTest[
    ExplodeCell @ Cell[ TextData @ { "Hello" }, "ChatOutput" ],
    { Cell[ TextData @ { "Hello" }, "Text" ] },
    SameTest -> MatchQ,
    TestID   -> "ExplodeCell-Text"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*List Items*)

(* An item keeps all of its content, with or without inline formatting: *)
VerificationTest[
    ExplodeCell @ FormatChatOutput[
        "* An **important** item\n* plain\n  * A *nested* one with `code`",
        <| "Status" -> "Finished" |>
    ],
    {
        Cell[ TextData @ { "An ", StyleBox[ "important", FontWeight -> Bold ], " item" }, "Item" ],
        Cell[ TextData @ { "plain" }, "Item" ],
        Cell[ TextData @ { "A ", StyleBox[ "nested", FontSlant -> Italic ], " one with ", _ }, "Subitem" ]
    },
    SameTest -> MatchQ,
    TestID   -> "ExplodeCell-ItemsWithInlineFormatting"
]

(* :!CodeAnalysis::EndBlock:: *)
