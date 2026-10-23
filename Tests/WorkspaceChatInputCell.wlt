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
(*attachedWorkspaceChatInputCell*)
VerificationTest[
    $inputCell = Wolfram`Chatbook`ChatModes`UI`Private`attachedWorkspaceChatInputCell[ "Bottom" ],
    Cell[ _BoxData, "ChatInputField", ___ ],
    SameTest -> MatchQ,
    TestID   -> "AttachedInputCell"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Send/Stop Button Selector*)
VerificationTest[
    $selectors = Cases[
        $inputCell,
        p_PaneSelectorBox /; ! FreeQ[ p, "NASendChatButton" ] && ! FreeQ[ p, "NAStopChatButton" ],
        Infinity
    ],
    { _PaneSelectorBox },
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector"
]

VerificationTest[
    $selector = First @ $selectors,
    PaneSelectorBox[ { (_Rule|_RuleDelayed).. }, _Dynamic, ___ ],
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Form"
]

(* The front end keeps animating the stop button's spinner if it's in the default pane (even while hidden): *)
VerificationTest[
    Drop[ $selector, 2 ],
    PaneSelectorBox[ ___?OptionQ ],
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-NoDefaultPane"
]

VerificationTest[
    Cases[
        $inputCell,
        PaneSelectorBox[ _, _, default: Except[ _?OptionQ ], ___ ] :> default,
        Infinity
    ],
    { ___? (FreeQ[ #, "StopChatButton" | "ChatEvaluatingSpinner" | _AnimatorBox | _ProgressIndicatorBox ] &) },
    SameTest -> MatchQ,
    TestID   -> "NoAnimatedDefaultPanes"
]

VerificationTest[
    Keys @ First @ $selector,
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Keys"
]

VerificationTest[
    FirstCase[ #, HoldPattern[ BoxID -> id_String ] :> id, Missing[ ], Infinity ] & /@ Association @ First @ $selector,
    <| False -> "NASendChatButton", True -> "NAStopChatButton" |>,
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Panes"
]

VerificationTest[
    FreeQ[ Lookup[ First @ $selector, False ], "StopChatButton" ] && ! FreeQ[ Lookup[ First @ $selector, True ], "StopChatButton" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-SpinnerOnlyInStopPane"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Selected Pane*)

(* Emulates the front end: the selector's Dynamic is evaluated in the kernel and the pane with a matching key is shown,
   falling back to the default pane (if any) when no key matches. *)
VerificationTest[
    Clear[ selectedButtonID, selectedButtonID0 ];

    (* the BoxID of the displayed button for a given value of $ChatEvaluationCell (or when it has no value) *)
    selectedButtonID[ value_ ] := Block[ { Wolfram`Chatbook`$ChatEvaluationCell = value }, selectedButtonID0[ ] ];
    selectedButtonID[ ] := Block[ { Wolfram`Chatbook`$ChatEvaluationCell }, selectedButtonID0[ ] ];

    selectedButtonID0[ ] := FirstCase[
        Replace[
            ReleaseHold @ Extract[ $selector, { 2, 1 }, Hold ],
            {
                k_ /; KeyExistsQ[ First @ $selector, k ] :> Lookup[ First @ $selector, k ],
                _ :> If[ Length @ $selector >= 3 && ! OptionQ @ $selector[[ 3 ]], $selector[[ 3 ]], Missing[ "NoPane" ] ]
            }
        ],
        HoldPattern[ BoxID -> id_String ] :> id,
        Missing[ "NoButton" ],
        Infinity
    ];

    "selectedButtonID defined",
    "selectedButtonID defined",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-Definition"
]

VerificationTest[
    selectedButtonID @ None,
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoChat"
]

VerificationTest[
    selectedButtonID @ CellObject[ "12345678-0000-0000-0000-000000000000" ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-ChatRunning"
]

(* Anything other than None (e.g. if the symbol does not have a value yet) shows the stop button, as before: *)
VerificationTest[
    selectedButtonID[ ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoValue"
]

(* :!CodeAnalysis::EndBlock:: *)
