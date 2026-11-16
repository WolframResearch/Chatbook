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
(*personaDisplayName*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Persona Names*)
VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ "Wolfie" ],
    RawBoxes @ DynamicBox @ FEPrivate`FrontEndResource[ "ChatbookStrings", "PersonaNameWolfie" ],
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-BuiltIn"
]

VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ "NotARealPersonaName" ],
    "NotARealPersonaName",
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Unknown-Name"
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
    TestID   -> "PersonaDisplayName-Data"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Non-String Settings*)

(* The chat input dingbat gets Missing[ "NotAvailable" ] for the persona while its cell is being removed: *)
VerificationTest[
    Wolfram`Chatbook`Common`personaDisplayName[ Missing[ "NotAvailable" ] ],
    "",
    SameTest -> MatchQ,
    TestID   -> "PersonaDisplayName-Missing"
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
    TestID   -> "PersonaDisplayName-Non-String"
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
    TestID   -> "PersonaDisplayName-Dingbat-Tooltip"
]

(* :!CodeAnalysis::EndBlock:: *)
