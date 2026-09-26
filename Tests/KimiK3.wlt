(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/KimiK3.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/KimiK3.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Kimi K3 is served through OpenRouter (model id like "moonshotai/kimi-k3"). These tests pin the
   family assignment and the settings that family resolves to for the OpenRouter service. All
   lookups are pure - no network access. Verified end-to-end against the live OpenRouter API
   (sync + streaming) when the config was added. *)

VerificationTest[
    familyOf = Function[
        name,
        Wolfram`Chatbook`Common`resolveFullModelSpec[ { "OpenRouter", name } ][ "Family" ]
    ];
    settingOf = Function[
        { name, key },
        Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[
            <|
                "Model"        -> Wolfram`Chatbook`Common`resolveFullModelSpec[ { "OpenRouter", name } ],
                "ToolsEnabled" -> True
            |>,
            key
        ]
    ];
    { Head @ familyOf, Head @ settingOf },
    { Function, Function },
    SameTest -> MatchQ,
    TestID   -> "Setup@@Tests/KimiK3.wlt:27,1-47,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Family assignment*)

(* The classifier matches the "Kimi" + "K3" words with a leading ___, so a provider prefix
   ("moonshotai/") and a bare id both land on the same family: *)
VerificationTest[
    familyOf /@ { "moonshotai/kimi-k3", "kimi-k3" },
    { "KimiK3", "KimiK3" },
    TestID -> "Family-KimiK3@@Tests/KimiK3.wlt:52,1-57,2"
]

(* Boundary: the K3 rule requires the literal word "K3", so K2.5 is not captured by it: *)
VerificationTest[
    familyOf @ "moonshotai/kimi-k2.5",
    "KimiK25",
    TestID -> "Family-KimiK25-NotCapturedByK3Rule@@Tests/KimiK3.wlt:60,1-65,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kimi K3 settings (OpenRouter)*)

(* Reasoning is mandatory for the OpenRouter Kimi K3 endpoint and cannot be disabled; it is pinned
   to effort "high" (an unset or disabled value produces a service error): *)
VerificationTest[
    settingOf[ "moonshotai/kimi-k3", "Reasoning" ],
    <| "effort" -> "high" |>,
    TestID -> "Settings-KimiK3-Reasoning@@Tests/KimiK3.wlt:73,1-78,2"
]

(* K3 doubles the context window over K2.5 (262144): *)
VerificationTest[
    { settingOf[ "moonshotai/kimi-k3", "MaxContextTokens" ], settingOf[ "moonshotai/kimi-k2.5", "MaxContextTokens" ] },
    { 1048576, 262144 },
    TestID -> "Settings-KimiK3-MaxContextTokens@@Tests/KimiK3.wlt:81,1-86,2"
]

(* Sampling params the endpoint rejects are marked NotSupported so they are stripped before the
   API call: *)
VerificationTest[
    settingOf[ "moonshotai/kimi-k3", # ] & /@ { "Temperature", "TopP", "PresencePenalty", "FrequencyPenalty" },
    { Missing[ "NotSupported" ], Missing[ "NotSupported" ], Missing[ "NotSupported" ], Missing[ "NotSupported" ] },
    TestID -> "Settings-KimiK3-UnsupportedSamplingParams@@Tests/KimiK3.wlt:91,1-96,2"
]

(* Behavioral settings inherited from the base Kimi family: *)
VerificationTest[
    settingOf[ "moonshotai/kimi-k3", # ] & /@ { "ToolMethod", "EndToken", "HybridToolMethod" },
    { "Simple", None, False },
    TestID -> "Settings-KimiK3-InheritedBehavior@@Tests/KimiK3.wlt:100,1-105,2"
]

(* :!CodeAnalysis::EndBlock:: *)
