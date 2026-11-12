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

(* A fake settings store that behaves like the front end: unsetting a key leaves (or creates) its parent as <||> *)
VerificationTest[
    $fakeScope = FrontEndObject[ LinkObject[ "FakeFrontEnd", 0, 0 ] ];

    storeKeys[ { TaggingRules, "ChatNotebookSettings", keys___ } ] := { keys };

    storeRead[ keys_List ] := Replace[
        Fold[
            Replace[ #1, { as: _Association | { ___Rule } :> Lookup[ as, #2, Inherited ], _ -> Inherited } ] &,
            $store,
            keys
        ],
        Missing[ ___ ] -> Inherited
    ];

    (* Like the front end, parents may be stored as rule lists (e.g. in notebooks saved by older versions): *)
    storeWrite[ { key_ }, Inherited, as_Association ] := KeyDrop[ as, key ];
    storeWrite[ { key_ }, value_, as_Association ] := Append[ as, key -> value ];
    storeWrite[ { key_, rest__ }, value_, as_Association ] := Append[
        as,
        key -> storeWrite[
            { rest },
            value,
            Replace[ Lookup[ as, key, <| |> ], { rules: { ___Rule } :> Association @ rules, Except[ _Association ] -> <| |> } ]
        ]
    ];

    withFakeStore[ eval_ ] := Block[
        {
            CurrentValue = Function[ storeRead @ storeKeys[ #2 ] ],
            Wolfram`Chatbook`Common`setCurrentValue = Function[ $store = storeWrite[ storeKeys[ #2 ], #3, $store ]; #3 ]
        },
        eval;
        $store
    ];
    withFakeStore // Attributes = { HoldFirst };

    $plainChat = <| "Name" -> "PlainChat", "Tools" -> { "WolframAlpha" } |>;

    checkboxHandler = FirstCase[
        Wolfram`Chatbook`ToolManager`Private`enabledControl[
            { 1, "WolframAlpha" },
            { 1, $plainChat },
            Dynamic[ { dRow, dColumn } ],
            Dynamic @ Evaluate @ $fakeScope,
            { $plainChat }
        ],
        Checkbox[ Dynamic[ _, f_ ], ___ ] :> f,
        $Failed,
        Infinity
    ];

    rightCol = Wolfram`Chatbook`ToolManager`Private`rightColControl[
        { 1, "DocumentationSearcher" },
        Dynamic[ { dRow, dColumn } ],
        Dynamic @ Evaluate @ $fakeScope,
        Dynamic @ notInherited,
        { }
    ];

    popupHandler = FirstCase[ rightCol, PopupMenu[ Dynamic[ _, f_ ], ___ ] :> f, $Failed, Infinity ];
    clearAction  = FirstCase[ rightCol, Button[ _, a_, ___ ] :> Function[ a ], $Failed, Infinity ];

    { checkboxHandler, popupHandler, clearAction }
    ,
    { _Function, _Function, _Function },
    SameTest -> MatchQ,
    TestID   -> "Definitions"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*No Empty Leftovers*)
VerificationTest[
    $store = <| |>;
    withFakeStore[ checkboxHandler[ False ]; checkboxHandler[ True ] ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "CheckboxRoundTrip"
]

VerificationTest[
    $store = <| |>;
    withFakeStore[ popupHandler[ None ]; popupHandler[ Inherited ] ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "PopupRoundTrip"
]

VerificationTest[
    $store = <| |>;
    withFakeStore[ popupHandler[ None ]; clearAction[ ] ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "ClearButton"
]

VerificationTest[
    $store = <|
        "ToolSelections"    -> <| "DocumentationSearcher" -> <| "PlainChat" -> True |>, "Other" -> <| "PlainChat" -> True |> |>,
        "ToolSelectionType" -> <| "DocumentationSearcher" -> All |>
    |>;
    withFakeStore[ clearAction[ ] ],
    <| "ToolSelections" -> <| "Other" -> <| "PlainChat" -> True |> |> |>,
    SameTest -> MatchQ,
    TestID   -> "ClearButtonKeepsOtherTools"
]

VerificationTest[
    $store = <|
        "ToolSelections"    -> { "DocumentationSearcher" -> { "PlainChat" -> True }, "Other" -> { "PlainChat" -> True } },
        "ToolSelectionType" -> { "DocumentationSearcher" -> All }
    |>;
    withFakeStore[ clearAction[ ] ],
    <| "ToolSelections" -> <| "Other" -> { "PlainChat" -> True } |> |>,
    SameTest -> MatchQ,
    TestID   -> "ClearButtonRuleLists"
]

VerificationTest[
    $store = <| "ToolSelectionType" -> { "DocumentationSearcher" -> All } |>;
    withFakeStore[ popupHandler[ Inherited ] ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "PopupInheritedRuleList"
]

(* :!CodeAnalysis::EndBlock:: *)
