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
    TestID   -> "SelectedPane-Definition@@Tests/WorkspaceChatInputCell.wlt:98,1-122,2"
]

VerificationTest[
    selectedButtonID @ None,
    "NASendChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoChat@@Tests/WorkspaceChatInputCell.wlt:124,1-129,2"
]

VerificationTest[
    selectedButtonID @ CellObject[ "12345678-0000-0000-0000-000000000000" ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-ChatRunning@@Tests/WorkspaceChatInputCell.wlt:131,1-136,2"
]

(* Anything other than None (e.g. if the symbol does not have a value yet) shows the stop button, as before: *)
VerificationTest[
    selectedButtonID[ ],
    "NAStopChatButton",
    SameTest -> MatchQ,
    TestID   -> "SelectedPane-NoValue@@Tests/WorkspaceChatInputCell.wlt:139,1-144,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*sidebarChatInputCellSendButton*)

(* The sidebar's send/stop selector must also keep the stop button (and its spinner) out of a default pane: *)
VerificationTest[
    $sidebarSelector = ToBoxes @ Wolfram`Chatbook`ChatModes`UI`Private`sidebarChatInputCellSendButton[
        fieldContent,
        input,
        returnKeyDownQ,
        chatEvalCell
    ],
    PaneSelectorBox[ { False -> _, True -> _ }, _Dynamic, ___?OptionQ ],
    SameTest -> MatchQ,
    TestID   -> "SidebarSendStopSelector-NoDefaultPane@@Tests/WorkspaceChatInputCell.wlt:151,1-161,2"
]

VerificationTest[
    FreeQ[ Lookup[ First @ $sidebarSelector, False ], "StopChatButton" ] &&
        ! FreeQ[ Lookup[ First @ $sidebarSelector, True ], "StopChatButton" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "SidebarSendStopSelector-SpinnerOnlyInStopPane@@Tests/WorkspaceChatInputCell.wlt:163,1-169,2"
]

(* :!CodeAnalysis::EndBlock:: *)
