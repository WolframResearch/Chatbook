(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPRendering.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPRendering.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LoadACPContext@@Tests/ACPRendering.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* These tests check box structure only; they need no front end. Labels use the English defaults and final cells use
   the front-end-free formatting path, so results are the same with or without a front end (CI runs under
   UsingFrontEnd). FE-only checks are marked as such and skipped without a front end. *)
VerificationTest[
    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels    = True;
    Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = True;
    $acpLogStart = AbsoluteTime[ ]; (* see ACPRendering-DebugLog *)

    $acpFixtureDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP" };
    $acpBaseTime = 1000.0;

    acpLoadFixture[ name_String ] := Import[ FileNameJoin @ { $acpFixtureDirectory, name <> ".json" }, "RawJSON" ];

    acpApplyEvent[ turn_, ev_Association ] := With[ { t = $acpBaseTime + ev[ "t" ] },
        Switch[ ev[ "Type" ],
            "Update"           , acpApplyUpdate[ turn, ev[ "Update" ], t ][ "Turn" ],
            "PermissionRequest", acpApplyPermissionRequest[ turn, ev[ "RequestID" ], ev[ "Params" ], t ][ "Turn" ],
            "PermissionAnswer" , acpApplyPermissionOutcome[ turn, ev[ "RequestID" ], ev[ "OptionID" ], t ][ "Turn" ],
            "CancelRequest"    , acpApplyPermissionWithdrawn[ turn, ev[ "RequestID" ], t ][ "Turn" ],
            "ClientCancel"     , acpApplyClientCancel[ turn, ev[ "Kind" ], t ][ "Turn" ],
            "Response"         , acpApplyTurnEnd[ turn, <| "StopReason" -> ev[ "Result", "stopReason" ], "Usage" -> Lookup[ ev[ "Result" ], "usage", None ] |>, t ][ "Turn" ],
            "ErrorResponse"    , acpApplyTurnEnd[ turn, <| "Error" -> <| "Code" -> ev[ "Code" ], "Message" -> ev[ "Message" ], "Data" -> ev[ "Data" ], "Actions" -> { "ChooseModel" } |> |>, t ][ "Turn" ]
        ]
    ];

    acpReplay[ name_String ] := acpReplay[ name, Infinity ];
    acpReplay[ name_String, n_ ] := Module[ { fx = acpLoadFixture @ name },
        Fold[
            acpApplyEvent,
            acpNewTurn @ <| "ID" -> "render-" <> name, "Prompt" -> fx[ "Prompt" ], "ProjectDirectory" -> fx[ "ProjectDirectory" ], "StartTime" -> $acpBaseTime |>,
            Take[ fx[ "Events" ], UpTo[ n ] ]
        ]
    ];
    acpEventIndex[ name_String, patt_ ] := First @ FirstPosition[ acpLoadFixture[ name ][ "Events" ], patt ];

    (* Evaluates eval with the given turns in the ACP store and empty opener state, without touching the real store: *)
    acpWithTurns // Attributes = { HoldRest };
    acpWithTurns[ turns_List, eval_ ] := Block[
        { $acpTurns = Association[ #[ "ID" ] -> # & /@ turns ], $acpOpen = <| |> },
        Scan[ acpDropRenderCache[ #[ "ID" ] ] &, turns ];
        eval
    ];

    acpLayoutBoxes[ id_ ] := First @ Wolfram`Chatbook`ACP`Rendering`Private`liveLayout @ id;

    (* { HoldComplete[ sym ], key } for every entity Dynamic in live layout boxes: *)
    acpEntityDynamics[ boxes_ ] := Cases[
        boxes,
        HoldPattern @ DynamicBox[ ToBoxes[ CompoundExpression[ s_Symbol, Wolfram`Chatbook`ACP`Common`acpEntityView[ _, key_ ] ], StandardForm ], TrackedSymbols :> { s_Symbol }, ___ ] :>
            { HoldComplete @ s, key },
        Infinity
    ];

    acpBoxStrings[ boxes_ ] := Cases[ boxes, s_String :> StringTrim[ s, "\"" ], Infinity ];
    acpContainsTextQ[ boxes_, text_String ] := AnyTrue[ acpBoxStrings @ boxes, StringContainsQ[ #, text ] & ];

    acpFinalItems[ cell_Cell ] := First @ Cases[ cell, Cell[ TextData[ items_List ], ___, Editable -> True, ___ ] :> items, Infinity, 1 ];

    acpFakeNotebook = NotebookObject[ "ACPRenderingTest", 1 ];

    (* Arguments of every ChatbookAction[ "ACP", action, ... ] call in boxes (patterns are built from evaluated args): *)
    acpActionCalls[ boxes_, action_String ] := Cases[ boxes, HoldPattern @ ChatbookAction[ "ACP", action, rest___ ] :> { rest }, Infinity ];
    acpActionNames[ boxes_, nbo_ ] := Cases[ boxes, HoldPattern @ ChatbookAction[ "ACP", a_String, nbo ] :> a, Infinity ];
    acpHasToggleQ[ boxes_, id_, key_, default_ ] := MemberQ[ acpActionCalls[ boxes, "ToggleOpen" ], { id, key, default } ];

    (* Pattern for a Dynamic tracking the symbol held in HoldComplete[ sym ]: *)
    acpTrackingPattern // Attributes = { HoldRest };
    acpTrackingPattern[ HoldComplete[ s_Symbol ], body_ ] := HoldPattern @ Dynamic[ CompoundExpression[ s, body ], TrackedSymbols :> { s } ];
    acpWrapperPattern[ HoldComplete[ s_Symbol ] ] := HoldPattern[ DynamicModule ][ { _Set }, DynamicWrapper[ _Dynamic, _, TrackedSymbols :> { s } ], ___ ];
    acpTrackedDynamicBoxQ[ boxes_, HoldComplete[ s_Symbol ], head_ ] :=
        ! FreeQ[ boxes, HoldPattern @ DynamicBox[ ToBoxes[ CompoundExpression[ s, head[ ___ ] ], StandardForm ], TrackedSymbols :> { s }, ___ ] ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Definitions@@Tests/ACPRendering.wlt:36,1-108,2"
]

VerificationTest[
    (* Inline cells inside ChatOutput cells (verified in a front end): BoxData cells need their boxes in a "Text" StyleBox,
       otherwise strings show in the code font, and TextData cells need the "Text" style. Unstyled BoxData cells are only
       allowed for Chatbook's own formatter output (TextRefLink templates, math). Returns the offending cells. *)
    acpInlineCellViolations[ boxes_ ] := Join[
        Cases[ boxes, c: Cell[ BoxData[ b_ ], "Text", ___ ] /; ! MatchQ[ b, StyleBox[ _, "Text", ___ ] ] :> c, Infinity ],
        Cases[ boxes, c: Cell[ BoxData[ Except[ _TemplateBox | _FormBox ] ], Except[ _String ], ___ ] :> c, Infinity ],
        Cases[ boxes, c: Cell[ BoxData[ Except[ _TemplateBox | _FormBox ] ] ] :> c, Infinity ],
        Cases[ boxes, c: Cell[ _TextData, Except[ _String ], ___ ] :> c, Infinity ],
        Cases[ boxes, c: Cell[ _TextData ] :> c, Infinity ]
    ];
    (* Items of the final cell (below the top-level TextData cell, which mirrors Chatbook's own output cells) *)
    acpFinalInnerItems[ cell_Cell ] := acpFinalItems @ cell;
    (* ImageSize of every image in boxes *)
    acpImageSizes[ boxes_ ] := Cases[ boxes, GraphicsBox[ TagBox[ _RasterBox, ___ ], ___, ImageSize -> size_, ___ ] :> size, Infinity ];
    (* Output texts (preformatted code block cells) of a tool card *)
    acpOutputTexts[ boxes_ ] := Cases[ boxes, Cell[ t_String, "ChatPreformatted", ___ ] :> t, Infinity ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Definitions-Audit@@Tests/ACPRendering.wlt:110,1-131,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Live View*)
VerificationTest[
    MatchQ[ acpLiveView[ "render-live-1" ], acpTrackingPattern[ acpLayoutSymbol[ "render-live-1" ], Wolfram`Chatbook`ACP`Rendering`Private`liveLayout[ "render-live-1" ] ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveView-TracksLayoutSymbol@@Tests/ACPRendering.wlt:136,1-141,2"
]

VerificationTest[
    turnC = acpReplay[ "exp5_C_writes", acpEventIndex[ "exp5_C_writes", KeyValuePattern @ { "Type" -> "PermissionRequest", "RequestID" -> 2 } ] ];
    acpWithTurns[ { turnC },
        Module[ { boxes = acpLayoutBoxes @ turnC[ "ID" ], dynamics },
            dynamics = acpEntityDynamics @ boxes;
            {
                MatchQ[ boxes, Cell[ TextData[ _List ], ___ ] ],
                dynamics[[ All, 2 ]] === turnC[ "Order" ],
                AllTrue[ dynamics, First @ # === acpEntitySymbol[ turnC[ "ID" ], Last @ # ] & ]
            }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveLayout-OneDynamicPerEntity@@Tests/ACPRendering.wlt:143,1-158,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        Module[ { boxes = acpLayoutBoxes @ turnC[ "ID" ], id = turnC[ "ID" ] },
            {
                (* opener header toggles the Work opener through ChatbookAction *)
                acpHasToggleQ[ boxes, id, "Work", True ],
                (* the elapsed-time label is its own Dynamic tracking the turn's Clock symbol *)
                acpTrackedDynamicBoxQ[ boxes, acpEntitySymbol[ id, "Clock" ], Wolfram`Chatbook`ACP`Rendering`Private`workingLabel ],
                (* no scroll panes and no DynamicModule state in live views *)
                FreeQ[ boxes, Scrollbars | DynamicModuleBox ]
            }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveLayout-Header@@Tests/ACPRendering.wlt:160,1-176,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        $acpOpen[ { turnC[ "ID" ], "Work" } ] = False;
        acpEntityDynamics @ acpLayoutBoxes @ turnC[ "ID" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveLayout-ClosedOpener@@Tests/ACPRendering.wlt:178,1-186,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        Wolfram`Chatbook`ACP`Rendering`Private`workingLabel @ turnC[ "ID" ]
    ],
    RawBoxes[ _? (acpContainsTextQ[ #, "Waiting for your approval" ] && acpContainsTextQ[ #, "Working" ] &) ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-WorkingLabel-Activity@@Tests/ACPRendering.wlt:188,1-195,2"
]

VerificationTest[
    acpWithTurns[ { }, { acpLayoutBoxes[ "render-no-such-turn" ], acpEntityView[ "render-no-such-turn", { "Tool", "x" } ], Wolfram`Chatbook`ACP`Rendering`Private`workingLabel[ "render-no-such-turn" ] } ],
    { _? (acpContainsTextQ[ #, "no longer available" ] &), RawBoxes[ _? (acpContainsTextQ[ #, "no longer available" ] &) ], RawBoxes[ _ ] },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-MissingTurnPlaceholder@@Tests/ACPRendering.wlt:197,1-202,2"
]

VerificationTest[
    acpWithTurns[ { turnC }, acpEntityView[ turnC[ "ID" ], { "Tool", "no-such-tool" } ] ],
    RawBoxes[ "" ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-MissingEntity@@Tests/ACPRendering.wlt:204,1-209,2"
]

VerificationTest[
    Module[ { child, turn },
        child = <| "opencode/child-session" -> <| "id" -> "ses_child", "depth" -> 1, "title" -> "Explore repo" |> |>;
        turn = Fold[
            acpApplyUpdate[ #1, #2, $acpBaseTime + 1 ][ "Turn" ] &,
            acpNewTurn @ <| "ID" -> "render-child", "StartTime" -> $acpBaseTime |>,
            {
                <| "sessionUpdate" -> "tool_call", "toolCallId" -> "task1", "name" -> "task", "title" -> "task", "rawInput" -> <| "description" -> "Explore repo" |> |>,
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "cm", "content" -> <| "type" -> "text", "text" -> "child" |>, "_meta" -> child |>
            }
        ];
        acpWithTurns[ { turn }, acpContainsTextQ[ acpLayoutBoxes[ "render-child" ], "Subagent: Explore repo" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveLayout-SubagentHeader@@Tests/ACPRendering.wlt:211,1-227,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Entity Views*)
VerificationTest[
    acpWithTurns[ { turnC },
        Module[ { key = { "Tool", "call_00_yrtqoymhaqurytxkbimvffbv" }, id = turnC[ "ID" ], closed },
            closed = acpEntityView[ id, key ];
            {
                closed === acpEntityView[ id, key ], (* cached *)
                acpContainsTextQ[ closed, "Wants to write main.py" ],
                acpContainsTextQ[ closed, "Awaiting approval" ],
                acpContainsTextQ[ closed, "+6" ],
                acpHasToggleQ[ closed, id, key, False ],
                ! FreeQ[ closed, TemplateBox[ _, "DiscardedMaterialOpenerIcon" ] ],
                FreeQ[ closed, "Changes" ]
            }
        ]
    ],
    { True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-Closed@@Tests/ACPRendering.wlt:232,1-250,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        Module[ { key = { "Tool", "call_00_yrtqoymhaqurytxkbimvffbv" }, id = turnC[ "ID" ], open },
            $acpOpen[ { id, key } ] = True;
            open = acpEntityView[ id, key ];
            {
                acpContainsTextQ[ open, "Changes" ],
                acpContainsTextQ[ open, "main.py" ],
                acpContainsTextQ[ open, "new file" ],
                acpContainsTextQ[ open, "def greet():" ],
                ! FreeQ[ open, TemplateBox[ _, "DiscardedMaterialCloserIcon" ] ],
                (* Details sub-opener, closed *)
                acpContainsTextQ[ open, "Details" ],
                acpHasToggleQ[ open, id, Append[ key, "Details" ], False ]
            }
        ]
    ],
    { True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-Open-Diff@@Tests/ACPRendering.wlt:252,1-272,2"
]

VerificationTest[
    turnFullC = acpReplay[ "exp5_C_writes" ];
    acpWithTurns[ { turnFullC },
        Module[ { key = { "Tool", "call_00_xkklgyu5x5fngwqzndo2olqe" }, id = turnFullC[ "ID" ], boxes },
            $acpOpen[ { id, key } ] = True;
            boxes = acpEntityView[ id, key ];
            {
                acpContainsTextQ[ boxes, "exit 1" ],
                ! FreeQ[ boxes, StyleBox[ "\"exit 1\"", ___, FontColor -> Wolfram`Chatbook`ACP`Rendering`Private`$amberText, ___ ] ],
                FreeQ[ boxes, "\"\:2717\"" | "\"\:2713\"" ],
                (* live views use the Active code block template *)
                ! FreeQ[ boxes, "ChatCodeBlockTemplateActive" ],
                FreeQ[ boxes, TemplateBox[ _, "ChatCodeBlockTemplate", ___ ] ],
                acpContainsTextQ[ boxes, "No module named pytest" ]
            }
        ]
    ],
    { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-ExitCodeAmber@@Tests/ACPRendering.wlt:274,1-294,2"
]

VerificationTest[
    turnR = acpReplay[ "exp4b_turn1_reject" ];
    acpWithTurns[ { turnR },
        Module[ { boxes = acpEntityView[ turnR[ "ID" ], { "Tool", "call_e86fc73fd46e4384bd8e55ba" } ] },
            { acpContainsTextQ[ boxes, "Declined: edit hello.txt" ], acpContainsTextQ[ boxes, "Declined" ], FreeQ[ boxes, "\"\:2717\"" ] }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-DeclinedNeutral@@Tests/ACPRendering.wlt:296,1-306,2"
]

VerificationTest[
    turnStop = acpReplay[ "exp6b_C_stop_running" ];
    acpWithTurns[ { turnStop },
        Module[ { boxes = acpEntityView[ turnStop[ "ID" ], { "Tool", "18200bef-2242-40de-bab4-e0bf76dd7aad" } ] },
            { acpContainsTextQ[ boxes, "Stopped: run" ], acpContainsTextQ[ boxes, "sleep 30 && echo done" ], FreeQ[ boxes, "\"\:2717\"" ] }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-StoppedNeutral@@Tests/ACPRendering.wlt:308,1-318,2"
]

VerificationTest[
    turnA = acpReplay[ "exp5_A_mcp" ];
    acpWithTurns[ { turnA },
        Module[ { key = { "Tool", "call_00_t0f4xkm2fzc7o94bv113pt4j" }, id = turnA[ "ID" ], boxes },
            $acpOpen[ { id, key } ] = True;
            boxes = acpEntityView[ id, key ];
            {
                acpContainsTextQ[ boxes, "Used Wolfram Language Evaluator" ],
                ! FreeQ[ boxes, DynamicBox[ FEPrivate`FrontEndResource[ "ChatbookExpressions", "ToolIconWolframLanguageEvaluator" ] ] ],
                (* each inner WL call is a Chatbook WL code cell *)
                ! FreeQ[ boxes, Cell[ BoxData[ "2+2" ], "ChatCodeActive", ___ ] ],
                ! FreeQ[ boxes, Cell[ BoxData[ "Plot[Sin[x], {x, 0, 2 Pi}]" ], "ChatCodeActive", ___ ] ],
                (* JSON result map with reminders stripped *)
                acpContainsTextQ[ boxes, "sum" ],
                acpContainsTextQ[ boxes, "Out[1]= 4" ],
                FreeQ[ boxes, s_String /; StringContainsQ[ s, "system-reminder" ] ] || acpContainsTextQ[ boxes, "Details" ],
                (* the image is shown inline *)
                ! FreeQ[ boxes, _RasterBox | _GraphicsBox ],
                (* the JavaScript is in a collapsed Script section *)
                acpHasToggleQ[ boxes, id, Append[ key, "Script" ], False ]
            }
        ]
    ],
    { True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-Execute@@Tests/ACPRendering.wlt:320,1-346,2"
]

VerificationTest[
    acpWithTurns[ { turnA },
        Module[ { key = { "Tool", "call_00_t0f4xkm2fzc7o94bv113pt4j" }, id = turnA[ "ID" ], output },
            $acpOpen[ { id, key } ] = True;
            output = Cases[ acpEntityView[ id, key ], Cell[ s_String, "ChatPreformatted", ___ ] :> s, Infinity ];
            AnyTrue[ output, StringContainsQ[ #, "system-reminder" ] & ]
        ]
    ],
    False,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-Execute-RemindersStripped@@Tests/ACPRendering.wlt:348,1-359,2"
]

VerificationTest[
    Module[ { text, turn, boxes },
        text = StringRiffle[ "line " <> ToString[ # ] & /@ Range[ 40 ], "\n" ];
        turn = Fold[
            acpApplyUpdate[ #1, #2, $acpBaseTime + 1 ][ "Turn" ] &,
            acpNewTurn @ <| "ID" -> "render-trunc", "StartTime" -> $acpBaseTime |>,
            {
                <| "sessionUpdate" -> "tool_call", "toolCallId" -> "t", "name" -> "shell", "title" -> "seq 40", "rawInput" -> <| "command" -> "seq 40" |> |>,
                <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "t", "status" -> "completed", "content" -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> text |> |> }, "rawOutput" -> <| "metadata" -> <| "exit" -> 0 |> |> |>
            }
        ];
        acpWithTurns[ { turn },
            $acpOpen[ { "render-trunc", { "Tool", "t" } } ] = True;
            boxes = acpEntityView[ "render-trunc", { "Tool", "t" } ];
            { acpContainsTextQ[ boxes, "28 earlier lines" ], acpContainsTextQ[ boxes, "line 40" ], acpContainsTextQ[ boxes, "40 lines" ], FreeQ[ boxes, s_String /; StringContainsQ[ s, "line 1\n" ] ] }
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-LiveOutputTruncated@@Tests/ACPRendering.wlt:361,1-381,2"
]

VerificationTest[
    acpWithTurns[ { turnA },
        Module[ { key = First @ Select[ turnA[ "Order" ], MatchQ[ { "Thought", _ } ] ], id = turnA[ "ID" ], closed, open },
            closed = acpEntityView[ id, key ];
            $acpOpen[ { id, key } ] = True;
            open = acpEntityView[ id, key ];
            {
                acpContainsTextQ[ closed, "Thought for" ],
                FreeQ[ closed, "ThinkingContent" ],
                ! FreeQ[ open, TemplateBox[ { _TextData }, "ThinkingContent" ] ],
                acpHasToggleQ[ closed, id, key, False ]
            }
        ]
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Thought-Live@@Tests/ACPRendering.wlt:383,1-400,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyUpdate[ acpNewTurn @ <| "ID" -> "render-thinking", "StartTime" -> $acpBaseTime |>, <| "sessionUpdate" -> "agent_thought_chunk", "messageId" -> "m:reasoning:0", "content" -> <| "type" -> "text", "text" -> "hmm" |> |>, $acpBaseTime + 1 ][ "Turn" ];
        acpWithTurns[ { turn }, acpContainsTextQ[ acpEntityView[ "render-thinking", { "Thought", "m:reasoning:0" } ], "Thinking\[Ellipsis]" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Thought-Active@@Tests/ACPRendering.wlt:402,1-410,2"
]

VerificationTest[
    turnMsg = acpReplay[ "exp5_C_writes", 40 ];
    acpWithTurns[ { turnMsg },
        Module[ { boxes = acpEntityView[ turnMsg[ "ID" ], { "Message", "msg_122a659fa001yNa98MSVFlYnzt" } ] },
            { MatchQ[ boxes, RawBoxes[ Cell[ TextData[ _List ], ___ ] ] ], acpContainsTextQ[ boxes, "\:2610 1. Create" ], acpContainsTextQ[ boxes, "Creating the three files now." ] }
        ]
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Message-Live-TaskList@@Tests/ACPRendering.wlt:412,1-422,2"
]

VerificationTest[
    Module[ { turn, boxes },
        turn = Fold[
            acpApplyUpdate[ #1, #2, $acpBaseTime + 1 ][ "Turn" ] &,
            acpNewTurn @ <| "ID" -> "render-notices", "StartTime" -> $acpBaseTime |>,
            {
                <| "sessionUpdate" -> "plan", "entries" -> { <| "content" -> "Write tests", "status" -> "completed" |>, <| "content" -> "Ship it", "status" -> "pending" |> } |>,
                <| "sessionUpdate" -> "session_info_update", "_meta" -> <| "opencode/compaction" -> <| "status" -> "completed", "messageId" -> "c1" |> |> |>
            }
        ];
        acpWithTurns[ { turn },
            { acpEntityView[ "render-notices", { "Plan" } ], acpEntityView[ "render-notices", { "Notice", 1 } ] }
        ]
    ],
    {
        RawBoxes[ _? (acpContainsTextQ[ #, "Write tests" ] && acpContainsTextQ[ #, "\:2611" ] && acpContainsTextQ[ #, "\:2610" ] &) ],
        RawBoxes[ _? (acpContainsTextQ[ #, "Conversation compacted" ] &) ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PlanAndNotice@@Tests/ACPRendering.wlt:424,1-444,2"
]

VerificationTest[
    Module[ { params, turn },
        params = <| "toolCall" -> <| "toolCallId" -> "per_1", "title" -> "/tmp/outside", "locations" -> { <| "path" -> "/tmp/outside" |> } |>, "options" -> { } |>;
        turn = acpApplyPermissionRequest[ acpNewTurn @ <| "ID" -> "render-perm", "StartTime" -> $acpBaseTime |>, 4, params, $acpBaseTime + 1 ][ "Turn" ];
        acpWithTurns[ { turn }, acpEntityView[ "render-perm", { "Permission", 4 } ] ]
    ],
    RawBoxes[ _? (acpContainsTextQ[ #, "Access outside the project: /tmp/outside" ] && acpContainsTextQ[ #, "Awaiting approval" ] && FreeQ[ #, _ButtonBox ] &) ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-StandalonePermission-Passive@@Tests/ACPRendering.wlt:446,1-455,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Streaming Text*)
VerificationTest[
    Wolfram`Chatbook`ACP`Rendering`Private`stableSplitPosition /@ {
        "no blank lines",
        "para one\n\npara two",
        "para\n\n```python\nx = 1\n\nprint(x)",
        "a\n\n```\ncode\n```\n\nafter\n\ntail"
    },
    { 0, 10, 6, 24 },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-StableSplit-CodeFence@@Tests/ACPRendering.wlt:460,1-470,2"
]

VerificationTest[
    Module[ { items1, items2, cache },
        Wolfram`Chatbook`ACP`Rendering`Private`$textCache = <| |>;
        items1 = Wolfram`Chatbook`ACP`Rendering`Private`streamingItems[ "render-stream", { "Message", "m" }, "First paragraph.\n\nSecond" ];
        cache  = Wolfram`Chatbook`ACP`Rendering`Private`$textCache[ { "render-stream", { "Message", "m" } } ];
        items2 = Wolfram`Chatbook`ACP`Rendering`Private`streamingItems[ "render-stream", { "Message", "m" }, "First paragraph.\n\nSecond paragraph." ];
        { cache[ "Length" ], items1, items2 }
    ],
    { 18, { "First paragraph.", "\n\n", "Second" }, { "First paragraph.", "\n\n", "Second paragraph." } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-StreamingTailOnly@@Tests/ACPRendering.wlt:472,1-483,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Diff View*)
VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "/project/hello.txt", "OldText" -> "hi", "NewText" -> "hello world", "Synthesized" -> False |> },
        { acpContainsTextQ[ boxes, "/project/hello.txt" ], acpContainsTextQ[ boxes, "+1" ], acpContainsTextQ[ boxes, "\[Minus]1" ], acpContainsTextQ[ boxes, "hello world" ], FreeQ[ boxes, "new file" ] }
    ],
    { True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-Edit@@Tests/ACPRendering.wlt:488,1-495,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView[ <| "type" -> "diff", "path" -> "/project/src/new.py", "oldText" -> Null, "newText" -> "a\nb\n" |>, <| "ProjectDirectory" -> "/project" |> ] },
        { acpContainsTextQ[ boxes, "src/new.py" ], FreeQ[ boxes, "\"/project/src/new.py\"" ], acpContainsTextQ[ boxes, "new file" ], acpContainsTextQ[ boxes, "+2" ] }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-NewFile-RawACP@@Tests/ACPRendering.wlt:497,1-504,2"
]

VerificationTest[
    Module[ { old, new, rows, boxes },
        old   = StringRiffle[ ToString /@ Range[ 100 ], "\n" ];
        new   = StringReplace[ old, "\n50\n" -> "\nfifty\n" ];
        rows  = Wolfram`Chatbook`ACP`Rendering`Private`diffRows[ <| "Path" -> "f", "OldText" -> old, "NewText" -> new |>, 3 ];
        boxes = ToBoxes @ acpDiffView[ <| "Path" -> "f", "OldText" -> old, "NewText" -> new |>, <| "MaxLines" -> 5 |> ];
        { Length @ rows, Count[ rows, { "@", _ } ], Count[ rows, { "-", "50" } ], Count[ rows, { "+", "fifty" } ], acpContainsTextQ[ boxes, "more lines" ] }
    ],
    { 10, 2, 1, 1, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-ContextAndTruncation@@Tests/ACPRendering.wlt:506,1-517,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "src/a.py", "Patch" -> "Index: src/a.py\n===\n--- a/src/a.py\n+++ b/src/a.py\n@@ -1,2 +1,2 @@\n-old\n+new\n same" |> },
        { acpContainsTextQ[ boxes, "@@ -1,2 +1,2 @@" ], acpContainsTextQ[ boxes, "old" ], acpContainsTextQ[ boxes, "new" ], FreeQ[ boxes, "\"+++ b/src/a.py\"" ] }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-Patch@@Tests/ACPRendering.wlt:519,1-526,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "w.txt", "OldText" -> None, "NewText" -> "x\ny", "Synthesized" -> True, "Write" -> True |> },
        { acpContainsTextQ[ boxes, "contents written" ], FreeQ[ boxes, "new file" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-ContentsWritten@@Tests/ACPRendering.wlt:528,1-535,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Final Cell*)
VerificationTest[
    finalA = acpFinalCell @ acpReplay[ "exp5_A_mcp" ];
    finalA,
    Cell[
        BoxData[ TemplateBox[ { Cell[ TextData[ _List ], ___ ] }, "AssistantMessageBox" ] ],
        "ChatOutput",
        GeneratedCell     -> True,
        CellAutoOverwrite -> True,
        TaggingRules      -> KeyValuePattern @ {
            "CellToStringData"     -> _String? (StringStartsQ[ "Here are the results:" ]),
            "ACPTurn"              -> KeyValuePattern @ { "ID" -> "render-exp5_A_mcp", "StopReason" -> "end_turn", "Tools" -> { __Association } },
            "ChatNotebookSettings" -> <| "ACPWindow" -> True |>
        }
    ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-Structure@@Tests/ACPRendering.wlt:540,1-556,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ finalA, opener },
        opener = First @ items;
        {
            MatchQ[ opener, Cell[ BoxData[ TemplateBox[ { _TextData, _String, KeyValuePattern[ "Type" -> "ACPWork" ] }, "ThoughtsOpener" ] ], "ThoughtsOpener", ___ ] ],
            StringStartsQ[ StringTrim[ opener[[ 1, 1, 1, 2 ]], "\"" ], "Worked for " ],
            (* work content overrides the gray, small ThinkingContent style *)
            MatchQ[ opener[[ 1, 1, 1, 1 ]], TextData[ { Cell[ TextData[ _List ], ___, FontColor -> _, ___, FontSize -> _, ___ ] } ] ],
            (* the answer follows the opener *)
            acpContainsTextQ[ Rest @ items, "Here are the results" ]
        }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-WorkedForOpener@@Tests/ACPRendering.wlt:558,1-573,2"
]

VerificationTest[
    {
        FreeQ[ finalA, Wolfram`Chatbook`ACP`Common`acpEntityView | Wolfram`Chatbook`ACP`Rendering`Private`liveLayout | Wolfram`Chatbook`ACP`Rendering`Private`workingLabel ],
        FreeQ[ finalA, "ChatCodeBlockTemplateActive" ],
        FreeQ[ finalA, s_Symbol /; StringStartsQ[ Context @ s, "Wolfram`Chatbook`ACP`" ] ],
        (* tool cards are front-end-only openers *)
        ! FreeQ[ finalA, DynamicModuleBox[ { Typeset`open$$ = False }, ___ ] ]
    },
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-NoKernelState@@Tests/ACPRendering.wlt:575,1-586,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp2_thought_only" ] },
        { MatchQ[ First @ items, Cell[ BoxData[ TemplateBox[ { _, "\"Thought for a second\"", <| "Type" -> "Literal" |> }, "ThoughtsOpener" ] ], ___ ] ], FreeQ[ items, s_String /; StringContainsQ[ s, "Worked for" ] ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-ThoughtOnly@@Tests/ACPRendering.wlt:588,1-595,2"
]

VerificationTest[
    Module[ { cell = acpFinalCell @ acpReplay[ "exp4b_turn1_reject" ], items },
        items = acpFinalItems @ cell;
        {
            acpContainsTextQ[ items, "Now editing it to say 'hello world':" ],
            (* the declined tool card is expanded below the opener *)
            ! FreeQ[ items, Cell[ BoxData[ (StyleBox[ #, "Text", ___ ] | # &) @ DynamicModuleBox[ { Typeset`open$$ = True }, _? (acpContainsTextQ[ #, "Declined: edit hello.txt" ] &), ___ ] ], ___ ] ],
            acpContainsTextQ[ Last @ items, "You declined: edit hello.txt. Tell OpenCode what to do instead." ],
            cell[[ -1, 2, "CellToStringData" ]]
        }
    ],
    { True, True, True, _String? (StringContainsQ[ "_You declined" ]) },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-DeclinedTail@@Tests/ACPRendering.wlt:597,1-611,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp6_stop_streaming" ] },
        { acpContainsTextQ[ items, "Johannes Gutenberg's movable" ], acpContainsTextQ[ Last @ items, "Stopped by you after" ], FreeQ[ items, "ThoughtsOpener" ] }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-StoppedPartialAnswer@@Tests/ACPRendering.wlt:613,1-620,2"
]

VerificationTest[
    Module[ { cell = acpFinalCell @ acpReplay[ "exp3_error" ] },
        { acpContainsTextQ[ cell, "Model exo-free has been deprecated" ], cell[[ -1, 2, "ACPTurn", "Error" ]] }
    ],
    { True, <| "Code" -> -32603, "Message" -> "Internal error: Model exo-free has been deprecated." |> },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-Error@@Tests/ACPRendering.wlt:622,1-629,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp2_retries" ] },
        acpContainsTextQ[ First @ items, "Rate limited; retried 6\[Times] over 47s" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-RetryNotice@@Tests/ACPRendering.wlt:631,1-638,2"
]

VerificationTest[
    {
        acpFinalCell[ "render-no-such-turn" ],
        acpFinalCell @ <| "ID" -> "broken" |>
    },
    {
        Cell[ BoxData[ TemplateBox[ { Cell[ TextData[ { _String? (StringContainsQ[ "no longer available" ]) } ], ___ ] }, "AssistantMessageBox" ] ], "ChatOutput", ___ ],
        Cell[ BoxData[ TemplateBox[ { _Cell }, "AssistantMessageBox" ] ], "ChatOutput", ___ ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-Fallbacks@@Tests/ACPRendering.wlt:640,1-651,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp5_B_shell" ] },
        Wolfram`Chatbook`ACP`Rendering`Private`finalCell[ turn, True ]
    ],
    Cell[ BoxData[ TemplateBox[ { _Cell }, "AssistantMessageBox" ] ], "ChatOutput", ___ ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-NoFrontEndFormatting@@Tests/ACPRendering.wlt:653,1-660,2"
]

(* FE-only: with a front end, answers are formatted with FormatChatOutput "Finished" (skipped without a front end).
   acpFinalCell falls back silently, so the test checks that the "Finished" path itself worked: no fallback was logged
   and FormatChatOutput gives a TextData cell for the answer. *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Block[ { Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = False },
            Module[ { t0, turn, answer, cell, logged },
                t0     = AbsoluteTime[ ];
                turn   = acpReplay[ "synthetic_answer_formatting" ];
                answer = StringRiffle[ turn[ "Entities", #, "Text" ] & /@ acpTurnSplit[ turn ][ "Answer" ], "\n\n" ];
                cell   = acpFinalCell @ turn;
                logged = Select[
                    Internal`BagPart[ $acpDebugLog, All ],
                    #[ "Time" ] >= t0 && MemberQ[ { "FinishedFormattingFallback", "FinalCellFallback", "FinalCellFailed" }, #[ "Where" ] ] &
                ];
                {
                    Wolfram`Chatbook`ACP`Rendering`Private`frontEndFormattingQ[ ],
                    logged,
                    FreeQ[ FormatChatOutput[ acpPreprocessAnswer @ answer, <| "Status" -> "Finished" |> ], _Failure | $Failed ],
                    MatchQ[ FormatChatOutput[ acpPreprocessAnswer @ answer, <| "Status" -> "Finished" |> ], RawBoxes[ Cell[ _TextData, ___ ] ] ],
                    cell
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | { True, { }, True, True, Cell[ BoxData[ TemplateBox[ { _Cell }, "AssistantMessageBox" ] ], "ChatOutput", ___ ] },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-FrontEndFormatting-FEOnly@@Tests/ACPRendering.wlt:665,1-691,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Declined And Stopped Tool Output*)

(* The "The user declined this tool call" / "Tool execution interrupted" texts only repeat the Declined/Stopped badge *)
VerificationTest[
    acpWithTurns[ { turnR, turnStop },
        Module[ { declined, stopped },
            $acpOpen[ { turnR[ "ID" ], { "Tool", "call_e86fc73fd46e4384bd8e55ba" } } ] = True;
            $acpOpen[ { turnStop[ "ID" ], { "Tool", "18200bef-2242-40de-bab4-e0bf76dd7aad" } } ] = True;
            declined = acpEntityView[ turnR[ "ID" ], { "Tool", "call_e86fc73fd46e4384bd8e55ba" } ];
            stopped  = acpEntityView[ turnStop[ "ID" ], { "Tool", "18200bef-2242-40de-bab4-e0bf76dd7aad" } ];
            {
                acpContainsTextQ[ declined, "Changes" ],
                acpOutputTexts @ declined,
                acpContainsTextQ[ declined, "Output" ] || acpContainsTextQ[ declined, "Error" ],
                acpContainsTextQ[ stopped, "sleep 30 && echo done" ],
                FreeQ[ acpOutputTexts @ stopped, "Tool execution interrupted" ],
                acpContainsTextQ[ stopped, "Output" ] || acpContainsTextQ[ stopped, "Error" ]
            }
        ]
    ],
    { True, { }, False, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-DeclinedStoppedNoOutput@@Tests/ACPRendering.wlt:698,1-718,2"
]

VerificationTest[
    Module[ { turn },
        turn = Fold[
            acpApplyUpdate[ #1, #2, $acpBaseTime + 1 ][ "Turn" ] &,
            acpNewTurn @ <| "ID" -> "render-stopped-partial", "StartTime" -> $acpBaseTime |>,
            {
                <| "sessionUpdate" -> "tool_call", "toolCallId" -> "s", "name" -> "shell", "title" -> "make", "rawInput" -> <| "command" -> "make" |> |>,
                <| "sessionUpdate" -> "tool_call", "toolCallId" -> "f", "name" -> "read", "title" -> "read", "rawInput" -> <| "path" -> "/project/missing.txt" |> |>,
                <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "f", "status" -> "failed", "rawOutput" -> <| "error" -> "File not found: /project/missing.txt" |> |>
            }
        ];
        turn = acpApplyClientCancel[ turn, "Stop", $acpBaseTime + 2 ][ "Turn" ];
        turn = acpApplyUpdate[
            turn,
            <| "sessionUpdate" -> "tool_call_update", "toolCallId" -> "s", "status" -> "failed", "content" -> {
                <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "compiling a.c" |> |>,
                <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "Tool execution interrupted" |> |>
            } |>,
            $acpBaseTime + 3
        ][ "Turn" ];
        acpWithTurns[ { turn },
            $acpOpen[ { "render-stopped-partial", { "Tool", "s" } } ] = True;
            $acpOpen[ { "render-stopped-partial", { "Tool", "f" } } ] = True;
            {
                acpOutputTexts @ acpEntityView[ "render-stopped-partial", { "Tool", "s" } ],
                (* a genuine failure keeps its error text *)
                acpOutputTexts @ acpEntityView[ "render-stopped-partial", { "Tool", "f" } ],
                acpContainsTextQ[ acpEntityView[ "render-stopped-partial", { "Tool", "f" } ], "Error" ]
            }
        ]
    ],
    { { "make", "compiling a.c" }, { "File not found: /project/missing.txt" }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-StoppedKeepsRealOutput@@Tests/ACPRendering.wlt:720,1-754,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cancelled Turn With Several Tools*)
VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "synthetic_cancelled_tools" ], opener, rest },
        opener = First @ items;
        rest   = Rest @ items;
        {
            (* the completed tools are inside the closed "Worked for" opener *)
            MatchQ[ opener, Cell[ BoxData[ TemplateBox[ { _, _, KeyValuePattern[ "Type" -> "ACPWork" ] }, "ThoughtsOpener" ] ], ___ ] ],
            acpContainsTextQ[ opener, "Read notes.md" ] && acpContainsTextQ[ opener, "Searched for" ],
            (* three closed tool cards, each with a closed Details section *)
            Count[ opener, DynamicModuleBox[ { Typeset`open$$ = False }, ___ ], Infinity ],
            (* only the declined edit is expanded below it *)
            Count[ rest, DynamicModuleBox[ { Typeset`open$$ = True }, ___ ], Infinity ],
            acpContainsTextQ[ rest, "Declined: edit notes.md" ],
            FreeQ[ rest, s_String /; StringContainsQ[ s, "Read notes.md" | "Searched for" ] ],
            FreeQ[ acpOutputTexts @ rest, "The user declined this tool call" ],
            acpContainsTextQ[ Last @ items, "You declined: edit notes.md." ]
        }
    ],
    { True, True, 6, 1, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-CompletedToolsThenDeclined@@Tests/ACPRendering.wlt:759,1-780,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Images*)
VerificationTest[
    {
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 1, 1 }, { 480, 360 } ],
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 12, 8 }, { 480, 360 } ],
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 1600, 1000 }, { 480, 360 } ],
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 400, 1000 }, { 480, 360 } ],
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 480, 360 }, { 480, 360 } ],
        Wolfram`Chatbook`ACP`Rendering`Private`imageDisplaySize[ { 5000, 2 }, { 480, 360 } ]
    },
    { { 1, 1 }, { 12, 8 }, { 480, 300 }, { 144, 360 }, { 480, 360 }, { 480, 1 } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Images-DisplaySize@@Tests/ACPRendering.wlt:785,1-797,2"
]

(* Small images are shown at their natural size (not stretched), large ones are scaled down *)
VerificationTest[
    turnFmt = acpReplay[ "synthetic_answer_formatting" ];
    acpWithTurns[ { turnFmt },
        Module[ { key = { "Tool", "call_exec_1" }, live },
            $acpOpen[ { turnFmt[ "ID" ], key } ] = True;
            live = acpEntityView[ turnFmt[ "ID" ], key ];
            { acpImageSizes @ live, acpImageSizes @ acpFinalCell @ turnFmt, acpImageSizes @ acpFinalCell @ acpReplay[ "exp5_A_mcp" ] }
        ]
    ],
    { { { 12, 8 }, { 320, 200 } }, { { 12, 8 }, { 480, 300 } }, { { 1, 1 } } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Images-NaturalSizeCapped@@Tests/ACPRendering.wlt:800,1-812,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Bold Text With Inline Code*)
VerificationTest[
    acpWithTurns[ { turnFmt },
        Module[ { live, final, star },
            star  = s_String /; StringContainsQ[ s, "**" ];
            live  = acpEntityView[ turnFmt[ "ID" ], { "Message", "msg_answer_1" } ];
            final = acpFinalItems @ acpFinalCell @ turnFmt;
            {
                (* no literal asterisks outside the code block *)
                Cases[ live /. Cell[ _, "ChatCodeBlock", ___ ] -> Null, star, Infinity ],
                Cases[ final /. Cell[ _, "ChatCodeBlock", ___ ] -> Null, star, Infinity ],
                (* the code block keeps them *)
                ! FreeQ[ final, s_String /; StringContainsQ[ s, "**`not bold`**" ] ],
                (* plain bold still works *)
                MemberQ[ Cases[ final, StyleBox[ t_String, FontWeight -> Bold ] :> t, Infinity ], "plain bold" ],
                acpContainsTextQ[ final, "Prime[Range[10]]" ]
            }
        ]
    ],
    { { }, { }, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-BoldCode-LiveAndFinal@@Tests/ACPRendering.wlt:817,1-838,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Inline Cell Styles*)
VerificationTest[
    Module[ { names, finals },
        names  = FileBaseName /@ FileNames[ "*.json", $acpFixtureDirectory ];
        finals = AssociationMap[ acpInlineCellViolations @ acpFinalItems @ acpFinalCell @ acpReplay @ # &, names ];
        Select[ finals, # =!= { } & ]
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-InlineCells-Final@@Tests/ACPRendering.wlt:843,1-852,2"
]

VerificationTest[
    Module[ { names, live },
        names = { "exp5_A_mcp", "exp5_C_writes", "exp4b_turn1_reject", "exp6b_C_stop_running", "exp2_retries", "synthetic_answer_formatting", "synthetic_cancelled_tools" };
        live = AssociationMap[
            Function[ name,
                With[ { turn = acpReplay @ name },
                    acpWithTurns[ { turn },
                        (* everything open, so every section is rendered *)
                        Scan[ ($acpOpen[ { turn[ "ID" ], # } ] = True; $acpOpen[ { turn[ "ID" ], Append[ #, "Details" ] } ] = True) &, turn[ "Order" ] ];
                        acpInlineCellViolations @ {
                            acpLayoutBoxes @ turn[ "ID" ],
                            acpEntityView[ turn[ "ID" ], # ] & /@ turn[ "Order" ]
                        }
                    ]
                ]
            ],
            names
        ];
        Select[ live, # =!= { } & ]
    ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-InlineCells-Live@@Tests/ACPRendering.wlt:854,1-877,2"
]

VerificationTest[
    Module[ { child },
        child = <| "ID" -> "ses_child", "ParentID" -> "ses_parent", "Title" -> "Explore", "Depth" -> 1 |>;
        {
            Wolfram`Chatbook`ACP`Rendering`Private`subagentHeaderCell @ child,
            acpWithTurns[ { }, acpEntityView[ "render-no-such-turn", { "Message", "m" } ] ]
        }
    ],
    {
        Cell[ BoxData[ StyleBox[ _, "Text", ___ ] ], "Text", ___ ],
        RawBoxes[ StyleBox[ _, "Text", ___ ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-InlineCells-HeaderAndPlaceholder@@Tests/ACPRendering.wlt:879,1-893,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Views*)
VerificationTest[
    permEvent = acpLoadFixture[ "exp5_C_writes" ][ "Events" ][[ acpEventIndex[ "exp5_C_writes", KeyValuePattern @ { "Type" -> "PermissionRequest", "RequestID" -> 2 } ] ]];
    shellEvent = acpLoadFixture[ "exp5_B_shell" ][ "Events" ][[ acpEventIndex[ "exp5_B_shell", KeyValuePattern[ "Type" -> "PermissionRequest" ] ] ]];
    acpWindowRecord[ pending_ ] := <|
        "Notebook" -> acpFakeNotebook, "Status" -> "Running", "ProjectDirectory" -> "/project",
        "AgentInfo" -> <| "Name" -> "OpenCode", "Version" -> "2.0.26" |>, "PendingPermissions" -> pending
    |>;
    MatchQ[ acpPermissionPanel @ acpFakeNotebook, acpWrapperPattern @ acpWindowSymbol @ acpFakeNotebook ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-StableDynamic@@Tests/ACPRendering.wlt:898,1-909,2"
]

VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 2 -> <| "TurnID" -> turnC[ "ID" ], "ToolKey" -> { "Tool", "call_00_yrtqoymhaqurytxkbimvffbv" }, "Params" -> permEvent[ "Params" ] |>, 3 -> <| "Params" -> permEvent[ "Params" ] |> |> |> },
        acpWithTurns[ { turnC },
            Module[ { boxes = First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook, buttons },
                buttons = Cases[ boxes, b_ButtonBox :> b, Infinity ];
                {
                    acpContainsTextQ[ boxes, "OpenCode wants to write main.py" ],
                    acpContainsTextQ[ boxes, "1 of 2" ],
                    acpContainsTextQ[ boxes, "def greet():" ],
                    Length @ buttons,
                    AllTrue[ buttons, MemberQ[ #, Method -> "Preemptive" ] & ],
                    acpActionCalls[ buttons, "PermissionResponse" ],
                    (* buttons are armed after a short delay *)
                    ! FreeQ[ buttons, HoldPattern @ If[ AbsoluteTime[ ] >= _Real, _ ] ],
                    acpContainsTextQ[ boxes, "Always allow" ],
                    acpContainsTextQ[ boxes, "all file edits in /project" ],
                    acpContainsTextQ[ boxes, "future sessions" ]
                }
            ]
        ]
    ],
    { True, True, True, 3, True, { { acpFakeNotebook, 2, "once" }, { acpFakeNotebook, 2, "always" }, { acpFakeNotebook, 2, "reject" } }, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-Edit@@Tests/ACPRendering.wlt:911,1-935,2"
]

VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 1 -> <| "Params" -> shellEvent[ "Params" ] |> |> |> },
        acpWithTurns[ { },
            Module[ { boxes = First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook },
                {
                    acpContainsTextQ[ boxes, "OpenCode wants to run a command" ],
                    acpContainsTextQ[ boxes, "echo hello && uname -s" ],
                    (* "Always allow" saves one pattern per subcommand: *)
                    acpContainsTextQ[ boxes, "commands matching \"echo *\", \"uname *\"" ],
                    FreeQ[ boxes, "1 of" ],
                    (* the command preview is plain text: no Chatbook code block (its Copy/Insert buttons don't work in the
                       attached input cell), so the only buttons are the permission options *)
                    FreeQ[ boxes, _String? (StringContainsQ[ "ChatCodeBlock" ]) ],
                    Length @ Cases[ boxes, _ButtonBox, Infinity ] === Length @ shellEvent[ "Params", "options" ]
                }
            ]
        ]
    ],
    { True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-Shell@@Tests/ACPRendering.wlt:937,1-958,2"
]

VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 5 -> <| "Params" -> <| "toolCall" -> <| "toolCallId" -> "per_5", "title" -> "/etc/hosts", "locations" -> { <| "path" -> "/etc/hosts" |> } |>, "options" -> { <| "optionId" -> "once", "kind" -> "allow_once" |> } |> |> |> |> },
        acpWithTurns[ { }, acpContainsTextQ[ First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook, "wants to access /etc/hosts outside the project" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ExternalDirectory@@Tests/ACPRendering.wlt:960,1-967,2"
]

(* What "Always allow" saves, as OpenCode derives it (patterns per subcommand, directories outside the project) *)
VerificationTest[
    Module[ { scope, texts },
        scope[ tool_ ] := Wolfram`Chatbook`ACP`Rendering`Private`alwaysScopeText[ tool, "OpenCode", "/project" ];
        texts = scope /@ {
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "cd build && rm -rf dist" |> |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "git status && npm publish" |> |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "FOO=1 npm test 2>&1 | tail -5" |> |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "npm run build -- --prod" |> |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "ls $(pwd)" |> |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "cd /etc && cat hosts" |> |>,
            <| "Name" -> "read", "RawInput" -> <| "filePath" -> "/etc/hosts" |>, "Locations" -> { <| "path" -> "/etc/hosts" |> } |>,
            <| "Name" -> "edit", "RawInput" -> <| "filePath" -> "/other/src/a.py" |> |>,
            <| "Name" -> "edit", "RawInput" -> <| "filePath" -> "src/a.py" |>, "Locations" -> { <| "path" -> "/project/src/a.py" |> } |>,
            <| "Name" -> "shell", "RawInput" -> <| "command" -> "cd src" |> |>
        };
        {
            StringContainsQ[ texts[[ 1 ]], "matching \"rm *\" in /project" ] && ! StringContainsQ[ texts[[ 1 ]], "cd" ],
            StringContainsQ[ texts[[ 2 ]], "matching \"git status *\", \"npm publish *\" in" ],
            StringContainsQ[ texts[[ 3 ]], "matching \"npm test *\", \"tail *\" in" ] && ! StringContainsQ[ texts[[ 3 ]], "FOO" ],
            StringContainsQ[ texts[[ 4 ]], "matching \"npm run build *\" in" ],
            StringContainsQ[ texts[[ 5 ]], "nested" ],
            StringContainsQ[ texts[[ 6 ]], "access files in /etc " ],
            StringContainsQ[ texts[[ 7 ]], "access files in /etc " ],
            StringContainsQ[ texts[[ 8 ]], "access files in /other/src " ],
            StringContainsQ[ texts[[ 9 ]], "all file edits in /project" ],
            StringContainsQ[ texts[[ 10 ]], "this kind of thing in /project" ]
        }
    ],
    { True, True, True, True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-AlwaysScope@@Tests/ACPRendering.wlt:970,1-1001,2"
]

VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 6 -> <| "Params" -> <|
            "toolCall" -> <| "toolCallId" -> "per_6", "name" -> "read", "title" -> "/etc/hosts", "rawInput" -> <| "filePath" -> "/etc/hosts" |>, "locations" -> { <| "path" -> "/etc/hosts" |> } |>,
            "options"  -> { <| "optionId" -> "once", "kind" -> "allow_once" |>, <| "optionId" -> "always", "kind" -> "allow_always" |> }
        |> |> |> |> },
        acpWithTurns[ { },
            Module[ { boxes = First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook },
                { acpContainsTextQ[ boxes, "access files in /etc" ], acpContainsTextQ[ boxes, "do this kind of thing" ] }
            ]
        ]
    ],
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-AlwaysScopeExternal@@Tests/ACPRendering.wlt:1003,1-1017,2"
]

VerificationTest[
    {
        Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| |> |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ],
        Block[ { $acpWindows = <| |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ],
        Block[ { $acpWindows = <| |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionSignature @ acpFakeNotebook ]
    },
    { RawBoxes[ "" ], RawBoxes[ "" ], None },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-Empty@@Tests/ACPRendering.wlt:1019,1-1028,2"
]

VerificationTest[
    Module[ { status },
        status[ rec_ ] := Block[ { $acpWindows = <| acpFakeNotebook -> Join[ acpWindowRecord @ <| |>, rec ] |> }, First @ Wolfram`Chatbook`ACP`Rendering`Private`statusContent @ acpFakeNotebook ];
        {
            acpContainsTextQ[ status @ <| "Status" -> "Connecting" |>, "Connecting to OpenCode" ],
            acpContainsTextQ[ status @ <| "Status" -> "Ready", "MCPReady" -> False |>, "OpenCode 2.0.26" ],
            (* no "MCP starting" indicator: OpenCode often never reports the MCP prompts although its tools work *)
            FreeQ[ status @ <| "Status" -> "Ready", "MCPReady" -> False |>, s_String /; StringContainsQ[ s, "MCP" ] ],
            acpContainsTextQ[ status @ <| "Status" -> "NoDirectory" |>, "Choose a project folder" ],
            acpActionNames[ status @ <| "Status" -> "Disconnected" |>, acpFakeNotebook ],
            acpActionNames[ status @ <| "Status" -> "Error", "Error" -> <| "Code" -> "ModelUnavailable", "Message" -> "Model gone", "Actions" -> { "ChooseModel", "Reconnect" } |> |>, acpFakeNotebook ]
        }
    ],
    { True, True, True, True, { "Reconnect" }, { "ChooseModel", "Reconnect" } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolbarStatus@@Tests/ACPRendering.wlt:1030,1-1046,2"
]

(* MCP readiness changes don't re-render the status view *)
VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> Join[ acpWindowRecord @ <| |>, <| "Status" -> "Ready", "MCPReady" -> False |> ] |> },
        Module[ { before = Wolfram`Chatbook`ACP`Rendering`Private`statusSignature @ acpFakeNotebook },
            $acpWindows[ acpFakeNotebook, "MCPReady" ] = True;
            before === Wolfram`Chatbook`ACP`Rendering`Private`statusSignature @ acpFakeNotebook
        ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolbarStatus-IgnoresMCPReady@@Tests/ACPRendering.wlt:1049,1-1059,2"
]

VerificationTest[
    Module[ { usage },
        usage[ u_ ] := Block[ { $acpWindows = <| acpFakeNotebook -> Append[ acpWindowRecord @ <| |>, "Usage" -> u ] |> }, First @ Wolfram`Chatbook`ACP`Rendering`Private`usageContent @ acpFakeNotebook ];
        {
            acpContainsTextQ[ usage @ <| "used" -> 8301, "size" -> 200000, "cost" -> <| "amount" -> 0, "currency" -> "USD" |> |>, "8.3k / 200k" ],
            FreeQ[ usage @ <| "used" -> 8301, "size" -> 200000, "cost" -> <| "amount" -> 0, "currency" -> "USD" |> |>, s_String /; StringContainsQ[ s, "$" ] ],
            acpContainsTextQ[ usage @ <| "used" -> 190000, "size" -> 200000, "cost" -> <| "amount" -> 0.5, "currency" -> "USD" |> |>, "$0.50" ],
            acpContainsTextQ[ usage @ <| "used" -> 190000, "size" -> 200000 |>, "almost full" ],
            usage @ None
        }
    ],
    { True, True, True, True, "" | "\"\"" },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-UsageMeter@@Tests/ACPRendering.wlt:1061,1-1075,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpErrorView[ <| "Code" -> "AuthRequired", "Message" -> "Sign in required", "Detail" -> "Run opencode auth login", "Actions" -> { "SignIn" } |>, acpFakeNotebook ] },
        {
            acpContainsTextQ[ boxes, "Sign in required" ],
            acpContainsTextQ[ boxes, "Run opencode auth login" ],
            acpActionNames[ boxes, acpFakeNotebook ],
            ! FreeQ[ boxes, Method -> "Preemptive" ]
        }
    ],
    { True, True, { "SignIn" }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ErrorView@@Tests/ACPRendering.wlt:1077,1-1089,2"
]

(* "Locate OpenCode..." is a file chooser run by the front end; the chosen file goes to the SetAgentExecutable action *)
VerificationTest[
    Module[ { view = acpErrorView[ <| "Code" -> "AgentNotFound", "Message" -> "OpenCode was not found", "Actions" -> { "LocateAgent", "Reconnect" } |>, acpFakeNotebook ] },
        {
            Length @ Cases[ view, FileNameSetter[ _Dynamic, "Open", ___ ], Infinity ],
            With[ { nbo = acpFakeNotebook }, ! FreeQ[ Cases[ view, _FileNameSetter, Infinity ], HoldPattern[ _[ "ACP", "SetAgentExecutable", nbo, _ ] ] ] ],
            acpActionNames[ view, acpFakeNotebook ],
            FreeQ[ ToBoxes @ view, _Failure ]
        }
    ],
    { 1, True, { "Reconnect" }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ErrorView-LocateAgent@@Tests/ACPRendering.wlt:1092,1-1104,2"
]

VerificationTest[
    MatchQ[ #, acpWrapperPattern @ acpWindowSymbol @ acpFakeNotebook ] & /@ { acpToolbarStatusView @ acpFakeNotebook, acpUsageMeterView @ acpFakeNotebook },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-WindowViews-StableDynamics@@Tests/ACPRendering.wlt:1106,1-1111,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug Log*)

(* Rendering failures are swallowed (with fallbacks) and logged; none may have happened in these tests *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DebugLog@@Tests/ACPRendering.wlt:1118,1-1126,2"
]

(* :!CodeAnalysis::EndBlock:: *)
