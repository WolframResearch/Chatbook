(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PreferencesContent.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PreferencesContent.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resetChatPreferences*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Notebooks Tab*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, cache, model, after },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        model    = <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>;
        WithCleanup[
            CurrentChatSettings[ $FrontEnd, "ToolSelectionType" ] = <| "WebSearcher" -> All |>;
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas"   ] = { "Birdnardo", "CodeAssistant" };
            CurrentChatSettings[ $FrontEnd, "Model"               ] = model;
            CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ] = <| "OpenAI" -> "gpt-4.1" |>;
            CurrentChatSettings[ $FrontEnd, "Temperature"         ] = 0.3;
            CurrentChatSettings[ $FrontEnd, "UserInstructions"    ] = "qa";
            Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Notebooks" ];
            after = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
            {
                Lookup[ after, "ToolSelectionType" ],
                Lookup[ after, "VisiblePersonas"   ],
                KeyExistsQ[ after, "Model"               ],
                KeyExistsQ[ after, "ServiceDefaultModel" ],
                KeyExistsQ[ after, "Temperature"         ],
                KeyExistsQ[ after, "UserInstructions"    ],
                AssociationQ @ cache,
                Lookup[ cache, "Model" ] =!= model
            },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    {
        <| "WebSearcher" -> All |>,
        { "Birdnardo", "CodeAssistant" },
        False,
        False,
        False,
        False,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Notebooks-PreservesOtherTabs@@Tests/PreferencesContent.wlt:28,1-67,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { original, before, after, cache },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            CurrentChatSettings[ $FrontEnd, "Temperature" ] = 0.3;
            before = Keys @ CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
            Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Notebooks" ];
            after = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
            {
                SubsetQ[ before, Keys @ Replace[ after, Except[ _Association ] -> <| |> ] ],
                Intersection[
                    Keys @ Replace[ after, Except[ _Association ] -> <| |> ],
                    Wolfram`Chatbook`PreferencesContent`Private`$notebooksTabSettingKeys
                ]
            },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Notebooks-NoDefaultsWritten@@Tests/PreferencesContent.wlt:69,1-91,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Services Tab*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, cache, trigger, service, model, state, modelNameSelector },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            CurrentChatSettings[ $FrontEnd, "Model" ] = <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>;
            cache   = CurrentChatSettings[ $FrontEnd ];
            trigger = Wolfram`Chatbook`Dynamics`Private`$preferencesTrigger;
            Needs[ "LLMServices`" -> None ];
            Block[ { LLMServices`ResetServices },
                Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Services" ]
            ];
            cache   = CurrentChatSettings[ $FrontEnd ];
            service = Wolfram`Chatbook`PreferencesContent`Private`extractServiceName @ Lookup[ cache, "Model" ];
            model   = Wolfram`Chatbook`PreferencesContent`Private`extractModelName @ Lookup[ cache, "Model" ];
            state   = "Loaded";
            modelNameSelector = Wolfram`Chatbook`Common`catchAlways @
                Wolfram`Chatbook`PreferencesContent`Private`makeModelNameSelector[
                    cache,
                    service,
                    model,
                    modelNameSelector,
                    state
                ];
            {
                Wolfram`Chatbook`Dynamics`Private`$preferencesTrigger > trigger,
                service,
                modelNameSelector
            },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { True, "LLMKit", "" },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Services-RebuildsPanel@@Tests/PreferencesContent.wlt:96,1-131,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { boxes1, boxes2 },
        boxes1 = ToBoxes @ Wolfram`Chatbook`Common`createPreferencesContent[ ];
        boxes2 = ToBoxes @ Wolfram`Chatbook`Common`createPreferencesContent[ ];
        { MatchQ[ boxes1, _DynamicModuleBox ], boxes1 =!= boxes2 }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "CreatePreferencesContent-UniqueBoxesPerRebuild@@Tests/PreferencesContent.wlt:133,1-142,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, file, stored },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        file     = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] <> ".wxf" };
        WithCleanup[
            Developer`WriteWXFFile[
                file,
                <|
                    "Model"             -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
                    "ToolSelectionType" -> <| "WebSearcher" -> All |>,
                    "VisiblePersonas"   -> { "Birdnardo" },
                    "Temperature"       -> 0.3,
                    "UserInstructions"  -> "qa"
                |>
            ];
            Block[
                {
                    $CloudEvaluation = True,
                    Wolfram`Chatbook`Settings`Private`$globalSettingsFile = file,
                    Wolfram`Chatbook`Settings`Private`$cachedGlobalSettings
                },
                Wolfram`Chatbook`Common`unsetChatSettingsKeys[
                    $FrontEnd,
                    Wolfram`Chatbook`PreferencesContent`Private`$notebooksTabSettingKeys
                ]
            ];
            stored = Developer`ReadWXFFile @ file;
            stored,
            Quiet @ DeleteFile @ file;
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    <|
        "ToolSelectionType" -> <| "WebSearcher" -> All |>,
        "VisiblePersonas"   -> { "Birdnardo" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "UnsetChatSettingsKeys-Cloud@@Tests/PreferencesContent.wlt:147,1-186,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Personas Tab*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, cache, after },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas"  ] = { "Birdnardo" };
            CurrentChatSettings[ $FrontEnd, "PersonaFavorites" ] = { "Birdnardo" };
            CurrentChatSettings[ $FrontEnd, "Temperature"      ] = 0.3;
            Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Personas" ];
            after = Replace[ CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ], Except[ _Association ] -> <| |> ];
            {
                KeyExistsQ[ after, "VisiblePersonas"  ],
                KeyExistsQ[ after, "PersonaFavorites" ],
                Lookup[ after, "Temperature" ],
                Lookup[ cache, { "VisiblePersonas", "PersonaFavorites" } ]
            },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    {
        False,
        False,
        0.3,
        { Wolfram`Chatbook`Common`$corePersonaNames, Wolfram`Chatbook`Common`$corePersonaNames }
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Personas-UnsetsKeys@@Tests/PreferencesContent.wlt:191,1-218,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { original, file, cache, stored },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        file     = FileNameJoin @ { $TemporaryDirectory, CreateUUID[ ] <> ".wxf" };
        WithCleanup[
            Developer`WriteWXFFile[
                file,
                <|
                    "Model"            -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>,
                    "VisiblePersonas"  -> { "Birdnardo" },
                    "PersonaFavorites" -> { "Birdnardo" },
                    "Temperature"      -> 0.3
                |>
            ];
            Block[
                {
                    $CloudEvaluation = True,
                    Wolfram`Chatbook`Settings`Private`$globalSettingsFile = file,
                    Wolfram`Chatbook`Settings`Private`$cachedGlobalSettings,
                    Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
                },
                Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Personas" ]
            ];
            stored = Developer`ReadWXFFile @ file;
            { stored, Lookup[ cache, { "VisiblePersonas", "PersonaFavorites", "Temperature" } ] },
            Quiet @ DeleteFile @ file;
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    {
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>, "Temperature" -> 0.3 |>,
        { Wolfram`Chatbook`Common`$corePersonaNames, Wolfram`Chatbook`Common`$corePersonaNames, 0.3 }
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Personas-Cloud@@Tests/PreferencesContent.wlt:220,1-256,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persona Menu*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, keys, nbo, personas, after },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        keys     = { "VisiblePersonas", "PersonaFavorites" };
        WithCleanup[
            Wolfram`Chatbook`Common`unsetChatSettingsKeys[ $FrontEnd, keys ];
            nbo      = CreateDocument[ { }, Visible -> False ];
            personas = Wolfram`Chatbook`UI`Private`filterPersonas @ nbo;
            after = Replace[ CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ], Except[ _Association ] -> <| |> ];
            { Keys @ personas, Intersection[ Keys @ after, keys ] },
            Quiet @ NotebookClose @ nbo;
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { Wolfram`Chatbook`Common`$corePersonaNames, { } },
    SameTest -> MatchQ,
    TestID   -> "FilterPersonas-ReadingWritesNothing@@Tests/PreferencesContent.wlt:261,1-279,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { original, nbo },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas"  ] = { "Wolfie", "PlainChat", "Birdnardo", "NotARealPersona" };
            CurrentChatSettings[ $FrontEnd, "PersonaFavorites" ] = { "Wolfie" };
            nbo = CreateDocument[ { }, Visible -> False ];
            Keys @ Wolfram`Chatbook`UI`Private`filterPersonas @ nbo,
            Quiet @ NotebookClose @ nbo;
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { "Wolfie", "Birdnardo", "PlainChat" },
    SameTest -> MatchQ,
    TestID   -> "FilterPersonas-VisibleAndFavoritesOrder@@Tests/PreferencesContent.wlt:281,1-297,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persona Manager*)
VerificationTest[
    UsingFrontEnd @ Module[ { original, keys, ran, after },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        keys     = { "VisiblePersonas", "PersonaFavorites", "CurrentPreferencesTab" };
        WithCleanup[
            Wolfram`Chatbook`Common`unsetChatSettingsKeys[ $FrontEnd, keys ];
            ran = Block[ { DynamicModule },
                SetAttributes[ DynamicModule, HoldAll ];
                DynamicModule[ vars_, body_, opts___ ] := Module @@ Hold[
                    vars,
                    body;
                    Lookup[ { opts }, Initialization ];
                    Lookup[ { opts }, Deinitialization ];
                    True
                ];
                Wolfram`Chatbook`PersonaManager`CreatePersonaManagerPanel[ ]
            ];
            after = Replace[ CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ], Except[ _Association ] -> <| |> ];
            { ran, Intersection[ Keys @ after, keys ] },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "PersonaManagerPanel-ViewingWritesNothing@@Tests/PreferencesContent.wlt:302,1-328,2"
]

VerificationTest[
    UsingFrontEnd @ Module[ { original, before, after },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            Wolfram`Chatbook`Common`unsetChatSettingsKeys[ $FrontEnd, { "VisiblePersonas" } ];
            Wolfram`Chatbook`Personas`GetPersonaData[ ];
            Wolfram`Chatbook`PersonaManager`Private`removeUninstalledVisiblePersonas[ ];
            before = KeyExistsQ[
                Replace[ CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ], Except[ _Association ] -> <| |> ],
                "VisiblePersonas"
            ];
            CurrentChatSettings[ $FrontEnd, "VisiblePersonas" ] = { "RawModel", "NotARealPersona", "PlainChat" };
            Wolfram`Chatbook`PersonaManager`Private`removeUninstalledVisiblePersonas[ ];
            after = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings", "VisiblePersonas" } ];
            { before, after },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original;
            Wolfram`Chatbook`Settings`Private`$currentSettingsCache = <| |>
        ]
    ],
    { False, { "RawModel", "PlainChat" } },
    SameTest -> MatchQ,
    TestID   -> "PersonaManagerPanel-RemovesUninstalledVisiblePersonas@@Tests/PreferencesContent.wlt:330,1-352,2"
]

(* :!CodeAnalysis::EndBlock:: *)
