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
    TestID   -> "GetContextFromSelection-ExcludesSelectedAndUnselectedCells"
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
    TestID   -> "SelectContextCells-FiltersBeforeApplyingLimits"
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
    TestID   -> "SelectContextCells-SidebarFiltersBeforeApplyingLimits"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`Context`Private`selectContextCells @ {
        <| "CellObject" -> CellObject[ "first" ], "CursorPosition" -> "AboveCell" |>,
        <| "CellObject" -> CellObject[ "second" ], "CursorPosition" -> None |>
    },
    <| "Before" -> { }, "Selected" -> { }, "After" -> { CellObject[ "first" ], CellObject[ "second" ] } |>,
    SameTest -> MatchQ,
    TestID   -> "SelectContextCells-AboveCellIncludesFirstCell"
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
    TestID   -> "SelectContextCells-SidebarSelectionSurvivesToolLoop"
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
    TestID   -> "SelectContextCells-SidebarContextNotReusedAcrossChats"
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
    TestID   -> "GetContextFromSelection-SidebarDropsRemovedCellsDuringChat"
]

VerificationTest[
    Wolfram`Chatbook`ChatModes`ContentSuggestions`Private`$contentSuggestionsOverrides[ "Multimodal" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ContentSuggestions-DisablesMultimodalContext"
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
    TestID   -> "GetContextFromSelection-AboveFirstCell"
]

VerificationTest[
    Wolfram`Chatbook`Common`chatExcludedQ @ Cell[ "Text", "Text", TaggingRules -> "unexpected" ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ChatExcludedQ-ToleratesNonKeyValueTaggingRules"
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
    (* These test the context in the system prompt, which is only used without prompt cache optimization: *)
    $plotSettings = <|
        "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
        "Multimodal"              -> True,
        "PromptCacheOptimization" -> False
    |>;
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
    TestID   -> "MergeMessages-MergesUserHistoryAcrossContextImage"
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
    TestID   -> "SelectContextImages-PrefersSelectedAndNearbyImages"
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
    TestID   -> "SelectContextImages-NoSelectionPreservesNotebookOrder"
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
    TestID   -> "MergeMessages-MergesOutgoingTemporaryBoundaryAfterSaving"
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
    TestID   -> "FoldContextImageMessage-FoldsIntoNextNonTemporaryUserMessage"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Loop*)
VerificationTest[
    Module[ { cells, settings, marker, count, hasTags, first, data, saved, second, data2, saved2, third },
        cells    = { Cell[ "Project codename: SILVERFISH", "Text" ], Cell[ "1 + 1", "Input" ] };
        settings = <|
            "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
            "Multimodal"              -> False,
            "Prompts"                 -> { "CUSTOM-PROMPT-XYZ" },
            "UserInstructions"        -> "USER-INSTRUCTIONS-XYZ",
            "PromptCacheOptimization" -> False
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
    TestID   -> "AddPrompts-ToolLoopDoesNotRepeatContext"
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
    TestID   -> "ToolLoop-KeepsUserMessageImages"
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
    TestID   -> "ReplaceAddedPrompts-ReplacesEarlierSection"
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
    TestID   -> "AddPrompts-NoPromptKeepsMessages"
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
    TestID   -> "PrepareMessagesForLLM-RemovesAddedPromptTags"
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
    TestID   -> "PrepareMessagesForLLM-StripsAddedPromptsAfterGeneratedLeadingMessage"
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
    TestID   -> "PrepareMessagesForLLM-StripsAddedPromptsBeforeRoleConversion"
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
    TestID   -> "PrepareMessagesForHTTPRequest-StripsAddedPrompts"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Cache Optimization*)

(* Constructs the messages of the inputs of a workspace chat about the same notebook, evaluating changes[[ i ]][ nb ]
   before input i + 1. A change can also give settings to update for the later inputs. Each request gets the earlier
   requests' messages as history, including their turn messages, and starts without the context prompts for searches,
   like a new chat evaluation. Gives the requests, the context prompt for searches after the last request, and the last
   request built again (like regenerating its response): *)
workspaceInputs // Attributes = { HoldRest };
workspaceInputs[ cells_, settings0_Association, changes_List ] := UsingFrontEnd @ Module[
    { nb, settings, history, requests, request, data, contextPrompt },
    WithCleanup[
        nb = NotebookPut @ Notebook @ cells;
        SelectionMove[ First @ Cells @ nb, All, Cell ];
        settings = <|
            AbsoluteCurrentChatSettings @ nb,
            "AllowSelectionContext"   -> True,
            "ConversationUUID"        -> CreateUUID[ ],
            "FocusedNotebook"         -> nb,
            "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
            "Multimodal"              -> False,
            "PromptCacheOptimization" -> True,
            "PromptGenerators"        -> { },
            "Tools"                   -> { "NotebookReader" },
            settings0
        |>;
        Block[
            {
                Wolfram`Chatbook`$WorkspaceChat             = True,
                Wolfram`Chatbook`Common`$evaluationNotebook = nb,
                Wolfram`Chatbook`Common`$selectedTools      =
                    KeyTake[ Wolfram`Chatbook`$DefaultTools, settings[ "Tools" ] ],
                Wolfram`Chatbook`Common`$contextPrompt      = None,
                Wolfram`Chatbook`Common`$selectionPrompt    = None,
                Wolfram`Chatbook`$ChatHandlerData           = <| |>
            },
            history = {
                <| "Role" -> "System", "Content" -> "sys" |>,
                <| "Role" -> "User", "Content" -> "What is this?" |>
            };
            requests = { };
            Do[
                Wolfram`Chatbook`Common`$contextPrompt = Wolfram`Chatbook`Common`$selectionPrompt = None;
                { request, data } = Reap[
                    Wolfram`Chatbook`Common`constructMessages[ settings, history ],
                    Wolfram`Chatbook`Common`$chatDataTag
                ];
                AppendTo[ requests, request ];
                If[ i <= Length @ changes,
                    settings = <| settings, Replace[ changes[[ i ]][ nb ], Except[ _Association ] -> <| |> ] |>;
                    history  = Join[
                        Association[ Flatten @ data ][ "Messages" ],
                        {
                            <| "Role" -> "Assistant", "Content" -> "It's a notebook." |>,
                            <| "Role" -> "User", "Content" -> "And now?" |>
                        }
                    ]
                ],
                { i, Length @ changes + 1 }
            ];
            contextPrompt = Wolfram`Chatbook`Common`$contextPrompt;
            { requests, contextPrompt, Wolfram`Chatbook`Common`constructMessages[ settings, history ] }
        ],
        NotebookClose @ nb
    ]
];

(* The requests of two inputs with change[ nb ] in between. With extra = True, the result also includes the context
   prompt for searches after the second request, and the second request built again: *)
twoWorkspaceInputs // Attributes = { HoldRest };
twoWorkspaceInputs[ cells_, settings0_Association, change_ ] := First @ workspaceInputs[ cells, settings0, { change } ];
twoWorkspaceInputs[ cells_, settings0_Association, change_, True ] :=
    With[ { result = workspaceInputs[ cells, settings0, { change } ] }, Join[ First @ result, Rest @ result ] ];

$contextMarker = "IMPORTANT: Below is some metadata";
$codenameCells = { Cell[ "Project codename: SILVERFISH", "Text" ], Cell[ "1 + 1", "Input" ] };

contentString[ message_ ] := StringJoin @ Cases[ Flatten @ { message[ "Content" ] }, s_String | KeyValuePattern[ "Data" -> s_String ] :> s ];

(* The notebook context is sent after the user message instead of in the system prompt: *)
VerificationTest[
    Module[ { first },
        { first } = Take[ twoWorkspaceInputs[ $codenameCells, <| |>, Identity ], 1 ];
        {
            Lookup[ first, "Role" ],
            StringFreeQ[ contentString @ first[[ 1 ]], $contextMarker ],
            StringContainsQ[ contentString @ first[[ 3 ]], { $contextMarker, "SILVERFISH" }, IgnoreCase -> False ]
        }
    ],
    { { "System", "User", "System" }, True, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextTurnMessage"
]

(* It's only sent once, and nothing is added for the next input when nothing changed: *)
VerificationTest[
    Module[ { first, second },
        { first, second } = twoWorkspaceInputs[ $codenameCells, <| |>, Identity ];
        {
            Take[ KeyTake[ second, { "Role", "Content" } ], Length @ first ] === KeyTake[ first, { "Role", "Content" } ],
            Lookup[ Drop[ second, Length @ first ], "Role" ],
            StringCount[ StringJoin[ contentString /@ second ], $contextMarker ]
        }
    ],
    { True, { "Assistant", "User" }, 1 },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextOnce"
]

(* When the selection moved, the next input gets a short notice: *)
VerificationTest[
    Module[ { first, second, notice },
        { first, second } = twoWorkspaceInputs[ $codenameCells, <| |>, SelectionMove[ Last @ Cells @ #, All, Cell ] & ];
        notice = contentString @ Last @ second;
        {
            Lookup[ Drop[ second, Length @ first ], "Role" ],
            StringContainsQ[ notice, "moved their selection" ],
            StringFreeQ[ notice, { "has changed", $contextMarker } ]
        }
    ],
    { { "Assistant", "User", "System" }, True, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextSelectionMoved"
]

(* When the content changed, the next input gets a short notice: *)
VerificationTest[
    Module[ { first, second, notice },
        { first, second } = twoWorkspaceInputs[
            $codenameCells,
            <| |>,
            NotebookWrite[ Last @ Cells @ #, Cell[ "2 + 2", "Input" ] ] &
        ];
        notice = contentString @ Last @ second;
        { Lookup[ Drop[ second, Length @ first ], "Role" ], StringContainsQ[ notice, "the notebook has changed" ] }
    ],
    { { "Assistant", "User", "System" }, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextEdited"
]

(* Images in the notebook context are sent in a separate user message after it: *)
VerificationTest[
    Module[ { first },
        { first } = Take[
            twoWorkspaceInputs[
                { Cell[ "Some text", "Text" ], Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 2 Pi } ], "Output" ] },
                <| "Multimodal" -> True |>,
                Identity
            ],
            1
        ];
        {
            Lookup[ first, "Role" ],
            first[[ 2, "Content" ]],
            Count[ first[[ 4 ]], KeyValuePattern[ "Type" -> "Image" ], Infinity ]
        }
    ],
    { { "System", "User", "System", "User" }, "What is this?", 1 },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextImages"
]

(* Regenerating the response to the second input gives the notice again, since what the AI last saw comes from the
   history: *)
VerificationTest[
    Module[ { first, second, contextPrompt, again },
        { first, second, contextPrompt, again } = twoWorkspaceInputs[
            $codenameCells,
            <| |>,
            SelectionMove[ Last @ Cells @ #, All, Cell ] &,
            True
        ];
        { StringContainsQ[ contentString @ Last @ second, "moved their selection" ], again === second }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextRegenerate"
]

(* When nothing changed, prompt generators still get the notebook context for their searches: *)
VerificationTest[
    Module[ { first, second, contextPrompt, again },
        { first, second, contextPrompt, again } = twoWorkspaceInputs[ $codenameCells, <| |>, Identity, True ];
        StringContainsQ[ contextPrompt, "SILVERFISH" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextSearchPrompt"
]

(* When the NotebookReader tool is available, the notice says how to read the notebook, with the tool's name as the
   model knows it: *)
VerificationTest[
    Table[
        Block[
            {
                Wolfram`Chatbook`Common`$selectedTools    = KeyTake[ Wolfram`Chatbook`$DefaultTools, { "NotebookReader" } ],
                Wolfram`Chatbook`Common`$simpleToolMethod = simple
            },
            StringCases[
                Wolfram`Chatbook`ChatModes`Context`Private`notebookChangeHint[
                    { "Selection" },
                    <| "Info" -> <| "WindowTitle" -> "Test" |> |>,
                    <| |>
                ][ "Content" ],
                "use the " ~~ name: Except[ WhitespaceCharacter ].. ~~ " tool" :> name
            ]
        ],
        { simple, { False, True } }
    ],
    { { "notebook_reader" }, { "/nb_read" } },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextReaderNotice"
]

(* A notice is only sent once for each change: *)
VerificationTest[
    Module[ { requests },
        requests = First @ workspaceInputs[
            $codenameCells,
            <| |>,
            { SelectionMove[ Last @ Cells @ #, All, Cell ] &, Identity }
        ];
        StringCount[ StringJoin[ contentString /@ Last @ requests ], "moved their selection" ]
    ],
    1,
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextNoticeOnce"
]

(* Without the NotebookReader tool, the AI can't read the notebook, so the full context is sent again when something
   changed: *)
VerificationTest[
    Module[ { first, second },
        { first, second } = twoWorkspaceInputs[
            $codenameCells,
            <| "Tools" -> { } |>,
            SelectionMove[ Last @ Cells @ #, All, Cell ] &
        ];
        {
            StringCount[ StringJoin[ contentString /@ Drop[ second, Length @ first ] ], $contextMarker ],
            StringFreeQ[ StringJoin[ contentString /@ second ], "moved their selection" ]
        }
    ],
    { 1, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextWithoutReader"
]

(* The context is built without relative times, since it is sent again unchanged in later requests: *)
VerificationTest[
    Module[ { file, first, second, context },
        file = FileNameJoin @ { $TemporaryDirectory, "NotebookContext-" <> CreateUUID[ ] <> ".nb" };
        WithCleanup[
            { first, second } = twoWorkspaceInputs[
                $codenameCells,
                <| "Tools" -> { } |>,
                (NotebookSave[ #, file ]; NotebookWrite[ Last @ Cells @ #, Cell[ "2 + 2", "Input" ] ]) &
            ];
            context = StringJoin[ contentString /@ Drop[ second, Length @ first ] ];
            { StringContainsQ[ context, "MemoryModificationTime" ], StringFreeQ[ context, { "ago)", "just now" } ] },
            Quiet @ DeleteFile @ file
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextNoRelativeTimes"
]

(* After the user turns off notebook content, the content that was sent earlier is not sent again: *)
VerificationTest[
    Module[ { first, second },
        { first, second } = twoWorkspaceInputs[ $codenameCells, <| |>, <| "AllowSelectionContext" -> False |> & ];
        StringCount[ StringJoin[ contentString /@ second ], $contextMarker ]
    ],
    0,
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextTurnedOff"
]

(* After a change, prompt generators get a smaller context around the current selection for their searches: *)
VerificationTest[
    Module[ { first, second, contextPrompt, again },
        { first, second, contextPrompt, again } = twoWorkspaceInputs[
            $codenameCells,
            <| |>,
            SelectionMove[ Last @ Cells @ #, All, Cell ] &,
            True
        ];
        StringQ @ contextPrompt
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextSearchPromptChanged"
]

(* That context is not sent, so the base prompt components it needs are not kept (they would be sent as hints): *)
VerificationTest[
    Wolfram`Chatbook`Common`withBasePromptBuilder[
        twoWorkspaceInputs[
            { Cell[ "Some text", "Text" ], Cell[ BoxData @ ToBoxes @ Plot[ Sin[ x ], { x, 0, 2 Pi } ], "Output" ] },
            <| "Multimodal" -> True |>,
            SelectionMove[ Last @ Cells @ #, All, Cell ] &
        ];
        MemberQ[ Wolfram`Chatbook`Common`collectedBasePromptNames[ ], "ConversionGraphics" ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextSearchPromptHints"
]

(* Other chats don't get the notebook context as turn messages: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`$WorkspaceChat = False, Wolfram`Chatbook`$SidebarChat = False },
        Wolfram`Chatbook`Common`notebookContextTurnMessages[ <| "AllowSelectionContext" -> True |>, { } ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "PromptCache-NotebookContextOtherChats"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook Context Limits*)

(* The notebook context and NotebookReader pages don't grow with larger chat budgets: *)
VerificationTest[
    Lookup[
        Wolfram`Chatbook`ChatModes`Context`Private`downScaledSettings /@ {
            <| "MaxContextTokens" -> 2^15, "MaxCellStringLength" -> 16384, "MaxOutputCellStringLength" -> 1000 |>,
            <| "MaxContextTokens" -> 2^18, "MaxCellStringLength" -> 16384, "MaxOutputCellStringLength" -> 1000 |>
        },
        "MaxContextTokens"
    ],
    { 8192, 8192 },
    SameTest -> MatchQ,
    TestID   -> "NotebookContextLimits-DownScaledSettings"
]

(* Gives the length of a notebook context serialized in a chat with the given state of the chat's token budget: *)
chatContextLength // Attributes = { HoldFirst };
chatContextLength[ eval_, budget_, cellStringBudget_ ] := Block[
    {
        Wolfram`Chatbook`Common`$chatState               = True,
        Wolfram`Chatbook`Common`$tokenBudget             = budget,
        Wolfram`Chatbook`Common`$tokenPressure           = 0.0,
        Wolfram`Chatbook`Common`$initialCellStringBudget = 16384,
        Wolfram`Chatbook`Common`$cellStringBudget        = cellStringBudget
    },
    StringLength @ eval
];

(* In a chat, the notebook context is serialized with its own token budget, so it doesn't depend on the length of the
   history or grow with larger chat budgets: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt   = None,
            Wolfram`Chatbook`Common`$selectionPrompt = None,
            Wolfram`Chatbook`$ChatHandlerData        = <| |>
        },
        UsingFrontEnd @ Module[ { nb, settings, length },
            WithCleanup[
                nb = NotebookPut @ Notebook @ Table[ Cell[ StringRepeat[ "word ", 1000 ], "Text" ], 60 ];
                SelectionMove[ First @ Cells @ nb, All, Cell ];
                settings = <| AbsoluteCurrentChatSettings @ nb, "MaxContextTokens" -> 2^18, "Multimodal" -> False |>;
                length[ budget_, cellStringBudget_ ] := chatContextLength[
                    Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ],
                    budget,
                    cellStringBudget
                ];
                {
                    length[ 2^18, 16384 ] === length[ 2^10, 0 ],
                    10 * 5000 < length[ 2^18, 16384 ] < 0.8 * 51 * 5000
                },
                NotebookClose @ nb
            ]
        ]
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookContextLimits-ChatBudget"
]

(* The context is built in one pass over the cells whatever is selected, so a single selected cell or the caret in a
   cell gives as much of the notebook as the caret between two cells: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Common`$contextPrompt   = None,
            Wolfram`Chatbook`Common`$selectionPrompt = None,
            Wolfram`Chatbook`$ChatHandlerData        = <| |>
        },
        UsingFrontEnd @ Module[ { nb, cell, settings, passes, results },
            WithCleanup[
                nb = NotebookPut @ Notebook @ Table[ Cell[ StringRepeat[ "word ", 1000 ], "Text" ], 60 ];
                cell = Cells[ nb ][[ 30 ]];
                settings = <| AbsoluteCurrentChatSettings @ nb, "MaxContextTokens" -> 2^18, "Multimodal" -> False |>;
                results = Internal`InheritedBlock[ { Wolfram`Chatbook`Common`makeChatMessages },
                    PrependTo[
                        DownValues @ Wolfram`Chatbook`Common`makeChatMessages,
                        HoldPattern @ Wolfram`Chatbook`Common`makeChatMessages[ ___ ] /; (passes++; False) :> Null
                    ];
                    Table[
                        SelectionMove[ cell, Sequence @@ selection ];
                        passes = 0;
                        {
                            chatContextLength[
                                Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, nb, settings ],
                                2^18,
                                16384
                            ],
                            passes
                        },
                        { selection, { { After, Cell }, { All, Cell }, { Before, CellContents } } }
                    ]
                ];
                { results[[ All, 2 ]], Min @ results[[ All, 1 ]] > 0.9 * Max @ results[[ All, 1 ]] },
                NotebookClose @ nb
            ]
        ]
    ],
    { { 1, 1, 1 }, True },
    SameTest -> MatchQ,
    TestID   -> "NotebookContextLimits-OnePassWithSelectedCell"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cell Syntax*)

(* A chat that has the notebook tools gets its notebook context in the cell syntax (docs/cell-syntax.md), with the
   cell ids of the tools. cellSyntaxNotebook evaluates eval in such a Notebook Assistant chat about a notebook of the
   given cells ($cellSyntaxNotebook), whose settings are $cellSyntaxSettings. The tools work on the notebook itself,
   and the snapshot that an edit makes is a hidden copy of it ($cellSyntaxSnapshots; no released front end makes
   snapshots yet). The tools' state, the selected tools and the stores that reading writes to are Blocked, so that
   nothing is left for other tests. The tools are selected after the settings are resolved, which selects tools
   itself. *)
cellSyntaxNotebook // Attributes = { HoldRest };
cellSyntaxNotebook[ cells_List, eval_ ] := Block[
    {
        Wolfram`Chatbook`$WorkspaceChat                             = True,
        Wolfram`Chatbook`Common`$selectedTools                      = <| |>,
        Wolfram`Chatbook`Common`$contextPrompt                      = None,
        Wolfram`Chatbook`Common`$selectionPrompt                    = None,
        Wolfram`Chatbook`Common`$attachments                        = <| |>,
        Wolfram`Chatbook`Common`$notebookAttachments                = <| |>,
        Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshots     = <| |>,
        Wolfram`Chatbook`Tools`NotebookTools`Private`$snapshotCount = 0,
        Wolfram`Chatbook`Tools`NotebookTools`Private`$cellTables    = <| |>,
        $cellSyntaxNotebook, $cellSyntaxSettings, $cellSyntaxSnapshots = { }
    },
    UsingFrontEnd @ WithCleanup[
        $cellSyntaxNotebook = NotebookPut @ Notebook @ cells;
        $cellSyntaxSettings = <|
            AbsoluteCurrentChatSettings @ $cellSyntaxNotebook,
            "AllowSelectionContext" -> True,
            "FocusedNotebook"       -> $cellSyntaxNotebook,
            "Multimodal"            -> False
        |>;
        Wolfram`Chatbook`Common`$selectedTools = KeyTake[ Wolfram`Chatbook`$DefaultTools, $cellSyntaxTools ];
        Block[
            {
                Wolfram`Chatbook`Common`$evaluationNotebook = $cellSyntaxNotebook,
                Wolfram`Chatbook`$ChatHandlerData           = <| "ChatNotebookSettings" -> $cellSyntaxSettings |>
            },
            Internal`InheritedBlock[ { Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd },
                PrependTo[
                    DownValues @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd,
                    HoldPattern @ Wolfram`Chatbook`Tools`NotebookTools`Private`notebookFrontEnd[ "Snapshot", nb_NotebookObject ] :>
                        Last @ AppendTo[ $cellSyntaxSnapshots, NotebookPut[ NotebookGet[ nb, "IncludeUUIDs" -> True ], Visible -> False ] ]
                ];
                eval
            ]
        ],
        NotebookClose /@ Append[ $cellSyntaxSnapshots, $cellSyntaxNotebook ]
    ]
];

$cellSyntaxTools = { "NotebookReader", "ReadCells", "EditInCell" };

$cellSyntaxCells = {
    Cell[ "A title", "Title" ],
    Cell[ TextData @ { "Some ", StyleBox[ "bold", FontWeight -> "Bold" ], " text here" }, "Text", CellTags -> "intro" ],
    Cell[ BoxData @ RowBox @ { "x", "=", FractionBox[ "1", "2" ] }, "Input", CellLabel -> "In[1]:=" ],
    Cell[ BoxData @ FractionBox[ "1", "2" ], "Output", CellLabel -> "Out[1]=" ],
    Cell[ "print('a*b')", "Program" ]
};

(* The notebook context of the chat, the cells in it, and what a tool gives the model *)
cellSyntaxContext[ ] := Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, $cellSyntaxNotebook, $cellSyntaxSettings ];
cellSyntaxContent[ context_String ] := First[ StringCases[ context, "<content>\n" ~~ content__ ~~ "\n</content>" :> content, 1 ], None ];
cellSyntaxTool[ name_String, args_Association ] :=
    Replace[ Wolfram`Chatbook`$DefaultTools[ name ][ args ], KeyValuePattern[ "String" -> text_String ] :> text ];

(* The context as it is serialized in a chat, whose cells can be as long as cellStringBudget (see chatContextLength) *)
cellSyntaxChatContext[ cellStringBudget_ ] := Block[
    {
        Wolfram`Chatbook`Common`$chatState               = True,
        Wolfram`Chatbook`Common`$tokenBudget             = 2^18,
        Wolfram`Chatbook`Common`$tokenPressure           = 0.0,
        Wolfram`Chatbook`Common`$initialCellStringBudget = cellStringBudget,
        Wolfram`Chatbook`Common`$cellStringBudget        = cellStringBudget
    },
    cellSyntaxContext[ ]
];

(* The cells are in cell tags with their ids, and the markers of selected cells are lines between the tags. The reminder
   and the prompts for searches have the text without the cell tags, and the prompts for searches also without
   typeset content. Nothing changes from one request to the next. *)
VerificationTest[
    cellSyntaxNotebook[
        $cellSyntaxCells,
        SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 3 ]], All, Cell ];
        With[ { context = cellSyntaxContext[ ] },
            {
                cellSyntaxContent @ context,
                StringCases[ context, "Reminder: " ~~ ___ ~~ EndOfString ],
                Wolfram`Chatbook`Common`$selectionPrompt,
                Wolfram`Chatbook`Common`$contextPrompt,
                context === cellSyntaxContext[ ]
            }
        ]
    ],
    {
        "<cell id='c1' style='Title'>\nA title\n</cell>\n\n<cell id='c2' style='Text' CellTags='intro'>\nSome **bold** text here\n</cell>\n\n<selection>\n\n<cell id='c3' style='Input' CellLabel='In[1]:='>\nx = <RawBoxes>FractionBox[\"1\", \"2\"]</RawBoxes>\n</cell>\n\n</selection>\n\n<cell id='c4' style='Output' CellLabel='Out[1]='>\n(1/2)\n</cell>\n\n<cell id='c5' style='Program'>\nprint('a*b')\n</cell>",
        { "Reminder: The user's currently selected text is: \"x = <RawBoxes>FractionBox[\"1\", \"2\"]</RawBoxes>\"" },
        "x =",
        "A title\n\nSome **bold** text here\n\n<selection>\n\nx = \n\n</selection>\n\n(1/2)\n\nprint('a*b')",
        True
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-Context"
]

(* Without the notebook tools the context is the markdown that it always was *)
VerificationTest[
    cellSyntaxNotebook[
        $cellSyntaxCells,
        SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 3 ]], All, Cell ];
        Block[ { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ Wolfram`Chatbook`$DefaultTools, { "NotebookReader" } ] },
            cellSyntaxContent @ cellSyntaxContext[ ]
        ]
    ],
    "# A title\n\nSome **bold** text here\n\n<selection>\n\n```wl\nIn[1]:= x = (1/2)\n```\n\n</selection>\n\n```wl\nOut[1]= (1/2)\n```\n\n```\nprint('a*b')\n```",
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-WithoutTools"
]

(* The context, the NotebookReader tool and the notebook tools give the same cells: the same ids and the same text,
   also for a cell that has code blocks in its text, which the markdown context would merge. None of them makes a
   snapshot. *)
VerificationTest[
    cellSyntaxNotebook[
        Append[ $cellSyntaxCells, Cell[ "```wl\na = 1\n```\n\n```wl\nb = 2\n```", "Program" ] ],
        SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 3 ]], All, Cell ];
        With[ { context = cellSyntaxContext[ ], read = cellSyntaxTool[ "ReadCells", <| |> ] },
            {
                StringDelete[ cellSyntaxContent @ context, "<selection>\n\n" | "\n\n</selection>" ] === read,
                Wolfram`Chatbook`Common`readUserNotebook[ $cellSyntaxSettings, "selection", 1 ] === context,
                cellSyntaxContent @ Wolfram`Chatbook`Common`readUserNotebook[ $cellSyntaxSettings, "all", 1 ] === read,
                StringCount[ read, "<cell id='c" ],
                $cellSyntaxSnapshots
            }
        ]
    ],
    { True, True, True, 6, { } },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-SameAsTools"
]

(* A cell is edited with the id and the text that the context has for it, without reading it first. The edit is in the
   snapshot, and the user's notebook is as it was. *)
VerificationTest[
    cellSyntaxNotebook[
        $cellSyntaxCells,
        SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 1 ]], All, Cell ];
        Module[ { id, body },
            { id, body } = First @ StringCases[
                cellSyntaxContext[ ],
                "<cell id='" ~~ i: WordCharacter.. ~~ "' style='Input'" ~~ Except[ "\n" ]... ~~ "\n" ~~ Shortest[ b__ ] ~~ "\n</cell>" :> { i, b },
                1
            ];
            {
                id,
                StringStartsQ[
                    cellSyntaxTool[ "EditInCell", <| "cell" -> id, "edits" -> { <| "oldText" -> body, "newText" -> StringReplace[ body, "x = " -> "y = 3 " ] |> } |> ],
                    "Opened s1 "
                ],
                First @ NotebookRead[ Cells[ First @ $cellSyntaxSnapshots ][[ 3 ]] ],
                First @ NotebookRead[ Cells[ $cellSyntaxNotebook ][[ 3 ]] ]
            }
        ]
    ],
    {
        "c3",
        True,
        BoxData @ RowBox @ { "y", "=", RowBox @ { "3", " ", FractionBox[ "1", "2" ] } },
        BoxData @ RowBox @ { "x", "=", FractionBox[ "1", "2" ] }
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-EditFromContext"
]

(* A selection inside a cell is marked in its body: in text, in a string of a code cell (a Program cell), and as a caret
   in code. Styled text stays one piece of markdown, with the markers around it. Without the markers, the body is what
   the tools read for the cell. A formula has no place for a marker, so the whole cell is selected. *)
VerificationTest[
    cellSyntaxNotebook[
        Append[ $cellSyntaxCells, Cell[ BoxData @ FormBox[ RowBox @ { "x", "+", "y" }, TraditionalForm ], "DisplayFormula" ] ],
        Module[ { cells = Cells @ $cellSyntaxNotebook, selected, cell },
            cell[ text_, id_ ] := First[ StringCases[ text, "<cell id='" <> id <> "'" ~~ Shortest[ __ ] ~~ "</cell>" ], None ];
            selected[ n_Integer, find_ ] := (
                SelectionMove[ cells[[ n ]], Before, CellContents ];
                If[ StringQ @ find, NotebookFind[ $cellSyntaxNotebook, find, Next ] ];
                With[ { text = cellSyntaxContent @ cellSyntaxContext[ ], id = "c" <> ToString @ n },
                    {
                        StringCases[ text, StartOfLine ~~ Except[ "\n" ]... ~~ "selection>" ~~ Except[ "\n" ]... ~~ EndOfLine ],
                        Wolfram`Chatbook`Common`$selectionPrompt,
                        cell[ StringDelete[ text, "<selection>" | "</selection>" ], id ] === cellSyntaxTool[ "ReadCells", <| "cells" -> id |> ]
                    }
                ]
            );
            {
                selected[ 2, "text" ], selected[ 2, "ol" ], selected[ 2, "old text" ], selected[ 3, None ],
                selected[ 5, "a*b" ], selected[ 6, None ]
            }
        ]
    ],
    {
        { { "Some **bold** <selection>text</selection> here" }, "text", True },
        { { "Some <selection>**bold**</selection> text here" }, "**bold**", True },
        { { "Some <selection>**bold** text</selection> here" }, "**bold** text", True },
        { { "<selection></selection>x = <RawBoxes>FractionBox[\"1\", \"2\"]</RawBoxes>" }, None, True },
        { { "print('<selection>a*b</selection>')" }, "a*b", True },
        { { "<selection>", "</selection>" }, "$$x+y$$", True }
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-SelectionInCell"
]

(* A cell whose body the length limit of the context cuts says so in its tag (the tools refuse to write such a body
   back), and keeps its tags *)
VerificationTest[
    cellSyntaxNotebook[
        Table[ Cell[ "CELL-" <> ToString @ i <> " " <> StringRepeat[ "word ", 300 ] <> "END-" <> ToString @ i, "Text" ], { i, 4 } ],
        Block[ { $cellSyntaxSettings = <| $cellSyntaxSettings, "MaxCellStringLength" -> 800 |> },
            With[ { text = cellSyntaxContent @ cellSyntaxContext[ ] },
                {
                    StringCases[ text, "<cell" ~~ Except[ "\n" ]... ],
                    StringCount[ text, "\n</cell>" ],
                    StringLength @ text < 1200,
                    StringStartsQ[ cellSyntaxTool[ "ReadCells", <| "cells" -> "c1" |> ], "<cell id='c1' style='Text'>\nCELL-1 word" ]
                }
            ]
        ]
    ],
    {
        {
            "<cell id='c1' style='Text' truncated='true'>", "<cell id='c2' style='Text' truncated='true'>",
            "<cell id='c3' style='Text' truncated='true'>", "<cell id='c4' style='Text' truncated='true'>"
        },
        4,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-Truncated-CellLength"
]

(* The same for a cell that the token budget of the context cuts: here the one cell is larger than the whole budget *)
VerificationTest[
    cellSyntaxNotebook[
        { Cell[ "START " <> StringRepeat[ "word ", 6000 ] <> "END", "Text" ] },
        SelectionMove[ $cellSyntaxNotebook, After, Notebook ];
        Block[
            {
                $cellSyntaxSettings = <| $cellSyntaxSettings, "MaxCellStringLength" -> 200000 |>,
                Wolfram`Chatbook`ChatModes`Context`Private`$maxNotebookContextTokens = 1000
            },
            With[ { text = cellSyntaxContent @ cellSyntaxChatContext[ 50000 ] },
                {
                    StringCases[ text, "<cell" ~~ Except[ "\n" ]... ],
                    StringEndsQ[ text, "END\n</cell>\n\n<selection></selection>" ],
                    StringContainsQ[ text, "START word" ],
                    StringLength @ text < 6000
                }
            ]
        ]
    ],
    { { "<cell id='c1' style='Text' truncated='true'>" }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-Truncated-TokenBudget"
]

(* What is cut is the body. A tag that says truncated already is not marked twice, nothing is left of a cell if there
   is no room for a body, and text that is no cell is cut as before. *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Common`$includeCellXML = True },
        With[ { cell = "<cell id='c1' style='Text'>\n" <> StringRepeat[ "word ", 100 ] <> "\n</cell>" },
            {
                Wolfram`Chatbook`ChatMessages`Private`cutCellString[ cell, 150 ],
                Wolfram`Chatbook`ChatMessages`Private`cutCellString[ Wolfram`Chatbook`ChatMessages`Private`cutCellString[ cell, 150 ], 120 ],
                Wolfram`Chatbook`ChatMessages`Private`cutCellString[ cell, 60 ],
                Wolfram`Chatbook`ChatMessages`Private`cutCellString[ StringRepeat[ "word ", 100 ], 40 ]
            }
        ]
    ],
    {
        _String? (StringMatchQ[ #, "<cell id='c1' style='Text' truncated='true'>\nword word " ~~ __ ~~ " word \n</cell>" ] && StringLength @ # <= 150 &),
        _String? (StringMatchQ[ #, "<cell id='c1' style='Text' truncated='true'>\nword word " ~~ __ ~~ " word \n</cell>" ] && StringLength @ # <= 120 &),
        "",
        _String? (StringLength @ # <= 40 && StringFreeQ[ #, "cell" ] &)
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-Truncated-CutCellString"
]

(* The context of a notebook that is longer than the token budget of the context stays within that budget, as it does
   without the tools: the budget, the last cell, which is always shown, and the text around the cells (one cell here
   is about 1400 tokens). With the tools the cells are serialized once also when the selection is in a cell, so that
   the budget is not spent on a serialization that is not used: the context is then the same but for the markers. *)
VerificationTest[
    cellSyntaxNotebook[
        Table[ Cell[ "CELL-" <> ToString @ i <> " " <> StringRepeat[ "word ", 1000 ], "Text" ], { i, 60 } ],
        Module[ { tokens, on, off, selected },
            tokens[ context_String ] :=
                Wolfram`Chatbook`ChatMessages`Private`tokenCount[ $cellSyntaxSettings, <| "Role" -> "System", "Content" -> context |> ];
            SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 30 ]], After, Cell ];
            on  = cellSyntaxChatContext[ 16384 ];
            off = Block[ { Wolfram`Chatbook`Common`$selectedTools = <| |> }, cellSyntaxChatContext[ 16384 ] ];
            SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 30 ]], All, Cell ];
            selected = cellSyntaxChatContext[ 16384 ];
            {
                tokens @ on <= Wolfram`Chatbook`ChatModes`Context`Private`$maxNotebookContextTokens + 2000,
                Abs[ tokens @ on - tokens @ off ] < 1500,
                20 < StringCount[ on, "\n</cell>" ] < 50,
                StringDelete[ selected, "<selection>" | "</selection>" | "\n" ] === StringDelete[ on, "<selection>" | "</selection>" | "\n" ]
            }
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-TokenBudget"
]

(* If the context does not show every cell of the notebook, its last line names the others, as the ranges that ReadCells
   takes. The line does not look for cells that are excluded from chats: it says that those stay hidden, and ReadCells
   leaves them out and says so. WriteCells replaces a cell that the context showed, and not one that it only named. A context
   that shows every cell, and one of a chat without the tools, have no such line. *)
VerificationTest[
    cellSyntaxNotebook[
        ReplacePart[
            Table[ Cell[ "Cell " <> ToString @ i, "Text" ], { i, 12 } ],
            10 -> Cell[ "Not for chats", "Text", TaggingRules -> <| "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |> ]
        ],
        Module[ { context, write },
            context[ opts___ ] := Wolfram`Chatbook`ChatModes`Common`getContextFromSelection[ None, $cellSyntaxNotebook, $cellSyntaxSettings, opts ];
            write[ id_String ] := cellSyntaxTool[ "WriteCells", <| "cells" -> "<cell id='" <> id <> "'>\nNew text\n</cell>" |> ];
            SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 5 ]], All, Cell ];
            With[ { some = context[ "MaxCellsBeforeSelection" -> 2, "MaxCellsAfterSelection" -> 3 ] },
                {
                    StringCases[ some, "<cell id='" ~~ id: WordCharacter.. :> id ],
                    Last @ StringSplit[ some, "\n" ],
                    StringStartsQ[ write[ "c9" ], "c9 has not been shown whole in this chat" ],
                    StringContainsQ[ write[ "c4" ], "Wrote to s1: changed c4." ],
                    cellSyntaxTool[ "ReadCells", <| "cells" -> "c10-c11" |> ],
                    NotebookDelete @ Cells[ $cellSyntaxNotebook ][[ 10 ]];
                    StringCount[ context[ ], "<cell id='" | "[Not shown" ],
                    Block[ { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ Wolfram`Chatbook`$DefaultTools, { "NotebookReader" } ] },
                        StringFreeQ[ context[ "MaxCellsBeforeSelection" -> 2, "MaxCellsAfterSelection" -> 3 ], "Not shown" | "<cell" ]
                    ]
                }
            ]
        ]
    ],
    {
        { "c3", "c4", "c5", "c6", "c7", "c8" },
        "[Not shown: the cells c1-c2, c9-c12 of the notebook. ReadCells reads them, but not cells that the user excluded from AI chats: those stay hidden.]",
        True,
        True,
        "<cell id='c11' style='Text'>\nCell 11\n</cell>\n\n[1 cell that the user excluded from AI chats is left out.]",
        11,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-CellsNotShown"
]

(* A graphic is an image link in the body of its cell, in code and in an output, whether the chat gets images or not.
   A multimodal chat gets the images of the links, each after its link and under a label that calls them image links
   (there are no MarkdownImageBoxes in the cell syntax), and at most $maxContextImages of them, the ones next to the
   selection first. A chat without images gets none. *)
VerificationTest[
    cellSyntaxNotebook[
        {
            Cell[ "Some text", "Text" ],
            Cell[ BoxData @ RowBox @ { "ColorNegate", "[", ToBoxes @ Graphics[ { Red, Disk[ ] }, ImageSize -> 40 ], "]" }, "Input" ],
            Cell[ BoxData @ ToBoxes @ Graphics[ { Blue, Disk[ ] }, ImageSize -> 40 ], "Output" ]
        },
        SelectionMove[ Cells[ $cellSyntaxNotebook ][[ 2 ]], All, Cell ];
        Module[ { request, parts, messages, textOnly, links },
            request[ multimodal_ ] := Block[ { Wolfram`Chatbook`Common`$multimodalMessages = multimodal },
                Wolfram`Chatbook`Common`constructMessages[
                    <|
                        $cellSyntaxSettings,
                        "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
                        "Multimodal"              -> multimodal,
                        "PromptCacheOptimization" -> False,
                        "PromptGenerators"        -> { },
                        "Tools"                   -> { }
                    |>,
                    { <| "Role" -> "System", "Content" -> "sys" |>, <| "Role" -> "User", "Content" -> "What is this?" |> }
                ]
            ];
            parts[ content_ ] := Replace[ content, KeyValuePattern @ { "Type" -> type_, "Data" -> data_ } :> If[ type === "Image", Image, data ], { 1 } ];
            messages = request @ True;
            textOnly = request @ False;
            links = DeleteDuplicates @ StringCases[ messages[[ 1, "Content" ]], "![Image](attachment://content-" ~~ WordCharacter.. ~~ ")" ];
            {
                StringCases[ cellSyntaxContent @ messages[[ 1, "Content" ]], "<cell id='c" ~~ _ ~~ "' style='" ~~ ("Input" | "Output") ~~ "'>\n" ~~ Shortest[ body__ ] ~~ "\n</cell>" :> body ] ===
                    { "ColorNegate[" <> First @ links <> "]", Last @ links },
                cellSyntaxContent @ textOnly[[ 1, "Content" ]] === cellSyntaxContent @ messages[[ 1, "Content" ]],
                parts @ messages[[ 2, "Content" ]],
                { Length @ textOnly, textOnly[[ 2, "Content" ]], FreeQ[ textOnly, _Image | "Image" ] },
                Block[ { Wolfram`Chatbook`ChatModes`Context`Private`$maxContextImages = 1 },
                    Rest @ parts @ request[ True ][[ 2, "Content" ]] === { First @ links, Image, "What is this?" }
                ]
            }
        ]
    ],
    {
        True,
        True,
        {
            "[Original images for the image links in the notebook context. Each image follows its link. The user's message follows the images.]",
            _String? (StringMatchQ[ "![Image](attachment://content-" ~~ WordCharacter.. ~~ ")" ]),
            Image,
            _String? (StringMatchQ[ "![Image](attachment://content-" ~~ WordCharacter.. ~~ ")" ]),
            Image,
            "What is this?"
        },
        { 2, "What is this?", True },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-Images"
]

(* Without the notebook tools, the label of the images is the one for the MarkdownImageBoxes of the markdown context: *)
VerificationTest[
    Table[
        Block[ { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ Wolfram`Chatbook`$DefaultTools, tools ] },
            {
                Wolfram`Chatbook`ChatMessages`Private`makeContextImageMessage[ { { "![Image](attachment://content-abcde)", "image" } } ][[ "Content", 1, "Data" ]],
                Wolfram`Chatbook`ChatModes`Context`Private`notebookContextImageMessage[ { { "![Image](attachment://content-abcde)", "image" } } ][[ "Content", 1, "Data" ]]
            }
        ],
        { tools, { { "NotebookReader" }, $cellSyntaxTools } }
    ],
    {
        {
            "[Original images for the MarkdownImageBoxes in the notebook context. Each image follows its markdown link. The user's message follows the images.]",
            "[Original images for the MarkdownImageBoxes in the notebook content above. Each image follows its markdown link.]"
        },
        {
            "[Original images for the image links in the notebook context. Each image follows its link. The user's message follows the images.]",
            "[Original images for the image links in the notebook content above. Each image follows its link.]"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-ImageLabels"
]

(* A chat with the tools is told how to read the syntax, in its system prompt. Other chats are not. *)
VerificationTest[
    cellSyntaxNotebook[
        $cellSyntaxCells,
        Table[
            Block[ { Wolfram`Chatbook`Common`$selectedTools = KeyTake[ Wolfram`Chatbook`$DefaultTools, tools ] },
                StringContainsQ[
                    First[
                        Wolfram`Chatbook`Common`withBasePromptBuilder @ Wolfram`Chatbook`Common`constructMessages[
                            <|
                                $cellSyntaxSettings,
                                "Model"                   -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
                                "PromptCacheOptimization" -> False,
                                "PromptGenerators"        -> { },
                                "Tools"                   -> { }
                            |>,
                            { <| "Role" -> "System", "Content" -> "<base-prompt></base-prompt>" |>, <| "Role" -> "User", "Content" -> "Hi" |> }
                        ]
                    ][ "Content" ],
                    "Notebook cells are shown as <cell id='c3' style='Input'>"
                ]
            ],
            { tools, { $cellSyntaxTools, { "NotebookReader" } } }
        ]
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-BasePrompt"
]

(* With prompt cache optimization the context is sent once. When it has to be sent again (here there is no
   NotebookReader tool to read the change with), the cells have the ids that they had: a cell that is new gets the next
   id, wherever it is in the notebook. *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Tools`NotebookTools`Private`$cellTables = <| |>,
            Wolfram`Chatbook`Common`$attachments                     = <| |>,
            Wolfram`Chatbook`Common`$notebookAttachments             = <| |>
        },
        Module[ { first, second, ids },
            { first, second } = twoWorkspaceInputs[
                $codenameCells,
                (* the same chat for both requests (the test's requests only get handler data on the way) *)
                <| "Tools" -> { "ReadCells", "EditInCell" }, "ConversationUUID" -> None |>,
                (SelectionMove[ First @ Cells @ #, Before, Cell ]; NotebookWrite[ #, Cell[ "A new first cell", "Text" ] ]) &
            ];
            ids = StringCases[ contentString @ #, "<cell id='" ~~ id: WordCharacter.. ~~ "'" ~~ Except[ "\n" ]... ~~ "\n" ~~ line: Except[ "\n" ].. :> id -> line ] &;
            {
                ids @ first[[ 3 ]],
                Take[ KeyTake[ second, { "Role", "Content" } ], Length @ first ] === KeyTake[ first, { "Role", "Content" } ],
                ids @ Last @ second
            }
        ]
    ],
    {
        { "c1" -> "Project codename: SILVERFISH", "c2" -> "1 + 1" },
        True,
        { "c3" -> "A new first cell", "c1" -> "Project codename: SILVERFISH", "c2" -> "1 + 1" }
    },
    SameTest -> MatchQ,
    TestID   -> "CellSyntax-PromptCacheCellIDs"
]

(* :!CodeAnalysis::EndBlock:: *)
