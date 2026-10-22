(* ::Package:: *)

(* ::Section::Closed:: *)
(*About*)

(* Developer tool: previews ACP turn rendering in a real front end by replaying recorded OpenCode traffic
   (Tests/Data/ACP/*.json) through the real reducer (Transcript.wl) and renderers (Rendering.wl) -- no OpenCode, no
   ACPLink, no connection. Not part of the paclet; load it by hand.

   Usage (in a front end session):

       PacletDirectoryLoad[ "path/to/Chatbook" ];
       Get[ "Wolfram`Chatbook`" ];
       Get[ FileNameJoin @ { "path/to/Chatbook", "Developer", "ACPPreview.wl" } ];

       acpPreviewFixtures[ ]                                   (* available fixture names *)
       nb = acpPreviewNotebook[ "exp5_C_writes" ]               (* replay at real speed *)
       nb = acpPreviewNotebook[ "exp5_A_mcp", "Speed" -> 4 ]    (* 4x faster *)
       acpPreviewStop[ nb ]                                    (* stop a replay early *)
       acpPreviewFinalNotebook[ "exp4b_turn1_reject" ]         (* only the final cell, no replay *)

   The exp* fixtures are sanitized recordings of real OpenCode traffic. The synthetic_* fixtures are hand-made to cover
   cases the recordings don't:
       "synthetic_answer_formatting"   skill/todowrite/execute tool titles, a 12x8 and a 1600x1000 image in tool output
                                       (natural size vs. scaled down), and an answer with bold spans around inline code
       "synthetic_cancelled_tools"     a declined edit after several completed tools (only the edit is expanded below
                                       the "Worked for" opener)

   acpPreviewNotebook[ fixture, opts ] creates a notebook (stylesheet Wolfram/ACPChat.nb, or Wolfram/WorkspaceChat.nb
   if ACPChat.nb is not available) containing:
     (a) a ChatInput user cell with the recorded prompt,
     (b) the live ChatOutput cell (AssistantMessageBoxActive + acpLiveView) whose turn is driven by a ScheduledTask that
         applies the recorded events with acpTurnUpdate/acpApplyUpdate (and the permission reducers),
     (c) an attached cell at the bottom with acpPermissionPanel, which shows recorded permission requests while they
         are pending (the replay holds for "PermissionHold" seconds at each request, then applies the recorded answer),
   and when the replay ends, acpFinalCell is written over the live cell.

   fixture is a fixture name (see acpPreviewFixtures[]), a path to a fixture .json file, or a fixture Association
   <| "Prompt" -> _, "ProjectDirectory" -> _, "Events" -> { <| "t", "Type", ... |>... } |>.

   Options:
     "Speed"            -> 1        replay speed factor
     "PermissionHold"   -> 4        seconds (real time) to keep each permission request visible before the recorded answer
     "SkipInitialDelay" -> True     start the first recorded event 0.5 s after opening instead of at its recorded time
     "FinalizeDelay"    -> 1.5      seconds after the response before the final cell replaces the live view

   Notes:
     * The preview notebook has no docked toolbar and no input field (DockedCells -> {}), so nothing tries to connect
       to an agent. Clicking permission buttons calls ChatbookAction[ "ACP", "PermissionResponse", ... ] like the real
       window; without a connection that only exercises the UI.wl/Connection.wl error paths. The replay applies the
       recorded answers itself.
     * A temporary window record (Status "Running") is registered for the preview notebook so the permission panel and
       the publisher work; it is removed when the replay ends or is stopped.
     * Opener toggles in the live view (Working header, tool cards, thoughts, Details) go through
       ChatbookAction[ "ACP", "ToggleOpen", ... ] and work as in the real window. As there, the Working opener starts
       closed: click its header to see the transcript while it is replayed. *)

(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`ChatbookACPPreview`" ];

acpPreviewFixtures;
acpPreviewNotebook;
acpPreviewFinalNotebook;
acpPreviewStop;
acpPreviewReplay;

Begin[ "`Private`" ];

(* Events with equal timestamps must keep their recorded order (SortBy breaks ties by canonical order): *)
stableSortByTime[ events_List ] := events[[ Ordering[ Lookup[ events, "t", 0 ] ] ]];


Needs[ "Wolfram`Chatbook`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* ::Section::Closed:: *)
(*Configuration*)
$fixtureDirectory = FileNameJoin @ { DirectoryName[ $InputFileName, 2 ], "Tests", "Data", "ACP" };
$tickInterval     = Quantity[ 100, "Milliseconds" ];

If[ ! AssociationQ @ $runs, $runs = <| |> ];

$stylesheet := If[
    FileExistsQ @ FileNameJoin @ { PacletObject[ "Wolfram/Chatbook" ][ "Location" ], "DarkModeSupport", "StyleSheets", "Wolfram", "ACPChat.nb" },
    FrontEnd`FileName[ { "Wolfram" }, "ACPChat.nb", CharacterEncoding -> "UTF-8" ],
    FrontEnd`FileName[ { "Wolfram" }, "WorkspaceChat.nb", CharacterEncoding -> "UTF-8" ]
];

Options[ acpPreviewNotebook ] = {
    "Speed"            -> 1,
    "PermissionHold"   -> 4,
    "SkipInitialDelay" -> True,
    "FinalizeDelay"    -> 1.5
};

(* ::Section::Closed:: *)
(*Fixtures*)
acpPreviewFixtures[ ] := FileBaseName /@ FileNames[ "*.json", $fixtureDirectory ];

loadFixture[ fx_Association ] := fx;
loadFixture[ file_String ] /; FileExistsQ @ file := Import[ file, "RawJSON" ];
loadFixture[ name_String ] := Import[ FileNameJoin @ { $fixtureDirectory, name <> ".json" }, "RawJSON" ];
loadFixture[ other_ ] := Failure[ "BadFixture", <| "MessageTemplate" -> "Unknown fixture: `1`", "MessageParameters" -> { other } |> ];

(* ::Section::Closed:: *)
(*Cells*)
userCell[ prompt_String ] := Cell[
    BoxData @ TemplateBox[ { Cell[ prompt, Background -> None, Selectable -> True, Editable -> True ] }, "UserMessageBox" ],
    "ChatInput",
    GeneratedCell -> True
];

activeCell[ turnID_String ] := Cell[
    BoxData @ TemplateBox[
        {
            Cell[
                BoxData @ StyleBox[ ToBoxes @ acpLiveView @ turnID, "Text" ],
                Background -> None,
                Editable   -> False,
                Selectable -> False
            ]
        },
        "AssistantMessageBoxActive"
    ],
    "ChatOutput",
    Editable     -> False,
    Selectable   -> False,
    CellTags     -> { "ACPActiveTurn", turnID },
    TaggingRules -> <| "ACPTurnID" -> turnID, "ACPKernelSessionID" -> $SessionID, "ACPPreview" -> True |>
];

panelCell[ nbo_NotebookObject ] := Cell[
    BoxData @ ToBoxes @ acpPermissionPanel @ nbo,
    "Text",
    Background  -> None,
    CellMargins -> { { 20, 20 }, { 10, 10 } }
];

(* ::Section::Closed:: *)
(*acpPreviewNotebook*)
acpPreviewNotebook[ fixture_, opts: OptionsPattern[ ] ] := Module[
    { fx, events, turnID, nbo, outCell, panel, shift, project, turn },

    fx = loadFixture @ fixture;
    If[ FailureQ @ fx || ! AssociationQ @ fx, Return[ fx, Module ] ];

    events  = stableSortByTime @ Lookup[ fx, "Events", { } ];
    project = Replace[ Lookup[ fx, "ProjectDirectory", None ], Except[ _String ] -> None ];
    shift   = If[ TrueQ @ OptionValue[ "SkipInitialDelay" ] && events =!= { }, Max[ 0, First[ events ][ "t" ] - 0.5 ], 0 ];
    events  = MapAt[ # - shift &, events, { All, "t" } ];
    turnID  = "acp-preview-" <> CreateUUID[ ];

    nbo = NotebookPut @ Notebook[
        { userCell @ Lookup[ fx, "Prompt", "" ] },
        StyleDefinitions     -> $stylesheet,
        DockedCells          -> { },
        NotebookEventActions -> { },
        WindowTitle          -> "ACP preview: " <> ToString @ Lookup[ fx, "Name", fixture ],
        Saveable             -> False,
        Evaluator            -> Replace[ Quiet @ CurrentValue[ EvaluationNotebook[ ], Evaluator ], Except[ _String ] -> "Local" ],
        TaggingRules         -> <|
            "ChatNotebookSettings" -> <| "WorkspaceChat" -> True, "ACPWindow" -> True, "SetCellDingbat" -> False, "TabbedOutput" -> False |>,
            "ACPPreview"           -> True
        |>
    ];

    (* Window record so the permission panel and the publisher work: *)
    acpWindowSet[
        nbo,
        <|
            "Notebook"           -> nbo,
            "Agent"              -> "OpenCode",
            "AgentInfo"          -> <| "Name" -> "OpenCode", "Version" -> "preview" |>,
            "Status"             -> "Running",
            "ProjectDirectory"   -> project,
            "PendingPermissions" -> <| |>,
            "Preview"            -> True
        |>
    ];

    turn = acpNewTurn @ <|
        "ID"               -> turnID,
        "Notebook"         -> nbo,
        "Prompt"           -> Lookup[ fx, "Prompt", "" ],
        "ProjectDirectory" -> project,
        "StartTime"        -> AbsoluteTime[ ],
        "FinalizeClaimed"  -> True (* keeps UI.wl's finalization fallback away; the preview finalizes itself *)
    |>;
    acpTurnCreate @ turn;

    SelectionMove[ nbo, After, Notebook ];
    NotebookWrite[ nbo, activeCell @ turnID ];
    outCell = First @ Cells[ nbo, CellTags -> turnID ];
    panel   = AttachCell[ nbo, panelCell @ nbo, Bottom, 0, Bottom ];

    $runs[ nbo ] = <|
        "TurnID"         -> turnID,
        "Notebook"       -> nbo,
        "OutputCell"     -> outCell,
        "PanelCell"      -> panel,
        "Events"         -> events,
        "Index"          -> 1,
        "Clock"          -> 0.0,
        "LastTick"       -> AbsoluteTime[ ],
        "HoldUntil"      -> 0,
        "Speed"          -> N @ OptionValue[ "Speed" ],
        "PermissionHold" -> N @ OptionValue[ "PermissionHold" ],
        "FinalizeDelay"  -> N @ OptionValue[ "FinalizeDelay" ],
        "Done"           -> False
    |>;

    $runs[ nbo, "Task" ] = SessionSubmit @ ScheduledTask[ acpIsolated @ replayTick @ nbo, $tickInterval ];
    nbo
];

(* ::Section::Closed:: *)
(*Replay*)
replayTick[ nbo_ ] := Module[ { run, now, dt, applied = 0, ev },
    run = Lookup[ $runs, nbo, None ];
    If[ ! AssociationQ @ run || TrueQ @ run[ "Done" ], Return[ Null, Module ] ];
    (* stop if the preview notebook was closed (checked about every 2 seconds): *)
    run[ "Ticks" ] = Lookup[ run, "Ticks", 0 ] + 1;
    If[ Mod[ run[ "Ticks" ], 20 ] === 0 && ! MemberQ[ Notebooks[ ], nbo ], Return[ cleanup @ nbo, Module ] ];
    now = AbsoluteTime[ ];
    dt  = now - run[ "LastTick" ];
    run[ "LastTick" ] = now;
    If[ now >= run[ "HoldUntil" ], run[ "Clock" ] += dt * run[ "Speed" ] ];

    While[
        run[ "Index" ] <= Length @ run[ "Events" ] && now >= run[ "HoldUntil" ] && run[ "Events" ][[ run[ "Index" ], "t" ]] <= run[ "Clock" ],
        ev = run[ "Events" ][[ run[ "Index" ] ]];
        run[ "Index" ] += 1;
        applied++;
        Switch[ applyEvent[ run, ev, now ],
            "Hold"    , run[ "HoldUntil" ] = now + run[ "PermissionHold" ],
            "Finished", run[ "Done" ] = True,
            _         , Null
        ]
    ];

    $runs[ nbo ] = run;

    If[ TrueQ @ run[ "Done" ] || run[ "Index" ] > Length @ run[ "Events" ],
        Quiet @ TaskRemove @ run[ "Task" ];
        $runs[ nbo, "Done" ] = True;
        With[ { n = nbo }, acpSchedule[ finalizePreview @ n, Quantity[ run[ "FinalizeDelay" ], "Seconds" ] ] ]
    ];
    applied
];


(* Applies one recorded event; returns "Hold" for permission requests and "Finished" for the prompt response. *)
applyEvent[ run_, ev_Association, now_ ] := Module[ { id = run[ "TurnID" ], nbo = run[ "Notebook" ] },
    Switch[ ev[ "Type" ],
        "Update",
            acpTurnUpdate[ id, acpApplyUpdate[ #, ev[ "Update" ], now ] & ];
            Null,

        "PermissionRequest",
            acpTurnUpdate[ id, acpApplyPermissionRequest[ #, ev[ "RequestID" ], ev[ "Params" ], now ] & ];
            acpWindowUpdate[
                nbo,
                Function[ w,
                    <|
                        w,
                        "PendingPermissions" -> Append[
                            Lookup[ w, "PendingPermissions", <| |> ],
                            ev[ "RequestID" ] -> <|
                                "TurnID"    -> id,
                                "ToolKey"   -> Lookup[ Lookup[ acpTurnGet[ id ], "Index", <| |> ][ "Permission" ], ev[ "RequestID" ], None ],
                                "Params"    -> ev[ "Params" ],
                                "ArrivedAt" -> now
                            |>
                        ]
                    |>
                ]
            ];
            acpPublish[ ];
            "Hold",

        "PermissionAnswer",
            acpTurnUpdate[ id, acpApplyPermissionOutcome[ #, ev[ "RequestID" ], ev[ "OptionID" ], now ] & ];
            removePending[ nbo, ev[ "RequestID" ] ];
            Null,

        "CancelRequest",
            acpTurnUpdate[ id, acpApplyPermissionWithdrawn[ #, ev[ "RequestID" ], now ] & ];
            removePending[ nbo, ev[ "RequestID" ] ];
            Null,

        "ClientCancel",
            acpTurnUpdate[ id, acpApplyClientCancel[ #, ev[ "Kind" ], now ] & ];
            Null,

        "Response",
            acpTurnUpdate[ id, acpApplyTurnEnd[ #, <| "StopReason" -> ev[ "Result", "stopReason" ], "Usage" -> Lookup[ ev[ "Result" ], "usage", None ] |>, now ] & ];
            "Finished",

        "ErrorResponse",
            acpTurnUpdate[
                id,
                acpApplyTurnEnd[
                    #,
                    <| "Error" -> <| "Code" -> ev[ "Code" ], "Message" -> ev[ "Message" ], "Data" -> ev[ "Data" ], "Actions" -> { "ChooseModel" } |> |>,
                    now
                ] &
            ];
            "Finished",

        _,
            Null
    ]
];


removePending[ nbo_, reqID_ ] := (
    acpWindowUpdate[ nbo, Function[ w, <| w, "PendingPermissions" -> KeyDrop[ Lookup[ w, "PendingPermissions", <| |> ], { reqID } ] |> ] ];
    acpPublish[ ]
);

(* ::Section::Closed:: *)
(*Finalization*)
finalizePreview[ nbo_ ] := Module[ { run, final },
    run = Lookup[ $runs, nbo, None ];
    If[ ! AssociationQ @ run, Return[ Null, Module ] ];
    final = acpFinalCell @ run[ "TurnID" ];
    If[ MemberQ[ Notebooks[ ], nbo ],
        Quiet @ NotebookWrite[ run[ "OutputCell" ], final, None, AutoScroll -> False ];
        Quiet @ NotebookDelete @ run[ "PanelCell" ]
    ];
    cleanup @ nbo
];


cleanup[ nbo_ ] := Module[ { run = Lookup[ $runs, nbo, None ] },
    If[ AssociationQ @ run,
        Quiet @ TaskRemove @ run[ "Task" ];
        acpTurnDrop @ run[ "TurnID" ];
        acpDropRenderCache @ run[ "TurnID" ]
    ];
    acpWindowDrop @ nbo;
    KeyDropFrom[ $runs, nbo ];
    Null
];

(* ::Section::Closed:: *)
(*acpPreviewStop*)
acpPreviewStop[ nbo_NotebookObject ] := Module[ { run = Lookup[ $runs, nbo, None ] },
    If[ AssociationQ @ run,
        Quiet @ TaskRemove @ run[ "Task" ];
        Quiet @ NotebookDelete @ run[ "PanelCell" ]
    ];
    cleanup @ nbo
];

acpPreviewStop[ All ] := Scan[ acpPreviewStop, Keys @ $runs ];

(* ::Section::Closed:: *)
(*acpPreviewReplay*)

(* The turn record after replaying all events of a fixture (no front end needed): *)
acpPreviewReplay[ fixture_ ] := Module[ { fx = loadFixture @ fixture, base = AbsoluteTime[ ] },
    If[ ! AssociationQ @ fx, Return[ fx, Module ] ];
    Fold[
        Function[ { turn, ev },
            With[ { t = base + ev[ "t" ] },
                Switch[ ev[ "Type" ],
                    "Update"           , acpApplyUpdate[ turn, ev[ "Update" ], t ][ "Turn" ],
                    "PermissionRequest", acpApplyPermissionRequest[ turn, ev[ "RequestID" ], ev[ "Params" ], t ][ "Turn" ],
                    "PermissionAnswer" , acpApplyPermissionOutcome[ turn, ev[ "RequestID" ], ev[ "OptionID" ], t ][ "Turn" ],
                    "CancelRequest"    , acpApplyPermissionWithdrawn[ turn, ev[ "RequestID" ], t ][ "Turn" ],
                    "ClientCancel"     , acpApplyClientCancel[ turn, ev[ "Kind" ], t ][ "Turn" ],
                    "Response"         , acpApplyTurnEnd[ turn, <| "StopReason" -> ev[ "Result", "stopReason" ], "Usage" -> Lookup[ ev[ "Result" ], "usage", None ] |>, t ][ "Turn" ],
                    "ErrorResponse"    , acpApplyTurnEnd[ turn, <| "Error" -> <| "Code" -> ev[ "Code" ], "Message" -> ev[ "Message" ], "Data" -> ev[ "Data" ], "Actions" -> { "ChooseModel" } |> |>, t ][ "Turn" ],
                    _                  , turn
                ]
            ]
        ],
        acpNewTurn @ <| "ID" -> "acp-preview-replay", "Prompt" -> Lookup[ fx, "Prompt", "" ], "ProjectDirectory" -> Lookup[ fx, "ProjectDirectory", None ], "StartTime" -> base |>,
        stableSortByTime @ Lookup[ fx, "Events", { } ]
    ]
];

(* ::Section::Closed:: *)
(*acpPreviewFinalNotebook*)

(* A notebook with the prompt and the final cell for a fixture (no replay, no live view): *)
acpPreviewFinalNotebook[ fixture_ ] := Module[ { fx = loadFixture @ fixture, turn },
    If[ ! AssociationQ @ fx, Return[ fx, Module ] ];
    turn = acpPreviewReplay @ fx;
    NotebookPut @ Notebook[
        { userCell @ Lookup[ fx, "Prompt", "" ], acpFinalCell @ turn },
        StyleDefinitions     -> $stylesheet,
        DockedCells          -> { },
        NotebookEventActions -> { },
        WindowTitle          -> "ACP final cell: " <> ToString @ Lookup[ fx, "Name", fixture ],
        Saveable             -> False,
        TaggingRules         -> <| "ChatNotebookSettings" -> <| "WorkspaceChat" -> True, "ACPWindow" -> True |>, "ACPPreview" -> True |>
    ]
];

(* ::Section::Closed:: *)
(*Package Footer*)
End[ ];
EndPackage[ ];
