(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/WorkspaceChatInputCell.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/WorkspaceChatInputCell.wlt:11,1-16,2"
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
    TestID   -> "AttachedInputCell@@Tests/WorkspaceChatInputCell.wlt:24,1-29,2"
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
    TestID   -> "SendStopSelector@@Tests/WorkspaceChatInputCell.wlt:34,1-43,2"
]

VerificationTest[
    $selector = First @ $selectors,
    PaneSelectorBox[ { (_Rule|_RuleDelayed).. }, _Dynamic, ___ ],
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Form@@Tests/WorkspaceChatInputCell.wlt:45,1-50,2"
]

(* The front end keeps animating the stop button's spinner if it's in the default pane (even while hidden): *)
VerificationTest[
    Drop[ $selector, 2 ],
    PaneSelectorBox[ ___?OptionQ ],
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-NoDefaultPane@@Tests/WorkspaceChatInputCell.wlt:53,1-58,2"
]

VerificationTest[
    Cases[
        $inputCell,
        PaneSelectorBox[ _, _, default: Except[ _?OptionQ ], ___ ] :> default,
        Infinity
    ],
    { ___? (FreeQ[ #, "StopChatButton" | "ChatEvaluatingSpinner" | _AnimatorBox | _ProgressIndicatorBox ] &) },
    SameTest -> MatchQ,
    TestID   -> "NoAnimatedDefaultPanes@@Tests/WorkspaceChatInputCell.wlt:60,1-69,2"
]

VerificationTest[
    Keys @ First @ $selector,
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Keys@@Tests/WorkspaceChatInputCell.wlt:71,1-76,2"
]

VerificationTest[
    FirstCase[ #, HoldPattern[ BoxID -> id_String ] :> id, Missing[ ], Infinity ] & /@ Association @ First @ $selector,
    <| False -> "NASendChatButton", True -> "NAStopChatButton" |>,
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-Panes@@Tests/WorkspaceChatInputCell.wlt:78,1-83,2"
]

VerificationTest[
    FreeQ[ Lookup[ First @ $selector, False ], "StopChatButton" ] && ! FreeQ[ Lookup[ First @ $selector, True ], "StopChatButton" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SendStopSelector-SpinnerOnlyInStopPane@@Tests/WorkspaceChatInputCell.wlt:85,1-90,2"
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
    TestID   -> "SelectedPane-Definition@@Tests/WorkspaceChatInputCell.wlt:99,1-134,2"
]

VerificationTest[
    selectedButtonID @ None,
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoChat@@Tests/WorkspaceChatInputCell.wlt:136,1-141,2"
]

VerificationTest[
    selectedButtonID @ CellObject[ "WindowInput" ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-ChatRunning@@Tests/WorkspaceChatInputCell.wlt:143,1-148,2"
]

(* A chat in another notebook (or the sidebar) doesn't turn the window's send button into a stop button: *)
VerificationTest[
    selectedButtonID @ CellObject[ "OtherInput" ],
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-OtherNotebookChat-robustness-4@@Tests/WorkspaceChatInputCell.wlt:151,1-156,2"
]

(* If the symbol does not have a value yet, there is no chat in this window: *)
VerificationTest[
    selectedButtonID[ ],
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoValue@@Tests/WorkspaceChatInputCell.wlt:159,1-164,2"
]

(* The Dynamic is only updated when a chat starts or ends: *)
VerificationTest[
    Cases[ $selector[[ 2 ]], HoldPattern[ TrackedSymbols :> s_ ] :> HoldComplete @ s, { 0, Infinity } ],
    { HoldComplete[ { Wolfram`Chatbook`$ChatEvaluationCell } ] },
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-TrackedSymbols@@Tests/WorkspaceChatInputCell.wlt:167,1-172,2"
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
    TestID   -> "StopButton-Scoped-robustness-4@@Tests/WorkspaceChatInputCell.wlt:175,1-185,2"
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
    TestID   -> "SidebarSendStopSelector-NoDefaultPane@@Tests/WorkspaceChatInputCell.wlt:193,1-203,2"
]

VerificationTest[
    $sidebarStopSelector = Lookup[ First @ $sidebarSelector, True ];
    FreeQ[ Lookup[ First @ $sidebarSelector, False ], "StopChatButton" ] &&
        FreeQ[ Lookup[ First @ $sidebarStopSelector, False ], "StopChatButton" ] &&
        ! FreeQ[ Lookup[ First @ $sidebarStopSelector, True ], "StopChatButton" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSendStopSelector-SpinnerOnlyInStopPane@@Tests/WorkspaceChatInputCell.wlt:205,1-213,2"
]

(* :!CodeAnalysis::EndBlock:: *)
