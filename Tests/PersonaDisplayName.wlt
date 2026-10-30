(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/PersonaDisplayName.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/PersonaDisplayName.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*personaDisplayName*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persona Names*)
VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ "Wolfie" ],
    RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameWolfie" ],
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-BuiltIn@@Tests/PersonaDisplayName.wlt:28,1-33,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ "NotARealPersonaName" ],
    "NotARealPersonaName",
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Unknown-Name@@Tests/PersonaDisplayName.wlt:35,1-40,2"
]

VerificationTest[
    {
        Wolfram`Chatbook`Common`personaDisplayName[ "MyPersona", <| "DisplayName" -> "My Persona" |> ],
        Wolfram`Chatbook`Common`personaDisplayName[ "MyPersona", <| |> ],
        Wolfram`Chatbook`Common`personaDisplayName[ "MyPersona", Missing[ "KeyAbsent", "MyPersona" ] ],
        Wolfram`Chatbook`Common`personaDisplayName[ "MyPersona", Automatic ]
    },
    { "My Persona", "MyPersona", "MyPersona", "MyPersona" },
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Data@@Tests/PersonaDisplayName.wlt:42,1-52,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-String Settings*)

(* The chat input dingbat gets Missing[ "NotAvailable" ] for the persona while its cell is being removed: *)
VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ Missing[ "NotAvailable" ] ],
    "",
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Missing@@Tests/PersonaDisplayName.wlt:59,1-64,2"
]

VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName /@ {
        None,
        Inherited,
        Automatic,
        $Failed,
        <| "LLMEvaluatorName" -> "Wolfie" |>
    },
    { "", "", "", "", "" },
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Non-String@@Tests/PersonaDisplayName.wlt:66,1-77,2"
]

(* The persona icon tooltip as constructed by the chat input dingbat: *)
VerificationTest[
    With[ { persona = Missing[ "NotAvailable" ] },
        ToBoxes @ Tooltip[
            Wolfram`Chatbook`Common`getPersonaMenuIcon @ persona,
            Wolfram`Chatbook`Common`personaDisplayName @ persona
        ]
    ],
    _? (FreeQ[ _Failure ]),
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Dingbat-Tooltip@@Tests/PersonaDisplayName.wlt:80,1-90,2"
]

(* :!CodeAnalysis::EndBlock:: *)
