(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName[ $TestFileName ], "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ModelFamilies.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ModelFamilies.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* Anthropic model families are grouped by capability tier, verified against the live API:
   temperature is rejected from 4.7 onward and by all of 5.x; "adaptive" reasoning is a 4.6+
   feature; only Fable 5 mandates thinking and only Fable 5 refuses the few-shot tool-example
   prompt. These tests pin the family assignment and the settings each tier resolves to. All
   lookups are pure - no network access. *)

VerificationTest[
    familyOf = Function[
        name,
        Wolfram`Chatbook`Common`resolveFullModelSpec[ { "Anthropic", name } ][ "Family" ]
    ];
    settingOf = Function[
        { name, key },
        Wolfram`Chatbook`Settings`Private`resolveAutoSetting0[
            <|
                "Model"        -> Wolfram`Chatbook`Common`resolveFullModelSpec[ { "Anthropic", name } ],
                "ToolsEnabled" -> True
            |>,
            key
        ]
    ];
    { Head @ familyOf, Head @ settingOf },
    { Function, Function },
    SameTest -> MatchQ,
    TestID   -> "Setup@@Tests/ModelFamilies.wlt:27,1-47,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Family assignment*)
VerificationTest[
    familyOf /@ { "claude-opus-5", "claude-sonnet-5", "claude-haiku-5" },
    { "Claude5", "Claude5", "Claude5" },
    TestID -> "Family-Claude5@@Tests/ModelFamilies.wlt:50,1-55,2"
]

(* A point release still hits the family rule, since the trailing ___ absorbs the extra word: *)
VerificationTest[
    familyOf @ "claude-opus-5-1",
    "Claude5",
    TestID -> "Family-Claude5-PointRelease@@Tests/ModelFamilies.wlt:58,1-63,2"
]

VerificationTest[
    familyOf /@ { "claude-fable-5", "claude-fable-5-20260101" },
    { "ClaudeFable5", "ClaudeFable5" },
    TestID -> "Family-ClaudeFable5@@Tests/ModelFamilies.wlt:66,1-71,2"
]

VerificationTest[
    familyOf @ "claude-mythos-5",
    "ClaudeMythos5",
    TestID -> "Family-ClaudeMythos5@@Tests/ModelFamilies.wlt:74,1-79,2"
]

VerificationTest[
    familyOf /@ { "claude-opus-4-7", "claude-opus-4-8", "claude-sonnet-4-7" },
    { "Claude47Plus", "Claude47Plus", "Claude47Plus" },
    TestID -> "Family-Claude47Plus@@Tests/ModelFamilies.wlt:82,1-87,2"
]

(* The regression this grouping hinges on: wordsPattern requires consecutive words, so the
   "5" rule must not capture the 4.5 generation. *)
VerificationTest[
    familyOf /@ {
        "claude-opus-4-5-20251101",
        "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5-20251001",
        "claude-opus-4-1-20250805"
    },
    { "Claude4", "Claude4", "Claude4", "Claude4" },
    TestID -> "Family-Claude4-NotCapturedByClaude5Rule@@Tests/ModelFamilies.wlt:92,1-103,2"
]

(* 4.6 is a separate tier only because its output ceiling doubled: *)
VerificationTest[
    familyOf /@ { "claude-opus-4-6", "claude-sonnet-4-6" },
    { "Claude46", "Claude46" },
    TestID -> "Family-Claude46@@Tests/ModelFamilies.wlt:98,1-103,2"
]

VerificationTest[
    familyOf /@ { "claude-3-7-sonnet-20250219", "claude-2.1" },
    { "Claude3", "Claude2" },
    TestID -> "Family-EarlierGenerations@@Tests/ModelFamilies.wlt:106,1-111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Claude 5 outage regression*)

(* These four values were wrong before the family regrouping: Temperature resolved to the global
   default 0.7, which the API rejects outright for 5.x, and the model fell back to
   Multimodal -> False with a 65536 context window. *)
VerificationTest[
    settingOf[ "claude-opus-5", "Temperature" ],
    Missing[ "NotSupported" ],
    TestID -> "Temperature-Opus5@@Tests/ModelFamilies.wlt:119,1-124,2"
]

VerificationTest[
    settingOf[ "claude-sonnet-5", "Temperature" ],
    Missing[ "NotSupported" ],
    TestID -> "Temperature-Sonnet5@@Tests/ModelFamilies.wlt:127,1-132,2"
]

VerificationTest[
    settingOf[ "claude-opus-5", "Multimodal" ],
    True,
    TestID -> "Multimodal-Opus5@@Tests/ModelFamilies.wlt:135,1-140,2"
]

VerificationTest[
    settingOf[ "claude-opus-5", "MaxContextTokens" ],
    200000,
    TestID -> "MaxContextTokens-Opus5@@Tests/ModelFamilies.wlt:143,1-148,2"
]

(* Temperature is still permitted for 4.6 and earlier, which do accept it: *)
VerificationTest[
    MatchQ[ settingOf[ "claude-opus-4-6", "Temperature" ], Missing[ "NotSupported" ] ],
    False,
    TestID -> "Temperature-Opus46-StillSupported@@Tests/ModelFamilies.wlt:152,1-157,2"
]

VerificationTest[
    settingOf[ "claude-opus-4-7", "Temperature" ],
    Missing[ "NotSupported" ],
    TestID -> "Temperature-Opus47@@Tests/ModelFamilies.wlt:160,1-165,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fable 5 settings are preserved and not leaked to the rest of 5.x*)
VerificationTest[
    settingOf[ "claude-fable-5", # ] & /@
        { "Reasoning", "ToolExamplePrompt", "MaxTokens", "MaxContextTokens" },
    { "adaptive", None, 128000, 1000000 },
    TestID -> "Settings-Fable5@@Tests/ModelFamilies.wlt:171,1-177,2"
]

(* Mythos inherits Fable's settings but keeps the conservative context window, since it could
   not be probed: *)
VerificationTest[
    settingOf[ "claude-mythos-5", # ] & /@
        { "Reasoning", "ToolExamplePrompt", "MaxContextTokens" },
    { "adaptive", None, 200000 },
    TestID -> "Settings-Mythos5@@Tests/ModelFamilies.wlt:182,1-188,2"
]

(* Live probing showed the reasoning_extraction refusal is Fable-specific: opus-5 and sonnet-5
   never refused the few-shot tool-example prompt, and they accept Reasoning -> None. Neither
   setting may be pinned for them. *)
VerificationTest[
    settingOf[ "claude-opus-5", "ToolExamplePrompt" ],
    Automatic,
    TestID -> "ToolExamplePrompt-Opus5-NotPinned@@Tests/ModelFamilies.wlt:194,1-199,2"
]

VerificationTest[
    settingOf[ "claude-opus-5", "Reasoning" ],
    Automatic,
    TestID -> "Reasoning-Opus5-NotPinned@@Tests/ModelFamilies.wlt:202,1-207,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*MaxTokens ceilings*)

(* MaxTokens must be set or the Anthropic provider silently caps output at 4096. Each value below
   is the ceiling the API itself reports when an oversized max_tokens is requested. *)
VerificationTest[
    settingOf[ #, "MaxTokens" ] & /@ {
        "claude-opus-4-1-20250805",
        "claude-opus-4-5-20251101",
        "claude-sonnet-4-5-20250929",
        "claude-haiku-4-5-20251001",
        "claude-opus-4-6",
        "claude-sonnet-4-6",
        "claude-opus-4-7",
        "claude-opus-5",
        "claude-fable-5"
    },
    { 32000, 64000, 64000, 64000, 128000, 128000, 128000, 128000, 128000 },
    TestID -> "MaxTokens-Ceilings@@Tests/ModelFamilies.wlt:198,1-212,2"
]

(* 4.1 is a BaseID-keyed downgrade rather than its own family, which only works because
   autoModelSetting checks BaseID before Family: *)
VerificationTest[
    {
        Wolfram`Chatbook`Common`resolveFullModelSpec[ { "Anthropic", "claude-opus-4-1-20250805" } ][ "BaseID" ],
        settingOf[ "claude-opus-4-1-20250805", "MaxTokens" ]
    },
    { "ClaudeOpus41", 32000 },
    TestID -> "MaxTokens-Opus41-BaseIDOverride@@Tests/ModelFamilies.wlt:217,1-226,2"
]

(* :!CodeAnalysis::EndBlock:: *)
