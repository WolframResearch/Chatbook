(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`PromptNotebook`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* The prompt notebook of the ACP window (see docs/acp-window.md, "Prompt notebook"): a regular notebook in which the user
   writes a long message (a spec, say) with all of the front end's editing, and sends it with the Send button of its
   docked cell. The button next to Send in the ACP window's input field opens it (or raises the one that is open).

   Rules:
   * It is the user's notebook: editable and saveable (the usual save dialog), never closed by the ACP window, and kept
     open and unchanged after sending, so it can be sent again (in the same session, or after New in a new one).
   * Sending it is sending a message whose only content is this notebook as an attachment (Attachments.wl): a main link
     job (acpMainLinkRun) converts it like an attached notebook (markdown, its graphics as images, the <attachment>
     block), and the pump starts the turn, or queues it while one runs, like a message of the input field (UI.wl's
     acpSendPreparedMessage). Its user cell is written after the last cell (an addressed write) with the notebook's chip:
     the input field is never cleared or moved.
   * Its owner (the ACP window it sends to) and its status are in its TaggingRules ({"ACPPrompt", "Owner"},
     {"ACPPrompt", "State"}, {"ACPPrompt", "StatusText"}); the kernel writes them. Its docked cell shows them, with the
     owner's target (the owner's {"ACP", "PromptTarget"}, which UI.wl's acpUpdateWindowTitle keeps up to date) and busy
     flag, through front-end-only Dynamics; its buttons are ChatbookAction buttons that load Chatbook first. So the
     docked cell keeps working after a kernel restart and in a saved notebook opened later, and always shows where Send
     goes. A notebook whose owner is gone (a saved one opened in a later front end session, or one whose window was
     closed) is not linked: Send links it to the open ACP window and asks for another click, so it never sends anywhere
     the docked cell did not show. For the same reason a message that is being prepared when the window starts a new chat
     (New, another folder or host, a restored session) is not sent (acpCancelPromptNotebookJobs, and the job remembers
     the target it was sent to).
   * It is never a source notebook: "ACPPromptNotebook" in its "ChatNotebookSettings" (ChatModes/Context.wl's exclusion
     reason "ACPPromptNotebook") keeps it from the agent's notebook tools, the attach menu and the Notebook Assistant's
     Sources, also when its "ExcludeFromChat" is reset. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpPromptNotebookWidth    = 720; (* points: the width of a new prompt notebook (less where the display has no room) *)
$acpPromptNotebookMinWidth = 360; (* points: the least width beside the ACP window; otherwise the front end places it *)
$promptTargetLength        = 60;  (* characters of the target's folder in the docked cell (the end is kept) *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*State*)

(* Not reset if this file is reloaded during development. In the MX build they start out empty.
     $promptJobs     prompt notebook -> <| "Token", "Owner", "StartedAt", "Target" |>: its message, whose main link job
                     prepares it (one message per prompt notebook at a time), and the target that the docked cell showed
                     when Send was clicked
     $promptTargets  ACP window -> the target written to its TaggingRules last ({"ACP", "PromptTarget"}) *)
If[ ! AssociationQ @ $promptJobs   , $promptJobs    = <| |> ];
If[ ! AssociationQ @ $promptTargets, $promptTargets = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*TaggingRules*)

(* The prompt notebook's own TaggingRules ({"ACPPrompt", key}): "Owner", "State", "StatusText" *)
promptGet // beginDefinition;

promptGet[ pop_NotebookObject, key_String, default_ ] := Replace[
    Quiet @ CurrentValue[ pop, { TaggingRules, "ACPPrompt", key } ],
    Inherited | $Failed | _Missing :> default
];

promptGet // endDefinition;


promptSet // beginDefinition;
promptSet[ pop_NotebookObject, key_String, value_ ] := (Quiet[ CurrentValue[ pop, { TaggingRules, "ACPPrompt", key } ] = value ]; value);
promptSet // endDefinition;


(* The status line of the docked cell: a state ("Preparing", "Queued", "Sent", "NotSent", "Retargeted", or None) and its
   text, which may name files or the agent's error (display-safe, acpSafeText) *)
setPromptStatus // beginDefinition;

setPromptStatus[ pop_NotebookObject, state_, text_String ] := (
    promptSet[ pop, "StatusText", acpNeutralizeLinearSyntax @ text ];
    promptSet[ pop, "State", state ];
    Null
);

setPromptStatus // endDefinition;


(* "Not sent." or "Not sent. reason" *)
notSentText // beginDefinition;
notSentText[ reason_String ] /; StringLength @ StringTrim @ reason > 0 := acpLabel[ "PromptNotebookNotSentReason", <| "reason" -> reason |> ];
notSentText[ _ ] := acpLabel[ "PromptNotebookNotSent" ];
notSentText // endDefinition;


(* A new message of pop that is not sent (cancelled, failed): "Not sent", unless its message from before is still queued
   in the ACP window owner (Send again while a message is queued replaces it once the new one is prepared, see
   acpReplacedPromptAttachments): that one is still sent; or unless that message was sent while the new one was prepared
   (job: the new message's job, whose "Earlier" is the status that the message from before got meanwhile, see
   acpNotePromptNotebooks): the status says so again *)
promptNotSent // beginDefinition;

promptNotSent[ pop_NotebookObject, owner_, reason_ ] := promptNotSent[ pop, owner, reason, None ];

promptNotSent[ pop_NotebookObject, owner_, reason_, job_ ] := Which[
    queuedInQ[ owner, pop ],
        setPromptStatus[ pop, "Queued", promptStatusText[ owner, "Queued", None ] ],
    MatchQ[ job, KeyValuePattern[ "Earlier" -> KeyValuePattern @ { "State" -> "Sent", "Text" -> _String } ] ],
        setPromptStatus[ pop, "Sent", job[ "Earlier", "Text" ] ],
    True,
        setPromptStatus[ pop, "NotSent", notSentText @ reason ]
];

promptNotSent // endDefinition;


queuedInQ // beginDefinition;

queuedInQ[ owner_NotebookObject, pop_NotebookObject ] := MemberQ[
    promptNotebooksIn @ Lookup[ Replace[ acpQueuedPromptOf @ acpWindowGet[ owner, "QueuedPrompt", None ], None -> <| |> ], "Attachments", { } ],
    pop
];

queuedInQ[ _, _ ] := False;

queuedInQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finding Prompt Notebooks*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebooks*)

(* The open prompt notebooks (front end calls), by the marker in their "ChatNotebookSettings" *)
acpPromptNotebooks // beginDefinition;

acpPromptNotebooks[ ] := If[ $FrontEnd === Null,
    { },
    Select[
        Replace[ Notebooks[ ], Except[ _List ] -> { } ],
        TrueQ @ Quiet @ CurrentValue[ #, { TaggingRules, "ChatNotebookSettings", "ACPPromptNotebook" } ] &
    ]
];

acpPromptNotebooks // endDefinition;


(* The open prompt notebooks of the ACP window owner *)
acpPromptNotebooksOf // beginDefinition;
acpPromptNotebooksOf[ owner_NotebookObject ] := Select[ acpPromptNotebooks[ ], promptGet[ #, "Owner", None ] === owner & ];
acpPromptNotebooksOf // endDefinition;


(* The prompt notebook of the ACP window owner (the one its button opened), or None *)
acpPromptNotebookOf // beginDefinition;
acpPromptNotebookOf[ owner_NotebookObject ] := First[ acpPromptNotebooksOf @ owner, None ];
acpPromptNotebookOf // endDefinition;


(* The prompt notebooks that items name (the references or prepared attachments of a message) *)
promptNotebooksIn // beginDefinition;

promptNotebooksIn[ items_List ] := DeleteDuplicates @ Cases[
    items,
    KeyValuePattern @ { "Prompt" -> True, "Notebook" -> pop_NotebookObject } |
        KeyValuePattern[ "Ref" -> KeyValuePattern @ { "Prompt" -> True, "Notebook" -> pop_NotebookObject } ] :> pop
];

promptNotebooksIn[ _ ] := { };

promptNotebooksIn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookAction*)

(* ChatbookAction["ACP", name, nbo] (preemptive buttons, isolated by acpAction):
     "OpenPromptNotebook"        the button next to Send (nbo: the ACP window)
     "PromptNotebookSend"        Send in the docked cell (nbo: the prompt notebook, its EvaluationNotebook[ ])
     "PromptNotebookCancel"      Cancel while its message is prepared
     "PromptNotebookOpenWindow"  "Open agent window" of a notebook that is not linked *)
acpPromptNotebookAction // beginDefinition;
acpPromptNotebookAction[ "OpenPromptNotebook"      , nbo_NotebookObject ] := acpOpenPromptNotebook @ nbo;
acpPromptNotebookAction[ "PromptNotebookSend"      , pop_NotebookObject ] := acpPromptNotebookSend @ pop;
acpPromptNotebookAction[ "PromptNotebookCancel"    , pop_NotebookObject ] := acpPromptNotebookCancel @ pop;
acpPromptNotebookAction[ "PromptNotebookOpenWindow", pop_NotebookObject ] := acpPromptNotebookOpenWindow @ pop;
acpPromptNotebookAction[ name_, args___ ] := (acpLog[ "UnknownAction", { name, args } ]; Missing[ "UnknownAction", name ]);
acpPromptNotebookAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Opening*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookButton*)

(* Next to Send in the input field (the Notebook Assistant's "open as a separate window" icon): opens the prompt
   notebook of the window, or raises it *)
acpPromptNotebookButton // beginDefinition;

acpPromptNotebookButton[ nbo_NotebookObject ] := Tooltip[
    acpActionButton[
        blueHueButtonAppearance[
            chatbookIcon[ "WorkspaceToolbarIconOpenAsChatbook", False, color @ "NA_BlueHueButtonIcon" ],
            { 24.5, 24.5 }
        ],
        { "OpenPromptNotebook", nbo },
        BoxID        -> "ACPPromptNotebookButton",
        FrameMargins -> 0
    ],
    acpLabel[ "PromptNotebookButtonTooltip" ]
];

acpPromptNotebookButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpOpenPromptNotebook*)

(* The button (preemptive): raises the window's prompt notebook if one is open; otherwise opens a new one beside the ACP
   window, with the input field's text, which leaves the input field (the draft's attachments stay). Gives the
   notebook. *)
acpOpenPromptNotebook // beginDefinition;

acpOpenPromptNotebook[ owner_NotebookObject ] := Catch @ Module[ { existing, input, pop },
    acpCheckSession @ owner;
    acpEnsureWindowRecord @ owner;
    existing = acpPromptNotebookOf @ owner;
    If[ MatchQ[ existing, _NotebookObject ],
        Quiet @ SetSelectedNotebook @ existing;
        Throw @ existing
    ];
    input = acpFE[ owner, "Input", "" ];
    pop   = NotebookPut @ acpPromptNotebook[ owner, acpPromptNotebookCells @ input, acpPromptNotebookGeometry @ owner ];
    If[ ! MatchQ[ pop, _NotebookObject ], Throw @ $Failed ];
    (* the text moved into the notebook *)
    If[ validInputStringQ @ input, acpFESet[ owner, "Input", "" ] ];
    sessionsMoveToActiveDesktop @ pop;
    promptNotebookFocus @ pop;
    acpPublish[ ];
    pop
];

acpOpenPromptNotebook // endDefinition;


(* The caret goes to the end of the moved text, if there is any *)
promptNotebookFocus // beginDefinition;

promptNotebookFocus[ pop_NotebookObject ] := (
    Quiet @ SetSelectedNotebook @ pop;
    Replace[ Quiet @ Cells @ pop, { ___, last_CellObject } :> Quiet @ SelectionMove[ last, After, CellContents ] ];
    Null
);

promptNotebookFocus // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookCells*)

(* The input field's text as the cells of a new prompt notebook (pure): a string as "Text" cells, one per paragraph
   (lines end a paragraph at a blank line), typed boxes (e.g. a pasted graphic) as one "Text" cell like the user cell's *)
acpPromptNotebookCells // beginDefinition;

acpPromptNotebookCells[ input_String ] := Cell[ #, "Text" ] & /@ Select[
    StringTrim[ #, "\n" .. ] & /@ StringSplit[ StringReplace[ input, "\r\n" | "\r" -> "\n" ], RegularExpression[ "\\n[ \\t]*\\n" ] ],
    StringLength @ StringTrim @ # > 0 &
];

acpPromptNotebookCells[ boxes_ ] /; validInputStringQ @ boxes := {
    Cell[
        Replace[
            makeBoxesInputMoreTextLike @ boxes,
            {
                text: _String | _TextData :> text,
                Cell[ b_, ___ ]          :> TextData @ { Cell @ BoxData @ b },
                other_                   :> TextData @ { Cell @ BoxData @ other }
            }
        ],
        "Text"
    ]
};

acpPromptNotebookCells[ _ ] := { };

acpPromptNotebookCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebook*)

(* The prompt notebook (pure, apart from the owner's kernel): a regular notebook (editable, saveable, the user's
   stylesheet default and magnification) with new cells in the "Text" style, the ACP window's kernel as its Evaluator
   (its docked cell's buttons run there), the owner and the status in its TaggingRules, never a source notebook
   ("ACPPromptNotebook", and excluded from chat), and the docked cell. geometry: see acpPromptNotebookGeometry. *)
acpPromptNotebook // beginDefinition;

acpPromptNotebook[ owner_NotebookObject, cells_List, geometry_Association ] := Notebook[
    cells,
    Sequence @@ {
        DockedCells         -> { acpPromptDockedCell @ Replace[ acpWindowGet[ owner, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ] },
        If[ MatchQ[ geometry[ "WindowMargins" ], { { _, _ }, { _, _ } } ], WindowMargins -> geometry[ "WindowMargins" ], Nothing ],
        WindowSize          -> Replace[ geometry[ "WindowSize" ], Except[ { _, _ } ] -> { $acpPromptNotebookWidth, Automatic } ],
        DefaultNewCellStyle -> "Text",
        Evaluator           -> sessionsEvaluator @ owner,
        StyleDefinitions    -> "Default.nb",
        TaggingRules        -> <|
            "ACPPrompt"            -> <| "Owner" -> owner, "State" -> None, "StatusText" -> acpLabel[ "PromptNotebookHint" ] |>,
            "ChatNotebookSettings" -> <| "ACPPromptNotebook" -> True, "ExcludeFromChat" -> True |>
        |>
    }
];

acpPromptNotebook // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpPromptNotebookPlacement*)

(* Where a new prompt notebook goes (pure): beside the ACP window, with its top margin and height (as the Sessions window
   is placed, see Sessions.wl's acpSessionsPlacement for the geometry): "Right" of it if the display has room for at
   least $acpPromptNotebookMinWidth points there (the width is cut to the room), else "Left" of it, else "Default" (the
   front end places it). owner: <| "Left", "Width", "Bottom", "Top", "Height", "Frame" |>; display: { xmin, xmax }. *)
acpPromptNotebookPlacement // beginDefinition;

acpPromptNotebookPlacement[ owner_Association, { xmin_? NumberQ, xmax_? NumberQ }, width_? NumberQ ] := Module[
    { l, w, b, t, h, f, v, right, left },
    { l, w, b, t, h } = Lookup[ owner, { "Left", "Width", "Bottom", "Top", "Height" }, None ];
    f     = Replace[ Lookup[ owner, "Frame", 0 ], Except[ _? NumberQ ] -> 0 ];
    v     = If[ NumberQ @ h, { Automatic, t }, { b, t } ];
    h     = If[ NumberQ @ h, h, Automatic ];
    right = xmax - (l + w + f) - f; (* the widest window right of the ACP window (WindowMargins include the frame) *)
    left  = l - xmin - f;           (* ... and left of it *)
    Which[
        right >= $acpPromptNotebookMinWidth,
            <| "Placement" -> "Right", "WindowMargins" -> { { l + w + f, Automatic }, v }, "WindowSize" -> { Min[ width, right ], h } |>,
        left >= $acpPromptNotebookMinWidth,
            <| "Placement" -> "Left", "WindowMargins" -> { { l - Min[ width, left ] - f, Automatic }, v }, "WindowSize" -> { Min[ width, left ], h } |>,
        True,
            <| "Placement" -> "Default", "WindowMargins" -> Automatic, "WindowSize" -> { width, h } |>
    ]
];

acpPromptNotebookPlacement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpPromptNotebookGeometry*)

(* The placement of a new prompt notebook beside the ACP window owner (front end calls; Sessions.wl's acpOwnerGeometry).
   Without a usable front end answer: the default width, placed by the front end. *)
acpPromptNotebookGeometry // beginDefinition;

acpPromptNotebookGeometry[ owner_NotebookObject ] := With[ { geometry = acpOwnerGeometry @ owner },
    If[ NumberQ @ geometry[ "Left" ] && MatchQ[ geometry[ "Display" ], { _? NumberQ, _? NumberQ } ],
        acpPromptNotebookPlacement[
            KeyTake[ geometry, { "Left", "Width", "Bottom", "Top", "Height", "Frame" } ],
            geometry[ "Display" ],
            $acpPromptNotebookWidth
        ],
        <| "Placement" -> "Default", "WindowMargins" -> Automatic, "WindowSize" -> { $acpPromptNotebookWidth, Automatic } |>
    ]
];

acpPromptNotebookGeometry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Docked Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptDockedCell*)

(* The docked cell of a prompt notebook (pure): self-contained, since the notebook is the user's and may be saved and
   opened anywhere: inline options, built-in boxes, Chatbook's front end resources (icons), front-end-only Dynamics (of
   the notebook's TaggingRules and its owner's) and ChatbookAction buttons that load Chatbook first. agent: the name in
   the "is working" note.
     * The title, the target (the owner's {"ACP", "PromptTarget"}, e.g. "OpenCode \[CenterDot] ~/projects/app"; "Not
       linked to an agent window" with "Open agent window" when the owner is gone) and Send.
     * The status line: the notebook's {"ACPPrompt", "StatusText"} (Cancel while "Preparing"), and while the owner is
       busy (its {"ACP", "Busy"}, as the input field's Send/Stop button reads it) that Send queues the message. *)
acpPromptDockedCell // beginDefinition;

acpPromptDockedCell[ agent_String ] := Cell[
    BoxData @ ToBoxes @ promptDockedView @ agent,
    Background           -> $promptBackground,
    CellFrame            -> { { 0, 0 }, { 1, 0 } },
    CellFrameColor       -> $promptDivider,
    CellFrameMargins     -> { { 10, 10 }, { 6, 6 } },
    CellMargins          -> 0,
    CellTags             -> "ACPPromptNotebookToolbar",
    FontColor            -> $promptFont,
    FontFamily           -> "Source Sans Pro",
    FontSize             -> 13,
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    ShowStringCharacters -> False
];

acpPromptDockedCell // endDefinition;


promptDockedView // beginDefinition;

promptDockedView[ agent_String ] := Grid[
    {
        {
            Pane[ $promptNotebookIcon, ImageMargins -> { { 0, 2 }, { 0, 0 } } ],
            Item[
                Column[
                    {
                        Style[ acpLabel[ "PromptNotebookTitle" ], FontWeight -> "DemiBold" ],
                        Pane[ promptTargetView[ ], ImageSize -> { Full, Automatic }, ImageSizeAction -> "ShrinkToFit" ]
                    },
                    Alignment -> Left,
                    Spacings  -> 0.1
                ],
                ItemSize -> Fit
            ],
            promptButton[
                Tooltip[ sessionsButtonLabel[ acpLabel[ "PromptNotebookSend" ], "Primary" ], acpLabel[ "PromptNotebookSendTooltip" ] ],
                "PromptNotebookSend",
                "ACPPromptNotebookSend"
            ]
        },
        { "", Item[ promptStatusView @ agent, ItemSize -> Fit ], SpanFromLeft }
    },
    Alignment -> { Left, Center },
    Spacings  -> { 0.5, 0.3 }
];

promptDockedView // endDefinition;


(* The owner's target, or "Not linked to an agent window" with "Open agent window" (front end only) *)
promptTargetView // beginDefinition;

promptTargetView[ ] := PaneSelector[
    {
        True -> Style[
            Dynamic @ CurrentValue[
                CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "Owner" } ],
                { TaggingRules, "ACP", "PromptTarget" }
            ],
            FontColor -> $promptMuted,
            FontSize  -> 12,
            LineBreakWithin -> False
        ],
        False -> Row @ {
            Style[ acpLabel[ "PromptNotebookNotLinked" ], FontColor -> $promptMuted, FontSize -> 12, FontSlant -> Italic ],
            Spacer[ 8 ],
            promptButton[
                Tooltip[ sessionsButtonLabel[ acpLabel[ "PromptNotebookOpenWindow" ], "Default" ], acpLabel[ "PromptNotebookOpenWindowTooltip" ] ],
                "PromptNotebookOpenWindow",
                "ACPPromptNotebookOpenWindow",
                "Queued"
            ]
        }
    },
    Dynamic @ FEPrivate`MatchQ[
        CurrentValue[
            CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "Owner" } ],
            { TaggingRules, "ACP", "PromptTarget" }
        ],
        _String
    ],
    ImageSize -> Automatic
];

promptTargetView // endDefinition;


(* The status text (Cancel while the message is prepared), and the note that the owner is busy (not repeated while the
   message is queued); front end only *)
promptStatusView // beginDefinition;

promptStatusView[ agent_String ] := Style[
    Row @ {
        Dynamic @ FEPrivate`If[
            FEPrivate`MatchQ[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "StatusText" } ], _String ],
            CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "StatusText" } ],
            ""
        ],
        PaneSelector[
            {
                "Preparing" -> Row @ {
                    Spacer[ 8 ],
                    promptButton[ sessionsButtonLabel[ acpLabel[ "PromptNotebookCancel" ], "Default" ], "PromptNotebookCancel", "ACPPromptNotebookCancel" ]
                }
            },
            Dynamic @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "State" } ],
            "",
            ImageSize -> Automatic
        ],
        PaneSelector[
            { True -> Row @ { Spacer[ 8 ], Style[ acpLabel[ "PromptNotebookWorking", <| "agent" -> agent |> ], FontColor -> $promptAccent ] } },
            Dynamic @ FEPrivate`If[
                FEPrivate`SameQ[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "State" } ], "Queued" ],
                False,
                TrueQ @ CurrentValue[
                    CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPPrompt", "Owner" } ],
                    { TaggingRules, "ACP", "Busy" }
                ]
            ],
            "",
            ImageSize -> Automatic
        ]
    },
    FontColor       -> $promptMuted,
    FontSize        -> 12,
    FontSlant       -> Italic,
    LineBreakWithin -> Automatic,
    LineIndent      -> 0
];

promptStatusView // endDefinition;


(* A ChatbookAction button of the docked cell: its notebook is the EvaluationNotebook[ ] of the click (the cell is built
   before the notebook exists, and a saved notebook opened later is another NotebookObject). Preemptive (Send and Cancel
   work while the kernel evaluates something else), except "Open agent window" (method "Queued"), the button of a
   notebook that is not linked, e.g. a saved one opened when no kernel runs: a preemptive click then only started the
   kernel, and the window opened at the second click; a queued one waits for the kernel. *)
promptButton // beginDefinition;

promptButton[ label_, name_String, boxID_String ] := promptButton[ label, name, boxID, "Preemptive" ];

promptButton[ label_, name_String, boxID_String, method_String ] := Replace[
    With[ { action = name }, acpActionCode[ action, EvaluationNotebook[ ] ] ],
    Hold[ code_ ] :> Button[ label, code, Appearance -> "Suppressed", BoxID -> boxID, Method -> method ]
];

promptButton // endDefinition;


(* The front end's notebook icon (as the attach menu shows notebooks; the colors are put into the front end's Dynamic
   as values) *)
$promptNotebookIcon := With[ { gray = color @ "NA_OverlayMenuNotebookIcon_Gray", red = color @ "NA_OverlayMenuNotebookIcon_Red" },
    RawBoxes @ DynamicBox[ FEPrivate`FrontEndResource[ "FEBitmaps", "NotebookIcon" ][ gray, red ] ]
];

$promptBackground := color @ "NA_Toolbar";
$promptDivider    := color @ "NA_OverlayMenuFrame";
$promptFont       := color @ "NA_OverlayMenuFont";
$promptAccent     := color @ "NA_BlueHueButtonIcon";
$promptMuted      := acpColor[ "Muted" ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Target*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptTargetLabel*)

(* Where a message of the window goes, as the prompt notebook's docked cell shows it (pure):
   "OpenCode \[CenterDot] ~/projects/app", "OpenCode \[CenterDot] host:~/projects/app" (remote windows),
   "OpenCode \[CenterDot] no project folder". The folder is display-safe and keeps its end. *)
acpPromptTargetLabel // beginDefinition;

acpPromptTargetLabel[ window_Association ] := Module[ { agent, dir, folder },
    agent  = Replace[ Lookup[ window, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ];
    dir    = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> None ];
    folder = Which[
        ! StringQ @ dir,
            acpLabel[ "PromptNotebookNoFolder" ],
        acpWindowSSH @ window === None,
            acpRemoteDisplayName @ acpAbbreviatePath[ dir, $promptTargetLength ],
        True,
            StringRiffle[
                acpRemoteDisplayName /@ acpRemoteFolderLabel[
                    Replace[ acpWindowShortHost @ window, Except[ _String ] -> "?" ],
                    dir,
                    acpWindowRemoteHome @ window,
                    $promptTargetLength
                ],
                ":"
            ]
    ];
    acpLabel[ "PromptNotebookTarget", <| "agent" -> agent, "folder" -> folder |> ]
];

acpPromptTargetLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSyncPromptTarget*)

(* The window's target in its TaggingRules ({"ACP", "PromptTarget"}), which the docked cells of its prompt notebooks show
   (front end only), so they follow a folder change, a host switch or a restored session at once. Called by UI.wl's
   acpUpdateWindowTitle (a new window, a folder change, housekeeping); written only when it changed. *)
acpSyncPromptTarget // beginDefinition;

acpSyncPromptTarget[ nbo_NotebookObject, window_Association ] := With[ { label = acpPromptTargetLabel @ window },
    If[ Lookup[ $promptTargets, Key @ nbo ] =!= label,
        $promptTargets[ nbo ] = label;
        acpFESet[ nbo, "PromptTarget", label ]
    ];
    label
];

acpSyncPromptTarget // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sending*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookSend*)

(* Send in the docked cell (preemptive, fast). The owner is the ACP window of the notebook's TaggingRules; a notebook
   whose owner is gone is linked to the open ACP window instead (findCurrentWorkspaceChat), and its status asks for
   another click: the docked cell showed no target. A message that is prepared already, or a window that can't send
   (no project folder, an error), sends nothing. Otherwise a main link job converts the notebook (acpPromptNotebookJob),
   and the status says so. Gives the job's token, or Null. *)
acpPromptNotebookSend // beginDefinition;

acpPromptNotebookSend[ pop_NotebookObject ] := Catch @ Module[ { stored, owner, window, notice, token },
    stored = promptGet[ pop, "Owner", None ];
    owner  = promptOwner @ stored;
    If[ owner === None,
        setPromptStatus[ pop, "NotSent", notSentText @ acpLabel[ "PromptNotebookNoWindow" ] ];
        Throw @ Null
    ];
    acpCheckSession @ owner;
    window = acpEnsureWindowRecord @ owner;
    If[ owner =!= stored,
        promptSet[ pop, "Owner", owner ];
        acpUpdateWindowTitle @ owner; (* its target, which the docked cell now shows *)
        setPromptStatus[ pop, "Retargeted", acpLabel[ "PromptNotebookRetargeted", <| "target" -> acpPromptTargetLabel @ window |> ] ];
        Throw @ Null
    ];
    (* one message of a notebook is prepared at a time *)
    If[ KeyExistsQ[ $promptJobs, pop ], Throw @ Null ];
    notice = acpCannotSendNotice @ window;
    If[ StringQ @ notice, setPromptStatus[ pop, "NotSent", notSentText @ notice ]; Throw @ Null ];
    token = createUUID[ ];
    PreemptProtect[
        $promptJobs[ pop ] = <| "Token" -> token, "Owner" -> owner, "StartedAt" -> AbsoluteTime[ ], "Target" -> acpPromptTargetLabel @ window |>
    ];
    setPromptStatus[ pop, "Preparing", acpLabel[ "PromptNotebookPreparing" ] ];
    With[ { o = owner, t = token }, acpMainLinkRun[ o, acpPromptNotebookJob[ pop, o, t ], "PromptNotebook" ] ];
    acpPublish[ ];
    token
];

acpPromptNotebookSend // endDefinition;


(* The ACP window a prompt notebook sends to: its owner while that is an open ACP window, else the open ACP window, else
   None *)
promptOwner // beginDefinition;

promptOwner[ stored_ ] := Which[
    MatchQ[ stored, _NotebookObject ] && acpWindowQ @ stored, stored,
    True, Replace[ findCurrentWorkspaceChat[ "ACP" ], Except[ _NotebookObject ] -> None ]
];

promptOwner // endDefinition;


(* Whether the message of pop with token is still being prepared (Cancel, a closed owner, New, a folder change, a host
   switch and housekeeping's timeout drop it) *)
promptJobQ // beginDefinition;
promptJobQ[ pop_NotebookObject, token_String ] := MatchQ[ Lookup[ $promptJobs, Key @ pop ], KeyValuePattern[ "Token" -> token ] ];
promptJobQ // endDefinition;


(* Claims the result of the job with token (only once): the job, or None if it was dropped meanwhile *)
claimPromptJob // beginDefinition;

claimPromptJob[ pop_NotebookObject, token_String ] := PreemptProtect @ With[ { job = Lookup[ $promptJobs, Key @ pop, None ] },
    If[ MatchQ[ job, KeyValuePattern[ "Token" -> token ] ],
        KeyDropFrom[ $promptJobs, Key @ pop ];
        job,
        None
    ]
];

claimPromptJob // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookCancel*)

(* Cancel while the message is prepared: its job stops at the next cell, and its result is dropped *)
acpPromptNotebookCancel // beginDefinition;

acpPromptNotebookCancel[ pop_NotebookObject ] := With[
    { job = PreemptProtect @ With[ { j = Lookup[ $promptJobs, Key @ pop, None ] }, KeyDropFrom[ $promptJobs, Key @ pop ]; j ] },
    promptNotSent[ pop, Lookup[ Replace[ job, Except[ _Association ] -> <| |> ], "Owner", None ], None, job ];
    acpPublish[ ];
    Null
];

acpPromptNotebookCancel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookJob*)

(* The main link job of a prompt notebook's message: the notebook as the only attachment of a message without typed text
   (Attachments.wl's acpPrepareAttachments, with the caps of the owner's window), handed to the pump
   (acpPromptNotebookPrepared). It stops at the next cell once the message was cancelled; an abort (Alt+.) hands over a
   failure. *)
acpPromptNotebookJob // beginDefinition;

acpPromptNotebookJob[ pop_NotebookObject, owner_NotebookObject, token_String ] := Module[ { result },
    If[ ! promptJobQ[ pop, token ], Return[ Null, Module ] ];
    result = promptFailure[ ];
    WithCleanup[
        result = acpCatchAll[
            preparePromptNotebook[ pop, owner, token ],
            (acpLog[ "PromptNotebookFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; promptFailure[ ]) &
        ],
        With[ { r = result }, acpSchedule @ acpPromptNotebookPrepared[ pop, owner, token, r ] ]
    ]
];

acpPromptNotebookJob // endDefinition;


preparePromptNotebook // beginDefinition;

preparePromptNotebook[ pop_NotebookObject, owner_NotebookObject, token_String ] := Module[ { ref },
    ref = acpNotebookAttachmentRef @ pop;
    If[ ! AssociationQ @ ref, Return[ promptFailure[ ], Module ] ];
    acpPrepareAttachments[
        owner,
        Function[ promptJobQ[ pop, token ] ],
        <| "Text" -> "", "Attachments" -> { <| ref, "Prompt" -> True |> } |>
    ]
];

preparePromptNotebook // endDefinition;


promptFailure // beginDefinition;
promptFailure[ ] := Failure[ "PromptNotebookError", <| "MessageTemplate" -> "The notebook could not be converted.", "Notice" -> acpLabel[ "PromptNotebookFailed" ] |> ];
promptFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookPrepared*)

(* The result of the job (in the pump), once (claimed by its token): an empty notebook, a failure (its notice), a window
   that was closed meanwhile or whose target is no longer the one the docked cell showed when Send was clicked (another
   folder or host: New, a folder change and a host switch cancel the job, see acpCancelPromptNotebookJobs; this is the
   check of the result) is not sent; otherwise the message is sent or queued like a message of the input field (UI.wl's
   acpSendPreparedMessage, whose turn start and queue set the "Sent" and "Queued" status). *)
acpPromptNotebookPrepared // beginDefinition;

acpPromptNotebookPrepared[ pop_NotebookObject, owner_NotebookObject, token_String, result_ ] := Catch @ Module[ { job, sent },
    job = claimPromptJob[ pop, token ];
    If[ ! AssociationQ @ job, Throw @ Null ];
    Which[
        ! MatchQ[ result, KeyValuePattern[ "Attachments" -> { __Association } ] ],
            promptNotSent[ pop, owner, failureNotice @ result, job ];
            Throw @ Null,
        emptyMessageQ @ result[ "Attachments" ],
            promptNotSent[ pop, owner, acpLabel[ "PromptNotebookEmpty" ], job ];
            Throw @ Null,
        ! acpWindowQ @ owner,
            setPromptStatus[ pop, "NotSent", notSentText @ acpLabel[ "PromptNotebookNoWindow" ] ];
            Throw @ Null,
        acpPromptTargetLabel @ acpWindowGet @ owner =!= Lookup[ job, "Target", None ],
            promptNotSent[ pop, owner, acpLabel[ "PromptNotebookNewChat" ], job ];
            Throw @ Null
    ];
    (* sent or queued in the order of the Send clicks (job's "StartedAt", see acpSendPreparedMessage) *)
    sent = acpSendPreparedMessage[ owner, result[ "Attachments" ], Lookup[ job, "StartedAt", AbsoluteTime[ ] ] ];
    If[ FailureQ @ sent, promptNotSent[ pop, owner, failureNotice @ sent, job ] ];
    acpPublish[ ];
    sent
];

acpPromptNotebookPrepared // endDefinition;


failureNotice // beginDefinition;
failureNotice[ failure_Failure ] := Replace[ failure[ "Notice" ], Except[ _String ] :> acpLabel[ "PromptNotebookFailed" ] ];
failureNotice[ _ ] := acpLabel[ "PromptNotebookFailed" ];
failureNotice // endDefinition;


(* A notebook without text or images *)
emptyMessageQ // beginDefinition;

emptyMessageQ[ attachments_List ] := AllTrue[
    attachments,
    StringTrim @ Replace[ Lookup[ #, "Text", "" ], Except[ _String ] -> "" ] === "" && Lookup[ #, "Images", { } ] === { } &
];

emptyMessageQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCancelPromptNotebookJobs*)

(* New, a folder change, a host switch or a restored session of the ACP window owner (UI.wl): a new chat, which the
   messages of its prompt notebooks that are being prepared do not go to (their jobs stop at the next cell, their
   results are dropped); their status says why. Gives the prompt notebooks. *)
acpCancelPromptNotebookJobs // beginDefinition;

acpCancelPromptNotebookJobs[ owner_NotebookObject, reason_ ] := Module[ { pops },
    pops = PreemptProtect @ With[ { cancelled = Keys @ Select[ $promptJobs, #[ "Owner" ] === owner & ] },
        KeyDropFrom[ $promptJobs, cancelled ];
        cancelled
    ];
    Scan[ setPromptStatus[ #, "NotSent", notSentText @ reason ] &, pops ];
    pops
];

acpCancelPromptNotebookJobs // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookHousekeeping*)

(* Housekeeping of the ACP window owner (UI.wl): a message of its prompt notebooks whose job did not end within timeout
   seconds (e.g. it waits behind a long evaluation of the user's) is not sent *)
acpPromptNotebookHousekeeping // beginDefinition;

acpPromptNotebookHousekeeping[ owner_NotebookObject, timeout_? NumberQ ] := Module[ { stale },
    stale = PreemptProtect @ With[
        {
            jobs = Select[
                $promptJobs,
                MatchQ[ #, KeyValuePattern @ { "Owner" -> owner, "StartedAt" -> t_? NumberQ /; AbsoluteTime[ ] - t > timeout } ] &
            ]
        },
        KeyDropFrom[ $promptJobs, Keys @ jobs ];
        jobs
    ];
    If[ Length @ stale > 0,
        acpLog[ "PromptNotebookTimeout", <| "Notebook" -> owner, "PromptNotebooks" -> Keys @ stale |> ];
        KeyValueMap[ promptNotSent[ #1, owner, acpLabel[ "PromptNotebookTimeout" ], #2 ] &, stale ]
    ];
    Keys @ stale
];

acpPromptNotebookHousekeeping // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReplacedPromptAttachments*)

(* The attachments of a queued message without those of the prompt notebooks whose new message (attachments) replaces
   them (UI.wl's queueMessage): Send in a prompt notebook whose message is queued queues its new version instead,
   so the agent does not get the notebook twice *)
acpReplacedPromptAttachments // beginDefinition;

acpReplacedPromptAttachments[ previous_List, attachments_List ] := With[ { pops = promptNotebooksIn @ attachments },
    If[ pops === { }, previous, Select[ previous, ! IntersectingQ[ promptNotebooksIn @ { # }, pops ] & ] ]
];

acpReplacedPromptAttachments // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNotePromptNotebooks*)

(* The status of the prompt notebooks whose messages items are (references or prepared attachments; other items are
   ignored), when UI.wl starts their turn ("Sent"), queues them ("Queued") or drops them ("NotSent", with a reason: a
   text, or None). A notebook whose new message is being prepared meanwhile (Send again while its message was queued)
   keeps "Preparing" and Cancel: its job notes what happened to the message from before ("Earlier"), and the job's own
   result sets the status (promptNotSent says "Sent" again if the new one is not sent). Gives the prompt notebooks. *)
acpNotePromptNotebooks // beginDefinition;

acpNotePromptNotebooks[ nbo_, items_, state_String ] := acpNotePromptNotebooks[ nbo, items, state, None ];

acpNotePromptNotebooks[ nbo_, items_, state_String, reason_ ] := With[ { pops = promptNotebooksIn @ items },
    If[ pops =!= { },
        With[ { text = promptStatusText[ nbo, state, reason ] },
            Scan[ If[ ! noteEarlierMessage[ #, state, text ], setPromptStatus[ #, state, text ] ] &, pops ]
        ]
    ];
    pops
];

acpNotePromptNotebooks // endDefinition;


(* The status of the message from before of a prompt notebook whose new message is being prepared, kept in its job;
   True if there is such a job *)
noteEarlierMessage // beginDefinition;

noteEarlierMessage[ pop_NotebookObject, state_String, text_String ] := PreemptProtect @ If[
    AssociationQ @ Lookup[ $promptJobs, Key @ pop ],
    $promptJobs[ pop ] = <| $promptJobs[ pop ], "Earlier" -> <| "State" -> state, "Text" -> text |> |>;
    True,
    False
];

noteEarlierMessage // endDefinition;


promptStatusText // beginDefinition;

promptStatusText[ nbo_, "Queued", _ ] := acpLabel[
    "PromptNotebookQueued",
    <| "agent" -> Replace[ acpWindowGet[ nbo, "Agent", "OpenCode" ], Except[ _String ] -> "OpenCode" ] |>
];

promptStatusText[ _, "Sent", _ ] := acpLabel[ "PromptNotebookSent", <| "time" -> DateString[ { "Hour24", ":", "Minute" } ] |> ];

promptStatusText[ _, _, reason_ ] := notSentText @ reason;

promptStatusText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Agent Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookOpenWindow*)

(* "Open agent window" of a notebook that is not linked: shows the ACP window (the open one, or a new one, as
   ShowNotebookAssistance[pop, "ACPWindow"] would: beside the prompt notebook) and links the notebook to it *)
acpPromptNotebookOpenWindow // beginDefinition;

acpPromptNotebookOpenWindow[ pop_NotebookObject ] := Module[ { owner },
    owner = showACPWindow[ pop, Null, False, False, <| |> ];
    If[ MatchQ[ owner, _NotebookObject ],
        promptSet[ pop, "Owner", owner ];
        setPromptStatus[ pop, None, acpLabel[ "PromptNotebookHint" ] ]
    ];
    owner
];

acpPromptNotebookOpenWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebooksOwnerClosed*)

(* The ACP window owner was closed (UI.wl): its prompt notebooks stay open (they are the user's), the messages of theirs
   that were prepared or queued are not sent, and they are unlinked ("Owner" None), so that their docked cells say that
   they are not linked and no longer show the owner's busy note: the docked cell's Dynamics read the owner's
   TaggingRules, and nothing makes them update when the owner closes; a change of "Owner" does. Send links an unlinked
   notebook to the open ACP window as before (acpPromptNotebookSend). *)
acpPromptNotebooksOwnerClosed // beginDefinition;

acpPromptNotebooksOwnerClosed[ owner_NotebookObject ] := (
    PreemptProtect[ $promptJobs = Select[ $promptJobs, #[ "Owner" ] =!= owner & ] ];
    KeyDropFrom[ $promptTargets, Key @ owner ];
    Scan[
        (
            If[ MatchQ[ promptGet[ #, "State", None ], "Preparing" | "Queued" ],
                setPromptStatus[ #, "NotSent", notSentText @ acpLabel[ "PromptNotebookWindowClosed" ] ]
            ];
            promptSet[ #, "Owner", None ]
        ) &,
        acpPromptNotebooksOf @ owner
    ];
    Null
);

acpPromptNotebooksOwnerClosed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPromptNotebookRecover*)

(* After a kernel restart (scheduled by UI.wl's acpRefreshWindowUI): the docked cells need nothing (front end state only),
   but a message that the old kernel prepared or queued is gone, so a "Preparing" or "Queued" status of a notebook of the
   window (with no job or queued message in this kernel) says that it was not sent. *)
acpPromptNotebookRecover // beginDefinition;

acpPromptNotebookRecover[ owner_NotebookObject ] := Module[ { queued },
    queued = promptNotebooksIn @ Lookup[ Replace[ acpQueuedPromptOf @ acpWindowGet[ owner, "QueuedPrompt", None ], None -> <| |> ], "Attachments", { } ];
    Scan[
        If[ MatchQ[ promptGet[ #, "State", None ], "Preparing" | "Queued" ] && ! KeyExistsQ[ $promptJobs, # ] && ! MemberQ[ queued, # ],
            setPromptStatus[ #, "NotSent", notSentText @ acpLabel[ "PromptNotebookInterrupted" ] ]
        ] &,
        acpPromptNotebooksOf @ owner
    ];
    Null
];

acpPromptNotebookRecover // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
