(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/Context.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/Context.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Excluded Cells*)
VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, settings, selectedContext, unselectedContext },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "QA1", "Title" ],
                Cell[ "1 + 1", "Input" ],
                Cell[ "PUBLIC-111 visible text", "Text" ],
                Cell[ "SECRET-222 excluded text", { "Text", "ChatExcluded" } ]
            };
            cells = Cells @ nb;
            settings = AbsoluteCurrentChatSettings @ nb;

            SelectionMove[ cells[[ 4 ]], All, Cell ];
            selectedContext = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];

            SelectionMove[ cells[[ 2 ]], After, Cell ];
            unselectedContext = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];

            {
                StringContainsQ[ selectedContext, "PUBLIC-111" ],
                StringFreeQ[ selectedContext, "SECRET-222" ],
                StringContainsQ[ unselectedContext, "PUBLIC-111" ],
                StringFreeQ[ unselectedContext, "SECRET-222" ]
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-ExcludesSelectedAndUnselectedCells@@Tests/Context.wlt:24,1-54,2"
]

VerificationTest[
    Module[ { cell1, cell2, cell3, info },
        cell1 = CellObject[ "included-before-limit" ];
        cell2 = CellObject[ "excluded" ];
        cell3 = CellObject[ "selected" ];
        info = <|
            "Before" -> {
                <| "CellObject" -> cell1 |>,
                <| "CellObject" -> cell2, "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>
            },
            "Selected" -> { <| "CellObject" -> cell3 |> },
            "After" -> { }
        |>;
        Block[ { Wolfram`Chatbook`ChatModes`Context`Private`$maxCellsBeforeSelection = 1 },
            Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells0 @ info
        ]
    ],
    <| "Before" -> { CellObject[ "included-before-limit" ] }, "Selected" -> { CellObject[ "selected" ] }, "After" -> { } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-FiltersBeforeApplyingLimits@@Tests/Context.wlt:56,1-76,2"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ {
        <| "CellObject" -> CellObject[ "first" ], "CursorPosition" -> "AboveCell" |>,
        <| "CellObject" -> CellObject[ "second" ], "CursorPosition" -> None |>
    },
    <| "Before" -> { }, "Selected" -> { }, "After" -> { CellObject[ "first" ], CellObject[ "second" ] } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-AboveCellIncludesFirstCell@@Tests/Context.wlt:78,1-86,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb1, nb2, settings, context1, context2 },
        WithCleanup[
            nb1 = NotebookPut @ Notebook @ { Cell[ "Project codename: SILVERFISH", "Text" ] };
            nb2 = NotebookPut @ Notebook @ {
                Cell[ "Project codename: GOLDFISH", "Text" ],
                Cell[ "Second cell CATFISH", "Text" ]
            };
            settings = AbsoluteCurrentChatSettings @ nb1;
            context1 = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb1, settings ];
            context2 = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb2, settings ];
            {
                StringQ @ context1 && StringContainsQ[ context1, "SILVERFISH" ],
                StringQ @ context2 && StringContainsQ[ context2, "GOLDFISH" ],
                StringQ @ context2 && StringContainsQ[ context2, "CATFISH" ]
            },
            NotebookClose /@ { nb1, nb2 }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-AboveFirstCell@@Tests/Context.wlt:88,1-110,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`chatExcludedQ @ Cell[ "Text", "Text", TaggingRules -> "unexpected" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ChatExcludedQ-ToleratesNonKeyValueTaggingRules@@Tests/Context.wlt:112,1-117,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Selected Graphics*)
VerificationTest[
    $plotCells = {
        Cell[ "Some text", "Text" ],
        Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 2 Pi } ], "Output" ]
    };
    $plotQuestion = <| "Role" -> "User", "Content" -> "Describe the selected plot in one short sentence." |>;
    $plotInput    = { <| "Role" -> "System", "Content" -> "You are a helpful assistant." |>, $plotQuestion };
    $plotSettings = <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>, "Multimodal" -> True |>;
    { $plotMessages, $plotData } = Reap[
        ConstructWorkspaceContextMessages[ $plotCells, $plotSettings, $plotInput ],
        Wolfram`Chatbook`Common`$chatDataTag
    ];
    $plotSaved = Last @ Cases[ $plotData, KeyValuePattern[ "Messages" -> m_ ] :> m, Infinity ];
    { Length @ $plotMessages, Length @ $plotSaved },
    { 2, 3 },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphics-Setup"
]

VerificationTest[
    {
        Lookup[ $plotMessages, "Role" ],
        StringQ @ $plotMessages[[ 1, "Content" ]],
        Count[ $plotMessages[[ 1 ]], KeyValuePattern[ "Type" -> "Image" ], Infinity ],
        Count[ $plotMessages[[ 2 ]], KeyValuePattern[ "Type" -> "Image" ], Infinity ],
        Last @ $plotMessages[[ 2, "Content" ]]
    },
    {
        { "System", "User" },
        True,
        0,
        1,
        <| "Type" -> "Text", "Data" -> "Describe the selected plot in one short sentence." |>
    },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphicsFoldedIntoUserMessage"
]

VerificationTest[
    {
        DeleteCases[ $plotSaved, _? Wolfram`Chatbook`Common`temporaryMessageQ ][[ 2 ]],
        Wolfram`Chatbook`Common`$lastMessages[[ 3 ]]
    },
    { $plotQuestion, $plotQuestion },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphicsSavedWithoutImages"
]

VerificationTest[
    Module[ { toolLoop },
        toolLoop = ConstructWorkspaceContextMessages[
            $plotCells,
            $plotSettings,
            Join[
                $plotSaved,
                {
                    <| "Role" -> "Assistant", "Content" -> "calling tool", "ToolRequest" -> True |>,
                    <| "Role" -> "User", "Content" -> "<tool_response>2</tool_response>", "ToolResponse" -> True |>
                }
            ]
        ];
        {
            Lookup[ toolLoop, "Role" ],
            Count[ toolLoop, KeyValuePattern[ "Type" -> "Image" ], Infinity ]
        }
    ],
    { { "System", "User", "Assistant", "User" }, 1 },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphicsToolLoopSendsImagesOnce"
]

VerificationTest[
    Module[ { messages },
        messages = ConstructWorkspaceContextMessages[ $plotCells, <| $plotSettings, "Multimodal" -> False |>, $plotInput ];
        {
            Lookup[ messages, "Role" ],
            StringFreeQ[ messages[[ 1, "Content" ]], "MarkdownImageBox" ],
            FreeQ[ messages, KeyValuePattern[ "Type" -> "Image" ] ]
        }
    ],
    { { "System", "User" }, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphicsTextFallback"
]

VerificationTest[
    Module[ { img1, img2 },
        img1 = <| "Type" -> "Image", "Data" -> "img1" |>;
        img2 = <| "Type" -> "Image", "Data" -> "img2" |>;
        Wolfram`Chatbook`ChatModes`Context`Private`contextImageParts @ {
            <| "Role" -> "User", "Content" -> { "a ![Image](attachment://content-1)", img1 } |>,
            <| "Role" -> "User", "Content" -> { "b ![Image](attachment://content-1)", img1 } |>,
            <| "Role" -> "User", "Content" -> {
                <| "Type" -> "Text", "Data" -> "c ![Image](attachment://content-2)" |>,
                img2
            } |>
        }
    ],
    {
        { "![Image](attachment://content-1)", <| "Type" -> "Image", "Data" -> "img1" |> },
        { "![Image](attachment://content-2)", <| "Type" -> "Image", "Data" -> "img2" |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ContextImageParts-PairsLinksAndDeduplicates"
]

VerificationTest[
    Wolfram`Chatbook`ChatMessages`Private`mergeMessageData @ {
        <| "Role" -> "System", "Content" -> "sys" |>,
        <| "Role" -> "User", "Content" -> "temp", "Temporary" -> True |>,
        <| "Role" -> "User", "Content" -> "input" |>
    },
    {
        <| "Role" -> "System", "Content" -> "sys" |>,
        <| "Role" -> "User", "Content" -> "temp", "Temporary" -> True |>,
        <| "Role" -> "User", "Content" -> "input" |>
    },
    SameTest -> MatchQ,
    TestID   -> "MergeMessageData-KeepsTemporaryMessagesSeparate"
]

VerificationTest[
    Module[ { images, generated },
        images = Wolfram`Chatbook`ChatMessages`Private`makeContextImageMessage @ {
            { "![Image](attachment://content-1)", <| "Type" -> "Image", "Data" -> "img" |> }
        };
        generated = <|
            "Role"      -> "User",
            "Content"   -> { "result", <| "Type" -> "Image", "Data" -> "other" |> },
            "Temporary" -> True
        |>;
        Wolfram`Chatbook`ChatMessages`Private`foldContextImageMessage @ {
            <| "Role" -> "System", "Content" -> "sys" |>,
            images,
            <| "Role" -> "User", "Content" -> "input" |>,
            <| "Role" -> "Assistant", "Content" -> "out" |>,
            generated,
            <| "Role" -> "User", "Content" -> "next" |>
        }
    ],
    {
        <| "Role" -> "System", "Content" -> "sys" |>,
        <|
            "Role"    -> "User",
            "Content" -> {
                KeyValuePattern[ "Type" -> "Text" ],
                <| "Type" -> "Text", "Data" -> "\n![Image](attachment://content-1)" |>,
                <| "Type" -> "Image", "Data" -> "img" |>,
                <| "Type" -> "Text", "Data" -> "input" |>
            }
        |>,
        <| "Role" -> "Assistant", "Content" -> "out" |>,
        KeyValuePattern @ { "Content" -> { "result", _ }, "Temporary" -> True },
        <| "Role" -> "User", "Content" -> "next" |>
    },
    SameTest -> MatchQ,
    TestID   -> "FoldContextImageMessage-FoldsOnlyContextImageMessages"
]

(* :!CodeAnalysis::EndBlock:: *)

