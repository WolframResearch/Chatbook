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

(* AIAutoAssist runs in the CellEpilog of every input cell in chat-enabled notebooks. These tests stub out the front end
   by giving the chat settings that `currentChatSettings` would return for the cell, and compare the decision to send a
   chat with the one made by fully resolving the settings (as was always done before). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Test Definitions*)
VerificationTest[
    $testCell     = CellObject[ "AIAutoAssistTestCell" ];
    $testNotebook = NotebookObject[ "AIAutoAssistTestNotebook" ];

    (* Settings as currentChatSettings would merge them from the global, notebook, and cell levels: *)
    testSettings[ global_, notebook_, cell_, persona_ ] := Wolfram`Chatbook`Common`mergeChatSettings @ {
        Wolfram`Chatbook`Common`$defaultChatSettings,
        <| global, "LLMEvaluator" -> persona |>,
        notebook,
        cell
    };

    (* Resolving settings in the chat state sets some global values that would affect later tests (e.g. formatting): *)
    withIsolatedChatState // Attributes = { HoldFirst };
    withIsolatedChatState[ eval_ ] := Internal`InheritedBlock[
        {
            Wolfram`Chatbook`$ChatHandlerData,
            Wolfram`Chatbook`Common`$lastCellObject,
            Wolfram`Chatbook`Common`$lastTask,
            Wolfram`Chatbook`Common`$tokenBudgetLog,
            Wolfram`Chatbook`Tools`Private`$toolBox
        },
        eval
    ];

    (* How the decision was made before using autoAssistPossibleQ: *)
    fullyResolvedDecision[ settings_ ] := withIsolatedChatState @ Wolfram`Chatbook`Common`withChatState @
        Wolfram`Chatbook`Common`autoAssistQ @ Wolfram`Chatbook`Common`resolveAutoSettings @ settings;

    (* Gives { sent, resolveCount, sendArguments } where `sent` is True if SendChat was called: *)
    autoAssistResult[ settings_ ] := Module[ { resolveCount = 0, sent = False, sendArguments = None, inner = False },
        withIsolatedChatState @ Internal`InheritedBlock[
            {
                Wolfram`Chatbook`Common`currentChatSettings,
                Wolfram`Chatbook`Common`parentNotebook,
                Wolfram`Chatbook`Common`resolveAutoSettings
            },
            Wolfram`Chatbook`Common`currentChatSettings[ $testCell ] = settings;
            Wolfram`Chatbook`Common`parentNotebook[ $testCell ] = $testNotebook;
            (* Count top-level calls to resolveAutoSettings: *)
            DownValues[ Wolfram`Chatbook`Common`resolveAutoSettings ] = Prepend[
                DownValues @ Wolfram`Chatbook`Common`resolveAutoSettings,
                HoldPattern[ Wolfram`Chatbook`Common`resolveAutoSettings[ s_ /; ! inner ] ] :>
                    (resolveCount++; Block[ { inner = True }, Wolfram`Chatbook`Common`resolveAutoSettings @ s ])
            ];
            Block[
                {
                    Wolfram`Chatbook`SendChat = Function[
                        sent = True;
                        sendArguments = { ##, Wolfram`Chatbook`$AutomaticAssistance };
                        Null
                    ]
                },
                Wolfram`Chatbook`Actions`AIAutoAssist[ $testCell, $testNotebook ]
            ]
        ];
        { sent, resolveCount, sendArguments }
    ];

    (* Personas that set "Assistance": *)
    $basePersonaData = Wolfram`Chatbook`Personas`GetCachedPersonaData[ ];
    $testPersonaData = <|
        $basePersonaData,
        "AIAutoAssistTestPersonaTrue"  -> <| $basePersonaData[ "PlainChat" ], "Assistance" -> True  |>,
        "AIAutoAssistTestPersonaFalse" -> <| $basePersonaData[ "PlainChat" ], "Assistance" -> False |>,
        "AIAutoAssistTestPersonaAuto"  -> <| $basePersonaData[ "PlainChat" ], "Assistance" -> Automatic |>
    |>;

    $assistanceValues = { Missing[ ], True, False, Automatic, Inherited };

    $personas = {
        "WolframAIAssistant",
        "PlainChat",
        "AIAutoAssistTestPersonaTrue",
        "AIAutoAssistTestPersonaFalse",
        "AIAutoAssistTestPersonaAuto",
        (* The "LLMEvaluator" setting can also be the persona data itself: *)
        <| "Name" -> "AIAutoAssistTestPersonaInline", "Assistance" -> True |>
    };

    toLevel[ _Missing ] := <| |>;
    toLevel[ value_   ] := <| "Assistance" -> value |>;

    AssociationQ @ $testPersonaData,
    True,
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-TestDefinitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Default Settings*)
VerificationTest[
    autoAssistResult @ testSettings[ <| |>, <| |>, <| |>, "WolframAIAssistant" ],
    { False, 0, None },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-Default-NoResolve"
]

VerificationTest[
    Wolfram`Chatbook`Common`autoAssistPossibleQ @ testSettings[ <| |>, <| |>, <| |>, "WolframAIAssistant" ],
    False,
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-Default-NotPossible"
]

(* An ordinary input evaluation should not reset the state of a chat that might still be in progress: *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`$ChatHandlerData       = <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |>,
            Wolfram`Chatbook`Common`$lastCellObject = "AIAutoAssistTestLastCell",
            Wolfram`Chatbook`Common`$lastTask       = "AIAutoAssistTestLastTask"
        },
        Internal`InheritedBlock[ { Wolfram`Chatbook`Common`currentChatSettings },
            Wolfram`Chatbook`Common`currentChatSettings[ $testCell ] =
                testSettings[ <| |>, <| |>, <| |>, "WolframAIAssistant" ];
            Wolfram`Chatbook`Actions`AIAutoAssist[ $testCell, $testNotebook ]
        ];
        {
            Wolfram`Chatbook`$ChatHandlerData,
            Wolfram`Chatbook`Common`$lastCellObject,
            Wolfram`Chatbook`Common`$lastTask
        }
    ],
    {
        <| "ChatNotebookSettings" -> <| "ToolMethod" -> "Simple" |> |>,
        "AIAutoAssistTestLastCell",
        "AIAutoAssistTestLastTask"
    },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-Default-ChatStateUnchanged"
]

(* No model-specific defaults currently set "Assistance", so an Automatic value always resolves to False: *)
VerificationTest[
    FreeQ[ Wolfram`Chatbook`Settings`Private`$modelAutoSettings, _Association? (KeyExistsQ[ "Assistance" ]) ],
    True,
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-NoModelDefaults"
]

(* Settings that couldn't be determined are left for resolveAutoSettings to handle: *)
VerificationTest[
    Wolfram`Chatbook`Common`autoAssistPossibleQ @ Missing[ "NotAvailable" ],
    True,
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-MissingSettings"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Explicitly Enabled*)
VerificationTest[
    autoAssistResult @ testSettings[ <| |>, <| "Assistance" -> True |>, <| |>, "WolframAIAssistant" ],
    {
        True,
        1,
        {
            $testCell,
            $testNotebook,
            KeyValuePattern @ { "Assistance" -> True, "ResolvedAutoSettings" -> True },
            True
        }
    },
    SameTest -> MatchQ,
    TestID   -> "AIAutoAssist-Enabled-SendChat"
]

VerificationTest[
    autoAssistResult @ testSettings[ <| |>, <| "Assistance" -> True |>, <| "Assistance" -> False |>, "WolframAIAssistant" ],
    { False, 0, None },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-DisabledInCell-NoResolve"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Personas*)

(* Persona values take precedence over other settings: *)
VerificationTest[
    Block[ { Wolfram`Chatbook`Personas`$CachedPersonaData = $testPersonaData },
        {
            First @ autoAssistResult @ testSettings[ <| |>, <| |>, <| "Assistance" -> False |>, "AIAutoAssistTestPersonaTrue" ],
            First @ autoAssistResult @ testSettings[ <| |>, <| |>, <| "Assistance" -> True |>, "AIAutoAssistTestPersonaFalse" ]
        }
    ],
    { True, False },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-PersonaPrecedence"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Decision Equivalence*)
VerificationTest[
    $equivalenceResults = Block[ { Wolfram`Chatbook`Personas`$CachedPersonaData = $testPersonaData },
        Flatten[
            Table[
                Module[ { settings, expected, result, assistanceQ },
                    settings    = testSettings[ toLevel @ global, toLevel @ notebook, toLevel @ cell, persona ];
                    expected    = fullyResolvedDecision @ settings;
                    result      = autoAssistResult @ settings;
                    (* The most specific value that is set, or the persona value: *)
                    assistanceQ = Or[
                        TrueQ @ Last[ DeleteCases[ { global, notebook, cell }, _Missing | Inherited ], Automatic ],
                        MatchQ[ persona, "AIAutoAssistTestPersonaTrue" | KeyValuePattern[ "Assistance" -> True ] ]
                    ];
                    <|
                        "Settings"     -> { global, notebook, cell, persona },
                        "Expected"     -> expected,
                        "Sent"         -> result[[ 1 ]],
                        "ResolveCount" -> result[[ 2 ]],
                        (* Settings are only fully resolved if "Assistance" could be True: *)
                        "Pass"         -> TrueQ[ BooleanQ @ expected && expected === result[[ 1 ]] ] &&
                                          result[[ 2 ]] === If[ assistanceQ, 1, 0 ]
                    |>
                ],
                { global  , $assistanceValues },
                { notebook, $assistanceValues },
                { cell    , $assistanceValues },
                { persona , $personas         }
            ],
            3
        ]
    ];
    Select[ $equivalenceResults, ! TrueQ @ #[ "Pass" ] & ],
    { },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-DecisionEquivalence"
]

(* Both outcomes are covered: *)
VerificationTest[
    Counts @ Lookup[ $equivalenceResults, "Expected" ],
    KeyValuePattern @ { True -> _Integer? Positive, False -> _Integer? Positive },
    SameTest -> MatchQ,
    TestID   -> "AIAutoAssist-DecisionEquivalence-Coverage"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Model Defaults*)

(* If a model-specific default for "Assistance" were defined, an Automatic value could resolve to True: *)
VerificationTest[
    Internal`InheritedBlock[ { Wolfram`Chatbook`Settings`Private`$modelAutoSettings, Wolfram`Chatbook`Common`autoModelSetting },
        (* Clear any cached "Assistance" values: *)
        DownValues[ Wolfram`Chatbook`Common`autoModelSetting ] = Select[
            DownValues @ Wolfram`Chatbook`Common`autoModelSetting,
            FreeQ[ First @ #, "Assistance" ] &
        ];
        Wolfram`Chatbook`Settings`Private`$modelAutoSettings[ Automatic, Automatic, "Assistance" ] = True;
        With[ { settings = testSettings[ <| |>, <| |>, <| |>, "WolframAIAssistant" ] },
            {
                Wolfram`Chatbook`Common`autoAssistPossibleQ @ settings,
                fullyResolvedDecision @ settings,
                Take[ autoAssistResult @ settings, 2 ]
            }
        ]
    ],
    { True, True, { True, 1 } },
    SameTest -> SameQ,
    TestID   -> "AIAutoAssist-ModelDefault"
]

(* :!CodeAnalysis::EndBlock:: *)
