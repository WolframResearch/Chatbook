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
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt   = None,
            Wolfram`Chatbook`Common`$selectionPrompt = None,
            Wolfram`Chatbook`$ChatHandlerData        = <| |>
        },
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
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-ExcludesSelectedAndUnselectedCells@@Tests/Context.wlt:24,1-61,2"
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
    TestID   -> "SelectContextCells-FiltersBeforeApplyingLimits@@Tests/Context.wlt:63,1-83,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, sidebarCell, workspace, sidebar },
        WithCleanup[
            nb = CreateDocument @ Join[
                Table[ Cell[ "included", "Text" ], 50 ],
                Flatten @ Table[
                    { Cell[ "included", "Text" ], Cell[ "excluded", { "Text", "ChatExcluded" } ] },
                    50
                ]
            ];
            cells = Cells @ nb;
            sidebarCell = First @ cells;
            SelectionMove[ nb, After, Notebook ];
            Block[ { Wolfram`Chatbook`ChatModes`Context`Private`$maxCellsBeforeSelection = 100 },
                workspace = Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ nb;
                Internal`InheritedBlock[
                    { Wolfram`Chatbook`ChatModes`Common`sidebarCellObject },
                    Wolfram`Chatbook`ChatModes`Common`sidebarCellObject[ _NotebookObject ] := sidebarCell;
                    Block[ { Wolfram`Chatbook`$SidebarChat = True },
                        sidebar = Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ nb
                    ]
                ]
            ];
            { sidebar === workspace, Length @ sidebar[ "Before" ] },
            NotebookClose @ nb
        ]
    ],
    { True, 100 },
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-SidebarFiltersBeforeApplyingLimits@@Tests/Context.wlt:85,1-115,2"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ {
        <| "CellObject" -> CellObject[ "first" ], "CursorPosition" -> "AboveCell" |>,
        <| "CellObject" -> CellObject[ "second" ], "CursorPosition" -> None |>
    },
    <| "Before" -> { }, "Selected" -> { }, "After" -> { CellObject[ "first" ], CellObject[ "second" ] } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-AboveCellIncludesFirstCell@@Tests/Context.wlt:117,1-125,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, sidebarCell, first, second, newCell },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "before", "Text" ],
                Cell[ "PartitionsP[417]", "Input" ],
                Cell[ "sidebar", "Text" ]
            };
            cells = Cells @ nb;
            sidebarCell = Last @ cells;
            Internal`InheritedBlock[
                { Wolfram`Chatbook`ChatModes`Common`sidebarCellObject },
                Wolfram`Chatbook`ChatModes`Common`sidebarCellObject[ _NotebookObject ] := sidebarCell;
                Block[
                    {
                        Wolfram`Chatbook`$SidebarChat                   = True,
                        Wolfram`Chatbook`Common`$chatState              = True,
                        Wolfram`Chatbook`Common`$sidebarSelectionContext = None
                    },
                    first = Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ nb;
                    SelectionMove[ Last @ cells, After, Cell ];
                    NotebookWrite[ nb, Cell[ "added during the chat", "Text" ] ];
                    newCell = Last @ Cells @ nb;
                    second = Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ nb
                ]
            ];
            {
                first[ "Before" ] === cells,
                second === first,
                FreeQ[ second, newCell ],
                MissingQ @ CurrentValue[ sidebarCell, { TaggingRules, "CurrentSelectionContext" } ] ||
                    CurrentValue[ sidebarCell, { TaggingRules, "CurrentSelectionContext" } ] === Inherited
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-SidebarSelectionSurvivesToolLoop@@Tests/Context.wlt:127,1-166,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { nb, cells, sidebarCell, select, first, second },
        WithCleanup[
            nb = CreateDocument @ {
                Cell[ "first", "Text" ],
                Cell[ "sidebar", "Text" ]
            };
            cells = Cells @ nb;
            sidebarCell = Last @ cells;
            select = Function[
                Wolfram`Chatbook`Common`withChatState @ Block[ { Wolfram`Chatbook`$SidebarChat = True },
                    Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ nb
                ]
            ];
            Internal`InheritedBlock[
                { Wolfram`Chatbook`ChatModes`Common`sidebarCellObject },
                Wolfram`Chatbook`ChatModes`Common`sidebarCellObject[ _NotebookObject ] := sidebarCell;
                first = select[ ];
                SelectionMove[ Last @ cells, After, Cell ];
                NotebookWrite[ nb, Cell[ "second chat", "Text" ] ];
                second = select[ ]
            ];
            {
                first[ "Before" ] === cells,
                second[ "Before" ] === Cells @ nb,
                Length @ second[ "Before" ] === 3,
                Wolfram`Chatbook`Common`$sidebarSelectionContext === None
            },
            NotebookClose @ nb
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-SidebarContextNotReusedAcrossChats@@Tests/Context.wlt:168,1-202,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt          = None,
            Wolfram`Chatbook`Common`$selectionPrompt        = None,
            Wolfram`Chatbook`$ChatHandlerData               = <| |>,
            Wolfram`Chatbook`$SidebarChat                   = True,
            Wolfram`Chatbook`Common`$chatState              = True,
            Wolfram`Chatbook`Common`$sidebarSelectionContext = None
        },
        UsingFrontEnd @ Module[ { nb, cells, sidebarCell, settings, deleted, replaced },
            WithCleanup[
                nb = CreateDocument @ {
                    Cell[ "Title", "Title" ],
                    Cell[ "ALPHA text", "Text" ],
                    Cell[ "BETA text", "Text" ],
                    Cell[ "GAMMA text", "Text" ],
                    Cell[ "sidebar", "Text" ]
                };
                cells = Cells @ nb;
                sidebarCell = Last @ cells;
                settings = AbsoluteCurrentChatSettings @ nb;
                Internal`InheritedBlock[
                    { Wolfram`Chatbook`ChatModes`Common`sidebarCellObject },
                    Wolfram`Chatbook`ChatModes`Common`sidebarCellObject[ _NotebookObject ] := sidebarCell;
                    Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];
                    NotebookDelete @ cells[[ 3 ]];
                    deleted = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ];
                    NotebookWrite[ cells[[ 4 ]], Cell[ "DELTA text", "Text" ] ];
                    replaced = Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ]
                ];
                {
                    StringQ @ deleted && StringContainsQ[ deleted, "ALPHA" ],
                    StringQ @ deleted && StringFreeQ[ deleted, "BETA" ],
                    StringQ @ deleted && StringContainsQ[ deleted, "GAMMA" ],
                    StringQ @ replaced && StringContainsQ[ replaced, "ALPHA" ],
                    StringQ @ replaced && StringFreeQ[ replaced, "GAMMA" ]
                },
                NotebookClose @ nb
            ]
        ]
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SidebarDropsRemovedCellsDuringChat@@Tests/Context.wlt:204,1-249,2"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`ContentSuggestions`Private`$contentSuggestionsOverrides[ "Multimodal" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ContentSuggestions-DisablesMultimodalContext@@Tests/Context.wlt:251,1-256,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt   = None,
            Wolfram`Chatbook`Common`$selectionPrompt = None,
            Wolfram`Chatbook`$ChatHandlerData        = <| |>
        },
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
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-AboveFirstCell@@Tests/Context.wlt:258,1-287,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`chatExcludedQ @ Cell[ "Text", "Text", TaggingRules -> "unexpected" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ChatExcludedQ-ToleratesNonKeyValueTaggingRules@@Tests/Context.wlt:289,1-294,2"
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
    TestID   -> "GetContextFromSelection-SelectedGraphics-Setup@@Tests/Context.wlt:299,1-316,2"
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
    TestID   -> "GetContextFromSelection-SelectedGraphicsFoldedIntoUserMessage@@Tests/Context.wlt:318,1-335,2"
]

VerificationTest[
    {
        DeleteCases[ $plotSaved, _? Wolfram`Chatbook`Common`temporaryMessageQ ][[ 2 ]],
        Wolfram`Chatbook`Common`$lastMessages[[ 3 ]]
    },
    { $plotQuestion, $plotQuestion },
    SameTest -> MatchQ,
    TestID   -> "GetContextFromSelection-SelectedGraphicsSavedWithoutImages@@Tests/Context.wlt:337,1-345,2"
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
    TestID   -> "GetContextFromSelection-SelectedGraphicsToolLoopSendsImagesOnce@@Tests/Context.wlt:347,1-368,2"
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
    TestID   -> "GetContextFromSelection-SelectedGraphicsTextFallback@@Tests/Context.wlt:370,1-382,2"
]

VerificationTest[
    Module[ { merged, unmerged },
        merged = ConstructWorkspaceContextMessages[
            $plotCells,
            $plotSettings,
            {
                <| "Role" -> "System", "Content" -> "sys" |>,
                <| "Role" -> "User", "Content" -> "FIRST" |>,
                <| "Role" -> "User", "Content" -> "SECOND" |>
            }
        ];
        unmerged = ConstructWorkspaceContextMessages[
            $plotCells,
            <| $plotSettings, "MergeMessages" -> False |>,
            {
                <| "Role" -> "System", "Content" -> "sys" |>,
                <| "Role" -> "User", "Content" -> "FIRST" |>,
                <| "Role" -> "User", "Content" -> "SECOND" |>
            }
        ];
        {
            Lookup[ merged, "Role" ],
            Count[ merged[[ 2, "Content" ]], s_String /; StringContainsQ[ s, "FIRST" ], Infinity ],
            Count[ merged[[ 2, "Content" ]], s_String /; StringContainsQ[ s, "SECOND" ], Infinity ],
            Count[ merged[[ 2 ]], KeyValuePattern[ "Type" -> "Image" ], Infinity ],
            Lookup[ unmerged, "Role" ]
        }
    ],
    { { "System", "User" }, 1, 1, 1, { "System", "User", "User" } },
    SameTest -> MatchQ,
    TestID   -> "MergeMessages-MergesUserHistoryAcrossContextImage@@Tests/Context.wlt:384,1-415,2"
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
    TestID   -> "ContextImageParts-PairsLinksAndDeduplicates@@Tests/Context.wlt:417,1-436,2"
]

VerificationTest[
    Module[ { links, content, context, selected },
        links = "![Image](attachment://content-" <> ToString[ # ] <> ")" & /@ Range[ 7 ];
        content = Flatten @ MapIndexed[
            { #1, <| "Type" -> "Image", "Data" -> "img" <> ToString @ First @ #2 |> } &,
            links
        ];
        context = StringRiffle[
            ReplacePart[
                links,
                4 -> Wolfram`Chatbook`Common`$leftSelectionIndicator <>
                     links[[ 4 ]] <>
                     Wolfram`Chatbook`Common`$rightSelectionIndicator
            ],
            "\n"
        ];
        selected = Wolfram`Chatbook`ChatModes`Context`Private`selectContextImages[
            { <| "Role" -> "User", "Content" -> content |> },
            context
        ];
        {
            Length @ selected,
            First @ selected,
            Cases[ selected, { link_String, _ } :> link ]
        }
    ],
    {
        5,
        { "![Image](attachment://content-4)", <| "Type" -> "Image", "Data" -> "img4" |> },
        {
            "![Image](attachment://content-4)",
            "![Image](attachment://content-3)",
            "![Image](attachment://content-5)",
            "![Image](attachment://content-2)",
            "![Image](attachment://content-6)"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "SelectContextImages-PrefersSelectedAndNearbyImages@@Tests/Context.wlt:438,1-477,2"
]

VerificationTest[
    Module[ { links, content },
        links = "![Image](attachment://content-" <> ToString[ # ] <> ")" & /@ Range[ 7 ];
        content = Flatten @ MapIndexed[
            { #1, <| "Type" -> "Image", "Data" -> "img" <> ToString @ First @ #2 |> } &,
            links
        ];
        Cases[
            Wolfram`Chatbook`ChatModes`Context`Private`selectContextImages[
                { <| "Role" -> "User", "Content" -> content |> },
                StringRiffle[ links, "\n" ]
            ],
            { link_String, _ } :> link
        ]
    ],
    "![Image](attachment://content-" <> ToString[ # ] <> ")" & /@ Range[ 5 ],
    SameTest -> MatchQ,
    TestID   -> "SelectContextImages-NoSelectionPreservesNotebookOrder@@Tests/Context.wlt:479,1-497,2"
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
    TestID   -> "MergeMessageData-KeepsTemporaryMessagesSeparate@@Tests/Context.wlt:499,1-512,2"
]

VerificationTest[
    Module[ { result, saved },
        saved = Wolfram`Chatbook`ChatMessages`Private`mergeMessageData @ {
            <| "Role" -> "System", "Content" -> "sys" |>,
            <| "Role" -> "Assistant", "Content" -> "tool call" |>,
            <| "Role" -> "System", "Content" -> "tool response" |>,
            <| "Role" -> "System", "Content" -> "retry", "Temporary" -> True |>
        };
        result = Wolfram`Chatbook`ChatMessages`Private`mergeOutgoingMessageData @ saved;
        {
            Lookup[ result, "Role" ],
            Last @ result,
            Lookup[ saved, "Role" ],
            Last @ saved
        }
    ],
    {
        { "System", "Assistant", "System" },
        KeyValuePattern[ "Content" -> { "tool response\n\nretry" } ],
        { "System", "Assistant", "System", "System" },
        KeyValuePattern @ { "Content" -> "retry", "Temporary" -> True }
    },
    SameTest -> MatchQ,
    TestID   -> "MergeMessages-MergesOutgoingTemporaryBoundaryAfterSaving@@Tests/Context.wlt:514,1-538,2"
]

VerificationTest[
    Module[ { images, generatedSystem, generatedUser },
        images = Wolfram`Chatbook`ChatMessages`Private`makeContextImageMessage @ {
            { "![Image](attachment://content-1)", <| "Type" -> "Image", "Data" -> "img" |> }
        };
        generatedSystem = <|
            "Role"      -> "System",
            "Content"   -> "generated system",
            "Temporary" -> True
        |>;
        generatedUser = <|
            "Role"      -> "User",
            "Content"   -> { "result", <| "Type" -> "Image", "Data" -> "other" |> },
            "Temporary" -> True
        |>;
        Wolfram`Chatbook`ChatMessages`Private`foldContextImageMessage @ {
            <| "Role" -> "System", "Content" -> "sys" |>,
            images,
            generatedSystem,
            generatedUser,
            <| "Role" -> "User", "Content" -> "input" |>,
            <| "Role" -> "Assistant", "Content" -> "out" |>
        }
    ],
    {
        <| "Role" -> "System", "Content" -> "sys" |>,
        KeyValuePattern @ { "Role" -> "System", "Content" -> "generated system", "Temporary" -> True },
        KeyValuePattern @ { "Content" -> { "result", _ }, "Temporary" -> True },
        <|
            "Role"    -> "User",
            "Content" -> {
                KeyValuePattern[ "Type" -> "Text" ],
                <| "Type" -> "Text", "Data" -> "\n![Image](attachment://content-1)" |>,
                <| "Type" -> "Image", "Data" -> "img" |>,
                <| "Type" -> "Text", "Data" -> "input" |>
            }
        |>,
        <| "Role" -> "Assistant", "Content" -> "out" |>
    },
    SameTest -> MatchQ,
    TestID   -> "FoldContextImageMessage-FoldsIntoNextNonTemporaryUserMessage@@Tests/Context.wlt:540,1-581,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Loop*)
VerificationTest[
    Module[ { cells, settings, marker, count, hasTags, first, data, saved, second, data2, saved2, third },
        cells    = { Cell[ "Project codename: SILVERFISH", "Text" ], Cell[ "1 + 1", "Input" ] };
        settings = <|
            "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
            "Multimodal"       -> False,
            "Prompts"          -> { "CUSTOM-PROMPT-XYZ" },
            "UserInstructions" -> "USER-INSTRUCTIONS-XYZ"
        |>;
        marker = "IMPORTANT: Below is some metadata";
        count  = Function[ messages,
            With[ { s = messages[[ 1, "Content" ]] },
                StringCount[ s, # ] & /@ { marker, "CUSTOM-PROMPT-XYZ", "USER-INSTRUCTIONS-XYZ", "SILVERFISH" }
            ]
        ];
        { first, data } = Reap[
            ConstructWorkspaceContextMessages[
                cells,
                settings,
                { <| "Role" -> "System", "Content" -> "sys" |>, <| "Role" -> "User", "Content" -> "hi" |> }
            ],
            Wolfram`Chatbook`Common`$chatDataTag
        ];
        saved = Last @ Cases[ data, KeyValuePattern[ "Messages" -> m_ ] :> m, Infinity ];
        { second, data2 } = Reap[
            ConstructWorkspaceContextMessages[
                cells,
                settings,
                Join[
                    saved,
                    {
                        <| "Role" -> "Assistant", "Content" -> "calling tool", "ToolRequest" -> True |>,
                        <| "Role" -> "User", "Content" -> "<tool_response>2</tool_response>", "ToolResponse" -> True |>
                    }
                ]
            ],
            Wolfram`Chatbook`Common`$chatDataTag
        ];
        saved2 = Last @ Cases[ data2, KeyValuePattern[ "Messages" -> m_ ] :> m, Infinity ];
        third = ConstructWorkspaceContextMessages[
            cells,
            settings,
            Join[
                saved2,
                {
                    <| "Role" -> "Assistant", "Content" -> "calling tool again", "ToolRequest" -> True |>,
                    <| "Role" -> "User", "Content" -> "<tool_response>3</tool_response>", "ToolResponse" -> True |>
                }
            ]
        ];
        hasTags = ! StringFreeQ[ #[[ 1, "Content" ]], "added-prompts" ] &;
        {
            count /@ { first, second, third },
            Function[
                chatMessages,
                hasTags @ Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
                    <| "ToolMethod" -> "Local" |>,
                    chatMessages
                ]
            ] /@ { first, second, third },
            hasTags /@ { saved, saved2 },
            StringStartsQ[ third[[ 1, "Content" ]], "sys" ]
        }
    ],
    { ConstantArray[ { 1, 1, 1, 1 }, 3 ], { False, False, False }, { True, True }, True },
    SameTest -> MatchQ,
    TestID   -> "AddPrompts-ToolLoopDoesNotRepeatContext@@Tests/Context.wlt:586,1-653,2"
]

(* The requests after a tool call are rebuilt from the saved messages, so they keep the images of the user's message,
   and send the same user message as the first request: *)
VerificationTest[
    Module[ { image, question, first, data, saved, second },
        image    = <| "Type" -> "Image", "Data" -> ConstantImage[ Red, { 8, 8 } ] |>;
        question = <|
            "Role"    -> "User",
            "Content" -> { <| "Type" -> "Text", "Data" -> "What color is this image?" |>, image }
        |>;
        { first, data } = Reap[
            ConstructWorkspaceContextMessages[
                $plotCells,
                $plotSettings,
                { <| "Role" -> "System", "Content" -> "sys" |>, question }
            ],
            Wolfram`Chatbook`Common`$chatDataTag
        ];
        saved  = Last @ Cases[ data, KeyValuePattern[ "Messages" -> m_ ] :> m, Infinity ];
        second = ConstructWorkspaceContextMessages[
            $plotCells,
            $plotSettings,
            Join[
                saved,
                {
                    <| "Role" -> "Assistant", "Content" -> "calling tool", "ToolRequest" -> True |>,
                    <| "Role" -> "User", "Content" -> "<tool_response>2</tool_response>", "ToolResponse" -> True |>
                }
            ]
        ];
        {
            Lookup[ second, "Role" ],
            (* One image from the selected plot, and the image from the user: *)
            Count[ first[[ 2 ]], KeyValuePattern[ "Type" -> "Image" ], Infinity ],
            Count[ second, KeyValuePattern[ "Type" -> "Image" ], Infinity ],
            MemberQ[ second[[ 2, "Content" ]], image ],
            second[[ 2 ]] === first[[ 2 ]]
        }
    ],
    { { "System", "User", "Assistant", "User" }, 2, 2, True, True },
    SameTest -> MatchQ,
    TestID   -> "ToolLoop-KeepsUserMessageImages@@Tests/Context.wlt:657,1-696,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`ChatMessages`Private`replaceAddedPrompts[ "sys", "ctx" ],
        Wolfram`Chatbook`ChatMessages`Private`replaceAddedPrompts[ "sys\n\n<added-prompts>old</added-prompts>", "new" ],
        Wolfram`Chatbook`ChatMessages`Private`replaceAddedPrompts[ "sys\n\n<added-prompts>old</added-prompts>", None ],
        Wolfram`Chatbook`Common`removeAddedPromptTags @ {
            <| "Role" -> "System", "Content" -> { <| "Type" -> "Text", "Data" -> "sys" |> } |>,
            <| "Role" -> "System", "Content" -> "<added-prompts>ctx</added-prompts>" |>,
            <| "Role" -> "User", "Content" -> "literal <added-prompts> text" |>
        }
    },
    {
        "sys\n\n<added-prompts>ctx</added-prompts>",
        "sys\n\n<added-prompts>new</added-prompts>",
        "sys",
        {
            <| "Role" -> "System", "Content" -> { <| "Type" -> "Text", "Data" -> "sys" |> } |>,
            <| "Role" -> "System", "Content" -> "ctx" |>,
            <| "Role" -> "User", "Content" -> "literal <added-prompts> text" |>
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ReplaceAddedPrompts-ReplacesEarlierSection@@Tests/Context.wlt:698,1-721,2"
]

VerificationTest[
    Module[ { listContent },
        listContent = {
            <| "Role" -> "System", "Content" -> { <| "Type" -> "Text", "Data" -> "sys" |> } |>,
            <| "Role" -> "User", "Content" -> "hi" |>
        };
        {
            Wolfram`Chatbook`ChatMessages`Private`addPrompts[ None, listContent ],
            Wolfram`Chatbook`ChatMessages`Private`addPrompts[ "", listContent ],
            Wolfram`Chatbook`ChatMessages`Private`addPrompts[
                None,
                { <| "Role" -> "System", "Content" -> "sys\n\n<added-prompts>old</added-prompts>" |> }
            ]
        } === { listContent, listContent, { <| "Role" -> "System", "Content" -> "sys" |> } }
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "AddPrompts-NoPromptKeepsMessages@@Tests/Context.wlt:723,1-741,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
        Module[ { result, submitted },
            result = Wolfram`Chatbook`AugmentChatMessages[
                { <| "Role" -> "System", "Content" -> "sys" |>, <| "Role" -> "User", "Content" -> "hi" |> },
                <|
                    "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
                    "Prompts"          -> { "CUSTOM-PROMPT-XYZ" },
                    "PromptGenerators" -> { },
                    "Tools"            -> { }
                |>
            ];
            submitted = Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
                <| "ToolMethod" -> "Local" |>,
                result
            ];
            {
                ListQ @ result,
                ! FreeQ[ result, s_String /; StringContainsQ[ s, "added-prompts" ] ],
                FreeQ[ submitted, s_String /; StringContainsQ[ s, "added-prompts" ] ],
                ! FreeQ[ submitted, s_String /; StringContainsQ[ s, "CUSTOM-PROMPT-XYZ" ] ]
            }
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "PrepareMessagesForLLM-RemovesAddedPromptTags@@Tests/Context.wlt:743,1-770,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
        Module[ { result, submitted },
            result = {
                <| "Role" -> "System", "Content" -> "GENERATED-DOCS-XYZ", "Temporary" -> True |>,
                <| "Role" -> "System", "Content" -> "sys\n\n<added-prompts>CUSTOM-PROMPT-XYZ</added-prompts>" |>,
                <| "Role" -> "User", "Content" -> "hi" |>
            };
            submitted = Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
                <| "ToolMethod" -> "Local" |>,
                result
            ];
            {
                result[[ 1, "Content" ]],
                FreeQ[ submitted, s_String /; StringContainsQ[ s, "added-prompts" ] ],
                ! FreeQ[ submitted, s_String /; StringContainsQ[ s, "CUSTOM-PROMPT-XYZ" ] ]
            }
        ]
    ],
    { "GENERATED-DOCS-XYZ", True, True },
    SameTest -> MatchQ,
    TestID   -> "PrepareMessagesForLLM-StripsAddedPromptsAfterGeneratedLeadingMessage@@Tests/Context.wlt:772,1-794,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
        Wolfram`Chatbook`SendChat`Private`prepareMessagesForLLM[
            <| "ToolMethod" -> "Local", "ConvertSystemRoleToUser" -> True |>,
            {
                <| "Role" -> "System", "Content" -> "sys\n\n<added-prompts>ctx</added-prompts>" |>,
                <| "Role" -> "User", "Content" -> "hi" |>
            }
        ]
    ],
    {
        KeyValuePattern @ { "Role" -> "User", "Content" -> "sys\n\nctx" },
        KeyValuePattern @ { "Role" -> "User", "Content" -> "hi" }
    },
    SameTest -> MatchQ,
    TestID   -> "PrepareMessagesForLLM-StripsAddedPromptsBeforeRoleConversion@@Tests/Context.wlt:796,1-812,2"
]

VerificationTest[
    Block[ { Wolfram`Chatbook`$ChatHandlerData = <| |> },
        Wolfram`Chatbook`SendChat`Private`prepareMessagesForHTTPRequest[
            <| "ToolMethod" -> "Local" |>,
            {
                <| "Role" -> "System", "Content" -> "sys\n\n<added-prompts>ctx</added-prompts>" |>,
                <| "Role" -> "User", "Content" -> "hi" |>
            }
        ]
    ],
    {
        KeyValuePattern @ { "role" -> "system", "content" -> "sys\n\nctx" },
        KeyValuePattern @ { "role" -> "user", "content" -> "hi" }
    },
    SameTest -> MatchQ,
    TestID   -> "PrepareMessagesForHTTPRequest-StripsAddedPrompts@@Tests/Context.wlt:814,1-830,2"
]

(* :!CodeAnalysis::EndBlock:: *)

