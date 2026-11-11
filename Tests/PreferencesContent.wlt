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
            CurrentChatSettings[ $FrontEnd, "Assistance"          ] = True;
            CurrentChatSettings[ $FrontEnd, "Model"               ] = model;
            CurrentChatSettings[ $FrontEnd, "ServiceDefaultModel" ] = <| "OpenAI" -> "gpt-4.1" |>;
            CurrentChatSettings[ $FrontEnd, "Temperature"         ] = 0.3;
            CurrentChatSettings[ $FrontEnd, "UserInstructions"    ] = "qa";
            Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Notebooks" ];
            after = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
            {
                Lookup[ after, "ToolSelectionType" ],
                Lookup[ after, "VisiblePersonas"   ],
                KeyExistsQ[ after, "Assistance"          ],
                KeyExistsQ[ after, "Model"               ],
                KeyExistsQ[ after, "ServiceDefaultModel" ],
                KeyExistsQ[ after, "Temperature"         ],
                KeyExistsQ[ after, "UserInstructions"    ],
                AssociationQ @ cache,
                Lookup[ cache, "Model" ] =!= model
            },
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    {
        <| "WebSearcher" -> All |>,
        { "Birdnardo", "CodeAssistant" },
        False,
        False,
        False,
        False,
        False,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Notebooks-PreservesOtherTabs"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Notebooks-NoDefaultsWritten"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { True, "LLMKit", "" },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Services-RebuildsPanel"
]

VerificationTest[
    UsingFrontEnd @ Module[ { boxes1, boxes2 },
        boxes1 = ToBoxes @ Wolfram`Chatbook`Common`createPreferencesContent[ ];
        boxes2 = ToBoxes @ Wolfram`Chatbook`Common`createPreferencesContent[ ];
        { MatchQ[ boxes1, _DynamicModuleBox ], boxes1 =!= boxes2 }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "CreatePreferencesContent-UniqueBoxesPerRebuild"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Cloud*)

(* The cloud preferences cell doesn't track the "Preferences" trigger, so resets that change the model rebuild it: *)
VerificationTest[
    UsingFrontEnd @ Module[ { original, cache, calls = { } },
        original = CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ];
        WithCleanup[
            Needs[ "LLMServices`" -> None ];
            Block[
                {
                    LLMServices`ResetServices,
                    Wolfram`Chatbook`Common`forceRefreshCloudPreferences = AppendTo[ calls, "Cloud" ] &
                },
                Scan[
                    (AppendTo[ calls, # ]; Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, # ]) &,
                    { "Notebooks", "Services", "Personas", "Tools" }
                ]
            ];
            calls,
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { "Notebooks", "Cloud", "Services", "Cloud", "Personas", "Tools" },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-RefreshesCloudPreferences"
]

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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    <|
        "ToolSelectionType" -> <| "WebSearcher" -> All |>,
        "VisiblePersonas"   -> { "Birdnardo" }
    |>,
    SameTest -> MatchQ,
    TestID   -> "UnsetChatSettingsKeys-Cloud"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    {
        False,
        False,
        0.3,
        { Wolfram`Chatbook`Common`$corePersonaNames, Wolfram`Chatbook`Common`$corePersonaNames }
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Personas-UnsetsKeys"
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
                    Wolfram`Chatbook`Settings`Private`$cachedGlobalSettings
                },
                Wolfram`Chatbook`PreferencesContent`Private`resetChatPreferences[ Dynamic @ cache, "Personas" ]
            ];
            stored = Developer`ReadWXFFile @ file;
            { stored, Lookup[ cache, { "VisiblePersonas", "PersonaFavorites", "Temperature" } ] },
            Quiet @ DeleteFile @ file;
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    {
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4.1" |>, "Temperature" -> 0.3 |>,
        { Wolfram`Chatbook`Common`$corePersonaNames, Wolfram`Chatbook`Common`$corePersonaNames, 0.3 }
    },
    SameTest -> MatchQ,
    TestID   -> "ResetChatPreferences-Personas-Cloud"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { Wolfram`Chatbook`Common`$corePersonaNames, { } },
    SameTest -> MatchQ,
    TestID   -> "FilterPersonas-ReadingWritesNothing"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { "Wolfie", "Birdnardo", "PlainChat" },
    SameTest -> MatchQ,
    TestID   -> "FilterPersonas-VisibleAndFavoritesOrder"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "PersonaManagerPanel-ViewingWritesNothing"
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
            CurrentValue[ $FrontEnd, { TaggingRules, "ChatNotebookSettings" } ] = original
        ]
    ],
    { False, { "RawModel", "PlainChat" } },
    SameTest -> MatchQ,
    TestID   -> "PersonaManagerPanel-RemovesUninstalledVisiblePersonas"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*AllowExternalLLMConnectivity*)
(* Runs a test with a temporary persistence key, as in a kernel before 16.0 (managed is True for 16.0+), and restores
   the kernel symbol afterwards: *)
withAllowExternalLLMSandbox // Attributes = { HoldFirst };
withAllowExternalLLMSandbox[ eval_ ] := withAllowExternalLLMSandbox[ eval, False ];
withAllowExternalLLMSandbox[ eval_, managed_ ] :=
    Module[ { key = "Wolfram/ChatbookTests/" <> CreateUUID[ ], attributes, values },
        attributes = Attributes @ System`$AllowExternalLLMConnectivity;
        values     = OwnValues @ System`$AllowExternalLLMConnectivity;
        WithCleanup[
            Block[
                {
                    Wolfram`Chatbook`PreferencesContent`Private`$allowExternalLLMConnectivityKey = key,
                    Wolfram`Chatbook`Common`sufficientVersionQ
                },
                Wolfram`Chatbook`Common`sufficientVersionQ[ 16.0 ] = managed;
                Wolfram`Chatbook`Common`sufficientVersionQ[ v_ ] := TrueQ[ $VersionNumber >= v ];
                eval[ key ]
            ],
            Quiet @ DeleteObject @ PersistentObject[ key, "Local" ];
            Unprotect @ System`$AllowExternalLLMConnectivity;
            OwnValues @ System`$AllowExternalLLMConnectivity = values;
            Attributes @ System`$AllowExternalLLMConnectivity = attributes
        ]
    ];

VerificationTest[
    withAllowExternalLLMSandbox @ Function[ key,
        Unprotect @ System`$AllowExternalLLMConnectivity;
        System`$AllowExternalLLMConnectivity =.;
        Protect @ System`$AllowExternalLLMConnectivity;
        {
            Wolfram`Chatbook`PreferencesContent`Private`setAllowExternalLLMConnectivity[ False ],
            System`$AllowExternalLLMConnectivity,
            MemberQ[ Attributes @ System`$AllowExternalLLMConnectivity, Protected ],
            PersistentSymbol[ key, "Local" ],
            Wolfram`Chatbook`PreferencesContent`Private`allowExternalLLMConnectivityQ[ ]
        }
    ],
    { False, False, True, False, False },
    SameTest -> MatchQ,
    TestID   -> "SetAllowExternalLLMConnectivity-UpdatesKernelAndPersists"
]

VerificationTest[
    withAllowExternalLLMSandbox @ Function[ key,
        PersistentSymbol[ key, "Local" ] = False;
        Unprotect @ System`$AllowExternalLLMConnectivity;
        System`$AllowExternalLLMConnectivity =.;
        Wolfram`Chatbook`Common`restoreAllowExternalLLMConnectivity[ ];
        System`$AllowExternalLLMConnectivity
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "RestoreAllowExternalLLMConnectivity-AppliesSavedValue"
]

(* A value already set in the session (by the user or the front end) takes priority over the saved one: *)
VerificationTest[
    withAllowExternalLLMSandbox @ Function[ key,
        PersistentSymbol[ key, "Local" ] = False;
        Unprotect @ System`$AllowExternalLLMConnectivity;
        System`$AllowExternalLLMConnectivity = True;
        Wolfram`Chatbook`Common`restoreAllowExternalLLMConnectivity[ ];
        System`$AllowExternalLLMConnectivity
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "RestoreAllowExternalLLMConnectivity-KeepsSessionValue"
]

(* Since 16.0 the front end's setting applies, even if an earlier version saved a different value: *)
VerificationTest[
    withAllowExternalLLMSandbox[
        Function[ key,
            PersistentSymbol[ key, "Local" ] = False;
            Unprotect @ System`$AllowExternalLLMConnectivity;
            System`$AllowExternalLLMConnectivity =.;
            Wolfram`Chatbook`Common`restoreAllowExternalLLMConnectivity[ ];
            OwnValues @ System`$AllowExternalLLMConnectivity
        ],
        True
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "RestoreAllowExternalLLMConnectivity-IgnoredWhenManaged"
]

(* Reading the front end option while building the content would make it rebuild whenever any $FrontEnd option changes: *)
VerificationTest[
    UsingFrontEnd @ Module[ { calls = { } },
        Internal`InheritedBlock[ { MathLink`CallFrontEnd },
            Unprotect @ MathLink`CallFrontEnd;
            MathLink`CallFrontEnd[ args___ ] /; ! TrueQ @ $inCall := Block[ { $inCall = True },
                AppendTo[ calls, HoldComplete @ args ];
                MathLink`CallFrontEnd @ args
            ];
            ToBoxes @ Wolfram`Chatbook`Common`createPreferencesContent[ ]
        ];
        FreeQ[ calls, "AllowExternalLLMConnectivity" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "CreatePreferencesContent-NoAllowExternalLLMConnectivityDependency"
]

(* :!CodeAnalysis::EndBlock:: *)
