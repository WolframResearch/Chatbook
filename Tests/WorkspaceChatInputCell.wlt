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
   falling back to the default pane (if any) when no key matches. The window's chat cells are top-level cells of the
   window notebook (EvaluationNotebook[ ] in the Dynamic): *)
VerificationTest[
    Clear[ selectedButtonID, selectedButtonID0 ];
    $windowNB = NotebookObject[ "TestWindow", "TestWindow" ];

    (* the BoxID of the displayed button for a given value of $ChatEvaluationCell (or when it has no value) *)
    selectedButtonID[ value_ ] := Block[ { Wolfram`Chatbook`$ChatEvaluationCell = value }, selectedButtonID0[ ] ];
    selectedButtonID[ ] := Block[ { Wolfram`Chatbook`$ChatEvaluationCell }, selectedButtonID0[ ] ];

    selectedButtonID0[ ] := Block[
        {
            EvaluationNotebook = $windowNB &,
            Wolfram`Chatbook`Common`parentNotebook = Replace[ {
                CellObject[ "WindowInput" ] -> $windowNB,
                CellObject[ "OtherInput" ]  -> NotebookObject[ "Other", "Other" ],
                _                           -> $Failed
            } ]
        },
        FirstCase[
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
        ]
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
    selectedButtonID @ CellObject[ "WindowInput" ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-ChatRunning"
]

(* A chat in another notebook (or the sidebar) doesn't turn the window's send button into a stop button: *)
VerificationTest[
    selectedButtonID @ CellObject[ "OtherInput" ],
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-OtherNotebookChat-robustness-4"
]

(* If the symbol does not have a value yet, there is no chat in this window: *)
VerificationTest[
    selectedButtonID[ ],
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoValue"
]

(* The Dynamic is only updated when a chat starts or ends: *)
VerificationTest[
    Cases[ $selector[[ 2 ]], HoldPattern[ TrackedSymbols :> s_ ] :> HoldComplete @ s, { 0, Infinity } ],
    { HoldComplete[ { Wolfram`Chatbook`$ChatEvaluationCell } ] },
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-TrackedSymbols"
]

(* The stop button only stops a chat in this window: *)
VerificationTest[
    FirstCase[
        Lookup[ First @ $selector, True ],
        HoldPattern[ ButtonFunction :> f_ ] :> HoldComplete @ f,
        Missing[ ],
        Infinity
    ],
    HoldComplete[ CompoundExpression[ _, Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "StopChatIn", EvaluationNotebook[ ] ] ] ],
    SameTest -> MatchQ,
    TestID   -> "StopButton-Scoped-robustness-4"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sidebarChatInputCellSendButton*)

(* The sidebar's send/stop selector (and the initialization gate around it) must also keep the stop button (and its
   spinner) out of a default pane: *)
VerificationTest[
    $sidebarSelector = ToBoxes @ Wolfram`Chatbook`ChatModes`UI`Private`sidebarChatInputCellSendButton[
        fieldContent,
        input,
        returnKeyDownQ,
        initializedQ
    ],
    PaneSelectorBox[ { False -> _, True -> PaneSelectorBox[ { False -> _, True -> _ }, _Dynamic, ___?OptionQ ] }, _Dynamic, ___?OptionQ ],
    SameTest -> MatchQ,
    TestID   -> "SidebarSendStopSelector-NoDefaultPane"
]

VerificationTest[
    $sidebarStopSelector = Lookup[ First @ $sidebarSelector, True ];
    FreeQ[ Lookup[ First @ $sidebarSelector, False ], "StopChatButton" ] &&
        FreeQ[ Lookup[ First @ $sidebarStopSelector, False ], "StopChatButton" ] &&
        ! FreeQ[ Lookup[ First @ $sidebarStopSelector, True ], "StopChatButton" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSendStopSelector-SpinnerOnlyInStopPane"
]

(* :!CodeAnalysis::EndBlock:: *)
