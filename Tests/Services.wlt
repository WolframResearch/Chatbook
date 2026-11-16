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

(* Calls made while $availableServices is building the table see the temporarily empty table: *)
VerificationTest[
    withoutServiceCache @ Block[ { Wolfram`Chatbook`Services`Private`getAvailableServices },
        Wolfram`Chatbook`Services`Private`getAvailableServices[ ] := {
            Wolfram`Chatbook`Services`Private`$buildingServiceTable,
            Wolfram`Chatbook`Common`$availableServices,
            Wolfram`Chatbook`Common`serviceIcon /@ Complement[ $serviceNames, $builtInIconNames ]
        };
        Wolfram`Chatbook`Common`$availableServices
    ],
    { True, <| |>, { "".. } },
    SameTest -> MatchQ,
    TestID   -> "ServiceIcon-DuringServiceTableBuild"
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

(* Unexpected service information (e.g. a failure from LLMServiceInformation) also uses the full table as usual: *)
VerificationTest[
    withoutServiceCache[
        {
            Wolfram`Chatbook`Common`getServiceIcon[ "Plain", $Failed ],
            AssociationQ @ Wolfram`Chatbook`Common`$serviceCache
        }
    ],
    { Missing[ "KeyAbsent", "Plain" ], True },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-InvalidInfo-FullTable-1"
]

VerificationTest[
    withoutServiceCache[
        {
            Wolfram`Chatbook`Common`getServiceIcon[ "Plain", <| "Plain" -> "P" |> ],
            AssociationQ @ Wolfram`Chatbook`Common`$serviceCache
        }
    ],
    { Missing[ "KeyAbsent", "Plain" ], True },
    SameTest -> MatchQ,
    TestID   -> "GetServiceIcon-InvalidInfo-FullTable-2"
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

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*LLM Kit Info Request*)

(* Evaluates with a signed-in test user, no LLM Kit info, and without sending any requests. `sent` counts the requests
   of startLLMKitInfoRequest, and `updates` the requests that getLLMKitInfo0 sends itself. *)
withLLMKitInfoTest // Attributes = { HoldFirst };

withLLMKitInfoTest[ eval_ ] := (
    LLMSynthesize;
    Block[
        {
            $CloudConnected = True,
            $CloudUserID    = "chatbook-test@example.com",
            $CloudBase      = "https://www.wolframcloud.com/",
            Wolfram`LLMFunctions`Common`$LLMKitInfo = None,
            Wolfram`Chatbook`Services`Private`$llmKitInfoRequest = None,
            ServiceSubmit = Function[ sent++; submitted = Association @ Cases[ { ## }, _Rule ]; None ],
            submitted = <| |>,
            sent = 0,
            updates = 0
        },
        Internal`InheritedBlock[ { Wolfram`LLMFunctions`Common`UpdateLLMKitInfo },
            Wolfram`LLMFunctions`Common`UpdateLLMKitInfo[ ] := (updates++; Null);
            eval
        ]
    ]
);

(* Gives a response with this body to the handler that startLLMKitInfoRequest passed to ServiceSubmit, with only the
   keys that it asked for, as URLSubmit does: *)
sendLLMKitInfoResponse[ body_String ] := submitted[ HandlerFunctions ][ "BodyReceived" ][
    KeyTake[ <| "BodyByteArray" -> StringToByteArray[ body, "UTF-8" ] |>, submitted[ HandlerFunctionsKeys ] ]
];

$testLLMKitInfoBody = "{\"success\": true, \"data\": {\"userHasSubscription\": true}}";

(* The response of the request that was sent ahead of time is used, and no other request is sent: *)
VerificationTest[
    withLLMKitInfoTest @ Module[ { started, info },
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        started = Wolfram`Chatbook`Services`Private`$llmKitInfoRequest;
        sendLLMKitInfoResponse @ $testLLMKitInfoBody;
        info = Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ];
        { KeyDrop[ started, "Task" ], info, sent, updates, Wolfram`Chatbook`Services`Private`$llmKitInfoRequest }
    ],
    {
        <| "User" -> "chatbook-test@example.com", "Cloud" -> "https://www.wolframcloud.com/", "Body" -> None |>,
        <| "userHasSubscription" -> True |>,
        1,
        0,
        None
    },
    TestID -> "LLMKitInfoRequest-ResponseUsed"
]

(* Without a usable response, getLLMKitInfo0 sends its own request as before: *)
VerificationTest[
    withLLMKitInfoTest @ {
        (* No response: *)
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ];
        updates,
        (* A response that is not the LLM Kit info: *)
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        sendLLMKitInfoResponse[ "{\"success\": false}" ];
        Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ];
        updates,
        (* A response for another user: *)
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        sendLLMKitInfoResponse @ $testLLMKitInfoBody;
        Block[ { $CloudUserID = "other-user@example.com" }, Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ] ];
        updates,
        (* No request was sent ahead of time: *)
        Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ];
        updates,
        sent
    },
    { 1, 2, 3, 4, 3 },
    TestID -> "LLMKitInfoRequest-Fallback"
]

(* The response is decoded as UTF-8: *)
VerificationTest[
    withLLMKitInfoTest[
        Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ];
        sendLLMKitInfoResponse[ "{\"success\": true, \"data\": {\"plan\": \"caf\[EAcute] \:2713\"}}" ];
        { Wolfram`Chatbook`Services`Private`getLLMKitInfo0[ ], updates }
    ],
    { <| "plan" -> "caf\[EAcute] \:2713" |>, 0 },
    TestID -> "LLMKitInfoRequest-UTF8"
]

(* Nothing is sent when the user is not signed in: *)
VerificationTest[
    withLLMKitInfoTest @ Block[ { $CloudConnected = False, $CloudUserID = None },
        { Wolfram`Chatbook`Common`startLLMKitInfoRequest[ ], sent, Wolfram`Chatbook`Services`Private`$llmKitInfoRequest }
    ],
    { Null, 0, None },
    TestID -> "LLMKitInfoRequest-NotSignedIn"
]

(* :!CodeAnalysis::EndBlock:: *)
