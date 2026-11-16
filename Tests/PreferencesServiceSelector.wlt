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
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeServiceSelector*)
VerificationTest[
    $parts = selectorParts[ $testServices, prefCache, service, model, modelNameSelector, state, pending ];
    { Head @ setterFrom @ $parts, wrapperOptions @ $parts },
    { Function, { OrderlessPatternSequence[ SynchronousUpdating -> False, TrackedSymbols :> { pending } ] } },
    SameTest -> MatchQ,
    TestID   -> "ServiceSelector-AsynchronousWrapper"
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
    TestID   -> "ServiceSelector-DisplayFollowsPrefCache"
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
    TestID   -> "ServiceSelector-SetterDoesNotFetchModelList"
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
    TestID   -> "ServiceSelector-SetterCachedModelList"
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
    TestID   -> "ServiceSelector-AsyncRunsCallback"
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
    TestID   -> "ServiceSelector-AsyncNewerSelection"
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
    TestID   -> "ServiceSelector-AsyncSameSelection"
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
    TestID   -> "ServiceSelector-AsyncNoPendingSelection"
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
    TestID   -> "NoModelListCache-SkipsRepeatedFetch"
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
    TestID   -> "NoModelListCache-Expires"
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
    TestID   -> "NoModelListCache-Invalidate"
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
    TestID   -> "NoModelListCache-Clear"
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
    TestID   -> "GetModelListQuietly-NoMessages"
]

(* A suppressed connection dialog is still detected while messages are quieted: *)
VerificationTest[
    Wolfram`Chatbook`Services`Private`getModelListQuietly @ <|
        "Service"   -> "QuietTestService",
        "ModelList" :> (Message[ Part::partw, 1, { } ]; Message[ DialogInput::nprmtv ]; { })
    |>,
    Missing[ "NotConnected" ],
    SameTest -> MatchQ,
    TestID   -> "GetModelListQuietly-NotConnected"
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
    TestID   -> "GetServiceDefaultModel-RetriesAutomatic"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*makeModelNameSelector*)
VerificationTest[
    (* Builds the model name selector for the given stored model with a stubbed model list, recording any settings
       writes, and returns { writes, prefCache, popup items, popup setter }: *)
    buildModelNameSelector[ name_ ] :=
        Module[ { writes = { }, cache, svc = "OpenAI", mdl = name, sel = None, st = "Loaded", popup },
            cache = <|
                "Model"               -> <| "Service" -> "OpenAI", "Name" -> name |>,
                "ServiceDefaultModel" -> <| |>
            |>;
            Block[
                {
                    Wolfram`Chatbook`Common`getServiceModelList = { <| "Name" -> "gpt-3.5-turbo", "DisplayName" -> "GPT-3.5", "Icon" -> "" |>, <| "Name" -> "gpt-4o", "DisplayName" -> "GPT-4o", "Icon" -> "" |> } &,
                    Wolfram`Chatbook`Common`chooseDefaultModelName = "gpt-3.5-turbo" &,
                    Wolfram`Chatbook`Common`$cloudNotebooks = True,
                    CurrentChatSettings
                },
                CurrentChatSettings /: Set[ CurrentChatSettings[ args___ ], v_ ] := (AppendTo[ writes, { args } -> v ]; v);
                CurrentChatSettings[ $FrontEnd, "Model" ] := cache[ "Model" ];
                popup = Wolfram`Chatbook`PreferencesContent`Private`makeModelNameSelector[ cache, svc, mdl, sel, st ]
            ];
            {
                writes,
                cache,
                Replace[ popup, HoldPattern @ PopupMenu[ _, items_, ___ ] :> items ],
                Replace[ popup, HoldPattern @ PopupMenu[ Dynamic[ _, setter_, ___ ], ___ ] :> setter ]
            }
        ],
    _,
    SameTest -> MatchQ,
    TestID   -> "ModelNameSelector-Definitions"
]

(* Viewing Preferences must not replace a model the service doesn't list (fine-tuned, custom, set in code): *)
VerificationTest[
    Most @ buildModelNameSelector[ "ft:gpt-4.1-mini:qa-org::abc123" ],
    {
        { },
        <|
            "Model"               -> <| "Service" -> "OpenAI", "Name" -> "ft:gpt-4.1-mini:qa-org::abc123" |>,
            "ServiceDefaultModel" -> <| |>
        |>,
        {
            "ft:gpt-4.1-mini:qa-org::abc123" -> "ft:gpt-4.1-mini:qa-org::abc123",
            Delimiter,
            "gpt-3.5-turbo" -> "GPT-3.5",
            "gpt-4o" -> "GPT-4o"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "ModelNameSelector-KeepsUnlistedModel"
]

VerificationTest[
    Most @ buildModelNameSelector[ "gpt-4o" ],
    {
        { },
        <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>, "ServiceDefaultModel" -> <| |> |>,
        { "gpt-3.5-turbo" -> "GPT-3.5", "gpt-4o" -> "GPT-4o" }
    },
    SameTest -> MatchQ,
    TestID   -> "ModelNameSelector-ListedModel"
]

(* A non-string name is shown as a display-only Automatic entry that the setter doesn't store: *)
VerificationTest[
    Module[ { result, setter },
        result = buildModelNameSelector[ Automatic ];
        setter = Last @ result;
        Block[ { Wolfram`Chatbook`PreferencesContent`Private`modelSelectCallback = Function[ Null, Throw[ "Called", $tag ], HoldRest ] },
            { Most @ result, Catch[ setter @ Automatic, $tag ] }
        ]
    ],
    {
        {
            { },
            <| "Model" -> <| "Service" -> "OpenAI", "Name" -> Automatic |>, "ServiceDefaultModel" -> <| |> |>,
            { Automatic -> Wolfram`Chatbook`Common`tr[ "Automatic" ], Delimiter, "gpt-3.5-turbo" -> "GPT-3.5", "gpt-4o" -> "GPT-4o" }
        },
        Null
    },
    SameTest -> MatchQ,
    TestID   -> "ModelNameSelector-AutomaticDisplayOnly"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*modelSelectCallback*)

(* A model set outside the UI may leave ServiceDefaultModel unset, which shouldn't be stored as a Missing[...]: *)
VerificationTest[
    Module[ { writes = { }, cache, svc = "OpenAI", mdl = "gpt-4o" },
        cache = <| "Model" -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |> |>;
        Block[ { CurrentChatSettings },
            CurrentChatSettings /: Set[ CurrentChatSettings[ args___ ], v_ ] := (AppendTo[ writes, { args } -> v ]; v);
            Wolfram`Chatbook`PreferencesContent`Private`modelSelectCallback[ "gpt-3.5-turbo", cache, svc, mdl ]
        ];
        { writes, cache }
    ],
    {
        {
            { $FrontEnd, "Model" } -> <| "Service" -> "OpenAI", "Name" -> "gpt-3.5-turbo" |>,
            { $FrontEnd, "ServiceDefaultModel" } -> <| "OpenAI" -> "gpt-3.5-turbo" |>
        },
        <|
            "Model"               -> <| "Service" -> "OpenAI", "Name" -> "gpt-3.5-turbo" |>,
            "ServiceDefaultModel" -> <| "OpenAI" -> "gpt-3.5-turbo" |>
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ModelSelectCallback-NoServiceDefaultModel"
]

VerificationTest[
    Module[ { cache, svc = "OpenAI", mdl = "gpt-4o" },
        cache = <|
            "Model"               -> <| "Service" -> "OpenAI", "Name" -> "gpt-4o" |>,
            "ServiceDefaultModel" -> <| "ServiceB" -> "b" |>
        |>;
        Block[ { CurrentChatSettings },
            CurrentChatSettings /: Set[ CurrentChatSettings[ ___ ], v_ ] := v;
            Wolfram`Chatbook`PreferencesContent`Private`modelSelectCallback[ "gpt-3.5-turbo", cache, svc, mdl ]
        ];
        cache[ "ServiceDefaultModel" ]
    ],
    <| "ServiceB" -> "b", "OpenAI" -> "gpt-3.5-turbo" |>,
    SameTest -> MatchQ,
    TestID   -> "ModelSelectCallback-KeepsOtherServices"
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
    TestID   -> "ServiceConnectButton-ClearsNoModelListCache"
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
    TestID   -> "ServiceConnectButton-Canceled"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*disconnectService*)

(* Disconnecting the selected service rebuilds the panel so it shows the new default model: *)
VerificationTest[
    Module[ { calls = { }, cache },
        cache = <| "Model" -> <| "Service" -> "DisconnectTestService", "Name" -> "m" |> |>;
        Block[
            {
                SystemCredential,
                SetEnvironment,
                Wolfram`Chatbook`PreferencesContent`Private`clearConnectionCache = Null &,
                Wolfram`Chatbook`Common`updateDynamics = AppendTo[ calls, # ] &,
                Wolfram`Chatbook`Common`forceRefreshCloudPreferences = AppendTo[ calls, "Cloud" ] &,
                CurrentChatSettings
            },
            SystemCredential /: Unset[ SystemCredential[ _ ] ] := Null;
            CurrentChatSettings /: Set[ CurrentChatSettings[ ___ ], v_ ] := v;
            Wolfram`Chatbook`PreferencesContent`Private`disconnectService[ Dynamic @ cache, "DisconnectTestService" ]
        ];
        { calls, cache[ "Model" ] === $DefaultModel }
    ],
    { { "Preferences", "Cloud", "Services" }, True },
    SameTest -> MatchQ,
    TestID   -> "DisconnectService-SelectedService"
]

(* Disconnecting another service leaves the panel alone: *)
VerificationTest[
    Module[ { calls = { }, cache },
        cache = <| "Model" -> <| "Service" -> "OtherTestService", "Name" -> "m" |> |>;
        Block[
            {
                SystemCredential,
                SetEnvironment,
                Wolfram`Chatbook`PreferencesContent`Private`clearConnectionCache = Null &,
                Wolfram`Chatbook`Common`updateDynamics = AppendTo[ calls, # ] &,
                Wolfram`Chatbook`Common`forceRefreshCloudPreferences = AppendTo[ calls, "Cloud" ] &,
                CurrentChatSettings
            },
            SystemCredential /: Unset[ SystemCredential[ _ ] ] := Null;
            CurrentChatSettings /: Set[ CurrentChatSettings[ ___ ], v_ ] := v;
            Wolfram`Chatbook`PreferencesContent`Private`disconnectService[ Dynamic @ cache, "DisconnectTestService" ]
        ];
        { calls, cache[ "Model" ] }
    ],
    { { "Services" }, <| "Service" -> "OtherTestService", "Name" -> "m" |> },
    SameTest -> MatchQ,
    TestID   -> "DisconnectService-OtherService"
]

(* :!CodeAnalysis::EndBlock:: *)
