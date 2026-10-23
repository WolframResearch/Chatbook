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
(*Test Definitions*)
VerificationTest[
    (* Evaluates `eval` as if the service table had not been built yet in this session: *)
    withoutServiceCache // Attributes = { HoldFirst };
    withoutServiceCache[ eval_ ] := Block[
        {
            Wolfram`Chatbook`Common`$serviceCache   = None,
            Wolfram`Chatbook`Common`$servicesLoaded = False
        },
        eval
    ];

    (* Builds the full service table from the given service information, the same way that $availableServices does: *)
    fullServiceTable[ info_ ] := Block[
        {
            Wolfram`Chatbook`Common`$availableServices              = <| |>,
            Wolfram`Chatbook`Services`Private`$buildingServiceTable = True
        },
        Wolfram`Chatbook`Services`Private`getAvailableServices0 @ info
    ];

    (* The previous definition of serviceIcon for service names, which always used the full service table: *)
    fullTableServiceIcon[ service_String ] := Replace[
        Wolfram`Chatbook`Common`$availableServices[ service, "Icon" ],
        Wolfram`Chatbook`Common`$$unspecified -> ""
    ];

    $usingLLMServices = TrueQ @ Wolfram`Chatbook`Common`$useLLMServices;
    $builtInIconNames = { "Wolfram", "OpenAI", "Anthropic", "PaLM" };

    $registeredServiceNames =
        If[ $usingLLMServices,
            Needs[ "LLMServices`" -> None ]; Keys @ LLMServices`LLMServiceInformation @ LLMServices`ChatSubmit,
            { "OpenAI" }
        ];

    $serviceNames = DeleteDuplicates @ Join[ $registeredServiceNames, $builtInIconNames, { "NotAService" } ];

    $iconEvaluations = 0;

    $customServices = <|
        "Plain"   -> <| "Icon" -> "P" |>,
        "Delayed" -> <| "Icon" :> ($iconEvaluations++; StringJoin[ "D", "!" ]) |>,
        "Self"    -> <| "Icon" :> Wolfram`Chatbook`Common`serviceIcon[ "Self" ] |>,
        "Nested"  -> <| "Icon" :> Wolfram`Chatbook`Common`serviceIcon[ "Plain" ] |>,
        "NoIcon"  -> <| |>,
        "Empty"   -> <| "Icon" -> "" |>,
        "Missing" -> <| "Icon" -> Missing[ ] |>,
        "Ollama"  -> <| "Icon" -> "O" |>
    |>;

    $customServiceNames = Append[ Keys @ $customServices, "Absent" ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*serviceIcon*)
VerificationTest[
    withoutServiceCache[
        $singleServiceIcons = AssociationMap[ Wolfram`Chatbook`Common`serviceIcon, $serviceNames ];
        Wolfram`Chatbook`Common`$serviceCache
    ],
    If[ $usingLLMServices, None, _Association ],
    SameTest -> MatchQ,
    TestID   -> "ServiceIcon-DoesNotBuildServiceTable"
]

VerificationTest[
    withoutServiceCache[
        Wolfram`Chatbook`Common`$availableServices;
        Select[ $serviceNames, Wolfram`Chatbook`Common`serviceIcon[ # ] =!= $singleServiceIcons[ # ] & ]
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "ServiceIcon-SameAsCachedServiceTable"
]

VerificationTest[
    withoutServiceCache @ Select[
        Complement[ $serviceNames, $builtInIconNames ],
        fullTableServiceIcon[ # ] =!= $singleServiceIcons[ # ] &
    ],
    { },
    SameTest -> SameQ,
    TestID   -> "ServiceIcon-SameAsFullTableLookup"
]

VerificationTest[
    withoutServiceCache[
        Wolfram`Chatbook`Common`$availableServices;
        { Wolfram`Chatbook`Common`serviceIcon[ "NotAService" ], AssociationQ @ Wolfram`Chatbook`Common`$serviceCache }
    ],
    { "", True },
    SameTest -> MatchQ,
    TestID   -> "ServiceIcon-CachedServiceTable-Unknown"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*getServiceIcon*)
VerificationTest[
    $iconEvaluations = 0;
    withoutServiceCache[
        {
            Wolfram`Chatbook`Common`getServiceIcon[ "Plain", $customServices ],
            $iconEvaluations,
            Wolfram`Chatbook`Common`getServiceIcon[ "Delayed", $customServices ],
            $iconEvaluations,
            Wolfram`Chatbook`Common`$serviceCache
        }
    ],
    { "P", 0, "D!", 1, None },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-OnlyEvaluatesRequestedIcon"
]

VerificationTest[
    $iconEvaluations = 0;
    $customServiceIcons = withoutServiceCache[
        Wolfram`Chatbook`Common`getServiceIcon[ #, $customServices ] & /@ $customServiceNames
    ];
    { $customServiceIcons, $iconEvaluations },
    {
        { "P", "D!", "", "", "", "", "", "O", Missing[ "KeyAbsent", "Absent" ] },
        1
    },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-CustomServices"
]

VerificationTest[
    withoutServiceCache @ With[ { table = fullServiceTable @ $customServices },
        table[ #, "Icon" ] & /@ $customServiceNames
    ],
    $customServiceIcons,
    SameTest -> SameQ,
    TestID   -> "GetServiceIcon-CustomServices-SameAsFullTable"
]

VerificationTest[
    Block[ { $CloudEvaluation = True },
        withoutServiceCache @ With[ { table = fullServiceTable @ $customServices },
            {
                Wolfram`Chatbook`Common`getServiceIcon[ #, $customServices ] & /@ { "Ollama", "Plain" },
                table[ #, "Icon" ] & /@ { "Ollama", "Plain" }
            }
        ]
    ],
    { { Missing[ "KeyAbsent", "Ollama" ], "P" }, { Missing[ "KeyAbsent", "Ollama" ], "P" } },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-CloudExclusions"
]

VerificationTest[
    withoutServiceCache @ With[ { table = fullServiceTable @ <| |> },
        {
            Wolfram`Chatbook`Common`getServiceIcon[ #, <| |> ] & /@ { "OpenAI", "Plain" },
            table[ #, "Icon" ] & /@ { "OpenAI", "Plain" }
        }
    ],
    { { icon: Except[ _Missing ], Missing[ "KeyAbsent", "Plain" ] }, { icon_, Missing[ "KeyAbsent", "Plain" ] } },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-FallbackServices"
]

VerificationTest[
    With[ { model = <| "Name" -> "b" |> },
        Wolfram`Chatbook`Services`Private`literalModelListQ /@ {
            <| "ModelList" -> { "a", model } |>,
            <| "ModelList" :> { "a", model } |>,
            <| "ModelList" -> { } |>,
            <| "ModelList" :> { } |>,
            <| "ModelList" :> getModels[ ] |>,
            <| |>
        }
    ],
    { True, True, False, False, False, False },
    SameTest -> SameQ,
    TestID   -> "LiteralModelListQ"
]

(* Building the table memoizes standardized models from literal model lists, so the full table is built as usual: *)
VerificationTest[
    withoutServiceCache[
        {
            Wolfram`Chatbook`Common`getServiceIcon[
                "Plain",
                <| "Plain" -> <| "Icon" -> "P" |>, "Literal" -> <| "ModelList" -> { "a" } |> |>
            ],
            AssociationQ @ Wolfram`Chatbook`Common`$serviceCache
        }
    ],
    { Missing[ "KeyAbsent", "Plain" ], True },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-LiteralModelLists-FullTable"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*resolveFullModelSpec*)
VerificationTest[
    withoutServiceCache[
        $defaultLLMKitModel = Wolfram`Chatbook`Common`resolveFullModelSpec @ <| "Service" -> "LLMKit", "Name" -> Automatic |>;
        $testLLMKitModel = Wolfram`Chatbook`Common`resolveFullModelSpec @ <|
            "Service" -> "LLMKit",
            "Name"    -> "chatbook-test-model-" <> CreateUUID[ ]
        |>;
        Wolfram`Chatbook`Common`$serviceCache
    ],
    If[ $usingLLMServices, None, _Association ],
    SameTest -> MatchQ,
    TestID   -> "ResolveFullModelSpec-LLMKit-DoesNotBuildServiceTable"
]

VerificationTest[
    { $defaultLLMKitModel, $testLLMKitModel },
    {
        KeyValuePattern @ { "Authentication" -> "LLMKit", "Icon" -> _, "ResolvedModel" -> True },
        KeyValuePattern @ { "Authentication" -> "LLMKit", "Icon" -> _, "ResolvedModel" -> True }
    },
    SameTest -> MatchQ,
    TestID   -> "ResolveFullModelSpec-LLMKit-Resolved"
]

VerificationTest[
    withoutServiceCache[
        Wolfram`Chatbook`Common`$availableServices;
        Wolfram`Chatbook`Common`serviceIcon @ $testLLMKitModel[ "Service" ]
    ],
    $testLLMKitModel[ "Icon" ],
    SameTest -> SameQ,
    TestID   -> "ResolveFullModelSpec-LLMKit-Icon"
]

(* :!CodeAnalysis::EndBlock:: *)
