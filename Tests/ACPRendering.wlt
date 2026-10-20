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
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ acpApplyEvent, acpEventIndex, acpLoadFixture, acpReplay ];

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
    TestID   -> "ACPRendering-Definitions@@Tests/ACPRendering.wlt:36,1-112,2"
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
    TestID   -> "ACPRendering-Definitions-Audit@@Tests/ACPRendering.wlt:114,1-135,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Live View*)
VerificationTest[
    MatchQ[ acpLiveView[ "render-live-1" ], acpTrackingPattern[ acpLayoutSymbol[ "render-live-1" ], Wolfram`Chatbook`ACP`Rendering`Private`liveLayout[ "render-live-1" ] ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveView-TracksLayoutSymbol@@Tests/ACPRendering.wlt:140,1-145,2"
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
    TestID   -> "ACPRendering-LiveLayout-OneDynamicPerEntity@@Tests/ACPRendering.wlt:147,1-162,2"
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
    TestID   -> "ACPRendering-LiveLayout-Header@@Tests/ACPRendering.wlt:164,1-180,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        $acpOpen[ { turnC[ "ID" ], "Work" } ] = False;
        acpEntityDynamics @ acpLayoutBoxes @ turnC[ "ID" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-LiveLayout-ClosedOpener@@Tests/ACPRendering.wlt:182,1-190,2"
]

VerificationTest[
    acpWithTurns[ { turnC },
        Wolfram`Chatbook`ACP`Rendering`Private`workingLabel @ turnC[ "ID" ]
    ],
    RawBoxes[ _? (acpContainsTextQ[ #, "Waiting for your approval" ] && acpContainsTextQ[ #, "Working" ] &) ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-WorkingLabel-Activity@@Tests/ACPRendering.wlt:192,1-199,2"
]

VerificationTest[
    acpWithTurns[ { }, { acpLayoutBoxes[ "render-no-such-turn" ], acpEntityView[ "render-no-such-turn", { "Tool", "x" } ], Wolfram`Chatbook`ACP`Rendering`Private`workingLabel[ "render-no-such-turn" ] } ],
    { _? (acpContainsTextQ[ #, "no longer available" ] &), RawBoxes[ _? (acpContainsTextQ[ #, "no longer available" ] &) ], RawBoxes[ _ ] },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-MissingTurnPlaceholder@@Tests/ACPRendering.wlt:201,1-206,2"
]

VerificationTest[
    acpWithTurns[ { turnC }, acpEntityView[ turnC[ "ID" ], { "Tool", "no-such-tool" } ] ],
    RawBoxes[ "" ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-MissingEntity@@Tests/ACPRendering.wlt:208,1-213,2"
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
    TestID   -> "ACPRendering-LiveLayout-SubagentHeader@@Tests/ACPRendering.wlt:215,1-231,2"
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
    TestID   -> "ACPRendering-ToolCard-Closed@@Tests/ACPRendering.wlt:236,1-254,2"
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
    TestID   -> "ACPRendering-ToolCard-Open-Diff@@Tests/ACPRendering.wlt:256,1-276,2"
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
    TestID   -> "ACPRendering-ToolCard-ExitCodeAmber@@Tests/ACPRendering.wlt:278,1-298,2"
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
    TestID   -> "ACPRendering-ToolCard-DeclinedNeutral@@Tests/ACPRendering.wlt:300,1-310,2"
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
    TestID   -> "ACPRendering-ToolCard-StoppedNeutral@@Tests/ACPRendering.wlt:312,1-322,2"
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
    TestID   -> "ACPRendering-ToolCard-Execute@@Tests/ACPRendering.wlt:324,1-350,2"
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
    TestID   -> "ACPRendering-ToolCard-Execute-RemindersStripped@@Tests/ACPRendering.wlt:352,1-363,2"
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
    TestID   -> "ACPRendering-ToolCard-LiveOutputTruncated@@Tests/ACPRendering.wlt:365,1-385,2"
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
    TestID   -> "ACPRendering-Thought-Live@@Tests/ACPRendering.wlt:387,1-404,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyUpdate[ acpNewTurn @ <| "ID" -> "render-thinking", "StartTime" -> $acpBaseTime |>, <| "sessionUpdate" -> "agent_thought_chunk", "messageId" -> "m:reasoning:0", "content" -> <| "type" -> "text", "text" -> "hmm" |> |>, $acpBaseTime + 1 ][ "Turn" ];
        acpWithTurns[ { turn }, acpContainsTextQ[ acpEntityView[ "render-thinking", { "Thought", "m:reasoning:0" } ], "Thinking\[Ellipsis]" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-Thought-Active@@Tests/ACPRendering.wlt:406,1-414,2"
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
    TestID   -> "ACPRendering-Message-Live-TaskList@@Tests/ACPRendering.wlt:416,1-426,2"
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
    TestID   -> "ACPRendering-PlanAndNotice@@Tests/ACPRendering.wlt:428,1-448,2"
]

VerificationTest[
    Module[ { params, turn },
        params = <| "toolCall" -> <| "toolCallId" -> "per_1", "title" -> "/tmp/outside", "locations" -> { <| "path" -> "/tmp/outside" |> } |>, "options" -> { } |>;
        turn = acpApplyPermissionRequest[ acpNewTurn @ <| "ID" -> "render-perm", "StartTime" -> $acpBaseTime |>, 4, params, $acpBaseTime + 1 ][ "Turn" ];
        acpWithTurns[ { turn }, acpEntityView[ "render-perm", { "Permission", 4 } ] ]
    ],
    RawBoxes[ _? (acpContainsTextQ[ #, "Access outside the project: /tmp/outside" ] && acpContainsTextQ[ #, "Awaiting approval" ] && FreeQ[ #, _ButtonBox ] &) ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-StandalonePermission-Passive@@Tests/ACPRendering.wlt:450,1-459,2"
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
    TestID   -> "ACPRendering-StableSplit-CodeFence@@Tests/ACPRendering.wlt:464,1-474,2"
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
    TestID   -> "ACPRendering-StreamingTailOnly@@Tests/ACPRendering.wlt:476,1-487,2"
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
    TestID   -> "ACPRendering-DiffView-Edit@@Tests/ACPRendering.wlt:492,1-499,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView[ <| "type" -> "diff", "path" -> "/project/src/new.py", "oldText" -> Null, "newText" -> "a\nb\n" |>, <| "ProjectDirectory" -> "/project" |> ] },
        { acpContainsTextQ[ boxes, "src/new.py" ], FreeQ[ boxes, "\"/project/src/new.py\"" ], acpContainsTextQ[ boxes, "new file" ], acpContainsTextQ[ boxes, "+2" ] }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-NewFile-RawACP@@Tests/ACPRendering.wlt:501,1-508,2"
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
    TestID   -> "ACPRendering-DiffView-ContextAndTruncation@@Tests/ACPRendering.wlt:510,1-521,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "src/a.py", "Patch" -> "Index: src/a.py\n===\n--- a/src/a.py\n+++ b/src/a.py\n@@ -1,2 +1,2 @@\n-old\n+new\n same" |> },
        { acpContainsTextQ[ boxes, "@@ -1,2 +1,2 @@" ], acpContainsTextQ[ boxes, "old" ], acpContainsTextQ[ boxes, "new" ], FreeQ[ boxes, "\"+++ b/src/a.py\"" ] }
    ],
    { True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-Patch@@Tests/ACPRendering.wlt:523,1-530,2"
]

VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "w.txt", "OldText" -> None, "NewText" -> "x\ny", "Synthesized" -> True, "Write" -> True |> },
        { acpContainsTextQ[ boxes, "contents written" ], FreeQ[ boxes, "new file" ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-ContentsWritten@@Tests/ACPRendering.wlt:532,1-539,2"
]

(* Inside hunks every line is content: a removed "-- comment" line is "--- comment" in the patch. File headers are
   dropped before the first hunk and after an "Index: " or "diff --git " line (patches of several files). *)
VerificationTest[
    {
        acpPatchRows @ StringRiffle[
            {
                "Index: a.sql", "===", "--- a/a.sql", "+++ b/a.sql",
                "@@ -1,3 +1,3 @@ select", "--- comment", "+++ counter", " keep", "\\ No newline at end of file",
                "diff --git a/b.txt b/b.txt", "index 1..2 100644", "--- a/b.txt", "+++ b/b.txt",
                "@@ -1 +1 @@", "-x", "+y",
                "Index: c.txt", "===", "--- c.txt", "+++ c.txt", "@@ -1 +1 @@", "-p", "+q"
            },
            "\n"
        ],
        acpDiffStats @ <| "Patch" -> "--- a/a.sql\n+++ b/a.sql\n@@ -1,2 +1,2 @@\n--- old comment\n+++ new counter\n same" |>,
        acpPatchRows @ "+only\n-lines",
        acpPatchRows @ None
    },
    {
        {
            { "@", "@@ -1,3 +1,3 @@ select" }, { "-", "-- comment" }, { "+", "++ counter" }, { "=", "keep" },
            { "@", "@@ -1 +1 @@" }, { "-", "x" }, { "+", "y" },
            { "@", "@@ -1 +1 @@" }, { "-", "p" }, { "+", "q" }
        },
        { 1, 1 },
        { { "+", "only" }, { "-", "lines" } },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-PatchRows@@Tests/ACPRendering.wlt:543,1-571,2"
]

(* "Header" -> False leaves out the path line; "Omitted" lines are added to the "more lines" note *)
VerificationTest[
    Module[ { diff = <| "Path" -> "src/a.py", "Patch" -> "@@ -1,3 +1,3 @@\n-a\n+b\n c" |>, plain, bare, cut },
        plain = ToBoxes @ acpDiffView @ diff;
        bare  = ToBoxes @ acpDiffView[ diff, <| "Header" -> False |> ];
        cut   = ToBoxes @ acpDiffView[ diff, <| "Header" -> False, "MaxLines" -> 2, "Omitted" -> 10 |> ];
        {
            acpContainsTextQ[ plain, "src/a.py" ],
            acpContainsTextQ[ bare, "src/a.py" ],
            acpContainsTextQ[ bare, "b" ],
            acpContainsTextQ[ cut, "12 more lines" ],
            acpContainsTextQ[ ToBoxes @ acpDiffView[ diff, <| "Omitted" -> 5 |> ], "5 more lines" ]
        }
    ],
    { True, False, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-HeaderAndOmitted@@Tests/ACPRendering.wlt:574,1-590,2"
]

(* The chat's diff views: natural width, no line numbers *)
VerificationTest[
    Module[ { boxes = ToBoxes @ acpDiffView @ <| "Path" -> "src/a.py", "Patch" -> "@@ -1,3 +1,3 @@\n-a\n+b\n c" |> },
        {
            Cases[ boxes, FrameBox[ _, opts___ ] /; MemberQ[ { opts }, RoundingRadius -> 4 ] :> Lookup[ { opts }, ImageSize, Automatic ], { 0, Infinity } ],
            Union @ Cases[ boxes, GridBox[ rows_, ___, GridBoxBackground -> _, ___ ] :> Length /@ rows, Infinity ],
            FreeQ[ boxes, GridBoxItemSize -> { "Columns" -> { ___, Fit }, ___ } ]
        }
    ],
    { { Automatic }, { { 2, 2, 2, 2 } }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-ChatLayout@@Tests/ACPRendering.wlt:593,1-604,2"
]

(* "LineNumbers": old and new line numbers from the hunk headers of patches, counted through line diffs (also across
   collapsed context), new numbers for contents written *)
VerificationTest[
    Module[ { rows, old, new },
        rows[ diff_ ] := Wolfram`Chatbook`ACP`Rendering`Private`diffRows[ diff, 3, True ];
        old = StringRiffle[ ToString /@ Range[ 20 ], "\n" ];
        new = StringReplace[ old, "\n10\n" -> "\nten\n" ];
        {
            rows @ <| "Path" -> "x", "Patch" -> "diff --git a/x b/x\n--- a/x\n+++ b/x\n@@ -3,4 +3,5 @@ f\n a\n-b\n+B\n+C\n c\n d\n@@ -20 +21 @@\n-y\n+z" |>,
            rows @ <| "Path" -> "x", "OldText" -> old, "NewText" -> new |>,
            rows @ <| "Path" -> "x", "OldText" -> None, "NewText" -> "p\nq\n" |>,
            rows @ <| "Path" -> "x", "NewText" -> "p\nq", "Write" -> True |>,
            rows @ <| "Path" -> "x", "Patch" -> "+only\n-lines\n@@ bad header @@\n same" |>
        }
    ],
    {
        {
            { "@", "@@ -3,4 +3,5 @@ f", None, None },
            { "=", "a", 3, 3 }, { "-", "b", 4, None }, { "+", "B", None, 4 }, { "+", "C", None, 5 }, { "=", "c", 5, 6 }, { "=", "d", 6, 7 },
            { "@", "@@ -20 +21 @@", None, None }, { "-", "y", 20, None }, { "+", "z", None, 21 }
        },
        {
            { "@", "\:22ef", None, None },
            { "=", "7", 7, 7 }, { "=", "8", 8, 8 }, { "=", "9", 9, 9 }, { "-", "10", 10, None }, { "+", "ten", None, 10 },
            { "=", "11", 11, 11 }, { "=", "12", 12, 12 }, { "=", "13", 13, 13 },
            { "@", "\:22ef", None, None }
        },
        { { "+", "p", None, 1 }, { "+", "q", None, 2 } },
        { { "=", "p", None, 1 }, { "=", "q", None, 2 } },
        { { "+", "only", None, None }, { "-", "lines", None, None }, { "@", "@@ bad header @@", None, None }, { "=", "same", None, None } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-LineNumberRows@@Tests/ACPRendering.wlt:608,1-639,2"
]

(* The number columns: narrow, muted, right-aligned, blank where a side has no line; a column without numbers is left
   out. "FullWidth": the frame fills the available width and the line column takes the rest of it. The line cap still
   applies. *)
VerificationTest[
    Module[ { numbers, frameSize, patch, both, newOnly, none, capped },
        (* { columns per row, number column texts } of the diff grid *)
        numbers[ boxes_ ] := FirstCase[
            boxes,
            GridBox[ rows_, opts___ ] /; MemberQ[ { opts }, GridBoxBackground -> _ ] :> {
                Union[ Length /@ rows ],
                Replace[ Drop[ #, -2 ], { StyleBox[ n_String, ___ ] :> StringTrim[ n, "\"" ], n_String :> StringTrim[ n, "\"" ] }, { 1 } ] & /@ rows,
                Lookup[ { opts }, GridBoxAlignment ],
                Lookup[ { opts }, GridBoxItemSize ]
            },
            None,
            Infinity
        ];
        frameSize[ boxes_ ] := FirstCase[ boxes, FrameBox[ _, opts___ ] /; MemberQ[ { opts }, RoundingRadius -> 4 ] :> Lookup[ { opts }, ImageSize, Automatic ], None, { 0, Infinity } ];
        patch   = <| "Path" -> "x", "Patch" -> "@@ -9,2 +9,2 @@\n-a\n+b\n c" |>;
        both    = ToBoxes @ acpDiffView[ patch, <| "LineNumbers" -> True, "FullWidth" -> True, "Header" -> False |> ];
        newOnly = ToBoxes @ acpDiffView[ <| "Path" -> "n", "OldText" -> None, "NewText" -> "p\nq" |>, <| "LineNumbers" -> True |> ];
        none    = ToBoxes @ acpDiffView[ <| "Path" -> "x", "Patch" -> "+only" |>, <| "LineNumbers" -> True, "FullWidth" -> True |> ];
        capped  = ToBoxes @ acpDiffView[ patch, <| "LineNumbers" -> True, "MaxLines" -> 2 |> ];
        {
            numbers @ both,
            frameSize @ both,
            numbers @ newOnly,
            frameSize @ newOnly,
            numbers @ none,
            numbers[ capped ][[ 2 ]],
            acpContainsTextQ[ capped, "2 more lines" ],
            FirstCase[ both, StyleBox[ "\"10\"", opts___ ] :> Lookup[ { opts }, FontColor ], None, Infinity ] === Wolfram`Chatbook`ACP`Rendering`Private`$mutedColor
        }
    ],
    {
        {
            { 4 },
            { { "", "" }, { "9", "" }, { "", "9" }, { "10", "10" } },
            { "Columns" -> { Right, Right, Left, Left }, "Rows" -> { { Baseline } } },
            { "Columns" -> { Automatic, Automatic, Automatic, Fit }, "Rows" -> { { Automatic } } }
        },
        Full,
        { { 3 }, { { "1" }, { "2" } }, { "Columns" -> { Right, Left, Left }, "Rows" -> { { Baseline } } }, _ },
        Automatic,
        { { 2 }, { { } }, _, { "Columns" -> { Automatic, Fit }, "Rows" -> { { Automatic } } } },
        { { "", "" }, { "9", "" } },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-DiffView-LineNumbersAndFullWidth@@Tests/ACPRendering.wlt:644,1-692,2"
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
    TestID   -> "ACPRendering-FinalCell-Structure@@Tests/ACPRendering.wlt:697,1-713,2"
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
    TestID   -> "ACPRendering-FinalCell-WorkedForOpener@@Tests/ACPRendering.wlt:715,1-730,2"
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
    TestID   -> "ACPRendering-FinalCell-NoKernelState@@Tests/ACPRendering.wlt:732,1-743,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp2_thought_only" ] },
        { MatchQ[ First @ items, Cell[ BoxData[ TemplateBox[ { _, "\"Thought for a second\"", <| "Type" -> "Literal" |> }, "ThoughtsOpener" ] ], ___ ] ], FreeQ[ items, s_String /; StringContainsQ[ s, "Worked for" ] ] }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-ThoughtOnly@@Tests/ACPRendering.wlt:745,1-752,2"
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
    TestID   -> "ACPRendering-FinalCell-DeclinedTail@@Tests/ACPRendering.wlt:754,1-768,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp6_stop_streaming" ] },
        { acpContainsTextQ[ items, "Johannes Gutenberg's movable" ], acpContainsTextQ[ Last @ items, "Stopped by you after" ], FreeQ[ items, "ThoughtsOpener" ] }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-StoppedPartialAnswer@@Tests/ACPRendering.wlt:770,1-777,2"
]

VerificationTest[
    Module[ { cell = acpFinalCell @ acpReplay[ "exp3_error" ] },
        { acpContainsTextQ[ cell, "Model exo-free has been deprecated" ], cell[[ -1, 2, "ACPTurn", "Error" ]] }
    ],
    { True, <| "Code" -> -32603, "Message" -> "Internal error: Model exo-free has been deprecated." |> },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-Error@@Tests/ACPRendering.wlt:779,1-786,2"
]

VerificationTest[
    Module[ { items = acpFinalItems @ acpFinalCell @ acpReplay[ "exp2_retries" ] },
        acpContainsTextQ[ First @ items, "Rate limited; retried 6\[Times] over 47s" ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-RetryNotice@@Tests/ACPRendering.wlt:788,1-795,2"
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
    TestID   -> "ACPRendering-FinalCell-Fallbacks@@Tests/ACPRendering.wlt:797,1-808,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp5_B_shell" ] },
        Wolfram`Chatbook`ACP`Rendering`Private`finalCell[ turn, True ]
    ],
    Cell[ BoxData[ TemplateBox[ { _Cell }, "AssistantMessageBox" ] ], "ChatOutput", ___ ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-FinalCell-NoFrontEndFormatting@@Tests/ACPRendering.wlt:810,1-817,2"
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
    TestID   -> "ACPRendering-FinalCell-FrontEndFormatting-FEOnly@@Tests/ACPRendering.wlt:822,1-848,2"
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
    TestID   -> "ACPRendering-ToolCard-DeclinedStoppedNoOutput@@Tests/ACPRendering.wlt:855,1-875,2"
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
    TestID   -> "ACPRendering-ToolCard-StoppedKeepsRealOutput@@Tests/ACPRendering.wlt:877,1-911,2"
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
    TestID   -> "ACPRendering-FinalCell-CompletedToolsThenDeclined@@Tests/ACPRendering.wlt:916,1-937,2"
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
    TestID   -> "ACPRendering-Images-DisplaySize@@Tests/ACPRendering.wlt:942,1-954,2"
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
    TestID   -> "ACPRendering-Images-NaturalSizeCapped@@Tests/ACPRendering.wlt:957,1-969,2"
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
    TestID   -> "ACPRendering-BoldCode-LiveAndFinal@@Tests/ACPRendering.wlt:974,1-995,2"
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
    TestID   -> "ACPRendering-InlineCells-Final@@Tests/ACPRendering.wlt:1000,1-1009,2"
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
    TestID   -> "ACPRendering-InlineCells-Live@@Tests/ACPRendering.wlt:1011,1-1034,2"
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
    TestID   -> "ACPRendering-InlineCells-HeaderAndPlaceholder@@Tests/ACPRendering.wlt:1036,1-1050,2"
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
    TestID   -> "ACPRendering-PermissionPanel-StableDynamic@@Tests/ACPRendering.wlt:1055,1-1066,2"
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
    TestID   -> "ACPRendering-PermissionPanel-Edit@@Tests/ACPRendering.wlt:1068,1-1092,2"
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
    TestID   -> "ACPRendering-PermissionPanel-Shell@@Tests/ACPRendering.wlt:1094,1-1115,2"
]

VerificationTest[
    Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 5 -> <| "Params" -> <| "toolCall" -> <| "toolCallId" -> "per_5", "title" -> "/etc/hosts", "locations" -> { <| "path" -> "/etc/hosts" |> } |>, "options" -> { <| "optionId" -> "once", "kind" -> "allow_once" |> } |> |> |> |> },
        acpWithTurns[ { }, acpContainsTextQ[ First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook, "wants to access /etc/hosts outside the project" ] ]
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ExternalDirectory@@Tests/ACPRendering.wlt:1117,1-1124,2"
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
    TestID   -> "ACPRendering-PermissionPanel-AlwaysScope@@Tests/ACPRendering.wlt:1127,1-1158,2"
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
    TestID   -> "ACPRendering-PermissionPanel-AlwaysScopeExternal@@Tests/ACPRendering.wlt:1160,1-1174,2"
]

VerificationTest[
    {
        Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| |> |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ],
        Block[ { $acpWindows = <| |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ],
        Block[ { $acpWindows = <| |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionSignature @ acpFakeNotebook ]
    },
    { RawBoxes[ "" ], RawBoxes[ "" ], None },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-Empty@@Tests/ACPRendering.wlt:1176,1-1185,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Scripts and notebook tools*)

(* OpenCode's code mode asks for permission with toolCall { name: "execute", rawInput: { code } } and nothing else (the
   permission's action, e.g. WolframNotebooks_InsertCells, is not in the request). The panel always shows the script
   as plain text, and the tool references that it shows above it. *)
VerificationTest[
    $acpPermissionOptions = {
        <| "optionId" -> "once"  , "kind" -> "allow_once"  , "name" -> "Allow once"   |>,
        <| "optionId" -> "always", "kind" -> "allow_always", "name" -> "Always allow" |>,
        <| "optionId" -> "reject", "kind" -> "reject_once" , "name" -> "Reject"       |>
    };
    (* a permission request as OpenCode 2.0.26 sends it for code mode, and for a direct call of an MCP tool *)
    acpScriptRequest[ code_String ] := <| "Params" -> <|
        "toolCall" -> <|
            "toolCallId" -> "call_script", "name" -> "execute", "title" -> "execute", "kind" -> "other", "status" -> "pending",
            "locations" -> { }, "rawInput" -> <| "code" -> code |>
        |>,
        "options"  -> $acpPermissionOptions
    |> |>;
    acpToolRequest[ name_String, input_Association ] := <| "Params" -> <|
        "toolCall" -> <| "toolCallId" -> "call_tool", "name" -> name, "title" -> name, "kind" -> "other", "status" -> "pending", "rawInput" -> input |>,
        "options"  -> $acpPermissionOptions
    |> |>;
    (* the panel's boxes for one pending request *)
    acpPanelBoxes[ info_Association ] := Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 7 -> info |> |> },
        acpWithTurns[ { }, First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ]
    ];
    (* the panel's headline (the text of its first line) *)
    acpPanelHeadline[ info_Association ] := FirstCase[
        acpBoxStrings @ acpPanelBoxes @ info,
        s_String /; StringStartsQ[ s, "OpenCode wants to" ],
        Missing[ "NoHeadline" ]
    ];
    (* the texts of the plain code blocks (Framed strings in the code font) of the panel *)
    acpPlainCodeTexts[ boxes_ ] := Cases[
        boxes,
        StyleBox[ s_String, ___, FontFamily -> "Source Code Pro", ___, PrivateFontOptions -> { "OperatorSubstitution" -> False }, ___ ] :>
            ToExpression[ s, InputForm ],
        Infinity
    ];
    $acpE2EScript = "return await tools.WolframNotebooks.InsertCells({notebook:\"5de1d007\",markdown:\"Escape velocity: v = sqrt(2 mu / r).\"});";
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptDefinitions@@Tests/ACPRendering.wlt:1194,1-1234,2"
]

(* The request of the end-to-end run: the headline names the tool, the call's notebook and markdown are shown, and the
   script itself below them; the options are the agent's *)
VerificationTest[
    Module[ { boxes = acpPanelBoxes @ acpScriptRequest @ $acpE2EScript, buttons },
        buttons = Cases[ boxes, b_ButtonBox :> b, Infinity ];
        {
            acpPanelHeadline @ acpScriptRequest @ $acpE2EScript,
            acpContainsTextQ[ boxes, "WolframNotebooks: InsertCells" ],
            acpContainsTextQ[ boxes, "5de1d007" ],
            MemberQ[ acpPlainCodeTexts @ boxes, "Escape velocity: v = sqrt(2 mu / r)." ],
            MemberQ[ acpPlainCodeTexts @ boxes, $acpE2EScript ],
            acpContainsTextQ[ boxes, "Script" ],
            (* plain text: no Chatbook code block, whose formatter would format the agent's text *)
            FreeQ[ boxes, _String? (StringContainsQ[ "ChatCodeBlock" ]) ],
            acpActionCalls[ buttons, "PermissionResponse" ],
            acpContainsTextQ[ boxes, "use the tool that it asks about here (the script may use WolframNotebooks: InsertCells)" ]
        }
    ],
    {
        "OpenCode wants to run a script that may use WolframNotebooks: InsertCells",
        True, True, True, True, True, True,
        { { acpFakeNotebook, 7, "once" }, { acpFakeNotebook, 7, "always" }, { acpFakeNotebook, 7, "reject" } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptE2E@@Tests/ACPRendering.wlt:1238,1-1262,2"
]

(* The window title of the notebook, once the pump resolved it (see acpNotebookTitles), with its id *)
VerificationTest[
    Module[ { info, boxes },
        info  = Append[ acpScriptRequest @ $acpE2EScript, "NotebookTitles" -> <| "5de1d007" -> <| "ID" -> "5de1d007", "Title" -> "Orbits.nb" |> |> ];
        boxes = acpPanelBoxes @ info;
        {
            acpContainsTextQ[ boxes, "Orbits.nb" ],
            acpContainsTextQ[ boxes, "5de1d007" ],
            (* the titles are part of the panel's signature: it is shown again when they arrive *)
            Block[ { $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ <| 7 -> info |> |> },
                Last @ Wolfram`Chatbook`ACP`Rendering`Private`permissionSignature @ acpFakeNotebook
            ]
        }
    ],
    { True, True, <| "5de1d007" -> <| "ID" -> "5de1d007", "Title" -> "Orbits.nb" |> |> },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptNotebookTitle@@Tests/ACPRendering.wlt:1265,1-1281,2"
]

(* The shapes of D2-01: the bracket form, the mixed form, a namespace alias, and decoys in a comment. The headline
   names every tool that the script names (the edits first), and the script is always shown *)
VerificationTest[
    Module[ { scripts },
        scripts = {
            "await tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: allIds})",
            "await tools[\"WolframNotebooks\"].DeleteCells({notebook:\"ab12cd34\", cells: \"c1\"})",
            "const nb = tools.WolframNotebooks;\nawait nb.DeleteCells({notebook:\"ab12cd34\", cells: \"c1\"})",
            "/* tools.WolframNotebooks.ListNotebooks({}) */ await tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: allIds})",
            "// tools.WolframNotebooks.ListNotebooks({});\nawait tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: allIds})"
        };
        {
            acpPanelHeadline @ acpScriptRequest @ # & /@ scripts,
            AllTrue[ scripts, MemberQ[ acpPlainCodeTexts @ acpPanelBoxes @ acpScriptRequest @ #, # ] & ],
            (* the arguments of the real call: the notebook, and cells that are not a literal *)
            With[ { boxes = acpPanelBoxes @ acpScriptRequest @ Last @ scripts },
                { acpContainsTextQ[ boxes, "ab12cd34" ], acpContainsTextQ[ boxes, "(computed)" ] }
            ]
        }
    ],
    {
        {
            "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells",
            "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells",
            "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells",
            "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells, WolframNotebooks: ListNotebooks",
            "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells, WolframNotebooks: ListNotebooks"
        },
        True,
        { True, True }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptBracketMixedDecoy@@Tests/ACPRendering.wlt:1285,1-1316,2"
]

(* A script whose tools can't be read: a neutral headline (or "and other tools" when some can), and the script, at
   most $permissionScriptLines lines with a note of the rest *)
VerificationTest[
    Module[ { long, boxes },
        long  = StringRiffle[ Join[ { "const n = pick();" }, Table[ "// line " <> ToString @ k, { k, 100 } ], { "return n;" } ], "\n" ];
        boxes = acpPanelBoxes @ acpScriptRequest @ long;
        {
            acpPanelHeadline @ acpScriptRequest[ "const x = compute();\nreturn x;" ],
            acpPanelHeadline @ acpScriptRequest[ "const t = tools;\nreturn t.WolframNotebooks.DeleteCells({});" ],
            acpPanelHeadline @ acpScriptRequest[ "await tools.WolframNotebooks.ListNotebooks({});\nawait tools.WolframNotebooks[name]({})" ],
            MemberQ[ acpPlainCodeTexts @ acpPanelBoxes @ acpScriptRequest[ "const x = compute();\nreturn x;" ], "const x = compute();\nreturn x;" ],
            Length @ StringSplit[ First @ acpPlainCodeTexts @ boxes, "\n" ],
            StringEndsQ[ First @ acpPlainCodeTexts @ boxes, "\[Ellipsis] 22 more lines" ],
            (* no tools: the "Always allow" text is the generic one *)
            acpContainsTextQ[ boxes, "do this kind of thing in /project" ]
        }
    ],
    {
        "OpenCode wants to run a script",
        "OpenCode wants to run a script that may use WolframNotebooks: DeleteCells and other tools",
        "OpenCode wants to run a script that may use WolframNotebooks: ListNotebooks and other tools",
        True,
        81,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptUnparseable@@Tests/ACPRendering.wlt:1320,1-1346,2"
]

(* A decoy (with literal arguments, in a regular expression) and a real edit that the reader can't see (a comment
   between "tools" and its member): the headline and the "Always allow" text name the edit with "and other tools", and
   the decoy's arguments and notebook are not shown. A script that names no tool that changes notebooks (which are what
   Chatbook's permission rules make OpenCode ask about) gets "and other tools" too. *)
VerificationTest[
    Module[ { hidden, scope },
        hidden = StringJoin[
            "const r = /tools.WolframNotebooks.InsertCells({notebook: \"5de1d007\", markdown: \"Escape velocity\"})/;\n",
            "await tools /* namespace */ .WolframNotebooks.DeleteCells({notebook: \"5de1d007\", cells: \"a1,b2,c3\"});"
        ];
        scope[ code_ ] := Wolfram`Chatbook`ACP`Rendering`Private`alwaysScopeText[
            <| "Name" -> "execute", "RawName" -> "execute", "RawInput" -> <| "code" -> code |>, "RawOutput" -> None |>,
            "OpenCode",
            "/project"
        ];
        {
            acpPanelHeadline @ acpScriptRequest @ hidden,
            StringContainsQ[ scope @ hidden, "(the script may use WolframNotebooks: InsertCells, WolframNotebooks: DeleteCells and other tools)" ],
            (* only the script is shown as code: no markdown argument of the decoy *)
            acpPlainCodeTexts @ acpPanelBoxes @ acpScriptRequest @ hidden === { hidden },
            acpPermissionNotebooks @ <| "toolCall" -> <| "name" -> "execute", "rawInput" -> <| "code" -> hidden |> |> |>,
            acpPanelHeadline @ acpScriptRequest[ "await tools.WolframNotebooks.ListNotebooks({})" ],
            StringContainsQ[ scope[ "await tools.WolframNotebooks.ListNotebooks({})" ], "(the script may use WolframNotebooks: ListNotebooks and other tools)" ],
            StringContainsQ[ scope @ $acpE2EScript, "(the script may use WolframNotebooks: InsertCells) in /project" ]
        }
    ],
    {
        "OpenCode wants to run a script that may use WolframNotebooks: InsertCells, WolframNotebooks: DeleteCells and other tools",
        True,
        True,
        { },
        "OpenCode wants to run a script that may use WolframNotebooks: ListNotebooks and other tools",
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptHiddenCall@@Tests/ACPRendering.wlt:1352,1-1385,2"
]

(* A real call with a long markdown literal and an edit hidden after it on the same line (tools.WolframNotebooks
   assigned in an expression): "and other tools", and the whole line is shown (wrapped, not cut). A script longer than
   $permissionScriptLength characters ends with a note of the rest. *)
VerificationTest[
    Module[ { markdown, hidden, long, boxes },
        markdown = "## Summary\\n\\n" <> StringRepeat[ "The orbital period follows from Kepler's third law. ", 6 ];
        hidden   = StringJoin[
            "await tools.WolframNotebooks.InsertCells({notebook: \"c6d32676\", markdown: \"", markdown, "\"}); ",
            "let p = tools.WolframNotebooks; await (p = tools.WolframNotebooks)[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"});"
        ];
        long  = "const s = \"" <> StringRepeat[ "x", 25000 ] <> "\";\nreturn s;";
        boxes = acpPanelBoxes @ acpScriptRequest @ long;
        {
            StringLength @ hidden > 400,
            acpPanelHeadline @ acpScriptRequest @ hidden,
            MemberQ[ acpPlainCodeTexts @ acpPanelBoxes @ acpScriptRequest @ hidden, hidden ],
            StringLength @ First @ acpPlainCodeTexts @ boxes,
            StringEndsQ[ First @ acpPlainCodeTexts @ boxes, StringRepeat[ "x", 100 ] <> "\n\[Ellipsis] 5023 more characters" ]
        }
    ],
    {
        True,
        "OpenCode wants to run a script that may use WolframNotebooks: InsertCells and other tools",
        True,
        20000 + StringLength[ "\n\[Ellipsis] 5023 more characters" ],
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptLongLines@@Tests/ACPRendering.wlt:1390,1-1416,2"
]

(* A direct call of a notebook tool (not in code mode): the same arguments as for a script, and a "command" in its
   input is neither shown nor taken for the scope of "Always allow" *)
VerificationTest[
    Module[ { info, boxes },
        info  = acpToolRequest[ "WolframNotebooks_InsertCells", <| "notebook" -> "5de1d007", "markdown" -> "# Notes\ntext", "position" -> "before", "command" -> "rm -rf /" |> ];
        boxes = acpPanelBoxes @ Append[ info, "NotebookTitles" -> <| "5de1d007" -> <| "ID" -> "5de1d007", "Title" -> "Orbits.nb" |> |> ];
        {
            acpPanelHeadline @ info,
            acpContainsTextQ[ boxes, "Orbits.nb" ],
            MemberQ[ acpPlainCodeTexts @ boxes, "# Notes\ntext" ],
            acpContainsTextQ[ boxes, "before" ],
            acpContainsTextQ[ boxes, "rm -rf" ],
            acpContainsTextQ[ boxes, "lets OpenCode use WolframNotebooks: InsertCells in /project" ]
        }
    ],
    { "OpenCode wants to use WolframNotebooks: InsertCells", True, True, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-DirectNotebookTool@@Tests/ACPRendering.wlt:1420,1-1436,2"
]

(* The script, the markdown and the arguments are the agent's: shown as plain strings, with the front end's linear
   syntax neutralized, never through the formatter *)
VerificationTest[
    Module[ { evil, boxes },
        evil  = FromCharacterCode[ { 63425, 63433, 63432 } ] <> "DynamicBox[Print[1]]" <> FromCharacterCode[ 63424 ];
        boxes = acpPanelBoxes @ acpScriptRequest[
            "await tools.WolframNotebooks.InsertCells({notebook: \"" <> evil <> "\", markdown: \"" <> evil <> "\"}) // " <> evil
        ];
        {
            FreeQ[ boxes, s_String /; StringContainsQ[ s, Characters @ FromCharacterCode @ Range[ 63424, 63437 ] ] ],
            FreeQ[ boxes, _DynamicBox ],
            Length @ acpPlainCodeTexts @ boxes
        }
    ],
    { True, True, 2 },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ScriptPlainText@@Tests/ACPRendering.wlt:1440,1-1455,2"
]

(* The tool cards show the same arguments: a script's calls while it runs, and a direct call of a notebook tool *)
VerificationTest[
    Module[ { tool, script, direct },
        tool[ name_, input_ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "t", "Name" -> Wolfram`Chatbook`ACP`Common`acpCanonicalToolName @ name, "RawName" -> name,
            "Kind" -> "other", "Title" -> name, "Status" -> "in_progress", "ClientOutcome" -> None, "RawInput" -> input, "RawOutput" -> None,
            "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None
        |>;
        (* the calls of the execute card's Input section (the section's Script opener needs a turn) *)
        script = ToBoxes[
            Wolfram`Chatbook`ACP`Rendering`Private`executeCallView /@ acpExecuteToolCalls @ tool[
                "execute",
                <| "code" -> "await tools.WolframNotebooks.ReplaceCells({notebook: \"5de1d007\", cells: [\"c1\", \"c2\"], markdown: md})" |>
            ]
        ];
        direct = ToBoxes @ Wolfram`Chatbook`ACP`Rendering`Private`inputSection[
            tool[ "WolframNotebooks_DeleteCells", <| "notebook" -> "5de1d007", "cells" -> "c1, c2", "unusedParameter" -> "x" |> ],
            { "Tool", "t" }
        ];
        {
            acpContainsTextQ[ script, "WolframNotebooks: ReplaceCells" ],
            acpContainsTextQ[ script, "c1, c2" ],
            acpContainsTextQ[ script, "(computed)" ],
            acpContainsTextQ[ direct, "c1, c2" ],
            (* only the tools' parameters *)
            acpContainsTextQ[ direct, "unusedParameter" ]
        }
    ],
    { True, True, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ToolCard-NotebookToolArguments@@Tests/ACPRendering.wlt:1458,1-1488,2"
]

(* The pump adds the notebooks' titles to a pending request (Connection.wl), and only to one that is still pending *)
VerificationTest[
    Module[ { titles = <| "5de1d007" -> <| "ID" -> "5de1d007", "Title" -> "Orbits.nb" |> |>, info, calls = { }, run },
        info = acpScriptRequest @ $acpE2EScript;
        run[ pending_ ] := Block[
            {
                $acpWindows = <| acpFakeNotebook -> acpWindowRecord @ pending |>,
                Wolfram`Chatbook`ACP`Common`acpNotebookTitles = (AppendTo[ calls, # ]; titles) &,
                (* no pump for the made-up window *)
                Wolfram`Chatbook`ACP`Common`acpMarkWindowDirty = Null &
            },
            Wolfram`Chatbook`ACP`Connection`Private`resolvePermissionNotebooks[ acpFakeNotebook, 7, { "5de1d007" } ];
            $acpWindows[ acpFakeNotebook, "PendingPermissions" ]
        ];
        {
            run @ <| 7 -> info |>,
            run @ <| 8 -> info |>,
            calls
        }
    ],
    {
        <| 7 -> KeyValuePattern[ "NotebookTitles" -> <| "5de1d007" -> <| "ID" -> "5de1d007", "Title" -> "Orbits.nb" |> |> ] |>,
        <| 8 -> _? (FreeQ[ #, "NotebookTitles" ] &) |>,
        { { "5de1d007" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionPanel-ResolveNotebookTitles@@Tests/ACPRendering.wlt:1491,1-1517,2"
]

(* acpNotebookTitles resolves the arguments as the tools do: an id (or the start of it) or a title of one of the listed
   notebooks; others are left out. Needs a front end (else Missing["TestSkipped"]); the notebook is closed again. *)
VerificationTest[
    If[ TrueQ @ Quiet @ MatchQ[ UsingFrontEnd @ $FrontEnd, _FrontEndObject ],
        UsingFrontEnd @ Module[ { nbo, id, titles },
            nbo = NotebookPut @ Notebook[ { Cell[ "Escape velocity", "Text" ] }, WindowTitle -> "ACPRendering Orbits" ];
            WithCleanup[
                id     = StringTake[ First @ nbo, 8 ];
                titles = Wolfram`Chatbook`ACP`Common`acpNotebookTitles @ { id, "ACPRendering Orbits", "no-such-notebook" };
                {
                    Keys @ titles === { id, "ACPRendering Orbits" },
                    MatchQ[ titles[ id ], <| "ID" -> _String? (StringStartsQ[ id ]), "Title" -> "ACPRendering Orbits" |> ],
                    titles[ "ACPRendering Orbits" ] === titles[ id ]
                },
                NotebookClose @ nbo
            ]
        ],
        Missing[ "TestSkipped" ]
    ],
    { True, True, True } | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-NotebookTitles-FrontEnd@@Tests/ACPRendering.wlt:1521,1-1541,2"
]

VerificationTest[
    Block[ { $FrontEnd = Null }, Wolfram`Chatbook`ACP`Common`acpNotebookTitles /@ { { "5de1d007" }, { } } ],
    { <| |>, <| |> },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-NotebookTitles-NoFrontEnd@@Tests/ACPRendering.wlt:1543,1-1548,2"
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
    TestID   -> "ACPRendering-ToolbarStatus@@Tests/ACPRendering.wlt:1550,1-1566,2"
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
    TestID   -> "ACPRendering-ToolbarStatus-IgnoresMCPReady@@Tests/ACPRendering.wlt:1569,1-1579,2"
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
    TestID   -> "ACPRendering-UsageMeter@@Tests/ACPRendering.wlt:1581,1-1595,2"
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
    TestID   -> "ACPRendering-ErrorView@@Tests/ACPRendering.wlt:1597,1-1609,2"
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
    TestID   -> "ACPRendering-ErrorView-LocateAgent@@Tests/ACPRendering.wlt:1612,1-1624,2"
]

VerificationTest[
    MatchQ[ #, acpWrapperPattern @ acpWindowSymbol @ acpFakeNotebook ] & /@ { acpToolbarStatusView @ acpFakeNotebook, acpUsageMeterView @ acpFakeNotebook },
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-WindowViews-StableDynamics@@Tests/ACPRendering.wlt:1626,1-1631,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Windows and Agent Text*)
VerificationTest[
    $acpTestSSH = <| "MachineName" -> "devbox.example.com", "Username" -> "u", "Arguments" -> { }, "Executable" -> Automatic |>;
    $acpRemotePaths = <| "Remote" -> True, "Host" -> "devbox", "HostLabel" -> "u@devbox.example.com", "Home" -> "/home/u" |>;
    $acpRemoteTurn  = <| "Host" -> "u@devbox.example.com", "Short" -> "devbox", "Home" -> "/home/u" |>;
    (* a string with linear syntax characters (U+F7C1 U+F7C9 ... U+F7C0), as an agent could send it *)
    $acpEvil = FromCharacterCode[ { 63425, 63433, 63432 } ] <> "DynamicBox[Print[1]]" <> FromCharacterCode[ 63424 ];
    acpLinearSyntaxQ[ expr_ ] := ! FreeQ[
        ToBoxes @ expr,
        s_String /; StringContainsQ[ s, Append[ Characters @ FromCharacterCode @ Range[ 63424, 63437 ], "\\!\\(" ] ]
    ];
    acpClickableQ[ expr_ ] := ! FreeQ[ ToBoxes @ expr, _ButtonBox | TemplateBox[ _, "HyperlinkURL" | "HyperlinkDefault", ___ ] ];
    (* Evaluates eval with every DirectoryQ or ExpandFileName of a path starting with one of prefixes sown (and not done) *)
    acpWithLocalPathTrap // Attributes = { HoldRest };
    acpWithLocalPathTrap[ prefixes_, eval_ ] := Internal`InheritedBlock[ { DirectoryQ, ExpandFileName },
        Unprotect[ DirectoryQ, ExpandFileName ];
        DirectoryQ[ p_String ] /; StringStartsQ[ p, prefixes ] := (Sow[ { "DirectoryQ", p } ]; False);
        ExpandFileName[ p_String ] /; StringStartsQ[ p, prefixes ] := (Sow[ { "ExpandFileName", p } ]; p);
        eval
    ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-RemoteDefinitions@@Tests/ACPRendering.wlt:1636,1-1659,2"
]

(* What the compact error view shows (acpErrorParts): ssh's last line, the hint, older errors' "Detail" split at the
   first blank line, hint-only and empty errors; every string neutralized *)
VerificationTest[
    {
        acpErrorParts @ <|
            "Message" -> "h didn't accept your SSH key.",
            "Hint"    -> "Agent chats sign in without prompts: use a key \[Ellipsis]",
            "Output"  -> "Warning: Permanently added \[Ellipsis]\nubuntu@h: Permission denied (publickey)."
        |>,
        acpErrorParts @ <| "Message" -> "OpenCode stopped unexpectedly.", "Detail" -> "Exit code: 1.\nError: boom" |>,
        acpErrorParts @ <| "Message" -> "Couldn't start.", "Detail" -> "Install it.\n\nfatal: one\nfatal: two" |>,
        acpErrorParts @ <| "Message" -> "OpenCode was not found on this computer.", "Detail" -> "Install it from https://opencode.ai, or \[Ellipsis]" |>,
        acpErrorParts[ <| "Message" -> "m", "Hint" -> StringRepeat[ "word ", 60 ] |> ][ "MoreQ" ],
        acpErrorParts @ <| "Message" -> "x", "Hint" -> None, "Output" -> "  \n " |>,
        acpErrorParts @ <| "Code" -> "SSHFailed" |>,
        acpErrorParts @ None
    },
    {
        <|
            "Message" -> "h didn't accept your SSH key.",
            "Line"    -> "ubuntu@h: Permission denied (publickey).",
            "Details" -> "Agent chats sign in without prompts: use a key \[Ellipsis]\n\nWarning: Permanently added \[Ellipsis]\nubuntu@h: Permission denied (publickey).",
            "MoreQ"   -> True
        |>,
        <| "Message" -> "OpenCode stopped unexpectedly.", "Line" -> "Error: boom", "Details" -> "Exit code: 1.\nError: boom", "MoreQ" -> True |>,
        <| "Message" -> "Couldn't start.", "Line" -> "fatal: two", "Details" -> "Install it.\n\nfatal: one\nfatal: two", "MoreQ" -> True |>,
        <|
            "Message" -> "OpenCode was not found on this computer.",
            "Line"    -> "Install it from https://opencode.ai, or \[Ellipsis]",
            "Details" -> "Install it from https://opencode.ai, or \[Ellipsis]",
            "MoreQ"   -> False
        |>,
        True,
        <| "Message" -> "x", "Line" -> None, "Details" -> None, "MoreQ" -> False |>,
        <| "Message" -> "SSHFailed", "Line" -> None, "Details" -> None, "MoreQ" -> False |>,
        <| "Message" -> "", "Line" -> None, "Details" -> None, "MoreQ" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-ErrorParts@@Tests/ACPRendering.wlt:1663,1-1700,2"
]

(* The line is cut to 200 characters, the output to its last 12 lines and the details to about 1500 characters; text with
   linear syntax characters (U+F7C1) is shown with U+FFFD instead *)
VerificationTest[
    Module[ { long, many, parts },
        long  = acpErrorParts @ <| "Message" -> "m", "Output" -> StringRepeat[ "x", 300 ] |>;
        many  = acpErrorParts @ <| "Message" -> "m", "Hint" -> "hint", "Output" -> StringRiffle[ "line " <> ToString[ # ] & /@ Range[ 30 ], "\n" ] |>;
        parts = acpErrorParts @ <| "Message" -> "a" <> $acpEvil, "Hint" -> "h" <> $acpEvil, "Output" -> "o" <> $acpEvil |>;
        {
            StringLength @ long[ "Line" ],
            StringEndsQ[ long[ "Line" ], "\[Ellipsis]" ],
            StringSplit[ many[ "Details" ], "\n" ][[ { 1, 3, -1 } ]],
            Length @ StringSplit[ many[ "Details" ], "\n" ],
            StringLength[ acpErrorParts[ <| "Message" -> "m", "Hint" -> "h", "Output" -> StringRepeat[ "y", 5000 ] |> ][ "Details" ] ] <= 1500,
            AnyTrue[ Values @ parts, acpLinearSyntaxQ ],
            StringContainsQ[ parts[ "Message" ] <> parts[ "Line" ] <> parts[ "Details" ], "\:fffd" ]
        }
    ],
    { 200, True, { "hint", "line 19", "line 30" }, 14, True, False, True },
    SameTest -> MatchQ,
    TestID   -> "Remote-ErrorParts-Limits@@Tests/ACPRendering.wlt:1704,1-1722,2"
]

(* The toolbar's compact error view: the message and the last line of the output, the buttons on their own row with
   "Details"; the hint and the output only when the window's "ErrorDetailOpen" is the error's key, with "Copy"; no
   "Locate OpenCode..." for a remote window; agent and ssh text neutralized in both views *)
VerificationTest[
    Module[ { err, local, remote, compact, closed, open, remoteView, plain, view, full },
        err = <|
            "Code"    -> "SSHAuthFailed",
            "Message" -> "devbox didn't accept your SSH key.",
            "Hint"    -> "Use a key without a passphrase.",
            "Output"  -> "debug1: tried a key\nu@devbox: Permission denied (publickey). " <> $acpEvil,
            "Detail"  -> "Use a key without a passphrase.\n\nu@devbox: Permission denied (publickey). " <> $acpEvil,
            "Actions" -> { "LocateAgent", "Reconnect" }
        |>;
        local   = Join[ acpWindowRecord @ <| |>, <| "Status" -> "Error", "Error" -> err |> ];
        remote  = <| local, "Settings" -> <| "SSHSettings" -> $acpTestSSH |> |>;
        compact[ rec_ ] := Block[ { $acpWindows = <| acpFakeNotebook -> rec |> }, acpErrorView[ err, acpFakeNotebook, "Compact" ] ];
        closed     = compact @ local;
        open       = compact @ <| local, "ErrorDetailOpen" -> acpErrorKey @ err |>;
        remoteView = compact @ remote;
        plain      = acpErrorView[ <| "Code" -> "AgentNotFound", "Message" -> "Not found", "Detail" -> "Install it.", "Actions" -> { "Reconnect" } |>, acpFakeNotebook, "Compact" ];
        view       = Block[ { $acpWindows = <| |> }, acpErrorView[ err, None, "Compact" ] ];
        full       = Block[ { $acpWindows = <| acpFakeNotebook -> remote |> }, acpErrorView[ err, acpFakeNotebook ] ];
        {
            (* message and the last line of the output; the hint only in the open details *)
            acpContainsTextQ[ ToBoxes @ closed, "didn't accept your SSH key" ],
            acpContainsTextQ[ ToBoxes @ closed, "Permission denied (publickey)" ],
            acpContainsTextQ[ ToBoxes @ closed, "debug1" ],
            acpContainsTextQ[ ToBoxes @ closed, "without a passphrase" ],
            acpContainsTextQ[ ToBoxes @ open, "without a passphrase" ] && acpContainsTextQ[ ToBoxes @ open, "debug1" ],
            acpActionNames[ closed, acpFakeNotebook ],
            acpActionNames[ open, acpFakeNotebook ],
            acpContainsTextQ[ ToBoxes @ closed, "Details" ],
            acpContainsTextQ[ ToBoxes @ open, "Hide details" ],
            (* the copy button carries no text: the action copies the window's error *)
            FreeQ[ Cases[ open, HoldPattern @ Button[ _, code_, ___ ] :> HoldComplete @ code, Infinity ], _String? (StringContainsQ[ "passphrase" ]) ],
            (* buttons on their own row, below the message; every line can wrap, also in a docked cell (whose style
               turns line breaking off), and commands show as typed (no operator substitution) *)
            MatchQ[ closed, Style[ Column[ { Row[ { _, _ } ], _Style, Row[ { __ }, _ ] }, ___ ], ___ ] ],
            FreeQ[ closed[[ 1, 1, 1 ]], _Button | _FileNameSetter ],
            MatchQ[
                closed,
                Style[ _Column, OrderlessPatternSequence[ LineBreakWithin -> Automatic, LineIndent -> 0, PrivateFontOptions -> { "OperatorSubstitution" -> False } ] ]
            ],
            (* "Locate OpenCode..." is a file chooser for local windows only *)
            Length @ Cases[ closed, _FileNameSetter, Infinity ],
            Length @ Cases[ remoteView, _FileNameSetter, Infinity ],
            acpActionNames[ remoteView, acpFakeNotebook ],
            Length @ Cases[ full, _FileNameSetter, Infinity ],
            (* a one-line detail is all there is to see: no "Details" *)
            acpActionNames[ plain, acpFakeNotebook ],
            acpContainsTextQ[ ToBoxes @ plain, "Install it." ],
            (* without a window: no buttons *)
            FreeQ[ view, _Button | _FileNameSetter ],
            (* neutralized everywhere: U+F7C1 becomes U+FFFD *)
            acpLinearSyntaxQ /@ { closed, open, remoteView, full },
            acpContainsTextQ[ ToBoxes @ full, "\:fffd" ] && acpContainsTextQ[ ToBoxes @ open, "\:fffd" ]
        }
    ],
    {
        True, True, False, False, True,
        { "Reconnect", "ToggleErrorDetail" },
        { "CopyErrorDetail", "Reconnect", "ToggleErrorDetail" },
        True, True, True, True, True, True,
        1, 0, { "Reconnect", "ToggleErrorDetail" }, 0,
        { "Reconnect" }, True,
        True,
        { False, False, False, False }, True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ErrorView-Compact@@Tests/ACPRendering.wlt:1727,1-1794,2"
]

(* The full view (final cells, the Review and picker windows) wraps its lines too, in any cell, and both views and the
   open details show commands and paths as typed: no operator substitution, which draws "-" as a long minus sign and
   "->" as an arrow *)
VerificationTest[
    Module[ { err, full, open, wrapQ },
        err  = <| "Code" -> "SSHHostKeyUnknown", "Message" -> "h is not a known host yet.", "Hint" -> "Connect with ssh -l u -p 22 h.", "Output" -> "Host key verification failed." |>;
        full = acpErrorView[ <| err, "Detail" -> "Connect with ssh -l u -p 22 h.\n\nHost key verification failed." |>, None, "Full" ];
        open = Block[ { $acpWindows = <| acpFakeNotebook -> <| acpWindowRecord @ <| |>, "Status" -> "Error", "Error" -> err, "ErrorDetailOpen" -> acpErrorKey @ err |> |> },
            acpErrorView[ err, acpFakeNotebook, "Compact" ]
        ];
        wrapQ = Function[ opts, SubsetQ[ Flatten @ { opts }, { LineBreakWithin -> Automatic, LineIndent -> 0, PrivateFontOptions -> { "OperatorSubstitution" -> False } } ] ];
        {
            wrapQ @ Cases[ full, HoldPattern[ BaseStyle -> s_ ] :> s, { 1 } ],
            (* the details' code font, where "-" is substituted as well *)
            AnyTrue[
                Cases[ open, Style[ s_String /; StringContainsQ[ s, "ssh -l u" ], opts___ ] :> { opts }, Infinity ],
                MemberQ[ #, FontFamily -> _ ] && wrapQ[ # ] &
            ]
        }
    ],
    { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ErrorView-TextStyle@@Tests/ACPRendering.wlt:1799,1-1819,2"
]

(* FE-only: in a docked cell (the toolbar), whose "DockedCell" style turns line breaking off, the compact view wraps a
   long message at the cell's width instead of making one line past the window's edge: rasterized, a long message
   makes the view taller, not wider (skipped without a front end) *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { size, long, short },
            size = Function[ view,
                ImageDimensions @ Rasterize[
                    Cell[ BoxData @ PaneBox[ ToBoxes @ view, ImageSize -> { 300, Automatic } ], "DockedCell", ShowStringCharacters -> False ],
                    ImageResolution -> 72
                ]
            ];
            long  = size @ acpErrorView[ <| "Message" -> StringRiffle[ ConstantArray[ "/tmp/a-b/c", 40 ], " " ] |>, None, "Compact" ];
            short = size @ acpErrorView[ <| "Message" -> "/tmp/a-b/c" |>, None, "Compact" ];
            { long[[ 1 ]] <= short[[ 1 ]], long[[ 2 ]] > 3 * short[[ 2 ]] }
        ]
    ],
    Missing[ "TestSkipped" ] | { True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ErrorView-WrapsInDockedCell-FEOnly@@Tests/ACPRendering.wlt:1824,1-1842,2"
]

(* B7.5: where "Always allow" applies for a remote window's request, resolved as POSIX paths on the host (~ is the
   remote home) with string operations only *)
VerificationTest[
    Module[ { abs, inside, external },
        abs      = Wolfram`Chatbook`ACP`Rendering`Private`remoteAbsolutePath;
        inside   = Wolfram`Chatbook`ACP`Rendering`Private`remoteInsideQ;
        external = Wolfram`Chatbook`ACP`Rendering`Private`remoteExternalDirectory;
        {
            abs[ #, "/home/u/proj", "/home/u" ] & /@ { "src/x.wl", "~/notes.md", "~", "/etc/hosts", "../other/y", "~bob/x", "$HOME/x", "`pwd`/x", "", "/a/./b/../c//" },
            abs[ "~/x", "/p", None ],
            abs[ "x", None, None ],
            {
                inside[ "/home/u/proj/a", "/home/u/proj" ],
                inside[ "/home/u/proj", "/home/u/proj/" ],
                inside[ "/home/u/project2/a", "/home/u/proj" ],
                inside[ "/home/u/proj/../x", "/home/u/proj" ],
                inside[ "/x", "/" ]
            },
            external[ "read", { "/etc/hosts" }, { }, "/home/u/proj", "/home/u" ],
            external[ "list", { "/var/log" }, { }, "/home/u/proj", "/home/u" ],
            external[ "grep", { "/var/log" }, { }, "/home/u/proj", "/home/u" ],
            external[ None, { }, { "~/other" }, "/home/u/proj", "/home/u" ],
            external[ None, { }, { "~/other" }, "/home/u/proj", None ],
            external[ "read", { "src/a.wl" }, { }, "/home/u/proj", "/home/u" ],
            external[ "read", { "/x" }, { }, "/home/u/proj", "/home/u" ],
            external[ "edit", { "../sibling/f.txt" }, { }, "/home/u/proj", "/home/u" ]
        }
    ],
    {
        { "/home/u/proj/src/x.wl", "/home/u/notes.md", "/home/u", "/etc/hosts", "/home/u/other/y", None, None, None, None, "/a/c" },
        None,
        None,
        { True, True, False, False, True },
        "/etc",
        "/var/log",
        "/var/log",
        "/home/u/other",
        None,
        None,
        "/",
        "/home/u/sibling"
    },
    SameTest -> MatchQ,
    TestID   -> "Remote-PermissionPaths@@Tests/ACPRendering.wlt:1846,1-1888,2"
]

(* The permission panel of a remote window: read /etc, list /var/log, cd ~/other (the known home), paths inside the
   project; the external folder shown abbreviated with the remote home; nothing looked at on this computer *)
VerificationTest[
    Module[ { scope, texts, sown, panel, remote, signatures },
        scope[ tool_ ] := Wolfram`Chatbook`ACP`Rendering`Private`alwaysScopeText[ tool, "OpenCode", "/home/u/proj", $acpRemotePaths ];
        remote = <|
            acpWindowRecord @ <| 7 -> <| "Params" -> <|
                "toolCall" -> <| "toolCallId" -> "per_7", "name" -> "bash", "rawInput" -> <| "command" -> "cd ~/other && ls" |> |>,
                "options"  -> { <| "optionId" -> "once", "kind" -> "allow_once" |>, <| "optionId" -> "always", "kind" -> "allow_always" |> }
            |> |> |>,
            "ProjectDirectory" -> "/home/u/proj",
            "RemoteHome"       -> "/home/u",
            "Settings"         -> <| "SSHSettings" -> $acpTestSSH |>
        |>;
        { texts, sown } = Reap @ acpWithLocalPathTrap[
            { "/etc", "/var", "/home/u", "~" },
            {
                scope @ <| "Name" -> "read", "RawInput" -> <| "filePath" -> "/etc/hosts" |>, "Locations" -> { <| "path" -> "/etc/hosts" |> } |>,
                scope @ <| "Name" -> "list", "RawInput" -> <| "path" -> "/var/log" |> |>,
                scope @ <| "Name" -> "shell", "RawInput" -> <| "command" -> "cd ~/other && ls" |> |>,
                scope @ <| "Name" -> "read", "RawInput" -> <| "filePath" -> "src/a.py" |>, "Locations" -> { <| "path" -> "/home/u/proj/src/a.py" |> } |>,
                scope @ <| "Name" -> "edit", "RawInput" -> <| "filePath" -> "/home/u/proj/src/a.py" |> |>,
                scope @ <| "Name" -> "read", "RawInput" -> <| "filePath" -> "~/.bashrc" |> |>,
                Block[ { $acpWindows = <| acpFakeNotebook -> remote |> },
                    acpWithTurns[ { }, First @ Wolfram`Chatbook`ACP`Rendering`Private`permissionPanelContent @ acpFakeNotebook ]
                ]
            }
        ];
        panel = Last @ texts;
        signatures = Block[ { $acpWindows = <| acpFakeNotebook -> # |> }, Wolfram`Chatbook`ACP`Rendering`Private`permissionSignature @ acpFakeNotebook ] & /@ {
            remote, <| remote, "RemoteHome" -> "/home/v" |>
        };
        {
            StringContainsQ[ texts[[ 1 ]], "access files in /etc " ],
            StringContainsQ[ texts[[ 2 ]], "access files in /var/log " ],
            StringContainsQ[ texts[[ 3 ]], "access files in ~/other " ],
            StringContainsQ[ texts[[ 4 ]], "this kind of thing in /home/u/proj" ],
            StringContainsQ[ texts[[ 5 ]], "all file edits in /home/u/proj" ],
            StringContainsQ[ texts[[ 6 ]], "access files in ~ " ],
            acpContainsTextQ[ panel, "access files in ~/other" ],
            sown,
            (* the remote home is part of the panel's signature *)
            Unequal @@ signatures
        }
    ],
    { True, True, True, True, True, True, True, { }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-PermissionScope-Remote@@Tests/ACPRendering.wlt:1892,1-1938,2"
]

(* Resource links of a remote window's turn: a file on the host is shown with its path on the host as a tooltip, not as
   a link; web links stay links; a local agent's file links stay links (its own files on this computer) *)
VerificationTest[
    Module[ { view, remoteFile, turn, cell },
        view = Wolfram`Chatbook`ACP`Rendering`Private`contentBlockView;
        remoteFile = view[ <| "type" -> "resource_link", "uri" -> "file:///home/u/my%20x.txt", "name" -> "my x.txt" |>, $acpRemoteTurn ];
        turn = Fold[
            Function[ { t, u }, acpApplyUpdate[ t, u, $acpBaseTime + 1 ][ "Turn" ] ],
            acpNewTurn @ <| "ID" -> "render-remote-links", "Prompt" -> "Q", "ProjectDirectory" -> "/home/u/proj", "Remote" -> $acpRemoteTurn, "StartTime" -> $acpBaseTime |>,
            {
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "m1", "content" -> <| "type" -> "text", "text" -> "Here:" |> |>,
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "m1", "content" -> <| "type" -> "resource_link", "uri" -> "file:///home/u/proj/a.txt", "name" -> "a.txt" |> |>,
                <| "sessionUpdate" -> "agent_message_chunk", "messageId" -> "m1", "content" -> <| "type" -> "resource_link", "uri" -> "https://example.com/doc", "name" -> "doc" |> |>
            }
        ];
        turn = acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, $acpBaseTime + 2 ][ "Turn" ];
        cell = acpFinalCell @ turn;
        {
            acpClickableQ @ remoteFile,
            acpContainsTextQ[ ToBoxes @ remoteFile, "On u@devbox.example.com: /home/u/my x.txt" ],
            acpContainsTextQ[ ToBoxes @ remoteFile, "my x.txt" ],
            acpClickableQ @ view[ <| "type" -> "resource_link", "uri" -> "HTTPS://example.com/x", "name" -> "x" |>, $acpRemoteTurn ],
            acpClickableQ @ view[ <| "type" -> "resource_link", "uri" -> "file:///tmp/a.txt", "name" -> "a.txt" |>, None ],
            acpClickableQ @ view[ <| "type" -> "resource_link", "uri" -> "FILE:///home/u/a.txt", "name" -> "a.txt" |>, $acpRemoteTurn ],
            (* the final cell of the remote turn: only the web link is clickable *)
            acpContainsTextQ[ cell, "On u@devbox.example.com: /home/u/proj/a.txt" ],
            Length @ Cases[ cell, TemplateBox[ _, "HyperlinkURL" | "HyperlinkDefault", ___ ] | _ButtonBox, Infinity ],
            (* and the live view of its message *)
            acpWithTurns[ { turn }, acpContainsTextQ[ First @ acpEntityView[ turn[ "ID" ], { "Message", "m1" } ], "On u@devbox.example.com: /home/u/proj/a.txt" ] ]
        }
    ],
    { False, True, True, True, True, False, True, 1, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ResourceLink-Remote@@Tests/ACPRendering.wlt:1942,1-1974,2"
]

(* The agent's names, URIs and block types never become boxes of its choice (linear syntax), local and remote turns;
   other URI schemes are shown, not clickable (OS protocol handlers); a resource's text is neutralized *)
VerificationTest[
    Module[ { view, blocks },
        view = Wolfram`Chatbook`ACP`Rendering`Private`contentBlockView;
        blocks = {
            <| "type" -> "resource_link", "uri" -> "https://example.com/" <> $acpEvil, "name" -> $acpEvil |>,
            <| "type" -> "resource_link", "uri" -> "file:///home/u/" <> $acpEvil, "name" -> $acpEvil |>,
            <| "type" -> "resource_link", "uri" -> "ms-msdt:" <> $acpEvil |>,
            <| "type" -> $acpEvil |>,
            <| "type" -> "resource", "resource" -> <| "uri" -> "file:///x", "text" -> "text " <> $acpEvil |> |>
        };
        {
            Flatten @ Table[ acpLinearSyntaxQ @ view[ b, r ], { b, blocks }, { r, { None, $acpRemoteTurn } } ],
            acpClickableQ @ view[ #, None ] & /@ {
                <| "type" -> "resource_link", "uri" -> "ms-msdt:x", "name" -> "help" |>,
                <| "type" -> "resource_link", "uri" -> "javascript:alert(1)", "name" -> "x" |>,
                <| "type" -> "resource_link", "uri" -> "search-ms:query=x", "name" -> "x" |>,
                <| "type" -> "resource_link", "uri" -> "https://example.com", "name" -> "x" |>
            },
            acpContainsTextQ[ ToBoxes @ view[ <| "type" -> "resource_link", "uri" -> "ms-msdt:x", "name" -> "help" |>, None ], "ms-msdt:x" ],
            acpContainsTextQ[ ToBoxes @ view[ <| "type" -> $acpEvil |>, None ], "\:fffd" ]
        }
    ],
    { ConstantArray[ False, 10 ], { False, False, False, True }, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-ResourceLink-LinearSyntax@@Tests/ACPRendering.wlt:1978,1-2003,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Untrusted Content Safety*)

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::GlobalSymbol:: *)

(* The agent's answer text is untrusted: rendering it must not import markdown images (a URL image would reach the
   network, could hang the pump or exhaust memory) or evaluate Wolfram|Alpha / resource lookups. finishedItems and
   formatStreaming are run with Import and WolframAlpha blocked to loggers, on an image, a Wolfram|Alpha free-form
   prompt and a DateObject; neither is ever called. *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = True },
        Module[ { importCalls = { }, alphaCalls = { }, payloads },
            payloads = {
                "![diagram](http://10.255.255.1/x.png)",
                "```wl\n\[FreeformPrompt][\"population of france\"]\n```",
                "```wl\nDateObject[{2024, 1, 1}, TimeZone -> \"America/New_York\"]\n```"
            };
            Block[
                {
                    Import       = (AppendTo[ importCalls, { ## } ]; $Failed) &,
                    WolframAlpha = (AppendTo[ alphaCalls, { ## } ]; $Failed) &
                },
                Scan[ Wolfram`Chatbook`ACP`Rendering`Private`finishedItems, payloads ];
                Scan[ Wolfram`Chatbook`ACP`Rendering`Private`formatStreaming[ "turn", #, False ] &, payloads ]
            ];
            { importCalls, alphaCalls }
        ]
    ],
    { { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-UntrustedContent-NoImportOrWolframAlpha@@Tests/ACPRendering.wlt:2016,1-2038,2"
]

(* With finished Wolfram Language formatting (a front end), neither a DateObject option nor front-end linear syntax in
   the agent's code runs code, in finishedItems or in the final codeBlock, and no image is imported, no Wolfram|Alpha
   query is made and no resource function is looked up. The probe list would gain an entry if any payload were
   evaluated. The same Wolfram|Alpha and resource function payloads in a chat's code block do make the calls, so the
   test can't pass because the formatter makes neither anyway; queries are unique, as their results are cached. *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`Rendering`Private`$acpNoFrontEndFormatting = False },
        UsingFrontEnd @ Module[ { importCalls = { }, alphaCalls = { }, resourceCalls = { }, lookups, acpCalls },
            Global`acpUntrustedProbe = { };
            Needs[ "FunctionResource`" -> None ];
            lookups[ ] := StringJoin[
                "```wl\n\[FreeformPrompt][\"population of ", CreateUUID[ ], "\"]\n",
                "ResourceFunction[\"NoSuchFunction", StringDelete[ CreateUUID[ ], "-" ], "\"]\n```"
            ];
            Block[
                {
                    Import       = (AppendTo[ importCalls, { ## } ]; $Failed) &,
                    WolframAlpha = (AppendTo[ alphaCalls, { ## } ]; $Failed) &,
                    FunctionResource`MakeResourceFunctionBoxes = (AppendTo[ resourceCalls, { ## } ]; $Failed) &
                },
                Wolfram`Chatbook`ACP`Rendering`Private`finishedItems @ lookups[ ];
                Wolfram`Chatbook`ACP`Rendering`Private`finishedItems[
                    "```wl\nDateObject[{2024, 1, 1}, TimeZone -> (AppendTo[Global`acpUntrustedProbe, \"date\"]; 0)]\n```"
                ];
                Wolfram`Chatbook`ACP`Rendering`Private`finishedItems[ "![a](http://10.255.255.1/x.png)" ];
                Wolfram`Chatbook`ACP`Rendering`Private`finishedItems[
                    "```wl\nf[\!\(\*RowBox[{AppendTo[Global`acpUntrustedProbe, \"ls\"]; \"x\"}]\)]\n```"
                ];
                Block[ { Wolfram`Chatbook`ACP`Rendering`Private`$renderMode = "Final" },
                    Wolfram`Chatbook`ACP`Rendering`Private`codeBlock[
                        "DateObject[{2024, 1, 1}, TimeZone -> (AppendTo[Global`acpUntrustedProbe, \"cb\"]; 0)]",
                        "Wolfram"
                    ];
                    Wolfram`Chatbook`ACP`Rendering`Private`codeBlock[
                        "f[\!\(\*RowBox[{AppendTo[Global`acpUntrustedProbe, \"lscb\"]; \"x\"}]\)]",
                        "Wolfram"
                    ];
                    Wolfram`Chatbook`ACP`Rendering`Private`codeBlock[
                        StringDelete[ lookups[ ], "```wl\n" | "\n```" ],
                        "Wolfram"
                    ]
                ];
                acpCalls = { importCalls, alphaCalls, resourceCalls };
                FormatChatOutput[ lookups[ ], <| "Status" -> "Finished" |> ]
            ];
            { Global`acpUntrustedProbe, acpCalls, Length /@ { alphaCalls, resourceCalls } }
        ]
    ],
    { { }, { { }, { }, { } }, { 1, 1 } },
    SameTest -> MatchQ,
    TestID   -> "ACPRendering-UntrustedContent-FinishedModeNoEvaluation@@Tests/ACPRendering.wlt:2045,1-2091,2"
]

(* :!CodeAnalysis::EndBlock:: *)

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
    TestID   -> "ACPRendering-DebugLog@@Tests/ACPRendering.wlt:2100,1-2108,2"
]

(* :!CodeAnalysis::EndBlock:: *)
