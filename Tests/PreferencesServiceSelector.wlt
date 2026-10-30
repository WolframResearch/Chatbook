(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PreferencesServiceSelector.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PreferencesServiceSelector.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    $testServices = <|
        "LLMKit"   -> <| "Service" -> "Wolfram AI Access", "Icon" -> "" |>,
        "ServiceA" -> <| "Service" -> "ServiceA", "Icon" -> "" |>,
        "ServiceB" -> <| "Service" -> "ServiceB", "Icon" -> "" |>
    |>;

    (* Builds the service selector with the given DynamicModule variables and returns its parts with the local
       `pending` variable replaced by the given symbol: *)
    selectorParts // Attributes = { HoldRest };
    selectorParts[ services_, dmPrefCache_, service_, model_, modelNameSelector_, state_, pending_ ] :=
        Replace[
            Wolfram`Chatbook`PreferencesContent`Private`makeServiceSelector[
                services, dmPrefCache, service, model, modelNameSelector, state
            ],
            HoldPattern @ DynamicModule[ vars_, wrapper_, ___ ] :>
                ReplaceAll[
                    Hold @ wrapper,
                    First @ Cases[ Hold @ vars, Verbatim[ Set ][ p_Symbol, None ] :> (HoldPattern @ p :> pending), { 2 } ]
                ]
        ];

    setterFrom[ Hold @ DynamicWrapper[ PopupMenu[ Dynamic[ _, setter_, ___ ], ___ ], ___ ] ] := setter;
    displayFrom[ Hold @ DynamicWrapper[ PopupMenu[ Dynamic[ display_, __ ], ___ ], ___ ] ] := Hold @ display;
    trackedFrom[ Hold @ DynamicWrapper[ PopupMenu[ Dynamic[ _, _, OrderlessPatternSequence[ TrackedSymbols :> tracked_, ___ ] ], ___ ], ___ ] ] := Hold @ tracked;
    asyncFrom[ Hold @ DynamicWrapper[ _, async_, ___ ] ] := Hold @ async;
    wrapperOptions[ Hold @ DynamicWrapper[ _, _, opts___ ] ] := { opts };
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "Definitions@@Tests/PreferencesServiceSelector.wlt:24,1-55,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeServiceSelector*)
VerificationTest[
    $parts = selectorParts[ $testServices, prefCache, service, model, modelNameSelector, state, pending ];
    { Head @ setterFrom @ $parts, wrapperOptions @ $parts },
    { Function, { OrderlessPatternSequence[ SynchronousUpdating -> False, TrackedSymbols :> { pending } ] } },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsynchronousWrapper@@Tests/PreferencesServiceSelector.wlt:60,1-66,2"
]

(* The popup shows a pending selection immediately, then follows dmPrefCache (e.g. after the Reset button): *)
VerificationTest[
    prefCache = <| "Model" -> <| "Service" -> "ServiceA", "Name" -> "a" |> |>;
    pending   = "ServiceB";
    {
        ReleaseHold @ displayFrom @ $parts,
        pending = None; ReleaseHold @ displayFrom @ $parts,
        prefCache[ "Model" ] = <| "Service" -> "LLMKit", "Name" -> Automatic |>; ReleaseHold @ displayFrom @ $parts,
        trackedFrom @ $parts
    },
    { "ServiceB", "ServiceA", "LLMKit", Hold @ { pending, prefCache } },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-DisplayFollowsPrefCache@@Tests/PreferencesServiceSelector.wlt:69,1-81,2"
]

(* The PopupMenu setter blocks the front end, so it must not download the model list: *)
VerificationTest[
    Module[ { calls = { }, result },
        prefCache = <| "Model" -> <| "Service" -> "ServiceA", "Name" -> "a" |> |>;
        service   = "ServiceA";
        model     = "a";
        state     = "Loaded";
        pending   = None;
        Block[
            {
                Wolfram`Chatbook`Common`getServiceModelList = (AppendTo[ calls, "getServiceModelList" ]; { }) &,
                Wolfram`Chatbook`Services`Private`getModelListQuietly = (AppendTo[ calls, "getModelListQuietly" ]; { }) &,
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback = (AppendTo[ calls, "serviceSelectCallback" ]; Null) &,
                Wolfram`Chatbook`PreferencesContent`Private`makeModelNameSelector = (AppendTo[ calls, "makeModelNameSelector" ]; Null) &,
                Wolfram`Chatbook`Common`modelListCachedQ = False &,
                CurrentChatSettings
            },
            CurrentChatSettings /: Set[ CurrentChatSettings[ ___ ], _ ] := AppendTo[ calls, "CurrentChatSettings" ];
            result = setterFrom[ $parts ][ "ServiceB" ]
        ];
        { calls, service, state, pending, prefCache }
    ],
    {
        { },
        "ServiceB",
        "Loading",
        "ServiceB",
        <| "Model" -> <| "Service" -> "ServiceA", "Name" -> "a" |> |>
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-SetterDoesNotFetchModelList@@Tests/PreferencesServiceSelector.wlt:84,1-114,2"
]

VerificationTest[
    Module[ { calls = { } },
        service = "ServiceA";
        state   = "Loaded";
        pending = None;
        Block[ { Wolfram`Chatbook`Common`modelListCachedQ = (AppendTo[ calls, # ]; True) & },
            setterFrom[ $parts ][ "ServiceB" ]
        ];
        { calls, service, state, pending }
    ],
    { { "ServiceB" }, "ServiceB", "Loaded", "ServiceB" },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-SetterCachedModelList@@Tests/PreferencesServiceSelector.wlt:116,1-129,2"
]

(* The asynchronous part runs the callback for the pending selection, then clears it: *)
VerificationTest[
    Module[ { calls = { } },
        pending = "ServiceB";
        Block[
            {
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, { #1, Hold[ ## ][[ 2 ;; ]] } ], HoldRest ]
            },
            ReleaseHold @ asyncFrom @ $parts
        ];
        { calls, pending }
    ],
    {
        { { "ServiceB", Hold[ prefCache, service, model, modelNameSelector, state ] } },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsyncRunsCallback@@Tests/PreferencesServiceSelector.wlt:132,1-150,2"
]

(* A selection made while the previous one is still loading is kept for the next evaluation, which the front end
   triggers because pending is tracked; each evaluation handles at most one selection: *)
VerificationTest[
    Module[ { calls = { }, afterFirst },
        pending = "ServiceA";
        Block[
            {
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, #1 ]; If[ #1 === "ServiceA", pending = "ServiceB" ], HoldRest ]
            },
            ReleaseHold @ asyncFrom @ $parts;
            afterFirst = { calls, pending };
            ReleaseHold @ asyncFrom @ $parts
        ];
        { afterFirst, calls, pending }
    ],
    { { { "ServiceA" }, "ServiceB" }, { "ServiceA", "ServiceB" }, None },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsyncNewerSelection@@Tests/PreferencesServiceSelector.wlt:154,1-171,2"
]

(* Picking the same service again while it's loading doesn't fetch it twice: *)
VerificationTest[
    Module[ { calls = { } },
        pending = "ServiceA";
        Block[
            {
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, #1 ]; pending = "ServiceA", HoldRest ]
            },
            ReleaseHold @ asyncFrom @ $parts
        ];
        { calls, pending }
    ],
    { { "ServiceA" }, None },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsyncSameSelection@@Tests/PreferencesServiceSelector.wlt:174,1-189,2"
]

VerificationTest[
    Module[ { calls = { } },
        pending = None;
        Block[
            {
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, #1 ], HoldRest ]
            },
            ReleaseHold @ asyncFrom @ $parts
        ];
        calls
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsyncNoPendingSelection@@Tests/PreferencesServiceSelector.wlt:191,1-206,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Negative model list cache*)
VerificationTest[
    Module[ { fetches = 0, info, results },
        info = <| "Service" -> "UnreachableTestService", "ModelList" :> (fetches++; Missing[ "NoModelList" ]) |>;
        Block[
            {
                Wolfram`Chatbook`Services`Private`$noModelListCache = <| |>,
                Wolfram`Chatbook`Common`$availableServices = <| "UnreachableTestService" -> info |>,
                Wolfram`Chatbook`Services`Private`getModelListQuietly = (fetches++; Missing[ "NoModelList" ]) &
            },
            results = Table[ Wolfram`Chatbook`Common`getServiceModelList[ "UnreachableTestService" ], 3 ];
            { results, fetches }
        ]
    ],
    { { Missing[ "NoModelList" ], Missing[ "NoModelList" ], Missing[ "NoModelList" ] }, 1 },
    SameTest -> MatchQ,
    TestID   -> "NoModelListCache-SkipsRepeatedFetch@@Tests/PreferencesServiceSelector.wlt:211,1-227,2"
]

VerificationTest[
    Module[ { fetches = 0 },
        Block[
            {
                Wolfram`Chatbook`Services`Private`$noModelListCache = <| |>,
                Wolfram`Chatbook`Services`Private`$noModelListCacheTime = 0,
                Wolfram`Chatbook`Common`$availableServices = <| "UnreachableTestService" -> <| |> |>,
                Wolfram`Chatbook`Services`Private`getModelListQuietly = (fetches++; Missing[ "NoModelList" ]) &
            },
            Do[ Wolfram`Chatbook`Common`getServiceModelList[ "UnreachableTestService" ], 3 ];
            { fetches, Length @ Wolfram`Chatbook`Services`Private`$noModelListCache }
        ]
    ],
    { 3, 1 },
    SameTest -> MatchQ,
    TestID   -> "NoModelListCache-Expires@@Tests/PreferencesServiceSelector.wlt:229,1-245,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Services`Private`$noModelListCache = <| "UnreachableTestService" -> AbsoluteTime[ ] |>,
            Wolfram`Chatbook`Common`$serviceCache = Wolfram`Chatbook`Common`$serviceCache
        },
        Wolfram`Chatbook`InvalidateServiceCache[ ];
        Wolfram`Chatbook`Services`Private`$noModelListCache
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "NoModelListCache-Invalidate@@Tests/PreferencesServiceSelector.wlt:247,1-259,2"
]

VerificationTest[
    Block[
        {
            Wolfram`Chatbook`Services`Private`$noModelListCache = <|
                "UnreachableTestService" -> AbsoluteTime[ ],
                "OtherTestService"       -> AbsoluteTime[ ]
            |>
        },
        Wolfram`Chatbook`Common`clearNoModelListCache[ "UnreachableTestService" ];
        Keys @ Wolfram`Chatbook`Services`Private`$noModelListCache
    ],
    { "OtherTestService" },
    SameTest -> MatchQ,
    TestID   -> "NoModelListCache-Clear@@Tests/PreferencesServiceSelector.wlt:261,1-275,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*getModelListQuietly*)

(* Failing third-party model list code doesn't reach the Messages window: *)
VerificationTest[
    Wolfram`Chatbook`Services`Private`getModelListQuietly @ <|
        "Service"   -> "QuietTestService",
        "ModelList" :> Join[ { }[[ 1 ]], StringReplace[ 1, "a" -> "b" ] ]
    |>,
    Missing[ "NoModelList" ],
    SameTest -> MatchQ,
    TestID   -> "GetModelListQuietly-NoMessages@@Tests/PreferencesServiceSelector.wlt:282,1-290,2"
]

(* A suppressed connection dialog is still detected while messages are quieted: *)
VerificationTest[
    Wolfram`Chatbook`Services`Private`getModelListQuietly @ <|
        "Service"   -> "QuietTestService",
        "ModelList" :> (Message[ Part::partw, 1, { } ]; Message[ DialogInput::nprmtv ]; { })
    |>,
    Missing[ "NotConnected" ],
    SameTest -> MatchQ,
    TestID   -> "GetModelListQuietly-NotConnected@@Tests/PreferencesServiceSelector.wlt:293,1-301,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*getServiceDefaultModel*)

(* A remembered Automatic doesn't stick: the next selection looks for a model again and uses the first one: *)
VerificationTest[
    Module[ { cache = <| |>, lists, results },
        lists = { Missing[ "NoModelList" ], { <| "Name" -> "m1" |>, <| "Name" -> "m2" |> } };
        Block[
            {
                Wolfram`Chatbook`Common`chooseDefaultModelName = Automatic &,
                Wolfram`Chatbook`Common`getServiceModelList = (First @ lists) &,
                CurrentChatSettings
            },
            CurrentChatSettings /: Set[ CurrentChatSettings[ ___ ], v_ ] := v;
            results = Table[
                With[
                    {
                        name = Wolfram`Chatbook`PreferencesContent`Private`getServiceDefaultModel[
                            Dynamic @ cache,
                            "QuietTestService"
                        ]
                    },
                    lists = Rest @ lists;
                    name
                ],
                2
            ]
        ];
        { results, cache }
    ],
    { { Automatic, "m1" }, <| "ServiceDefaultModel" -> <| "QuietTestService" -> "m1" |> |> },
    SameTest -> MatchQ,
    TestID   -> "GetServiceDefaultModel-RetriesAutomatic@@Tests/PreferencesServiceSelector.wlt:308,1-337,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*serviceConnectButton*)

(* After connecting, the Connect button always fetches again, even if a failure was cached just before: *)
VerificationTest[
    Module[ { calls = { }, button },
        service = "UnreachableTestService";
        button  = Wolfram`Chatbook`PreferencesContent`Private`serviceConnectButton[
            Dynamic @ prefCache, Dynamic @ service, Dynamic @ model, Dynamic @ modelNameSelector, Dynamic @ state
        ];
        Block[
            {
                Wolfram`Chatbook`Services`Private`$noModelListCache = <| "UnreachableTestService" -> AbsoluteTime[ ] |>,
                Wolfram`LLMFunctions`APIs`Common`ConnectToService = (AppendTo[ calls, "Connect" ]; ServiceObject[ "Test" ]) &,
                Wolfram`Chatbook`Common`getServiceModelList = (
                    AppendTo[ calls, { "Fetch", KeyExistsQ[ Wolfram`Chatbook`Services`Private`$noModelListCache, # ] } ];
                    { <| "Name" -> "m" |> }
                ) &,
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, { "Callback", #1 } ], HoldRest ],
                Needs
            },
            Replace[ button, HoldPattern @ Button[ _, action_, ___ ] :> action ]
        ];
        calls
    ],
    { "Connect", { "Fetch", False }, { "Callback", "UnreachableTestService" } },
    SameTest -> MatchQ,
    TestID   -> "ServiceConnectButton-ClearsNoModelListCache@@Tests/PreferencesServiceSelector.wlt:344,1-369,2"
]

(* A cancelled connection doesn't fetch or change anything: *)
VerificationTest[
    Module[ { calls = { }, button },
        service = "UnreachableTestService";
        button  = Wolfram`Chatbook`PreferencesContent`Private`serviceConnectButton[
            Dynamic @ prefCache, Dynamic @ service, Dynamic @ model, Dynamic @ modelNameSelector, Dynamic @ state
        ];
        Block[
            {
                Wolfram`Chatbook`Services`Private`$noModelListCache = <| "UnreachableTestService" -> 0 |>,
                Wolfram`LLMFunctions`APIs`Common`ConnectToService = (AppendTo[ calls, "Connect" ]; $Canceled) &,
                Wolfram`Chatbook`Common`getServiceModelList = (AppendTo[ calls, "Fetch" ]; { }) &,
                Wolfram`Chatbook`PreferencesContent`Private`serviceSelectCallback =
                    Function[ Null, AppendTo[ calls, "Callback" ], HoldRest ],
                Needs
            },
            Replace[ button, HoldPattern @ Button[ _, action_, ___ ] :> action ];
            { calls, Wolfram`Chatbook`Services`Private`$noModelListCache }
        ]
    ],
    { { "Connect" }, <| "UnreachableTestService" -> 0 |> },
    SameTest -> MatchQ,
    TestID   -> "ServiceConnectButton-Canceled@@Tests/PreferencesServiceSelector.wlt:372,1-394,2"
]

(* :!CodeAnalysis::EndBlock:: *)
