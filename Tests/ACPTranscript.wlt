(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPTranscript.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPTranscript.wlt:11,1-16,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)
(* :!CodeAnalysis::Disable::NoSurroundingCatch:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LoadACPContext@@Tests/ACPTranscript.wlt:26,1-31,2"
]

VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ acpApplyEvent, acpEventIndex, acpLoadFixture, acpReplay ];

    (* Labels come from the English defaults (no front end text resources), so results don't depend on a front end: *)
    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = True;

    $acpFixtureDirectory = FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP" };
    $acpBaseTime = 1000.0;

    acpLoadFixture[ name_String ] := Import[ FileNameJoin @ { $acpFixtureDirectory, name <> ".json" }, "RawJSON" ];

    (* Applies one recorded event (see Tests/Data/ACP/*.json) to a turn through the public reducer API: *)
    acpApplyEvent[ turn_, ev_Association ] := With[ { t = $acpBaseTime + ev[ "t" ] },
        Switch[ ev[ "Type" ],
            "Update"           , acpApplyUpdate[ turn, ev[ "Update" ], t ][ "Turn" ],
            "PermissionRequest", acpApplyPermissionRequest[ turn, ev[ "RequestID" ], ev[ "Params" ], t ][ "Turn" ],
            "PermissionAnswer" , acpApplyPermissionOutcome[ turn, ev[ "RequestID" ], ev[ "OptionID" ], t ][ "Turn" ],
            "CancelRequest"    , acpApplyPermissionWithdrawn[ turn, ev[ "RequestID" ], t ][ "Turn" ],
            "ClientCancel"     , acpApplyClientCancel[ turn, ev[ "Kind" ], t ][ "Turn" ],
            "Response"         , acpApplyTurnEnd[ turn, <| "StopReason" -> ev[ "Result", "stopReason" ], "Usage" -> Lookup[ ev[ "Result" ], "usage", None ] |>, t ][ "Turn" ],
            "ErrorResponse"    , acpApplyTurnEnd[ turn, <| "Error" -> <| "Code" -> ev[ "Code" ], "Message" -> ev[ "Message" ], "Data" -> ev[ "Data" ] |> |>, t ][ "Turn" ]
        ]
    ];

    acpReplay[ name_String ] := acpReplay[ name, Infinity ];
    acpReplay[ name_String, n_ ] := Module[ { fx = acpLoadFixture @ name },
        Fold[
            acpApplyEvent,
            acpNewTurn @ <| "ID" -> name, "Prompt" -> fx[ "Prompt" ], "ProjectDirectory" -> fx[ "ProjectDirectory" ], "StartTime" -> $acpBaseTime |>,
            Take[ fx[ "Events" ], UpTo[ n ] ]
        ]
    ];

    (* Number of events up to and including the first one matching patt: *)
    acpEventIndex[ name_String, patt_ ] := First @ FirstPosition[ acpLoadFixture[ name ][ "Events" ], patt ];

    acpEntity[ turn_, key_ ] := turn[ "Entities", key ];
    acpKeysOfType[ turn_, type_ ] := Select[ turn[ "Order" ], MatchQ[ #, { type, ___ } ] & ];
    acpToolByID[ turn_, id_String ] := turn[ "Entities", turn[ "Index", "Tool", id ] ];

    acpUpdate[ kind_String, rest___Rule ] := <| "sessionUpdate" -> kind, rest |>;
    acpChunk[ id_, text_String ] := acpUpdate[ "agent_message_chunk", "messageId" -> id, "content" -> <| "type" -> "text", "text" -> text |> ];
    acpThought[ id_, text_String ] := acpUpdate[ "agent_thought_chunk", "messageId" -> id, "content" -> <| "type" -> "text", "text" -> text |> ];
    acpToolCall[ id_String, name_String, rest___Rule ] := acpUpdate[ "tool_call", "toolCallId" -> id, "name" -> name, "title" -> name, "status" -> "pending", rest ];
    acpToolUpdate[ id_String, rest___Rule ] := acpUpdate[ "tool_call_update", "toolCallId" -> id, rest ];

    (* Applies a list of updates (time increases by 1 second per update): *)
    acpApplyAll[ turn0_, updates_List ] := Fold[ acpApplyUpdate[ #1, #2[[ 1 ]], $acpBaseTime + #2[[ 2 ]] ][ "Turn" ] &, turn0, Transpose @ { updates, Range @ Length @ updates } ];
    acpFreshTurn[ ] := acpNewTurn @ <| "ID" -> "synthetic", "ProjectDirectory" -> "/project", "StartTime" -> $acpBaseTime |>;

    (* Anything logged after this point as a message or failure is unexpected (ACPTranscript-DebugLog) *)
    $acpLogStart = AbsoluteTime[ ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Definitions@@Tests/ACPTranscript.wlt:33,1-91,2"
]

VerificationTest[
    FileNames[ "*.json", $acpFixtureDirectory ] // Length,
    _Integer? (# >= 15 &),
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Fixtures-Present@@Tests/ACPTranscript.wlt:93,1-98,2"
]

VerificationTest[
    FreeQ[ acpLoadFixture /@ FileBaseName /@ FileNames[ "*.json", $acpFixtureDirectory ], s_String /; StringContainsQ[ s, "/home/ubuntu" | "TestProject" ] ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Fixtures-Sanitized@@Tests/ACPTranscript.wlt:100,1-105,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn Records*)
VerificationTest[
    acpNewTurn @ <| "ID" -> "t1", "Prompt" -> "hi", "StartTime" -> 5.0 |>,
    KeyValuePattern @ {
        "ID" -> "t1", "Prompt" -> "hi", "StartTime" -> 5.0, "Status" -> "Running", "Order" -> { }, "Entities" -> <| |>,
        "Version" -> 0, "WaitingTime" -> 0, "WaitingSince" -> None, "StopReason" -> None, "ClientCancel" -> None,
        "Error" -> None, "EndTime" -> None, "RetryInfo" -> None, "PendingPermissions" -> { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-NewTurn@@Tests/ACPTranscript.wlt:110,1-119,2"
]

VerificationTest[
    { acpTurnEndedQ @ acpFreshTurn[ ], acpTurnEndedQ @ acpApplyTurnEnd[ acpFreshTurn[ ], <| "StopReason" -> "end_turn" |>, 1001. ][ "Turn" ] },
    { False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-TurnEndedQ@@Tests/ACPTranscript.wlt:121,1-126,2"
]

VerificationTest[
    acpApplyTurnEnd[ acpFreshTurn[ ], <| "StopReason" -> "end_turn" |>, 1001. ][ "Turn", "Status" ],
    "Running",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-TurnEnd-KeepsStatus@@Tests/ACPTranscript.wlt:128,1-133,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Small Helpers*)
VerificationTest[
    acpCanonicalToolName /@ { "bash", "task", "apply_patch", "Read", "shell", "execute", None },
    { "shell", "subagent", "patch", "read", "shell", "execute", None },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-CanonicalToolName@@Tests/ACPTranscript.wlt:138,1-143,2"
]

VerificationTest[
    acpFormatDuration /@ { 0.4, 45, 59.4, 133, 3599, 3600, 3840 },
    { "1s", "45s", "59s", "2m 13s", "59m 59s", "1h 0m", "1h 4m" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-FormatDuration@@Tests/ACPTranscript.wlt:145,1-150,2"
]

VerificationTest[
    acpPreprocessAnswer[ "Plan:\n- [ ] one\n- [x] two\n  * [X] nested\n- [link](x) and [ ] not a task" ],
    "Plan:\n- \:2610 one\n- \:2611 two\n  * \:2611 nested\n- [link](x) and [ ] not a task",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PreprocessAnswer-TaskList@@Tests/ACPTranscript.wlt:152,1-157,2"
]

(* Chatbook's formatter can't show bold spans that contain inline code (the asterisks were shown literally): *)
VerificationTest[
    acpPreprocessAnswer /@ StringReplace[ "ARROW" -> FromCharacterCode[ 8594 ] ] @ {
        "**`Prime[Range[10]]`:** gives the primes",
        "**`2+2` ARROW `4`**",
        "**Result of `f[x]` is `x^2`**, done",
        "***`x` value***",
        "a **`x`** b **c** `d` **`e`:**",
        "**`a*b`** and **`c`**"
    },
    StringReplace[ "ARROW" -> FromCharacterCode[ 8594 ] ] @ {
        "`Prime[Range[10]]`: gives the primes",
        "`2+2` ARROW `4`",
        "**Result of** `f[x]` **is** `x^2`, done",
        "`x` ***value***",
        "a `x` b **c** `d` `e`:",
        "`a*b` and `c`"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PreprocessAnswer-BoldCode@@Tests/ACPTranscript.wlt:160,1-179,2"
]

VerificationTest[
    acpPreprocessAnswer /@ {
        "plain **bold** text and `code`",
        "**bold** `code` **more**",
        "**foo**`x`**bar**",
        "**Note:** use `foo`",
        "**unclosed `x`",
        "x ** `y` ** z",
        "**`x` **",
        "no markers at all",
        "```wl\n**`x`**\n- [ ] a\n```\n**`y`**\n- [ ] b",
        "~~~\n**`x`**\n~~~",
        "```inline```\n**`x`**"
    },
    {
        "plain **bold** text and `code`",
        "**bold** `code` **more**",
        "**foo**`x`**bar**",
        "**Note:** use `foo`",
        "**unclosed `x`",
        "x ** `y` ** z",
        "**`x` **",
        "no markers at all",
        "```wl\n**`x`**\n- [ ] a\n```\n`y`\n- \:2610 b",
        "~~~\n**`x`**\n~~~",
        "```inline```\n`x`"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PreprocessAnswer-BoldCode-Unchanged@@Tests/ACPTranscript.wlt:181,1-210,2"
]

(* The rewritten text formats without literal asterisks (front-end-free streaming formatter): *)
VerificationTest[
    Module[ { boxes },
        boxes = Block[ { Wolfram`Chatbook`Common`$dynamicText = True },
            Wolfram`Chatbook`FormatChatOutput[ acpPreprocessAnswer @ StringReplace[ "**`Prime[Range[10]]`:** done\n\n**`2+2` ARROW `4`**\n\n**Result of `f` is `x`**", "ARROW" -> FromCharacterCode[ 8594 ] ], <| "Status" -> "Streaming" |> ]
        ];
        { FreeQ[ boxes, s_String /; StringContainsQ[ s, "*" ] ], Count[ boxes, StyleBox[ _, FontWeight -> Bold ], Infinity ] }
    ],
    { True, 2 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PreprocessAnswer-BoldCode-Formatted@@Tests/ACPTranscript.wlt:213,1-223,2"
]

VerificationTest[
    acpStripToolOutput[ "Out[1]= 4\n\n\n<system-reminder>Pass session=\"x\" in future calls.</system-reminder>" ],
    "Out[1]= 4",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-StripToolOutput-Reminder@@Tests/ACPTranscript.wlt:225,1-230,2"
]

VerificationTest[
    acpStripToolOutput @ StringReplace[ "<ESC>[1;31merror<ESC>[0m: bad\r\nline2<ESC>]0;title<BEL>\n  \n", { "<ESC>" -> FromCharacterCode[ 27 ], "<BEL>" -> FromCharacterCode[ 7 ] } ],
    "error: bad\nline2",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-StripToolOutput-ANSI@@Tests/ACPTranscript.wlt:232,1-237,2"
]

VerificationTest[
    acpLineDiff[ "a\nb\nc", "a\nB\nc\nd" ],
    { { "=", "a" }, { "-", "b" }, { "+", "B" }, { "=", "c" }, { "+", "d" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff@@Tests/ACPTranscript.wlt:239,1-244,2"
]

VerificationTest[
    {
        acpDiffStats @ <| "Path" -> "f", "OldText" -> "hi", "NewText" -> "hello world" |>,
        acpDiffStats @ <| "Path" -> "f", "OldText" -> None, "NewText" -> "a\nb\nc\n" |>,
        acpDiffStats @ <| "Path" -> "f", "Patch" -> "--- a/f\n+++ b/f\n@@ -1,2 +1,2 @@\n-x\n+y\n+z\n w" |>
    },
    { { 1, 1 }, { 3, 0 }, { 2, 1 } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-DiffStats@@Tests/ACPTranscript.wlt:246,1-255,2"
]

(* The line diff gives the fewest removed and added lines (a longest common subsequence, after the common first and last
   lines), never more than the earlier implementation (SequenceAlignment over all lines, inlined here), and its "=" and
   "-" lines are the old text, its "=" and "+" lines the new one *)
VerificationTest[
    Module[ { oldDiff, check },
        oldDiff[ a_List, b_List ] := Which[
            a === b, { "=", # } & /@ a,
            a === { }, { "+", # } & /@ b,
            b === { }, { "-", # } & /@ a,
            True, Flatten[ Replace[ SequenceAlignment[ a, b ], { { r_List, d_List } :> Join[ { "-", # } & /@ r, { "+", # } & /@ d ], c_List :> ({ "=", # } & /@ c) }, { 1 } ], 1 ]
        ];
        check[ a_List, b_List ] := With[ { ops = acpLineDiff[ StringRiffle[ a, "\n" ], StringRiffle[ b, "\n" ] ] },
            {
                Cases[ ops, { "=" | "-", l_ } :> l ] === a && Cases[ ops, { "=" | "+", l_ } :> l ] === b,
                Count[ ops, { "=", _ } ] === Length @ LongestCommonSequence[ a, b ],
                Count[ ops, { "=", _ } ] >= Count[ oldDiff[ a, b ], { "=", _ } ]
            }
        ];
        SeedRandom[ 1234 ];
        Union @ Flatten @ Table[
            check[
                RandomChoice[ { "a", "b", "c", "d", " " }, RandomInteger[ { 1, 14 } ] ],
                RandomChoice[ { "a", "b", "c", "d", " " }, RandomInteger[ { 1, 14 } ] ]
            ],
            { 1500 }
        ]
    ],
    { True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-Minimal@@Tests/ACPTranscript.wlt:260,1-287,2"
]

(* OpenCode sends whole files: an edit of one line of a large file is one removed and one added line (the earlier
   implementation showed all old lines removed and all new lines added past 4 million line pairs), a replaced block is
   that block, and changes at both ends of a large file are aligned through the lines that occur once in each text *)
VerificationTest[
    Module[ { lines, old, new, info, block, ends, time },
        lines = Table[ "    value_" <> ToString[ i ] <> " = compute(" <> ToString[ i ] <> ")", { i, 5000 } ];
        old   = StringRiffle[ lines, "\n" ] <> "\n";
        new   = StringReplace[ old, lines[[ 2500 ]] <> "\n" -> "    changed = 1\n" ];
        { time, info } = AbsoluteTiming @ acpLineDiffInfo[ old, new ];
        block = acpLineDiffInfo[ old, StringReplace[ old, StringRiffle[ lines[[ 1001 ;; 1300 ]], "\n" ] -> StringRiffle[ Table[ "new " <> ToString[ i ], { i, 400 } ], "\n" ] ] ];
        (* every other line is blank: 25 million pairs of equal lines, too many to compare all at once *)
        ends  = With[ { riffled = Riffle[ Table[ "v" <> ToString[ i ], { i, 5000 } ], "" ] },
            acpLineDiffInfo[ StringRiffle[ riffled, "\n" ], StringRiffle[ ReplacePart[ riffled, { 3 -> "first", 9998 -> "last" } ], "\n" ] ]
        ];
        {
            time < 2,
            info[ "Stats" ],
            info[ "Aligned" ],
            Select[ info[ "Ops" ], First @ # =!= "=" & ],
            block[ "Stats" ],
            ends[ "Stats" ],
            ends[ "Aligned" ]
        }
    ],
    { True, { 1, 1 }, True, { { "-", "    value_2500 = compute(2500)" }, { "+", "    changed = 1" } }, { 400, 300 }, { 2, 2 }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-LargeFiles@@Tests/ACPTranscript.wlt:292,1-316,2"
]

(* Past the budget of line pairs, a stretch without lines that occur once in each text is shown as removed and added
   lines (correct, not minimal), and the diff says that it is not aligned *)
VerificationTest[
    Module[ { a, b, info },
        a    = ConstantArray[ "x", 2000 ];
        b    = ReplacePart[ a, { 100 -> "y", 1900 -> "z" } ];
        info = acpLineDiffInfo[ StringRiffle[ a, "\n" ], StringRiffle[ b, "\n" ] ];
        {
            info[ "Aligned" ],
            Cases[ info[ "Ops" ], { "=" | "-", l_ } :> l ] === a,
            Cases[ info[ "Ops" ], { "=" | "+", l_ } :> l ] === b,
            Block[ { Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffMatches = 10^9 },
                KeyTake[ acpLineDiffInfo[ StringRiffle[ a, "\n" ] <> "\n", StringRiffle[ b, "\n" ] <> "\n" ], { "Stats", "Aligned" } ]
            ]
        }
    ],
    { False, True, True, <| "Stats" -> { 2, 2 }, "Aligned" -> True |> },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-NotAligned@@Tests/ACPTranscript.wlt:320,1-337,2"
]

(* Past the budget, the stretches between the lines that occur once in each text are charged with their own pairs of
   equal lines, not with the product of their lengths: 70 blocks of the same 500 lines (2.45 million pairs in all), each
   after a line of its own and changed at both ends, are all compared (the earlier charge used up the budget after 8
   blocks and showed the rest as removed and added) *)
VerificationTest[
    Module[ { block, a, b, info },
        block = Table[ "l" <> ToString[ i ], { i, 500 } ];
        a     = Flatten @ Table[ { "anchor" <> ToString[ k ], block }, { k, 70 } ];
        b     = Flatten @ Table[ { "anchor" <> ToString[ k ], ReplacePart[ block, { 1 -> "first" <> ToString[ k ], 500 -> "last" <> ToString[ k ] } ] }, { k, 70 } ];
        info  = acpLineDiffInfo[ StringRiffle[ a, "\n" ], StringRiffle[ b, "\n" ] ];
        {
            Wolfram`Chatbook`ACP`Transcript`Private`equalPairs[ a, b ] > Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffMatches,
            info[ "Stats" ],
            info[ "Aligned" ]
        }
    ],
    { True, { 140, 140 }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-Budget@@Tests/ACPTranscript.wlt:343,1-358,2"
]

(* The last results are kept: the panel, card headers and the final cell share one comparison. A hit compares the texts,
   so an entry under the same hashes for other texts is never used. *)
VerificationTest[
    Block[ { Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache = <| |> },
        Module[ { old = "a\nb\nc", new = "a\nB\nc", first, key },
            first = acpLineDiffInfo[ old, new ];
            key   = { Hash @ old, Hash @ new };
            {
                Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache[ key, "Info" ] === first,
                acpLineDiff[ old, new ] === first[ "Ops" ],
                acpDiffStats @ <| "OldText" -> old, "NewText" -> new |>,
                (* an entry for other texts under the same key (as after a hash collision) *)
                Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache[ key ] = <| "Old" -> "x", "New" -> "y", "Info" -> <| "Ops" -> { }, "Stats" -> { 9, 9 }, "Aligned" -> True |> |>;
                acpLineDiffInfo[ old, new ] === first,
                (* at most $maxCachedLineDiffs results, the oldest are dropped *)
                Do[ acpLineDiff[ "p" <> ToString @ i, "q" ], { i, 40 } ];
                Length @ Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache
            }
        ]
    ],
    { True, True, { 1, 1 }, True, 16 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-Cache@@Tests/ACPTranscript.wlt:362,1-383,2"
]

(* The oldest results are also dropped while the entries take more than $maxCachedLineDiffBytes (a diff of a large file
   takes tens of megabytes); the newest is kept even when it alone takes more *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache          = <| |>,
            Wolfram`Chatbook`ACP`Transcript`Private`$maxCachedLineDiffBytes = 3*^5
        },
        Module[ { text, cache, bytes, small, big },
            text  = StringRiffle[ Table[ "line " <> ToString[ i ] <> " of " <> ToString[ # ], { i, 500 } ], "\n" ] &;
            cache := Wolfram`Chatbook`ACP`Transcript`Private`$lineDiffCache;
            bytes := Total @ Lookup[ Values @ cache, "Bytes", 0 ];
            Do[ acpLineDiff[ text @ k, "q" ], { k, 10 } ];
            small = { Length @ cache, bytes <= 3*^5, Last @ Keys @ cache === { Hash @ text @ 10, Hash[ "q" ] } };
            big   = StringRiffle[ Table[ "big line " <> ToString[ i ], { i, 20000 } ], "\n" ];
            acpLineDiff[ big, "q" ];
            { small, Length @ cache, Keys @ cache === { { Hash @ big, Hash[ "q" ] } }, bytes > 3*^5 }
        ]
    ],
    { { n_Integer /; 1 < n < 10, True, True }, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-LineDiff-CacheBytes@@Tests/ACPTranscript.wlt:387,1-407,2"
]

(* Unchanged runs are collapsed to $diffContextLines lines of context in time proportional to the rows, with packed
   arrays (the earlier implementation, inlined here, was quadratic): the same rows, also with line numbers *)
VerificationTest[
    Module[ { oldCollapse, collapse, rows, tenth },
        oldCollapse[ ops_List, context_Integer ] := Module[ { changed, keep, out = { }, skipping = False },
            changed = Flatten @ Position[ ops, { "+" | "-", __ }, { 1 } ];
            If[ changed === { }, Return[ ops, Module ] ];
            keep = Union @ Flatten[ Range[ Max[ 1, # - context ], Min[ Length @ ops, # + context ] ] & /@ changed ];
            Do[
                If[ MemberQ[ keep, i ],
                    AppendTo[ out, ops[[ i ]] ]; skipping = False,
                    If[ ! skipping, AppendTo[ out, PadRight[ { "@", "\:22ef" }, Length @ ops[[ i ]], None ] ]; skipping = True ]
                ],
                { i, Length @ ops }
            ];
            out
        ];
        collapse = Wolfram`Chatbook`ACP`Rendering`Private`collapseContext;
        SeedRandom[ 99 ];
        rows = Table[ { RandomChoice[ { 8, 1, 1 } -> { "=", "+", "-" } ], ToString @ i }, { i, RandomInteger[ { 0, 60 } ] }, { 300 } ];
        {
            AllTrue[ rows, collapse[ #, 3 ] === oldCollapse[ #, 3 ] && collapse[ #, 0 ] === oldCollapse[ #, 0 ] & ],
            AllTrue[
                Wolfram`Chatbook`ACP`Rendering`Private`numberLineOps /@ Take[ rows, 50 ],
                collapse[ #, 3 ] === oldCollapse[ #, 3 ] &
            ],
            (* 200,000 rows, every other one or every tenth changed: about 0.1 s each (the quadratic implementations took
               seconds for 40,000 rows) *)
            First @ AbsoluteTiming @ collapse[ Table[ { If[ OddQ @ i, "+", "=" ], "l" }, { i, 200000 } ], 3 ] < 2,
            First @ AbsoluteTiming[ tenth = collapse[ Table[ { If[ Divisible[ i, 10 ], "+", "=" ], "l" }, { i, 200000 } ], 3 ] ] < 2,
            { Length @ tenth, Count[ tenth, { "@", _ } ], Count[ tenth, { "+", _ } ] }
        }
    ],
    { True, True, True, True, { 159997, 20000, 20000 } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-CollapseContext-Linear@@Tests/ACPTranscript.wlt:411,1-445,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Labels*)
VerificationTest[
    { acpLabel[ "WorkedFor", <| "time" -> "5s" |> ], acpLabel[ "Working" ], acpLabel[ "NoSuchACPLabelKey" ] },
    { "Worked for 5s", "Working", "NoSuchACPLabelKey" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-Defaults@@Tests/ACPTranscript.wlt:450,1-455,2"
]

VerificationTest[
    Block[ { $acpUIStrings = <| "ACPTestOnlyKey" -> "From UI table `x`" |> },
        { acpLabel[ "ACPTestOnlyKey" ], acpLabel[ "ACPTestOnlyKey", <| "x" -> 1 |> ] }
    ],
    { "From UI table `x`", "From UI table 1" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-UIStrings@@Tests/ACPTranscript.wlt:457,1-464,2"
]

VerificationTest[
    AllTrue[ Values @ $acpStrings, StringQ ] && DuplicateFreeQ @ Keys @ $acpStrings,
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-Table@@Tests/ACPTranscript.wlt:466,1-471,2"
]

VerificationTest[
    {
        (* Agents.wl's strings are the last fallback *)
        acpLabel[ "BillingOpenAI" ] === $acpConnectionStrings[ "BillingOpenAI" ],
        (* the toolbar no longer has an MCP indicator *)
        KeyExistsQ[ $acpStrings, "ToolbarMCPStarting" ],
        (* the three tables don't define a key twice *)
        DuplicateFreeQ @ Join[ Keys @ $acpStrings, Keys @ $acpUIStrings, Keys @ $acpConnectionStrings ]
    },
    { True, False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-Tables@@Tests/ACPTranscript.wlt:473,1-485,2"
]

(* With a front end, labels come from the "ChatbookStrings" text resources ("ACP" <> key), memoized; keys the front end
   doesn't know (or errors) fall back to the tables, and nothing is thrown. *)
VerificationTest[
    Module[ { calls = 0, resources, labels },
        resources = <| "ACPWorking" -> "Arbeitet", "ACPWorkedFor" -> "Gearbeitet: `time`" |>;
        Block[
            {
                Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = False,
                Wolfram`Chatbook`ACP`Transcript`Private`$labelCache          = <| |>,
                Wolfram`Chatbook`ACP`Transcript`Private`$templateCache       = <| |>,
                Wolfram`Chatbook`ACP`Transcript`Private`frontEndAvailableQ = True &,
                FrontEndResource = Function[ calls++; Switch[ #2, "ACPThinking", Message[ FrontEndResource::fake ]; $Failed, "ACPDoneNoReply", Throw[ "boom" ], _, Lookup[ resources, #2, $Failed ] ] ]
            },
            labels = {
                acpLabel[ "Working" ],
                acpLabel[ "WorkedFor", <| "time" -> "5s" |> ],
                acpLabel[ "Thinking" ],
                acpLabel[ "DoneNoReply" ],
                acpLabel[ "SubagentHeader", <| "title" -> "x" |> ]
            };
            (* memoized: no more front end calls *)
            labels = Append[ labels, { calls, acpLabel[ "Working" ], acpLabel[ "WorkedFor", <| "time" -> "6s" |> ], calls } ]
        ];
        labels
    ],
    { "Arbeitet", "Gearbeitet: 5s", "Thinking\[Ellipsis]", "Done.", "Subagent: x", { 5, "Arbeitet", "Gearbeitet: 6s", 5 } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-FrontEndResources@@Tests/ACPTranscript.wlt:489,1-515,2"
]

(* Every tool label group has the strings acpToolTitle needs *)
VerificationTest[
    Module[ { groups },
        groups = Union[
            Values @ Wolfram`Chatbook`ACP`Transcript`Private`$toolLabelGroups,
            Values @ Wolfram`Chatbook`ACP`Transcript`Private`$kindLabelGroups,
            { "Generic" }
        ];
        Select[ Flatten @ Outer[ "Tool" <> #1 <> #2 &, groups, { "Verb", "Pending", "Running", "Done" } ], ! KeyExistsQ[ $acpStrings, # ] & ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-ToolGroups@@Tests/ACPTranscript.wlt:518,1-530,2"
]

(* All literal acpLabel keys used in Transcript.wl and Rendering.wl have English defaults *)
VerificationTest[
    Complement[
        Union @ Flatten @ Map[
            StringCases[
                ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", # },
                "acpLabel[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" ~~ (" ]" | ",") :> key
            ] &,
            { "Transcript.wl", "Rendering.wl" }
        ],
        Keys @ $acpStrings
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Label-Coverage@@Tests/ACPTranscript.wlt:533,1-547,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Fixture Replays*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp5 A: MCP execute calls, image output, shell with permission*)
VerificationTest[
    turnA = acpReplay[ "exp5_A_mcp" ];
    { turnA[ "StopReason" ], Length @ acpKeysOfType[ turnA, "Tool" ], Length @ acpKeysOfType[ turnA, "Message" ], Length @ acpKeysOfType[ turnA, "Thought" ] },
    { "end_turn", 4, 5, 5 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Entities@@Tests/ACPTranscript.wlt:556,1-562,2"
]

VerificationTest[
    tool = acpToolByID[ turnA, "call_00_t0f4xkm2fzc7o94bv113pt4j" ];
    { tool[ "Name" ], tool[ "Status" ], tool[ "Version" ], acpToolTitle @ tool, acpToolSummary @ tool },
    { "execute", "completed", 3, "Used Wolfram Language Evaluator", "2 calls" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-ExecuteTitle-NoOpUpdatesIgnored@@Tests/ACPTranscript.wlt:564,1-570,2"
]

VerificationTest[
    acpExecuteToolCalls @ acpToolByID[ turnA, "call_00_t0f4xkm2fzc7o94bv113pt4j" ],
    {
        KeyValuePattern @ { "Tool" -> "Wolfram.WolframLanguageEvaluator", "Code" -> "2+2" },
        KeyValuePattern @ { "Tool" -> "Wolfram.WolframLanguageEvaluator", "Code" -> "Plot[Sin[x], {x, 0, 2 Pi}]" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-ExecuteScriptParsing@@Tests/ACPTranscript.wlt:572,1-580,2"
]

VerificationTest[
    acpToolByID[ turnA, "call_00_2yr2c8ismakyxzrfju41k3fq" ] // { acpExecuteToolCalls[ # ][[ All, "Code" ]], acpToolSummary @ # } &,
    { { "Head[Plot[Sin[x], {x, 0, 2 Pi}]]", "Export[\"/project/sin_plot.png\", Plot[Sin[x], {x, 0, 2 Pi}]]" }, "2 calls" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-ExecuteMetadataToolCalls@@Tests/ACPTranscript.wlt:582,1-587,2"
]

VerificationTest[
    (* while running, the MCP tool names come from the script *)
    Module[ { n = acpEventIndex[ "exp5_A_mcp", KeyValuePattern[ "Update" -> KeyValuePattern @ { "sessionUpdate" -> "tool_call_update", "status" -> "in_progress" } ] ], turn },
        turn = acpReplay[ "exp5_A_mcp", n ];
        { acpToolTitle @ acpToolByID[ turn, "call_00_t0f4xkm2fzc7o94bv113pt4j" ], acpTurnActivityLabel[ turn, $acpBaseTime + 2 ] }
    ],
    { "Using Wolfram Language Evaluator", "Using Wolfram Language Evaluator" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-ExecuteRunningTitle@@Tests/ACPTranscript.wlt:589,1-598,2"
]

VerificationTest[
    acpToolTitle @ acpToolByID[ acpReplay[ "exp5_A_mcp", acpEventIndex[ "exp5_A_mcp", KeyValuePattern[ "Update" -> KeyValuePattern[ "sessionUpdate" -> "tool_call" ] ] ] ], "call_00_t0f4xkm2fzc7o94bv113pt4j" ],
    "Preparing code\[Ellipsis]",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-PendingTitle@@Tests/ACPTranscript.wlt:600,1-605,2"
]

VerificationTest[
    shell = acpToolByID[ turnA, "call_00_1izfibafieznes01ey9efyqd" ];
    { shell[ "Name" ], shell[ "ExitCode" ], shell[ "Permission", "Outcome" ], acpToolTitle @ shell, acpToolSummary @ shell },
    { "shell", 0, "once", "Ran `cp /tmp/sin_plot.png /project/sin_plot.png && ls -l /project/sin_plot.png`", "1 line" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Shell@@Tests/ACPTranscript.wlt:607,1-613,2"
]

VerificationTest[
    split = acpTurnSplit @ turnA;
    { Length @ split[ "Answer" ], split[ "Tail" ], Length @ split[ "Work" ], StringStartsQ[ acpEntity[ turnA, First @ split[ "Answer" ] ][ "Text" ], "Here are the results" ] },
    { 1, { }, 13, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Split@@Tests/ACPTranscript.wlt:615,1-621,2"
]

VerificationTest[
    { turnA[ "WaitingSince" ], Round[ turnA[ "WaitingTime" ], 0.01 ], acpWorkedForLabel @ turnA, acpTurnStatusLine @ turnA },
    { None, 1.03, "Worked for 23s", None },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Labels@@Tests/ACPTranscript.wlt:623,1-628,2"
]

VerificationTest[
    turnA[ "Usage" ],
    KeyValuePattern @ { "inputTokens" -> 9853, "outputTokens" -> 815 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Usage@@Tests/ACPTranscript.wlt:630,1-635,2"
]

VerificationTest[
    turnA[ "ContextUsage" ],
    <| "Used" -> 10307, "Size" -> 200000, "Cost" -> <| "amount" -> 0, "currency" -> "USD" |> |>,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-ContextUsage@@Tests/ACPTranscript.wlt:637,1-642,2"
]

VerificationTest[
    acpTurnToMarkdown @ turnA,
    _String? (StringStartsQ[ #, "Here are the results:" ] && StringEndsQ[ #, "at a higher resolution?" ] &),
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5A-Markdown@@Tests/ACPTranscript.wlt:644,1-649,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp5 B: shell with permission, title tenses*)
VerificationTest[
    Module[ { name = "exp5_B_shell", id = "call_00_oi68fufuro1wrdqk244upop2", title },
        title[ patt_ ] := acpToolTitle @ acpToolByID[ acpReplay[ name, acpEventIndex[ name, patt ] ], id ];
        {
            title @ KeyValuePattern[ "Update" -> KeyValuePattern[ "sessionUpdate" -> "tool_call" ] ],
            title @ KeyValuePattern[ "Update" -> KeyValuePattern[ "status" -> "in_progress" ] ],
            title @ KeyValuePattern[ "Type" -> "PermissionRequest" ],
            acpToolTitle @ acpToolByID[ acpReplay @ name, id ]
        }
    ],
    {
        "Preparing a command\[Ellipsis]",
        "Running `echo hello && uname -s`",
        "Wants to run `echo hello && uname -s`",
        "Ran `echo hello && uname -s`"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5B-TitleTenses@@Tests/ACPTranscript.wlt:654,1-672,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp5_B_shell", acpEventIndex[ "exp5_B_shell", KeyValuePattern[ "Type" -> "PermissionRequest" ] ] ] },
        { turn[ "PendingPermissions" ], turn[ "WaitingSince" ], acpTurnActivityLabel[ turn, $acpBaseTime + 6 ] }
    ],
    { { 1 }, _Real, "Waiting for your approval" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5B-AwaitingApproval@@Tests/ACPTranscript.wlt:674,1-681,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp5_B_shell" ], tool },
        tool = acpToolByID[ turn, "call_00_oi68fufuro1wrdqk244upop2" ];
        { acpToolSummary @ tool, tool[ "Permission", "Outcome" ], tool[ "Permission", "Title" ], tool[ "Title" ], acpTurnSplit[ turn ][ "Tail" ] }
    ],
    { "2 lines", "once", "echo hello && uname -s", "echo hello && uname -s", { } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5B-Result@@Tests/ACPTranscript.wlt:683,1-691,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp5 C: writes with permission diffs, withdrawn request, exit code*)
VerificationTest[
    turnC = acpReplay[ "exp5_C_writes" ];
    main = acpToolByID[ turnC, "call_00_yrtqoymhaqurytxkbimvffbv" ];
    { main[ "Status" ], acpToolTitle @ main, acpToolSummary @ main, main[ "Diffs" ] },
    {
        "completed",
        "Created main.py",
        "+6",
        { KeyValuePattern @ { "Path" -> "/project/main.py", "OldText" -> None, "NewText" -> _String, "Source" -> "Permission", "Synthesized" -> False } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-DiffSurvivesCompletion-U1@@Tests/ACPTranscript.wlt:696,1-708,2"
]

VerificationTest[
    (* the completion text replaced the content, but not the diff: *)
    main[ "Content" ],
    { KeyValuePattern[ "content" -> KeyValuePattern[ "text" -> "Created file successfully: main.py" ] ] },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-ContentReplaced@@Tests/ACPTranscript.wlt:710,1-716,2"
]

VerificationTest[
    (* the permission's own title/status are not merged into the tool *)
    Module[ { turn = acpReplay[ "exp5_C_writes", acpEventIndex[ "exp5_C_writes", KeyValuePattern @ { "Type" -> "PermissionRequest", "RequestID" -> 2 } ] ], tool },
        tool = acpToolByID[ turn, "call_00_yrtqoymhaqurytxkbimvffbv" ];
        { tool[ "Status" ], tool[ "Title" ], tool[ "Permission", "Title" ], tool[ "Permission", "Outcome" ], acpToolTitle @ tool }
    ],
    { "in_progress", "write", "/project/main.py", None, "Wants to write main.py" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-PermissionTitleSeparate@@Tests/ACPTranscript.wlt:718,1-727,2"
]

VerificationTest[
    readme = acpToolByID[ turnC, "call_01_q68u8w1wktjsrcdkie6go91q" ];
    { readme[ "Permission", "Outcome" ], readme[ "ClientOutcome" ], readme[ "Status" ], acpToolTitle @ readme, turnC[ "PendingPermissions" ] },
    { "withdrawn", None, "completed", "Created README.md", { } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-WithdrawnThenAnswered@@Tests/ACPTranscript.wlt:729,1-735,2"
]

VerificationTest[
    testFile = acpToolByID[ turnC, "call_02_yzeo92fq08oj490x8g0ikbo6" ];
    { testFile[ "Permission" ], acpToolTitle @ testFile, acpToolSummary @ testFile, testFile[ "Diffs" ] },
    { None, "Wrote test_main.py", "+5", { KeyValuePattern @ { "Synthesized" -> True, "Write" -> True, "OldText" -> None } } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-SynthesizedWriteDiff@@Tests/ACPTranscript.wlt:737,1-743,2"
]

VerificationTest[
    pytest = acpToolByID[ turnC, "call_00_xkklgyu5x5fngwqzndo2olqe" ];
    { pytest[ "Status" ], pytest[ "ExitCode" ], acpToolSummary @ pytest, pytest[ "Permission", "Outcome" ] },
    { "completed", 1, "exit 1", "always" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-ExitCode@@Tests/ACPTranscript.wlt:745,1-751,2"
]

VerificationTest[
    Module[ { split = acpTurnSplit @ turnC },
        { Length @ split[ "Answer" ], split[ "Tail" ], StringContainsQ[ acpEntity[ turnC, First @ split[ "Answer" ] ][ "Text" ], "- [x] 1." ] }
    ],
    { 1, { }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-Split@@Tests/ACPTranscript.wlt:753,1-760,2"
]

VerificationTest[
    StringCount[ acpPreprocessAnswer @ acpTurnToMarkdown @ turnC, "\:2611" ],
    4,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-Checklist@@Tests/ACPTranscript.wlt:762,1-767,2"
]

VerificationTest[
    (* each message id produced one segment *)
    { Length @ acpKeysOfType[ turnC, "Message" ], DuplicateFreeQ @ turnC[ "Order" ] },
    { 4, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp5C-MessageSegments@@Tests/ACPTranscript.wlt:769,1-775,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp4b: rejected edits*)
VerificationTest[
    turnR1 = acpReplay[ "exp4b_turn1_reject" ];
    edit = acpToolByID[ turnR1, "call_e86fc73fd46e4384bd8e55ba" ];
    { turnR1[ "StopReason" ], turnR1[ "ClientCancel" ], edit[ "Status" ], edit[ "ClientOutcome" ], edit[ "Permission", "Outcome" ], acpToolTitle @ edit },
    { "cancelled", "Reject", "failed", "Declined", "reject", "Declined: edit hello.txt" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-Declined@@Tests/ACPTranscript.wlt:780,1-787,2"
]

VerificationTest[
    edit[ "Diffs" ],
    { KeyValuePattern @ { "Path" -> "/project/hello.txt", "OldText" -> "hi", "NewText" -> "hello world", "Synthesized" -> False } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-DeclinedDiffKept@@Tests/ACPTranscript.wlt:789,1-794,2"
]

VerificationTest[
    Module[ { split = acpTurnSplit @ turnR1 },
        { split[ "Answer" ], split[ "Tail" ], Length @ split[ "Work" ] }
    ],
    { { }, { { "Message", "msg_12295fa29001OKkO4A0Gta0R2z" }, { "Tool", "call_e86fc73fd46e4384bd8e55ba" } }, 3 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-TailForReject-U2@@Tests/ACPTranscript.wlt:796,1-803,2"
]

VerificationTest[
    { acpTurnStatusLine @ turnR1, acpWorkedForLabel @ turnR1 },
    { "You declined: edit hello.txt. Tell OpenCode what to do instead.", _String? (StringStartsQ[ "Worked for " ]) },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-StatusLine@@Tests/ACPTranscript.wlt:805,1-810,2"
]

VerificationTest[
    acpTurnToMarkdown @ turnR1,
    "Now editing it to say 'hello world':\n\n_Declined: edit hello.txt_\n\n_You declined: edit hello.txt. Tell OpenCode what to do instead._",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-Markdown@@Tests/ACPTranscript.wlt:812,1-817,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp4b_turn2_reject" ], read },
        read = acpToolByID[ turn, "call_ad7710f65e4343f5a8f77ef5" ];
        { acpToolTitle @ read, acpToolSummary @ read, acpTurnSplit[ turn ][ "Tail" ][[ All, 1 ]] }
    ],
    { "Read hello.txt", "1 line", { "Message", "Tool" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4b-Turn2@@Tests/ACPTranscript.wlt:819,1-827,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp4a: default permissions*)
VerificationTest[
    Module[ { turn = acpReplay[ "exp4a_default_perms" ] },
        {
            acpToolTitle @ acpToolByID[ turn, "call_00_okljsfr05vr146vfxlxhglkp" ],
            acpToolSummary @ acpToolByID[ turn, "call_00_okljsfr05vr146vfxlxhglkp" ],
            acpToolTitle @ acpToolByID[ turn, "call_00_djjnnn8wwiwjmvjip8re8rws" ],
            acpToolSummary @ acpToolByID[ turn, "call_01_ge2sr4vng11viervb6aaezfq" ],
            acpToolTitle @ acpToolByID[ turn, "call_01_ge2sr4vng11viervb6aaezfq" ]
        }
    ],
    { "Listed project", "1 entry", "Wrote hello.txt", "4 lines", "Ran `ls -la`" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp4a-DirectoryRead@@Tests/ACPTranscript.wlt:832,1-845,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp6: Stop*)
VerificationTest[
    turnS = acpReplay[ "exp6_stop_streaming" ];
    {
        turnS[ "StopReason" ],
        turnS[ "ClientCancel" ],
        acpTurnSplit @ turnS,
        StringEndsQ[ acpEntity[ turnS, First @ turnS[ "Order" ] ][ "Text" ], "Gutenberg's movable" ]
    },
    { "cancelled", "Stop", <| "Work" -> { }, "Answer" -> { { "Message", _ } }, "Tail" -> { } |>, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6-StopKeepsPartialAnswer-U2@@Tests/ACPTranscript.wlt:850,1-861,2"
]

VerificationTest[
    { acpWorkedForLabel @ turnS, acpTurnStatusLine @ turnS },
    { _String? (StringStartsQ[ "Stopped after " ]), _String? (StringStartsQ[ "Stopped by you after " ]) },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6-Labels@@Tests/ACPTranscript.wlt:863,1-868,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp6b_B_stop_permission" ], tool },
        tool = acpToolByID[ turn, "cc3cb7d2-5b7e-4b87-8780-a4a2a297b081" ];
        { tool[ "Status" ], tool[ "ClientOutcome" ], tool[ "Permission", "Outcome" ], acpToolTitle @ tool, turn[ "PendingPermissions" ], acpTurnSplit[ turn ][ "Tail" ][[ All, 1 ]] }
    ],
    { "failed", "Stopped", "cancelled", "Stopped: run `echo cancel-test`", { }, { "Message", "Tool" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6b-StopWithPendingPermission@@Tests/ACPTranscript.wlt:870,1-878,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp6b_C_stop_running" ], tool },
        tool = acpToolByID[ turn, "18200bef-2242-40de-bab4-e0bf76dd7aad" ];
        { tool[ "Status" ], tool[ "ClientOutcome" ], acpToolTitle @ tool, acpToolSummary @ tool, acpTurnSplit[ turn ] }
    ],
    { "failed", "Stopped", "Stopped: run `sleep 30 && echo done`", "", <| "Work" -> { }, "Answer" -> { }, "Tail" -> { { "Tool", _ } } |> },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6b-StopRunningTool@@Tests/ACPTranscript.wlt:880,1-888,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp6b_C_stop_running", acpEventIndex[ "exp6b_C_stop_running", KeyValuePattern[ "Type" -> "ClientCancel" ] ] ] },
        { acpToolByID[ turn, "18200bef-2242-40de-bab4-e0bf76dd7aad" ][ "ClientOutcome" ], acpTurnActivityLabel[ turn, $acpBaseTime + 6 ] }
    ],
    { "Stopped", "Stopping\[Ellipsis]" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6b-StopMarksUnfinishedTools@@Tests/ACPTranscript.wlt:890,1-897,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp6b_D_after" ] },
        { acpToolTitle @ acpToolByID[ turn, "7a1d9c0c-551d-4117-83b4-6fc0ba5bee23" ], acpTurnToMarkdown @ turn }
    ],
    { "Ran `echo after-cancel`", "The output is:\nafter-cancel" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp6b-AfterCancel@@Tests/ACPTranscript.wlt:899,1-906,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp7: plan mode reject*)
VerificationTest[
    Module[ { turn = acpReplay[ "exp7_plan_reject" ] },
        { acpToolSummary @ acpToolByID[ turn, "call_00_hseahh3aip0g1jaaafvd4c8j" ], turn[ "ClientCancel" ], acpTurnSplit[ turn ][ "Tail" ] }
    ],
    { "0 entries", "Reject", { { "Tool", "call_00_xpv27hd4llvlpuo8gx1i0oxb" } } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp7-PlanReject@@Tests/ACPTranscript.wlt:911,1-918,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp2: retries and thought-only turns*)
VerificationTest[
    turnRetry = acpReplay[ "exp2_retries" ];
    notice = acpEntity[ turnRetry, { "Notice", 1 } ];
    { notice[ "Kind" ], notice[ "Data", "FirstAttempt" ], notice[ "Data", "LastAttempt" ], notice[ "Data", "Active" ], notice[ "Data", "ErrorType" ], turnRetry[ "RetryInfo" ], turnRetry[ "RetryEpisode" ] },
    { "Retry", 2, 7, False, "provider.rate-limit", None, None },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-RetryNotice@@Tests/ACPTranscript.wlt:923,1-930,2"
]

VerificationTest[
    Round[ notice[ "Data", "EndTime" ] - notice[ "Data", "StartTime" ] ],
    47,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-RetryDuration@@Tests/ACPTranscript.wlt:932,1-937,2"
]

VerificationTest[
    Module[ { turn, next },
        turn = acpReplay[ "exp2_retries", 1 ];
        next = turn[ "RetryInfo", "NextRetryAt" ];
        { turn[ "RetryInfo", "Attempt" ], NumberQ @ next, acpTurnActivityLabel[ turn, next - 7 ], acpTurnActivityLabel[ turn, next + 1 ] }
    ],
    { 2, True, "Retrying in 7s (rate limited, attempt 2)", "Retrying (attempt 2)\[Ellipsis]" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-RetryActivityLabel@@Tests/ACPTranscript.wlt:939,1-948,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp2_retries", 2 ] },
        { turn[ "RetryInfo" ], acpEntity[ turn, { "Notice", 1 } ][ "Data", "Active" ] }
    ],
    { None, False },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-RetryCleared@@Tests/ACPTranscript.wlt:950,1-957,2"
]

VerificationTest[
    { acpTurnSplit[ turnRetry ][ "Work" ][[ All, 1 ]], acpWorkedForLabel @ turnRetry },
    { { "Notice", "Thought" }, "Worked for 48s" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-RetryWork@@Tests/ACPTranscript.wlt:959,1-964,2"
]

VerificationTest[
    Module[ { turn = acpReplay[ "exp2_thought_only" ] },
        { acpTurnSplit[ turn ][ "Work" ][[ All, 1 ]], acpTurnToMarkdown @ turn }
    ],
    { { "Thought" }, "Hello! How can I help you today?" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp2-ThoughtOnly@@Tests/ACPTranscript.wlt:966,1-973,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*exp3: prompt error*)
VerificationTest[
    Module[ { turn = acpReplay[ "exp3_error" ] },
        {
            acpTurnEndedQ @ turn,
            turn[ "StopReason" ],
            turn[ "Error" ],
            acpWorkedForLabel @ turn,
            acpTurnStatusLine @ turn,
            acpTurnToMarkdown @ turn
        }
    ],
    {
        True,
        None,
        KeyValuePattern @ { "Code" -> -32603, "Message" -> "Internal error: Model exo-free has been deprecated." },
        _String? (StringStartsQ[ "Failed after " ]),
        "Failed: Internal error: Model exo-free has been deprecated.",
        "_Failed: Internal error: Model exo-free has been deprecated._"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-exp3-Error@@Tests/ACPTranscript.wlt:978,1-999,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Split Rule For Every Stop Reason*)
VerificationTest[
    msgToolMsg = acpApplyAll[
        acpFreshTurn[ ],
        {
            acpChunk[ "m1", "Let me look." ],
            acpToolCall[ "t1", "read", "rawInput" -> <| "path" -> "/project/a.txt" |> ],
            acpToolUpdate[ "t1", "status" -> "completed", "content" -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "Read file a.txt, lines 1-3\n1: a\n2: b\n3: c" |> |> } ],
            acpChunk[ "m2", "Final answer." ]
        }
    ];
    Table[
        With[ { turn = acpApplyTurnEnd[ msgToolMsg, <| "StopReason" -> reason |>, 1010. ][ "Turn" ] },
            { reason, acpTurnSplit @ turn, acpTurnStatusLine @ turn }
        ],
        { reason, { "end_turn", "max_tokens", "max_turn_requests", "refusal", "cancelled", "something_else" } }
    ],
    {
        { "end_turn"         , <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, None },
        { "max_tokens"       , <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, "Response cut off (max tokens)." },
        { "max_turn_requests", <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, "Stopped: step limit reached." },
        { "refusal"          , <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, "OpenCode refused to continue." },
        { "cancelled"        , <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, _String? (StringStartsQ[ "Cancelled after " ]) },
        { "something_else"   , <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { { "Message", "m2" } }, "Tail" -> { } |>, "Stopped (something_else)." }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-AllStopReasons-WithAnswer@@Tests/ACPTranscript.wlt:1004,1-1030,2"
]

VerificationTest[
    msgTool = Most @ msgToolMsg[ "Order" ] // Function[ keys, <| msgToolMsg, "Order" -> keys |> ];
    Table[
        acpTurnSplit @ acpApplyTurnEnd[ msgTool, <| "StopReason" -> reason |>, 1010. ][ "Turn" ],
        { reason, { "end_turn", "max_tokens", "cancelled" } }
    ],
    {
        <| "Work" -> { { "Message", "m1" }, { "Tool", "t1" } }, "Answer" -> { }, "Tail" -> { } |>,
        <| "Work" -> { }, "Answer" -> { }, "Tail" -> { { "Message", "m1" }, { "Tool", "t1" } } |>,
        <| "Work" -> { }, "Answer" -> { }, "Tail" -> { { "Message", "m1" }, { "Tool", "t1" } } |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-AllStopReasons-NoAnswer@@Tests/ACPTranscript.wlt:1032,1-1045,2"
]

VerificationTest[
    acpTurnToMarkdown @ acpApplyTurnEnd[ msgTool, <| "StopReason" -> "end_turn" |>, 1010. ][ "Turn" ],
    "Done.",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-EmptyAnswerDone@@Tests/ACPTranscript.wlt:1047,1-1052,2"
]

VerificationTest[
    acpTurnSplit @ acpApplyTurnEnd[ msgTool, <| "Error" -> <| "Code" -> -32000, "Message" -> "auth required" |> |>, 1010. ][ "Turn" ],
    <| "Work" -> { }, "Answer" -> { }, "Tail" -> { { "Message", "m1" }, { "Tool", "t1" } } |>,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-Error@@Tests/ACPTranscript.wlt:1054,1-1059,2"
]

(* A cancelled turn whose last step ran several tools without any text in between: only the tools from the first one that
   didn't complete normally belong to the expanded tail; the completed ones stay in the "Worked for" opener. *)
VerificationTest[
    turnCT = acpReplay[ "synthetic_cancelled_tools" ];
    { turnCT[ "StopReason" ], turnCT[ "ClientCancel" ], acpTurnSplit @ turnCT },
    {
        "cancelled",
        "Reject",
        <|
            "Work"   -> { { "Message", "msg_look_1" }, { "Tool", "call_read_1" }, { "Tool", "call_glob_1" }, { "Tool", "call_grep_1" } },
            "Answer" -> { },
            "Tail"   -> { { "Tool", "call_edit_1" } }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-CompletedToolsThenDeclined@@Tests/ACPTranscript.wlt:1063,1-1077,2"
]

VerificationTest[
    {
        acpTurnStatusLine @ turnCT,
        acpTurnToMarkdown @ turnCT
    },
    {
        "You declined: edit notes.md. Tell OpenCode what to do instead.",
        "_Declined: edit notes.md_\n\n_You declined: edit notes.md. Tell OpenCode what to do instead._"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-CompletedToolsThenDeclined-Text@@Tests/ACPTranscript.wlt:1079,1-1090,2"
]

(* The same without the "Let me look around first." message, and with the message right before the declined tool: *)
VerificationTest[
    Module[ { tools, declined, run },
        tools = Flatten @ Table[
            { acpToolCall[ id, "glob", "rawInput" -> <| "pattern" -> "*" <> id |> ], acpToolUpdate[ id, "status" -> "completed" ] },
            { id, { "t1", "t2", "t3" } }
        ];
        declined = { acpToolCall[ "t4", "edit", "rawInput" -> <| "path" -> "/project/a.txt", "oldString" -> "a", "newString" -> "b" |> ] };
        run[ updates_ ] := Module[ { turn = acpApplyAll[ acpFreshTurn[ ], updates ] },
            turn = acpApplyPermissionRequest[ turn, 1, <| "toolCall" -> <| "toolCallId" -> "t4" |>, "options" -> { <| "optionId" -> "reject", "kind" -> "reject_once" |> } |>, 1100. ][ "Turn" ];
            turn = acpApplyPermissionOutcome[ turn, 1, "reject", 1101. ][ "Turn" ];
            turn = acpApplyUpdate[ turn, acpToolUpdate[ "t4", "status" -> "failed", "rawOutput" -> <| "error" -> "The user declined this tool call" |> ], 1102. ][ "Turn" ];
            KeyTake[ acpTurnSplit @ acpApplyTurnEnd[ turn, <| "StopReason" -> "cancelled" |>, 1103. ][ "Turn" ], { "Work", "Tail" } ]
        ];
        {
            run @ Join[ tools, declined ],
            run @ Join[ tools, { acpChunk[ "m1", "Now editing:" ] }, declined ]
        }
    ],
    {
        <| "Work" -> { { "Tool", "t1" }, { "Tool", "t2" }, { "Tool", "t3" } }, "Tail" -> { { "Tool", "t4" } } |>,
        <| "Work" -> { { "Tool", "t1" }, { "Tool", "t2" }, { "Tool", "t3" } }, "Tail" -> { { "Message", "m1" }, { "Tool", "t4" } } |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-TailStartsAtFirstUnfinishedTool@@Tests/ACPTranscript.wlt:1093,1-1117,2"
]

(* Stopped after several completed tools: only the last one is shown expanded *)
VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            Flatten @ Table[ { acpToolCall[ id, "read", "rawInput" -> <| "path" -> "/project/" <> id |> ], acpToolUpdate[ id, "status" -> "completed" ] }, { id, { "t1", "t2", "t3" } } ]
        ];
        turn = acpApplyClientCancel[ turn, "Stop", 1010. ][ "Turn" ];
        KeyTake[ acpTurnSplit @ acpApplyTurnEnd[ turn, <| "StopReason" -> "cancelled" |>, 1011. ][ "Turn" ], { "Work", "Tail" } ]
    ],
    <| "Work" -> { { "Tool", "t1" }, { "Tool", "t2" } }, "Tail" -> { { "Tool", "t3" } } |>,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Split-AllToolsCompleted-LastToolOnly@@Tests/ACPTranscript.wlt:1120,1-1132,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Reducer Robustness (U12, U13)*)
VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpChunk[ "m1", "A" ], acpToolCall[ "t1", "glob" ], acpChunk[ "m1", "B" ] } ];
        { turn[ "Order" ], acpEntity[ turn, { "Message", "m1" } ][ "Text" ], acpEntity[ turn, { "Message", "m1#2" } ][ "Text" ], acpTurnSplit[ acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, 1010. ][ "Turn" ] ][ "Answer" ] }
    ],
    { { { "Message", "m1" }, { "Tool", "t1" }, { "Message", "m1#2" } }, "A", "B", { { "Message", "m1#2" } } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-InterleavedSegments@@Tests/ACPTranscript.wlt:1137,1-1145,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpThought[ "msg_1:reasoning:0", "think" ], acpChunk[ "msg_1", "text" ], acpThought[ "msg_1:reasoning:0", " more" ] } ];
        turn[ "Order" ]
    ],
    { { "Thought", "msg_1:reasoning:0" }, { "Message", "msg_1" }, { "Thought", "msg_1:reasoning:0#2" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-ListKeysWithColons@@Tests/ACPTranscript.wlt:1147,1-1155,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpUpdate[ "agent_message_chunk", "content" -> <| "type" -> "text", "text" -> "a" |> ], acpUpdate[ "agent_message_chunk", "content" -> <| "type" -> "text", "text" -> "b" |> ] } ];
        { turn[ "Order" ], acpEntity[ turn, First @ turn[ "Order" ] ][ "Text" ] }
    ],
    { { { "Message", "segment#1" } }, "ab" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-ChunksWithoutMessageID@@Tests/ACPTranscript.wlt:1157,1-1165,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "t1", "shell", "rawInput" -> <| "command" -> "ls" |> ],
                acpToolUpdate[ "t1", "status" -> "completed" ],
                acpToolCall[ "t1", "shell", "rawInput" -> <| "command" -> "pwd" |> ]
            }
        ];
        { turn[ "Order" ], acpToolTitle @ acpEntity[ turn, { "Tool", "t1" } ], acpToolTitle @ acpEntity[ turn, { "Tool", "t1", 2 } ] }
    ],
    { { { "Tool", "t1" }, { "Tool", "t1", 2 } }, "Ran `ls`", "Preparing a command\[Ellipsis]" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-TerminalIDReuse@@Tests/ACPTranscript.wlt:1167,1-1182,2"
]

VerificationTest[
    Module[ { turn, update, r1, r2 },
        turn   = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "shell" ] } ];
        update = acpToolUpdate[ "t1", "status" -> "in_progress", "title" -> "ls", "rawInput" -> <| "command" -> "ls" |> ];
        r1 = acpApplyUpdate[ turn, update, 1010. ];
        r2 = acpApplyUpdate[ r1[ "Turn" ], update, 1011. ];
        { r1[ "Changed" ], r2[ "Changed" ], r2[ "Layout" ], r2[ "Turn", "Version" ] === r1[ "Turn", "Version" ], r2[ "Turn", "Entities", { "Tool", "t1" }, "Version" ], r2[ "Turn", "LastEventTime" ] }
    ],
    { { { "Tool", "t1" } }, { }, False, True, 2, 1011. },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-NoOpUpdateNoVersionBump@@Tests/ACPTranscript.wlt:1184,1-1195,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolUpdate[ "ghost", "status" -> "in_progress", "kind" -> "read", "title" -> "Read notes.md" ] } ];
        { turn[ "Order" ], acpEntity[ turn, { "Tool", "ghost" } ][ "Status" ], acpToolTitle @ acpEntity[ turn, { "Tool", "ghost" } ] }
    ],
    { { { "Tool", "ghost" } }, "in_progress", "Read notes.md" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-UpdateForUnseenTool@@Tests/ACPTranscript.wlt:1197,1-1205,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "t1", "read", "rawInput" -> <| "path" -> "/project/notes.md" |> ],
                acpToolUpdate[ "t1", "title" -> "/project/notes.md" ],
                acpToolUpdate[ "t1", "title" -> "read", "rawInput" -> Null, "name" -> Null ]
            }
        ];
        { acpEntity[ turn, { "Tool", "t1" } ][ "Title" ], acpEntity[ turn, { "Tool", "t1" } ][ "RawInput" ], acpEntity[ turn, { "Tool", "t1" } ][ "Name" ] }
    ],
    { "/project/notes.md", <| "path" -> "/project/notes.md" |>, "read" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-NeverDowngradeTitle-NullUnchanged@@Tests/ACPTranscript.wlt:1207,1-1222,2"
]

VerificationTest[
    Module[ { turn, diff },
        diff = <| "type" -> "diff", "path" -> "/project/a.txt", "oldText" -> "x", "newText" -> "y" |>;
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "t1", "edit" ],
                acpToolUpdate[ "t1", "content" -> { diff } ],
                acpToolUpdate[ "t1", "status" -> "completed", "content" -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "Edited a.txt" |> |>, diff } ]
            }
        ];
        { Length @ acpEntity[ turn, { "Tool", "t1" } ][ "Diffs" ], Length @ acpEntity[ turn, { "Tool", "t1" } ][ "Content" ] }
    ],
    { 1, 2 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-DiffsAccumulateWithoutDuplicates@@Tests/ACPTranscript.wlt:1224,1-1240,2"
]

VerificationTest[
    Module[ { turn, tool },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "p1", "apply_patch", "rawInput" -> <| "patchText" -> "..." |> ],
                acpToolUpdate[
                    "p1",
                    "status" -> "completed",
                    "rawOutput" -> <| "metadata" -> <| "files" -> { <| "file" -> "src/a.py", "patch" -> "@@ -1,2 +1,2 @@\n-old\n+new\n same", "additions" -> 1, "deletions" -> 1 |> } |> |>
                ]
            }
        ];
        tool = acpEntity[ turn, { "Tool", "p1" } ];
        { tool[ "Name" ], tool[ "Diffs" ], acpToolSummary @ tool, acpToolTitle @ tool }
    ],
    { "patch", { KeyValuePattern @ { "Path" -> "src/a.py", "Patch" -> _String, "Source" -> "Metadata" } }, "+1 \[Minus]1", _String },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-PatchMetadataDiffs@@Tests/ACPTranscript.wlt:1242,1-1261,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*One diff per file (OpenCode completions carry both a full-text diff and a metadata patch)*)
VerificationTest[
    $diffPatchText = "*** Begin Patch\n*** Update File: main.py\n@@\n-print('hi')\n+print('hello')\n*** End Patch";
    $diffMainPy    = <| "type" -> "diff", "path" -> "/project/main.py", "oldText" -> "print('hi')\n", "newText" -> "print('hello')\n" |>;
    $diffMainPyMetadata = <| "metadata" -> <| "files" -> { <|
        "file" -> "main.py", "patch" -> "Index: main.py\n===================================================================\n--- main.py\n+++ main.py\n@@ -1,1 +1,1 @@\n-print('hi')\n+print('hello')\n",
        "additions" -> 1, "deletions" -> 1, "status" -> "modified"
    |> } |> |>;
    (* An apply_patch that was not asked about (e.g. after "Always allow"): the completion has both shapes *)
    Module[ { turn, tool },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "p1", "apply_patch", "kind" -> "edit", "rawInput" -> <| |> ],
                acpToolUpdate[ "p1", "status" -> "in_progress", "rawInput" -> <| "patchText" -> $diffPatchText |>, "locations" -> { <| "path" -> "/project/main.py" |> } ],
                acpToolUpdate[
                    "p1",
                    "status"    -> "completed",
                    "locations" -> { <| "path" -> "/project/main.py" |> },
                    "content"   -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "Success. Updated the following files:\nM main.py" |> |>, $diffMainPy },
                    "rawOutput" -> $diffMainPyMetadata
                ]
            }
        ];
        tool = acpEntity[ turn, { "Tool", "p1" } ];
        { Length @ tool[ "Diffs" ], First[ tool[ "Diffs" ] ][ "Source" ], acpToolSummary @ tool }
    ],
    { 1, "Update", "+1 \[Minus]1" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-OneDiffPerFile-UnaskedPatch@@Tests/ACPTranscript.wlt:1266,1-1295,2"
]

VerificationTest[
    (* An edit that was not asked about, in the live wire shape (probe/out3.txt) *)
    Module[ { turn, tool },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "e1", "edit", "kind" -> "edit", "locations" -> { }, "rawInput" -> <| |> ],
                acpToolUpdate[ "e1", "status" -> "in_progress", "kind" -> "edit", "title" -> "edit", "locations" -> { <| "path" -> "/project/hello.txt" |> },
                    "rawInput" -> <| "path" -> "/project/hello.txt", "oldString" -> "hi there", "newString" -> "hi world" |> ],
                acpToolUpdate[
                    "e1",
                    "status"    -> "completed",
                    "locations" -> { <| "path" -> "/project/hello.txt" |> },
                    "content"   -> {
                        <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "Edited hello.txt (1 replacement)" |> |>,
                        <| "type" -> "diff", "path" -> "/project/hello.txt", "oldText" -> "hi there\n", "newText" -> "hi world\n" |>
                    },
                    "rawOutput" -> <| "metadata" -> <| "files" -> { <|
                        "file" -> "hello.txt", "patch" -> "Index: hello.txt\n===================================================================\n--- hello.txt\n+++ hello.txt\n@@ -1,1 +1,1 @@\n-hi there\n+hi world\n",
                        "status" -> "modified", "additions" -> 1, "deletions" -> 1
                    |> }, "truncated" -> False |> |>
                ]
            }
        ];
        tool = acpEntity[ turn, { "Tool", "e1" } ];
        { Length @ tool[ "Diffs" ], First[ tool[ "Diffs" ] ][ "Source" ], acpToolSummary @ tool }
    ],
    { 1, "Update", "+1 \[Minus]1" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-OneDiffPerFile-UnaskedEdit@@Tests/ACPTranscript.wlt:1297,1-1327,2"
]

VerificationTest[
    (* An edit that was asked about whose file differs from the preview after the write (e.g. a formatter ran): the
       completed diff replaces the preview; an identical one leaves the preview *)
    Module[ { params, run },
        params = <|
            "sessionId" -> "s",
            "toolCall"  -> <| "toolCallId" -> "e1", "title" -> "/project/hello.txt", "status" -> "pending", "kind" -> "edit", "name" -> "edit",
                "content" -> { <| "type" -> "diff", "path" -> "/project/hello.txt", "oldText" -> "hi there\n", "newText" -> "hi world\n" |> } |>,
            "options"   -> { <| "optionId" -> "once", "kind" -> "allow_once", "name" -> "Allow once" |> }
        |>;
        run[ newText_ ] := Module[ { turn },
            turn = acpApplyAll[
                acpFreshTurn[ ],
                {
                    acpToolCall[ "e1", "edit", "kind" -> "edit", "rawInput" -> <| |> ],
                    acpToolUpdate[ "e1", "status" -> "in_progress", "rawInput" -> <| "path" -> "/project/hello.txt", "oldString" -> "hi there", "newString" -> "hi world" |> ]
                }
            ];
            turn = acpApplyPermissionRequest[ turn, 7, params, 1010. ][ "Turn" ];
            turn = acpApplyPermissionOutcome[ turn, 7, "once", 1011. ][ "Turn" ];
            turn = acpApplyUpdate[
                turn,
                acpToolUpdate[ "e1", "status" -> "completed", "content" -> { <| "type" -> "diff", "path" -> "/project/hello.txt", "oldText" -> "hi there\n", "newText" -> newText |> } ],
                1012.
            ][ "Turn" ];
            With[ { tool = acpEntity[ turn, { "Tool", "e1" } ] }, { Lookup[ tool[ "Diffs" ], "Source" ], acpToolSummary @ tool } ]
        ];
        { run[ "hi world  \n" ], run[ "hi world\n" ] }
    ],
    { { { "Update" }, "+1 \[Minus]1" }, { { "Permission" }, "+1 \[Minus]1" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-OneDiffPerFile-AskedEditChangedByFormatter@@Tests/ACPTranscript.wlt:1329,1-1361,2"
]

VerificationTest[
    (* rawOutput (metadata patch) in an earlier update than the full-text content diff *)
    Module[ { turn, tool },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "p2", "apply_patch", "kind" -> "edit", "rawInput" -> <| "patchText" -> $diffPatchText |> ],
                acpToolUpdate[ "p2", "rawOutput" -> $diffMainPyMetadata ],
                acpToolUpdate[ "p2", "status" -> "completed", "content" -> { $diffMainPy } ]
            }
        ];
        tool = acpEntity[ turn, { "Tool", "p2" } ];
        { Length @ tool[ "Diffs" ], First[ tool[ "Diffs" ] ][ "Source" ], acpToolSummary @ tool }
    ],
    { 1, "Update", "+1 \[Minus]1" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-OneDiffPerFile-MetadataFirst@@Tests/ACPTranscript.wlt:1363,1-1380,2"
]

VerificationTest[
    Module[ { turn, res },
        turn = acpFreshTurn[ ];
        res = acpApplyUpdate[ turn, acpUpdate[ "some_future_update", "x" -> 1 ], 1001. ];
        { res[ "Changed" ], res[ "Layout" ], KeyDrop[ res[ "Turn" ], { "LastEventTime", "FirstEventTime" } ] === KeyDrop[ turn, { "LastEventTime", "FirstEventTime" } ] }
    ],
    { { }, False, True },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U12-UnknownUpdateIgnored@@Tests/ACPTranscript.wlt:1382,1-1391,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpUpdate[ "plan", "entries" -> { <| "content" -> "Step 1", "status" -> "in_progress", "priority" -> "high" |> } ],
                acpUpdate[ "plan", "entries" -> { <| "content" -> "Step 1", "status" -> "completed", "priority" -> "high" |>, <| "content" -> "Step 2", "status" -> "pending", "priority" -> "low" |> } ]
            }
        ];
        { turn[ "Order" ], Length @ acpEntity[ turn, { "Plan" } ][ "Entries" ], acpEntity[ turn, { "Plan" } ][ "Version" ] }
    ],
    { { { "Plan" } }, 2, 2 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Plan@@Tests/ACPTranscript.wlt:1393,1-1407,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpUpdate[ "session_info_update", "_meta" -> <| "opencode/compaction" -> <| "status" -> "started", "messageId" -> "c1", "reason" -> "manual" |> |> ],
                acpUpdate[ "session_info_update", "_meta" -> <| "opencode/compaction" -> <| "status" -> "completed", "messageId" -> "c1", "reason" -> "manual" |> |> ]
            }
        ];
        { turn[ "Order" ], acpEntity[ turn, { "Notice", 1 } ][ "Kind" ], acpEntity[ turn, { "Notice", 1 } ][ "Data", "Status" ] }
    ],
    { { { "Notice", 1 } }, "Compaction", "completed" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-CompactionNotice@@Tests/ACPTranscript.wlt:1409,1-1423,2"
]

VerificationTest[
    Module[ { child, turn, ended },
        child = <| "opencode/child-session" -> <| "id" -> "ses_child", "parentID" -> "ses_parent", "depth" -> 1, "title" -> "Explore repo" |> |>;
        turn = acpApplyAll[
            acpFreshTurn[ ],
            {
                acpToolCall[ "task1", "task", "rawInput" -> <| "description" -> "Explore repo", "prompt" -> "Look around" |> ],
                Append[ acpChunk[ "cm1", "child text" ], "_meta" -> child ],
                Append[ acpToolCall[ "ses_child:c1", "read", "rawInput" -> <| "path" -> "/project/x" |> ], "_meta" -> child ],
                acpToolUpdate[ "task1", "status" -> "completed" ],
                acpChunk[ "m2", "Parent answer" ]
            }
        ];
        ended = acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, 1010. ][ "Turn" ];
        {
            acpEntity[ turn, { "Message", "cm1" } ][ "Child" ],
            acpEntity[ turn, { "Tool", "ses_child:c1" } ][ "Child", "ID" ],
            acpToolTitle @ acpEntity[ turn, { "Tool", "task1" } ],
            acpTurnSplit[ ended ][ "Answer" ]
        }
    ],
    { KeyValuePattern @ { "ID" -> "ses_child", "ParentID" -> "ses_parent", "Title" -> "Explore repo", "Depth" -> 1 }, "ses_child", "Subagent: Explore repo", { { "Message", "m2" } } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U13-ChildSessions@@Tests/ACPTranscript.wlt:1425,1-1449,2"
]

VerificationTest[
    Module[ { child, turn },
        child = <| "opencode/child-session" -> <| "id" -> "ses_child", "depth" -> 1 |> |>;
        turn = acpApplyAll[ acpFreshTurn[ ], { acpChunk[ "m1", "parent" ], Append[ acpChunk[ "cm", "child" ], "_meta" -> child ] } ];
        acpTurnSplit[ acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, 1010. ][ "Turn" ] ][ "Answer" ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-U13-ChildEndsTrailingMessages@@Tests/ACPTranscript.wlt:1451,1-1460,2"
]

VerificationTest[
    Module[ { res },
        res = acpApplyNotice[ acpFreshTurn[ ], <| "Kind" -> "Info", "Text" -> "A background subagent asked for permission; it was cancelled." |>, 1001. ];
        { res[ "Changed" ], res[ "Layout" ], res[ "Turn", "Entities", { "Notice", 1 } ] }
    ],
    { { { "Notice", 1 } }, True, KeyValuePattern @ { "Type" -> "Notice", "Kind" -> "Info", "Text" -> _String, "Version" -> 1 } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ApplyNotice@@Tests/ACPTranscript.wlt:1462,1-1470,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpUpdate[ "agent_message_chunk", "messageId" -> "m1", "content" -> <| "type" -> "image", "mimeType" -> "image/png", "data" -> "AAAA" |> ] } ];
        { acpEntity[ turn, { "Message", "m1" } ][ "Text" ], acpEntity[ turn, { "Message", "m1" } ][ "Blocks" ] }
    ],
    { "", { KeyValuePattern[ "type" -> "image" ] } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-NonTextBlocks@@Tests/ACPTranscript.wlt:1472,1-1480,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Permissions*)
VerificationTest[
    Module[ { turn, params, res },
        params = <|
            "sessionId" -> "s",
            "toolCall"  -> <| "toolCallId" -> "per_123", "title" -> "/tmp/outside", "kind" -> "other", "locations" -> { <| "path" -> "/tmp/outside" |> } |>,
            "options"   -> { <| "optionId" -> "once", "kind" -> "allow_once", "name" -> "Allow once" |>, <| "optionId" -> "reject", "kind" -> "reject_once", "name" -> "Reject" |> }
        |>;
        res  = acpApplyPermissionRequest[ acpFreshTurn[ ], 7, params, 1001. ];
        turn = res[ "Turn" ];
        {
            res[ "Layout" ],
            turn[ "Order" ],
            acpToolTitle @ acpEntity[ turn, { "Permission", 7 } ],
            turn[ "PendingPermissions" ],
            acpApplyPermissionOutcome[ turn, 7, "once", 1004. ][ "Turn", "Entities", { "Permission", 7 }, "Outcome" ],
            acpApplyPermissionOutcome[ turn, 7, "once", 1004. ][ "Turn", "WaitingTime" ]
        }
    ],
    { True, { { "Permission", 7 } }, "Access outside the project: /tmp/outside", { 7 }, "once", 3. },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Permission-Standalone@@Tests/ACPTranscript.wlt:1485,1-1506,2"
]

VerificationTest[
    Module[ { turn, options, outcome },
        options = {
            <| "optionId" -> "a1", "kind" -> "allow_once" |>,
            <| "optionId" -> "a2", "kind" -> "allow_always" |>,
            <| "optionId" -> "r1", "kind" -> "reject_once" |>
        };
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "shell", "rawInput" -> <| "command" -> "ls" |> ] } ];
        turn = acpApplyPermissionRequest[ turn, 1, <| "toolCall" -> <| "toolCallId" -> "t1" |>, "options" -> options |>, 1002. ][ "Turn" ];
        outcome[ option_ ] := With[ { t = acpApplyPermissionOutcome[ turn, 1, option, 1003. ][ "Turn" ] },
            { t[ "Entities", { "Tool", "t1" }, "Permission", "Outcome" ], t[ "Entities", { "Tool", "t1" }, "ClientOutcome" ], t[ "ClientCancel" ] }
        ];
        outcome /@ { "a1", "a2", "r1", None, "allow_always" }
    ],
    {
        { "once", None, None },
        { "always", None, None },
        { "reject", "Declined", "Reject" },
        { "cancelled", None, None },
        { "always", None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Permission-OutcomeNormalization@@Tests/ACPTranscript.wlt:1508,1-1531,2"
]

VerificationTest[
    Module[ { turn, withdrawn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "write", "rawInput" -> <| "path" -> "/project/r.md", "content" -> "x" |> ] } ];
        turn = acpApplyPermissionRequest[ turn, 3, <| "toolCall" -> <| "toolCallId" -> "t1", "content" -> { <| "type" -> "diff", "path" -> "/project/r.md", "oldText" -> Null, "newText" -> "x" |> } |>, "options" -> { } |>, 1002. ][ "Turn" ];
        withdrawn = acpApplyPermissionWithdrawn[ turn, 3, 1002.5 ][ "Turn" ];
        {
            withdrawn[ "Entities", { "Tool", "t1" }, "Permission", "Outcome" ],
            withdrawn[ "Entities", { "Tool", "t1" }, "ClientOutcome" ],
            withdrawn[ "PendingPermissions" ],
            withdrawn[ "WaitingTime" ],
            acpApplyPermissionOutcome[ withdrawn, 3, "always", 1003. ][ "Changed" ],
            withdrawn[ "Entities", { "Tool", "t1" }, "Diffs" ]
        }
    ],
    { "withdrawn", None, { }, 0.5, { }, { KeyValuePattern @ { "OldText" -> None, "NewText" -> "x", "Synthesized" -> False } } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Permission-CancelRequestWithdrawal@@Tests/ACPTranscript.wlt:1533,1-1550,2"
]

VerificationTest[
    acpApplyPermissionOutcome[ acpFreshTurn[ ], 99, "once", 1001. ][ "Changed" ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Permission-UnknownRequest@@Tests/ACPTranscript.wlt:1552,1-1557,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "edit" ] } ];
        turn = acpApplyPermissionRequest[ turn, 1, <| "toolCall" -> <| "toolCallId" -> "t1", "name" -> "edit", "rawInput" -> <| "path" -> "/project/a.txt", "oldString" -> "a", "newString" -> "b" |> |>, "options" -> { } |>, 1010. ][ "Turn" ];
        turn = acpApplyPermissionOutcome[ turn, 1, "once", 1022. ][ "Turn" ];
        turn = acpApplyTurnEnd[ turn, <| "StopReason" -> "end_turn" |>, 1030. ][ "Turn" ];
        {
            turn[ "WaitingTime" ],
            (* the label doesn't count the waiting; its tooltip says how long it was (from 5 s on) *)
            acpWorkedForLabel @ turn,
            acpWorkedForTooltip @ turn,
            acpWorkedForTooltip @ <| turn, "WaitingTime" -> 4.9 |>,
            (* only "Worked for" labels have it: not those of stopped, failed and replayed turns *)
            Map[
                { acpWorkedForLabel @ #, acpWorkedForTooltip @ # } &,
                {
                    <| turn, "ClientCancel" -> "Stop" |>,
                    <| turn, "Error" -> <| "Code" -> -32603, "Message" -> "Internal error" |> |>,
                    <| turn, "Replayed" -> True |>
                }
            ],
            turn[ "Entities", { "Tool", "t1" }, "RawInput", "path" ]
        }
    ],
    {
        12.,
        "Worked for 18s",
        "Plus 12s waiting for your approval",
        None,
        { { "Stopped after 30s", None }, { "Failed after 30s", None }, { "Worked", None } },
        "/project/a.txt"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-Permission-WaitingTime@@Tests/ACPTranscript.wlt:1559,1-1593,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "shell", "rawInput" -> <| "command" -> "make" |> ] } ];
        turn = acpApplyPermissionRequest[ turn, 1, <| "toolCall" -> <| "toolCallId" -> "t1" |>, "options" -> { } |>, 1002. ][ "Turn" ];
        turn = acpApplyClientCancel[ turn, "Stop", 1005. ][ "Turn" ];
        { turn[ "ClientCancel" ], turn[ "PendingPermissions" ], turn[ "Entities", { "Tool", "t1" }, "Permission", "Outcome" ], turn[ "Entities", { "Tool", "t1" }, "ClientOutcome" ], acpApplyClientCancel[ turn, "Reject", 1006. ][ "Turn", "ClientCancel" ] }
    ],
    { "Stop", { }, "cancelled", "Stopped", "Stop" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ClientCancel-Stop@@Tests/ACPTranscript.wlt:1595,1-1605,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Activity Labels*)
VerificationTest[
    Module[ { fresh = acpFreshTurn[ ], msg, thought },
        msg     = acpApplyAll[ fresh, { acpChunk[ "m", "x" ] } ];
        thought = acpApplyAll[ fresh, { acpThought[ "m:reasoning:0", "x" ] } ];
        {
            acpTurnActivityLabel[ fresh, $acpBaseTime + 2 ],
            acpTurnActivityLabel[ fresh, $acpBaseTime + 12 ],
            acpTurnActivityLabel[ msg, $acpBaseTime + 2 ],
            acpTurnActivityLabel[ msg, $acpBaseTime + 9 ],
            acpTurnActivityLabel[ thought, $acpBaseTime + 2 ],
            acpTurnActivityLabel[ acpApplyTurnEnd[ msg, <| "StopReason" -> "end_turn" |>, 1003. ][ "Turn" ], $acpBaseTime + 4 ]
        }
    ],
    {
        "Thinking\[Ellipsis]",
        "Waiting for OpenCode\[Ellipsis] 12s (MCP servers may still be starting)",
        "Writing answer\[Ellipsis]",
        "Waiting for OpenCode\[Ellipsis] 8s",
        "Thinking\[Ellipsis]",
        "Finishing\[Ellipsis]"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ActivityLabels@@Tests/ACPTranscript.wlt:1610,1-1633,2"
]

VerificationTest[
    Module[ { turn },
        turn = acpApplyAll[ acpFreshTurn[ ], { acpToolCall[ "t1", "shell" ], acpToolUpdate[ "t1", "status" -> "in_progress", "rawInput" -> <| "command" -> "sleep 30" |> ] } ];
        (* a running tool wins over silence *)
        acpTurnActivityLabel[ turn, $acpBaseTime + 60 ]
    ],
    "Running `sleep 30`",
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ActivityLabel-RunningTool@@Tests/ACPTranscript.wlt:1635,1-1644,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Tool Titles And Summaries*)
VerificationTest[
    Module[ { tool },
        tool[ name_, input_, status_: "completed", rest___ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> None,
            "Title" -> name, "AgentTitle" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
            "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
        |>;
        {
            acpToolTitle[ tool[ "grep", <| "pattern" -> "TODO" |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "glob", <| "pattern" -> "*.wl" |>, "in_progress" ], Automatic, <| |> ],
            acpToolTitle[ tool[ "webfetch", <| "url" -> "https://example.com" |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "websearch", <| "query" -> "wolfram" |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "skill", <| "name" -> "notebooks" |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "todowrite", <| |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "edit", <| "path" -> "/project/src/a.py" |>, "failed" ], Automatic, <| "ProjectDirectory" -> "/project" |> ],
            acpToolTitle[ tool[ "WolframAlpha", <| "query" -> "x" |> ], Automatic, <| |> ],
            acpToolTitle[ tool[ "read", <| "path" -> "/project/a.txt" |> ], "Awaiting", <| "ProjectDirectory" -> "/project" |> ],
            acpToolTitle[ tool[ "execute", <| "code" -> "await tools.Wolfram.WolframAlpha({ query: \"pi\" })" |>, "in_progress" ], Automatic, <| |> ],
            acpToolTitle[ tool[ "execute", <| "code" -> "return 1" |>, "completed" ], Automatic, <| |> ]
        }
    ],
    {
        "Searched for `TODO`",
        "Searching for `*.wl`",
        "Fetched https://example.com",
        "Searched the web for \"wolfram\"",
        "Loaded skill notebooks",
        "Updated the to-do list",
        "Couldn't edit src/a.py",
        "Used Wolfram|Alpha",
        "Wants to read a.txt",
        "Using Wolfram|Alpha",
        "Ran code"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-Verbs@@Tests/ACPTranscript.wlt:1649,1-1685,2"
]

VerificationTest[
    Module[ { tool },
        (* agents without OpenCode's "name" field: fall back to kind/title *)
        tool = <| "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> None, "RawName" -> None, "Kind" -> "read", "Title" -> "Read README.md", "Status" -> "completed", "ClientOutcome" -> None,
                  "RawInput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None |>;
        { acpToolTitle @ tool, acpToolTitle @ <| tool, "ClientOutcome" -> "Declined" |>, acpToolTitle @ <| tool, "Title" -> "read", "Locations" -> { <| "path" -> "/x/y.txt" |> } |> }
    ],
    { "Read README.md", "Declined: Read README.md", "Read y.txt" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-KindFallback@@Tests/ACPTranscript.wlt:1687,1-1697,2"
]

(* The parts of a title (acpToolTitleParts), which the views fit on one line: the object and its kind (code, path,
   text), the fixed text around it; queries and questions keep their quotes in the fixed text, and an object inside a
   phrase (LSP) keeps the phrase *)
VerificationTest[
    Module[ { tool },
        tool[ name_, input_, status_: "completed", rest___ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> None,
            "Title" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
            "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
        |>;
        KeyTake[ #, { "Prefix", "Object", "Kind", "Suffix" } ] & /@ {
            acpToolTitleParts[ tool[ "bash", <| "command" -> "ls -la" |> ], Automatic, <| |> ],
            acpToolTitleParts[ tool[ "read", <| "filePath" -> "/project/src/a.wl" |> ], Automatic, <| "ProjectDirectory" -> "/project" |> ],
            acpToolTitleParts[ tool[ "websearch", <| "query" -> "wolfram" |> ], Automatic, <| |> ],
            acpToolTitleParts[ tool[ "lsp", <| "operation" -> "hover", "filePath" -> "/project/src/a.ts" |> ], Automatic, <| "ProjectDirectory" -> "/project" |> ],
            acpToolTitleParts[ tool[ "todowrite", <| |> ], Automatic, <| |> ],
            acpToolTitleParts[ tool[ "bash", <| |>, "pending" ], Automatic, <| |> ]
        }
    ],
    {
        <| "Prefix" -> "Ran ", "Object" -> "ls -la", "Kind" -> "Code", "Suffix" -> "" |>,
        <| "Prefix" -> "Read ", "Object" -> "src/a.wl", "Kind" -> "Path", "Suffix" -> "" |>,
        <| "Prefix" -> "Searched the web for \"", "Object" -> "wolfram", "Kind" -> "Text", "Suffix" -> "\"" |>,
        <| "Prefix" -> "Looked up `hover` in ", "Object" -> "src/a.ts", "Kind" -> "Path", "Suffix" -> "" |>,
        <| "Prefix" -> "Updated ", "Object" -> "the to-do list", "Kind" -> "Text", "Suffix" -> "" |>,
        <| "Prefix" -> "Preparing a command\[Ellipsis]", "Object" -> "", "Kind" -> None, "Suffix" -> "" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-Parts@@Tests/ACPTranscript.wlt:1702,1-1728,2"
]

(* The views cut titles to the width of their line, so the kernel keeps 200 characters of an object (and the tooltip its
   whole first line, up to 1000): commands and queries lose their end, paths their start, so that the file name stays;
   the objects that had no limit (the tools of an execute call, an MCP tool's name, an agent's own title) have it too.
   The status line's phrase (acpToolAction) keeps 60 characters *)
VerificationTest[
    Module[ { tool, path, command, parts, execute, mcp, titled },
        tool[ name_, input_, status_: "completed", rest___ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> None,
            "Title" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
            "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
        |>;
        path    = "/project/" <> StringRiffle[ ConstantArray[ "folder", 40 ], "/" ] <> "/File.wl";
        command = "echo " <> StringRepeat[ "x", 300 ];
        parts   = acpToolTitleParts[ tool[ "read", <| "filePath" -> path |> ], Automatic, <| "ProjectDirectory" -> "/project" |> ];
        execute = acpToolTitle @ tool[
            "execute", <| "code" -> "x" |>, "completed",
            "RawOutput" -> <| "metadata" -> <| "toolCalls" -> Table[ <| "tool" -> "Server.Tool" <> ToString @ i, "input" -> <| |> |>, { i, 40 } ] |> |>
        ];
        mcp     = acpToolTitle @ tool[ "server_" <> StringRepeat[ "y", 300 ], <| |> ];
        titled  = acpToolTitle @ <| tool[ "x", <| |> ], "Name" -> None, "RawName" -> None, "Title" -> "Edit " <> StringRepeat[ "z", 300 ], "ClientOutcome" -> "Declined" |>;
        {
            190 < StringLength @ parts[ "Object" ] <= 200,
            StringStartsQ[ parts[ "Object" ], "\[Ellipsis]/" ],
            StringEndsQ[ parts[ "Object" ], "/folder/File.wl" ],
            parts[ "Truncated" ],
            parts[ "Tooltip" ] === StringDrop[ path, 9 ],
            StringLength @ acpToolTitle @ tool[ "bash", <| "command" -> command |> ],
            StringTake[ acpToolTitle @ tool[ "bash", <| "command" -> command |> ], -3 ],
            acpToolTitleParts[ tool[ "bash", <| "command" -> command |> ] ][ "Tooltip" ] === command,
            acpToolTitle @ tool[ "bash", <| "command" -> "echo a\necho b" |> ],
            StringLength @ execute <= 210,
            StringLength @ mcp <= 210,
            StringLength @ titled <= 220 && StringStartsQ[ titled, "Declined: Edit zzz" ],
            StringLength @ acpToolAction @ tool[ "bash", <| "command" -> command |> ]
        }
    ],
    { True, True, True, True, True, 206, "x\[Ellipsis]`", True, "Ran `echo a \[Ellipsis]`", True, True, True, 66 },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-Limits@@Tests/ACPTranscript.wlt:1734,1-1769,2"
]

(* An object of several lines (e.g. a script given as a command) shows its first line and " ..." in the title, which
   counts as cut: the tooltip is always shown, with the object's first lines (at most 10, then "..." on its own line) *)
VerificationTest[
    Module[ { tool, two, many },
        tool[ name_, input_, status_: "completed", rest___ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> None,
            "Title" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
            "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
        |>;
        two  = acpToolTitleParts @ tool[ "bash", <| "command" -> "echo a\necho b" |> ];
        many = acpToolTitleParts @ tool[ "bash", <| "command" -> StringRiffle[ Table[ "echo " <> ToString @ i, { i, 12 } ], "\n" ] |> ];
        {
            KeyTake[ two, { "Object", "Truncated", "Tooltip" } ],
            many[ "Truncated" ],
            StringSplit[ many[ "Tooltip" ], "\n" ],
            acpToolTitleParts[ tool[ "bash", <| "command" -> "ls -la\n" |> ] ][ "Truncated" ]
        }
    ],
    {
        <| "Object" -> "echo a \[Ellipsis]", "Truncated" -> True, "Tooltip" -> "echo a\necho b" |>,
        True,
        Append[ Table[ "echo " <> ToString @ i, { i, 10 } ], "\[Ellipsis]" ],
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-MultiLine@@Tests/ACPTranscript.wlt:1773,1-1797,2"
]

(* Every string of a title, its parts, the status line, the phrase of a declined tool and the activity label is
   neutralized: the agent's text (a pattern, a command, the title of a tool call without a name, an MCP tool's name, the
   location of a permission request, the stop reason) can't make boxes through linear syntax *)
VerificationTest[
    Module[ { evil, linear, tool, tools, perm, turn },
        evil   = FromCharacterCode[ { 63425, 63433, 63432 } ] <> "DynamicBox[Print[1]]" <> FromCharacterCode[ 63424 ];
        linear = ! FreeQ[ #, s_String /; StringContainsQ[ s, Characters @ FromCharacterCode @ Range[ 63424, 63437 ] ] ] &;
        tool[ name_, input_, status_: "completed", rest___ ] := <|
            "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> None,
            "Title" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
            "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
        |>;
        tools = {
            tool[ "grep", <| "pattern" -> "a" <> evil |> ],
            tool[ "bash", <| "command" -> "ls " <> evil |>, "in_progress" ],
            <| tool[ "x", <| |> ], "Name" -> None, "RawName" -> None, "Title" -> "Edit " <> evil |>,
            tool[ "Wolfram_" <> evil, <| |> ],
            <| tool[ "bash", <| "command" -> "rm " <> evil |> ], "ClientOutcome" -> "Declined" |>
        };
        perm = <|
            "Type" -> "Permission", "Outcome" -> "reject",
            "Params" -> <| "toolCall" -> <| "toolCallId" -> "p", "title" -> evil, "locations" -> { <| "path" -> "/tmp/" <> evil |> } |> |>
        |>;
        turn = <|
            acpNewTurn @ <| "ID" -> "evil", "StartTime" -> $acpBaseTime |>,
            "EndTime" -> $acpBaseTime + 5, "StopReason" -> "odd " <> evil
        |>;
        {
            linear[ acpToolTitle /@ Append[ tools, perm ] ],
            linear[ acpToolTitleParts /@ Append[ tools, perm ] ],
            linear[ acpToolAction /@ Append[ tools, perm ] ],
            linear @ acpTurnStatusLine @ turn,
            linear @ acpTurnActivityLabel[ <| turn, "EndTime" -> None, "Order" -> { { "Tool", "x" } }, "Entities" -> <| { "Tool", "x" } -> tools[[ 2 ]] |> |>, $acpBaseTime + 1 ],
            acpToolTitle @ First @ tools
        }
    ],
    { False, False, False, False, False, "Searched for `a\:fffd\:fffd\:fffdDynamicBox[Print[1]]\:fffd`" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-Neutralized@@Tests/ACPTranscript.wlt:1802,1-1838,2"
]

VerificationTest[
    Module[ { tool, text },
        text[ s_ ] := { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> s |> |> };
        tool[ name_, content_, rest___ ] := <| "Type" -> "Tool", "Name" -> name, "Kind" -> None, "Status" -> "completed", "ClientOutcome" -> None, "Content" -> content, "Diffs" -> { }, "RawOutput" -> None, "RawInput" -> None, "ExitCode" -> None, "Permission" -> None, rest |>;
        {
            acpToolSummary @ tool[ "glob", text[ "No files found" ] ],
            acpToolSummary @ tool[ "glob", text[ "a.wl\nb.wl\nc.wl" ] ],
            acpToolSummary @ tool[ "grep", text[ "x" ], "RawOutput" -> <| "metadata" -> <| "count" -> 7 |> |> ],
            acpToolSummary @ tool[ "shell", text[ "" ], "ExitCode" -> 0 ],
            acpToolSummary @ tool[ "shell", text[ "a\nb\n" ], "ExitCode" -> 2 ],
            acpToolSummary @ tool[ "read", text[ "Read file a.txt, lines 1-42\n..." ] ],
            acpToolSummary @ tool[ "shell", text[ "x" ], "Status" -> "in_progress" ],
            acpToolSummary @ tool[ "edit", { }, "Diffs" -> { <| "Path" -> "a", "OldText" -> "a\nb\nc", "NewText" -> "a\nB\nc\nd\ne" |> } ]
        }
    ],
    { "No files found", "3 files", "7 matches", "no output", "exit 2", "42 lines", "", "+3 \[Minus]1" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolSummaries@@Tests/ACPTranscript.wlt:1840,1-1858,2"
]

VerificationTest[
    acpExecuteToolNames @ <| "RawInput" -> <| "code" -> "const a = await tools.Wolfram.WolframLanguageContext({ context: \"x\" });\nconst b = await tools.Wolfram.WolframLanguageEvaluator({ code: `Range[3]` });\nreturn {a, b};" |>, "RawOutput" -> None |>,
    { "Wolfram Language Context", "Wolfram Language Evaluator" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteToolNames@@Tests/ACPTranscript.wlt:1860,1-1865,2"
]

VerificationTest[
    acpExecuteToolCalls[ <| "RawInput" -> <| "code" -> "await tools.Wolfram.WolframLanguageEvaluator({ code: `Range[3]` });\nawait tools.Wolfram.WolframLanguageEvaluator({ code: \"f[\\\"a\\\"]\\n\" })" |>, "RawOutput" -> None |> ][[ All, "Code" ]],
    { "Range[3]", "f[\"a\"]\n" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScriptCodeArguments@@Tests/ACPTranscript.wlt:1867,1-1872,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Execute scripts*)

(* acpExecuteScript reads what an agent's code mode script does with MCP tools (see Transcript.wl): the permission panel
   shows it above the script (OpenCode's request names only "execute" and the script) *)

(* The request of the end-to-end run (OpenCode 2.0.26, InsertCells through code mode) *)
VerificationTest[
    acpExecuteScript[ "return await tools.WolframNotebooks.InsertCells({notebook:\"5de1d007\",markdown:\"Escape velocity: v = sqrt(2 mu / r).\"});" ],
    <|
        "Calls" -> {
            <|
                "Tool"          -> "WolframNotebooks.InsertCells",
                "Input"         -> None,
                "Code"          -> None,
                "Arguments"     -> <| "notebook" -> "5de1d007", "markdown" -> "Escape velocity: v = sqrt(2 mu / r)." |>,
                "MoreArguments" -> False
            |>
        },
        "Tools"    -> { "WolframNotebooks.InsertCells" },
        "Complete" -> True
    |>,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-E2ERequest@@Tests/ACPTranscript.wlt:1882,1-1899,2"
]

(* Every form of a tool reference: dots, brackets with any quotes, mixed, optional chaining, white space *)
VerificationTest[
    Module[ { tools },
        tools[ code_ ] := acpExecuteScript[ code ][ "Tools" ];
        {
            tools[ "await tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook: \"ab12cd34\"})" ],
            tools[ "await tools['WolframNotebooks']['DeleteCells']({})" ],
            tools[ "await tools[`WolframNotebooks`][`DeleteCells`]({})" ],
            tools[ "await tools[\"WolframNotebooks\"].DeleteCells({})" ],
            tools[ "await tools.WolframNotebooks[\"DeleteCells\"]({})" ],
            tools[ "await tools?.WolframNotebooks?.[\"DeleteCells\"]?.({})" ],
            tools[ "await tools\n  .WolframNotebooks\n  [ \"DeleteCells\" ] ( {} )" ],
            tools[ "await globalThis.tools.WolframNotebooks.DeleteCells({})" ],
            tools[ "const nb = tools[\"WolframNotebooks\"];\nawait nb.DeleteCells({});\nawait nb['ReadNotebook']({});" ],
            tools[ "await tools.Wolfram.WolframAlpha({ query: \"pi\" })" ]
        }
    ],
    {
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells" },
        { "WolframNotebooks.DeleteCells", "WolframNotebooks.ReadNotebook" },
        { "Wolfram.WolframAlpha" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-ReferenceForms@@Tests/ACPTranscript.wlt:1902,1-1932,2"
]

(* The shapes of D2-01: the bracket form, the mixed form, a decoy in a comment. Every reference counts, wherever it
   is, so the decoy can't hide the real call; the call's arguments are read where they are literals *)
VerificationTest[
    Module[ { read },
        read[ code_ ] := acpExecuteScript[ code ][[ { "Tools", "Calls" } ]];
        {
            read[ "await tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: allIds})" ],
            read[ "await tools[\"WolframNotebooks\"].DeleteCells({ notebook: 'ab12cd34', cells: [\"c1\", \"c2\"] })" ],
            read[ "/* tools.WolframNotebooks.ListNotebooks({}) */ await tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: allIds})" ],
            read[ "// tools.WolframNotebooks.ListNotebooks({});\nawait tools[\"WolframNotebooks\"][\"DeleteCells\"]({notebook:\"ab12cd34\", cells: \"c1, c2\"})" ]
        }
    ],
    {
        <|
            "Tools" -> { "WolframNotebooks.DeleteCells" },
            "Calls" -> { KeyValuePattern[ "Arguments" -> <| "notebook" -> "ab12cd34", "cells" -> Missing[ "Computed" ] |> ] }
        |>,
        <|
            "Tools" -> { "WolframNotebooks.DeleteCells" },
            "Calls" -> { KeyValuePattern[ "Arguments" -> <| "notebook" -> "ab12cd34", "cells" -> { "c1", "c2" } |> ] }
        |>,
        <|
            "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" },
            "Calls" -> {
                (* in a comment: its arguments can't be read *)
                KeyValuePattern @ { "Tool" -> "WolframNotebooks.ListNotebooks", "Arguments" -> Missing[ "Computed" ] },
                KeyValuePattern @ { "Tool" -> "WolframNotebooks.DeleteCells", "Arguments" -> <| "notebook" -> "ab12cd34", "cells" -> Missing[ "Computed" ] |> }
            }
        |>,
        <|
            "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" },
            "Calls" -> {
                KeyValuePattern @ { "Tool" -> "WolframNotebooks.ListNotebooks" },
                KeyValuePattern @ { "Tool" -> "WolframNotebooks.DeleteCells", "Arguments" -> <| "notebook" -> "ab12cd34", "cells" -> "c1, c2" |> }
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-BracketMixedDecoy@@Tests/ACPTranscript.wlt:1936,1-1973,2"
]

(* Tools reached in ways that can't be read make the references incomplete; the edit tools that the script names
   anywhere count (also in a string), and so do names written with Unicode escapes (the server's name written after an
   escaped "tools" is not part of a reference that can be read) *)
VerificationTest[
    Module[ { read },
        read[ code_ ] := acpExecuteScript[ code ][[ { "Tools", "Complete" } ]];
        {
            read[ "// tools.WolframNotebooks.ListNotebooks({});\nconst n = 'DeleteCells';\nawait tools.WolframNotebooks[n]({notebook: 'a'})" ],
            read[ "const t = tools;\nawait t.WolframNotebooks.DeleteCells({})" ],
            read[ "const nb = tools.WolframNotebooks;\nawait nb[name]({})" ],
            read[ "const { DeleteCells } = tools.WolframNotebooks;\nawait DeleteCells({})" ],
            read[ "/* tools.WolframNotebooks.ListNotebooks() */ await \\u0074ools.WolframNotebooks.DeleteCells({notebook: \"x\"})" ],
            read[ "const x = compute();\nreturn x;" ],
            (* the word in text is no use of the tools, and neither is the server's name in text *)
            read[ "await tools.WolframNotebooks.InsertCells({notebook: \"a\", markdown: \"Use these tools. Then the tools [1] work.\"})" ],
            read[ "// WolframNotebooks: a summary\nawait tools.WolframNotebooks.InsertCells({notebook: \"a\", markdown: \"See WolframNotebooks\"})" ],
            (* the server's name anywhere else is, and so is a string that is the name or a path that starts with it *)
            read[ "await tools.WolframNotebooks.InsertCells({notebook: \"a\"});\nconst s = WolframNotebooks;" ],
            read[ "await tools.WolframNotebooks.InsertCells({notebook: \"a\"});\nconst s = 'WolframNotebooks';" ],
            read[ "await tools.WolframNotebooks.InsertCells({notebook: \"a\"});\nconst s = \"WolframNotebooks.Delete\" + \"Cells\";" ]
        }
    ],
    {
        <| "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" }, "Complete" -> False |>,
        <| "Tools" -> { "WolframNotebooks.DeleteCells" }, "Complete" -> False |>,
        <| "Tools" -> { }, "Complete" -> False |>,
        <| "Tools" -> { "WolframNotebooks.DeleteCells" }, "Complete" -> False |>,
        <| "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" }, "Complete" -> False |>,
        <| "Tools" -> { }, "Complete" -> True |>,
        <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> True |>,
        <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> True |>,
        <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> False |>,
        <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> False |>,
        <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-Unresolved@@Tests/ACPTranscript.wlt:1978,1-2012,2"
]

(* Plain JavaScript that reaches a tool without a reference that can be read, after a decoy in a comment: every such
   use of "tools" (or of an alias) makes the references incomplete, and the edit tool that the script names is listed,
   so the decoy can't pass for all that the script does. White space of JavaScript's that PCRE's \s lacks (U+FEFF,
   U+3000, ...) still makes a reference. *)
VerificationTest[
    Module[ { decoy, call, read },
        decoy = "/* tools.WolframNotebooks.ListNotebooks({}) */\n";
        call  = ".WolframNotebooks.DeleteCells({notebook:\"ab12cd34\", cells:\"c1,c2\"})";
        read[ code_ ] := acpExecuteScript[ decoy <> code ][[ { "Tools", "Complete" } ]];
        {
            read /@ {
                "await tools /**/ " <> call,
                "await tools // x\n  " <> call,
                "await (0, tools)" <> call,
                "const t = 0 || tools;\nawait t" <> call,
                "const t = true ? tools : 0;\nawait t" <> call,
                "const f = async (a, t) => t.WolframNotebooks.DeleteCells(a);\nawait f({notebook:\"ab12cd34\"}, tools)",
                "const g = () => { return tools };\nawait g()" <> call,
                "const nb = tools.WolframNotebooks;\nconst m = nb;\nawait m.DeleteCells({})",
                "await globalThis[\"tools\"][\"WolframNotebooks\"][\"DeleteCells\"]({})"
            },
            read /@ {
                "await tools" <> FromCharacterCode[ 16^^FEFF ] <> call,
                "await tools" <> FromCharacterCode[ 16^^3000 ] <> call
            }
        }
    ],
    {
        ConstantArray[ <| "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" }, "Complete" -> False |>, 9 ],
        ConstantArray[ <| "Tools" -> { "WolframNotebooks.ListNotebooks", "WolframNotebooks.DeleteCells" }, "Complete" -> True |>, 2 ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-HiddenUses@@Tests/ACPTranscript.wlt:2018,1-2047,2"
]

(* The same after a decoy with literal arguments, with tools.WolframNotebooks assigned in an expression (an alias is only
   a declaration of its own), a comment or computed member after it, a line comment that ends inside a declaration, or
   a name in brackets that is not a plain name (an octal escape, a string whose quotes end two literals with a call
   between them): the edit is reached in a way that can't be read. A name written with an escape of any number of
   digits is decoded, so the edit is named. *)
VerificationTest[
    Module[ { decoy, read },
        decoy = "if (false) await tools.WolframNotebooks.InsertCells({notebook: \"c6d32676\", markdown: \"## Summary\"});\n";
        read[ code_ ] := acpExecuteScript[ decoy <> code ][[ { "Tools", "Complete" } ]];
        {
            read /@ {
                "let p = tools.WolframNotebooks;\nawait (p = tools.WolframNotebooks)[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"});",
                "let p = tools.WolframNotebooks;\nawait (p = tools[\"WolframNotebooks.Delete\\x43ells\"])({notebook: \"c6d32676\", cells: \"all\"});",
                "let p = tools.WolframNotebooks;\nawait (p = tools.WolframNotebooks /* ns */ [\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"}));",
                "let r = tools.WolframNotebooks;\nawait (r = tools.WolframNotebooks // then\n  [\"Replace\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"}));",
                "const p = tools.WolframNotebooks /**/ [\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"});\nawait p;",
                "const x = // const p =\n  tools.WolframNotebooks;\nawait x[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"});",
                "let p = tools[\"\\127olframNotebooks\"];\nawait p[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\", cells: \"all\"});",
                "const y = 'const p = tools[' + await tools.WolframNotebooks[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\"}) + '];';",
                "const y = 'x tools.a[' + await tools.WolframNotebooks[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\"}) + ']';",
                "const nb = tools.WolframNotebooks;\nconst y = 'nb[' + await nb[\"Delete\" + \"Cells\"]({notebook: \"c6d32676\"}) + ']';"
            },
            read[ "return await t\\u{0000006F}ols.W\\u{0000006F}lframNotebooks.D\\u{00000065}leteCells({notebook: \"c6d32676\", cells: \"all\"});" ]
        }
    ],
    {
        ConstantArray[ <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> False |>, 10 ],
        <| "Tools" -> { "WolframNotebooks.InsertCells", "WolframNotebooks.DeleteCells" }, "Complete" -> True |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-HiddenAliasUses@@Tests/ACPTranscript.wlt:2054,1-2080,2"
]

(* Which definitions of an alias are read: a declaration (const, let or var) on one line that ends there *)
VerificationTest[
    Module[ { read },
        read[ code_ ] := acpExecuteScript[ code ][[ { "Tools", "Complete" } ]];
        {
            read /@ {
                "const nb = tools.WolframNotebooks;\nawait nb.InsertCells({notebook: \"a\"});",
                "let nb = tools[\"WolframNotebooks\"]\nawait nb.InsertCells({notebook: \"a\"})",
                "{ var nb = tools.WolframNotebooks }\nawait nb.InsertCells({notebook: \"a\"});"
            },
            read[ "await f();\nconst nb = tools.WolframNotebooks" ],
            read /@ {
                "nb = tools.WolframNotebooks;\nawait nb.InsertCells({notebook: \"a\"});",
                "const nb = tools.WolframNotebooks // the notebook tools\nawait nb.InsertCells({notebook: \"a\"});",
                "const nb = tools.WolframNotebooks, x = 1;\nawait nb.InsertCells({notebook: \"a\"});",
                "const nb = tools.WolframNotebooks\n(nb.InsertCells)({notebook: \"a\"});",
                "const nb =\n  tools.WolframNotebooks;\nawait nb.InsertCells({notebook: \"a\"});"
            }
        }
    ],
    {
        ConstantArray[ <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> True |>, 3 ],
        <| "Tools" -> { }, "Complete" -> True |>,
        ConstantArray[ <| "Tools" -> { "WolframNotebooks.InsertCells" }, "Complete" -> False |>, 5 ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-AliasDeclarations@@Tests/ACPTranscript.wlt:2083,1-2109,2"
]

(* A decoy that JavaScript never runs (in a regular expression, after an HTML-like comment, in the text of a template
   literal after a substitution with a comment) is not taken for a call: arguments are only read up to the first token
   after which JavaScript may read the script differently, and the decoy's notebook is not resolved. Arguments before
   such a token are read. *)
VerificationTest[
    Module[ { decoy, real, read },
        decoy = "tools.WolframNotebooks.InsertCells({notebook: \"5de1d007\", markdown: \"Escape velocity\"})";
        real  = "\nawait tools[\"WolframNotebooks\"][\"InsertCells\"](p);";
        read[ code_ ] := {
            acpExecuteScript[ code ][ "Calls" ][[ All, "Arguments" ]],
            acpPermissionNotebooks @ <| "toolCall" -> <| "name" -> "execute", "rawInput" -> <| "code" -> code |> |> |>
        };
        {
            read[ "const r = /" <> decoy <> "/;" <> real ],
            read[ "<!-- " <> decoy <> real ],
            read[ "x = 1\n--> " <> decoy <> real ],
            read[ "const s = `${/*`*/0}" <> decoy <> "`;" <> real ],
            read[ "const s = `" <> decoy <> real ],
            read[ "await " <> decoy <> ";\nconst r = /x/;" ]
        }
    ],
    {
        { { Missing[ "Computed" ], Missing[ "Computed" ] }, { } },
        { { Missing[ "Computed" ], Missing[ "Computed" ] }, { } },
        { { Missing[ "Computed" ], Missing[ "Computed" ] }, { } },
        { { Missing[ "Computed" ], Missing[ "Computed" ] }, { } },
        { { Missing[ "Computed" ], Missing[ "Computed" ] }, { } },
        { { <| "notebook" -> "5de1d007", "markdown" -> "Escape velocity" |> }, { "5de1d007" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-UnclearTokens@@Tests/ACPTranscript.wlt:2115,1-2142,2"
]

(* A slash after a number, a literal, "]" or a name (not a keyword) is a division, and a template literal with string
   literals, braces and template literals in its substitutions is read as JavaScript does: the arguments of a call
   after them are read, and its notebook is resolved. After ")", "}" or a keyword such as return, a slash may start a
   regular expression, and so may a slash in a substitution: the arguments after them are not read. *)
VerificationTest[
    Module[ { call, read },
        call = "\nawait tools.WolframNotebooks.InsertCells({ notebook: \"c6d32676\", markdown: \"Done.\" });";
        read[ code_ ] := {
            Last[ acpExecuteScript[ code <> call ][ "Calls" ] ][ "Arguments" ],
            acpPermissionNotebooks @ <| "toolCall" -> <| "name" -> "execute", "rawInput" -> <| "code" -> code <> call |> |> |>
        };
        {
            read /@ {
                "const half = 10 / 2;",
                "const r = n / 2 / m[0] / 'x' / `a` / length;",
                "const rows = [[1, 2], [3, 4]];\nconst table = `${rows.map(r => `| ${r.join(\" | \")} |`).join(\"\\n\")}`;",
                "const md = `${xs.map(x => { return `- ${x}`; }).join(\"\\n\")}`;"
            },
            read /@ {
                "const half = (a + b) / 2;",
                "if (a) {}\n/x/.test(s);",
                "const f = () => { return /x/ };",
                "const s = `${x.replace(/\\|/g, \"\")}`;"
            }
        }
    ],
    {
        ConstantArray[ { <| "notebook" -> "c6d32676", "markdown" -> "Done." |>, { "c6d32676" } }, 4 ],
        ConstantArray[ { Missing[ "Computed" ], { } }, 4 ]
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-ReadableTokens@@Tests/ACPTranscript.wlt:2148,1-2176,2"
]

(* Reading a script takes time in proportion to its length: literals and comments that are not closed are one token
   each, and only $maxScriptAliases definitions of aliases are read (these took from 15 s to 100 s before) *)
VerificationTest[
    Module[ { call, time },
        call = "await tools.WolframNotebooks.ListNotebooks({});\n";
        time[ code_String ] := Block[ { Wolfram`Chatbook`ACP`Transcript`Private`$scriptCache = <| |> },
            First @ AbsoluteTiming @ acpExecuteScript @ code
        ];
        Max[
            time[ call <> "const s = '" <> StringRepeat[ "\\'", 20000 ] ],
            time[ call <> "const s = `" <> StringRepeat[ "\\`", 20000 ] ],
            time[ StringJoin @ Table[ "const a" <> ToString[ i ] <> "=tools.W;", { i, 4000 } ] ],
            time[ StringRepeat[ "tools[\"\\\"", 10000 ] ],
            time[ StringRepeat[ "await tools.WolframNotebooks.ListNotebooks();", 2000 ] ],
            time[ call <> StringRepeat[ "/* ", 20000 ] ]
        ] < 3
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-Performance@@Tests/ACPTranscript.wlt:2180,1-2198,2"
]

(* Reading the arguments is bounded too ($maxTokenVisits, also for comments; lists of at most $maxListItems items), and
   only the first $maxScriptTokens tokens are read: references whose arguments run to the end of a long script, a long
   list, dense references and aliases (these took from 3 s to 8.5 s before) *)
VerificationTest[
    Module[ { open, time },
        open = StringRepeat[ "tools.W.I({a: (", 100 ];
        time[ code_String ] := Block[ { Wolfram`Chatbook`ACP`Transcript`Private`$scriptCache = <| |> },
            First @ AbsoluteTiming @ acpExecuteScript @ code
        ];
        Max[
            time[ open <> StringRepeat[ "/**/", 24000 ] ],
            time[ open <> StringRepeat[ "//\n", 32000 ] ],
            time[ open <> StringRepeat[ "a+", 48000 ] ],
            time[ "await tools.W.I({cells: [" <> StringRepeat[ "1,", 49000 ] <> "]})" ],
            time[ StringRepeat[ "tools.a.b();", 8300 ] ],
            time[ StringJoin[ Table[ "const a" <> ToString[ i ] <> "=tools.W;", { i, 20 } ], Table[ "a" <> ToString[ Mod[ i, 20 ] + 1 ] <> ".b();", { i, 11000 } ] ] ],
            time[ StringRepeat[ "`${ `x` ", 12000 ] ],
            time[ "await tools.W.I({});\n" <> StringRepeat[ "1/", 49000 ] ]
        ] < 1.5
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-PerformanceReading@@Tests/ACPTranscript.wlt:2203,1-2223,2"
]

(* Literal values (decoded), values that are not literals, spreads, computed keys and __proto__ *)
VerificationTest[
    Module[ { arguments },
        arguments[ object_ ] := Lookup[ First @ acpExecuteScript[ "await tools.WolframNotebooks.InsertCells(" <> object <> ")" ][ "Calls" ], { "Arguments", "MoreArguments" } ];
        {
            arguments[ "{notebook: \"a\\u0062c\", markdown: 'it\\'s\\n\\x41\\u{1F600}', offset: 10, limit: -2, cell: null, x: true, cells: [\"a\", 'b',]}" ],
            arguments[ "{ markdown: `# Title\nline` }" ],
            arguments[ "{ notebook: id, markdown: `# ${title}`, cell: \"a\" + b, position: (\"before\"), cells }" ],
            arguments[ "{ notebook: \"a\\1\", markdown: \"\\08\" }" ],
            arguments[ "{ notebook: \"a\", ...rest, markdown: \"m\" }" ],
            arguments[ "{ notebook: \"a\", [key]: \"x\", markdown: \"m\" }" ],
            arguments[ "{ notebook: \"a\", __proto__: { notebook: \"b\" } }" ],
            arguments[ "{ notebook: \"a\", notebook: \"b\" }" ],
            arguments[ "{ notebook: \"a\" /* , notebook: \"b\" */, markdown: \"m\" // , notebook: \"c\"\n}" ],
            arguments[ "args" ],
            arguments[ "" ],
            (* \u{...} with any number of digits, as in JavaScript *)
            arguments[ "{notebook: \"\\u{00000061}b\\u{0063}\", markdown: \"\\u{110000}\"}" ]
        }
    ],
    {
        {
            <|
                "notebook" -> "abc", "markdown" -> "it's\nA" <> FromCharacterCode[ 128512 ], "offset" -> 10, "limit" -> -2,
                "cell" -> Null, "x" -> True, "cells" -> { "a", "b" }
            |>,
            False
        },
        { <| "markdown" -> "# Title\nline" |>, False },
        {
            <|
                "notebook" -> Missing[ "Computed" ], "markdown" -> Missing[ "Computed" ], "cell" -> Missing[ "Computed" ],
                "position" -> Missing[ "Computed" ], "cells" -> Missing[ "Computed" ]
            |>,
            False
        },
        { <| "notebook" -> Missing[ "Computed" ], "markdown" -> Missing[ "Computed" ] |>, False },
        { <| "notebook" -> Missing[ "Computed" ], "markdown" -> "m" |>, True },
        { <| "notebook" -> Missing[ "Computed" ], "markdown" -> "m" |>, True },
        { <| "notebook" -> Missing[ "Computed" ] |>, True },
        { <| "notebook" -> "b" |>, False },
        { <| "notebook" -> "a", "markdown" -> "m" |>, False },
        { Missing[ "Computed" ], False },
        { <| |>, False },
        { <| "notebook" -> "abc", "markdown" -> Missing[ "Computed" ] |>, False }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-Literals@@Tests/ACPTranscript.wlt:2226,1-2273,2"
]

(* Syntax that the reader doesn't place the way JavaScript does (regular expressions, HTML-like comments, an argument
   that is an expression) gives up the whole argument, so that a value that is shown is the one JavaScript uses; a
   substitution with a template literal in it is read as JavaScript does; a line comment ends at any line terminator, as
   in JavaScript *)
VerificationTest[
    Module[ { arguments },
        arguments[ args_ ] := First[ acpExecuteScript[ "await tools.WolframNotebooks.InsertCells(" <> args <> ")" ][ "Calls" ] ][ "Arguments" ];
        {
            (* JavaScript: markdown is /"/ and the notebook is "evil" *)
            arguments[ "{notebook: \"real\", markdown: /\"/, notebook: \"evil\"}/}" ],
            (* JavaScript: the template literal holds `, notebook: "evil"}` *)
            arguments[ "{notebook: \"real\", markdown: `${` , notebook: \"evil\"}`}`}" ],
            arguments[ "{notebook: \"real\"\n<!-- , notebook: \"evil\"\n}" ],
            arguments[ "{notebook: \"real\"} && {notebook: \"evil\"}" ],
            (* JavaScript: the comment ends at U+2028, so the notebook is "evil" *)
            arguments[ "{notebook: \"real\" // c\:2028, notebook: \"evil\"\n}" ]
        }
    ],
    {
        Missing[ "Computed" ],
        <| "notebook" -> "real", "markdown" -> Missing[ "Computed" ] |>,
        Missing[ "Computed" ],
        Missing[ "Computed" ],
        <| "notebook" -> "evil" |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-NoSpoofing@@Tests/ACPTranscript.wlt:2279,1-2302,2"
]

(* Long scripts are read up to $maxScriptLength characters, and the arguments of the first $maxScriptReferences
   references; the references are then not complete *)
VerificationTest[
    Module[ { many, long },
        many = acpExecuteScript @ StringRepeat[ "await tools.WolframNotebooks.ReadNotebook({notebook: \"aaaaaaaa\"});\n", 150 ];
        long = acpExecuteScript[ StringRepeat[ " ", 100000 ] <> "await tools.WolframNotebooks.DeleteCells({})" ];
        { Length @ many[ "Calls" ], many[ "Tools" ], many[ "Complete" ], long }
    ],
    { 100, { "WolframNotebooks.ReadNotebook" }, False, <| "Calls" -> { }, "Tools" -> { }, "Complete" -> False |> },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-Limits@@Tests/ACPTranscript.wlt:2306,1-2315,2"
]

(* The arguments of a call after the first $maxScriptTokens tokens are not read, and a list of more than $maxListItems
   items is not read *)
VerificationTest[
    Module[ { call, arguments },
        call = "await tools.WolframNotebooks.DeleteCells({notebook: \"a\", cells: [" <> StringRiffle[ ConstantArray[ "\"c\"", # ], "," ] <> "]});" &;
        arguments[ code_ ] := Last[ acpExecuteScript[ code ][ "Calls" ] ][ "Arguments" ];
        {
            arguments[ StringRepeat[ "x;", 9000 ] <> call @ 2 ],
            arguments[ StringRepeat[ "x;", 11000 ] <> call @ 2 ],
            Length @ arguments[ call @ 1000 ][ "cells" ],
            Block[
                {
                    Wolfram`Chatbook`ACP`Transcript`Private`$maxListItems = 3,
                    Wolfram`Chatbook`ACP`Transcript`Private`$scriptCache  = <| |>
                },
                { arguments[ call @ 3 ], arguments[ call @ 4 ] }
            ]
        }
    ],
    {
        <| "notebook" -> "a", "cells" -> { "c", "c" } |>,
        Missing[ "Computed" ],
        1000,
        { <| "notebook" -> "a", "cells" -> { "c", "c", "c" } |>, <| "notebook" -> "a", "cells" -> Missing[ "Computed" ] |> }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteScript-TokenLimits@@Tests/ACPTranscript.wlt:2319,1-2344,2"
]

(* The tools of a call that ran come from its metadata (complete), else from the script *)
VerificationTest[
    {
        acpExecuteToolReferences @ <|
            "RawInput"  -> <| "code" -> "/* tools.WolframNotebooks.DeleteCells */ await tools.WolframNotebooks.ListNotebooks({})" |>,
            "RawOutput" -> <| "metadata" -> <| "toolCalls" -> { <| "tool" -> "WolframNotebooks.ListNotebooks", "status" -> "completed" |> } |> |>
        |>,
        acpExecuteToolReferences @ <|
            "RawInput"  -> <| "code" -> "/* tools.WolframNotebooks.DeleteCells */ await tools.WolframNotebooks.ListNotebooks({})" |>,
            "RawOutput" -> None
        |>,
        acpExecuteToolReferences @ <| "RawInput" -> None, "RawOutput" -> None |>
    },
    {
        <| "Tools" -> { "WolframNotebooks.ListNotebooks" }, "Complete" -> True |>,
        <| "Tools" -> { "WolframNotebooks.DeleteCells", "WolframNotebooks.ListNotebooks" }, "Complete" -> True |>,
        <| "Tools" -> { }, "Complete" -> True |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ExecuteToolReferences@@Tests/ACPTranscript.wlt:2347,1-2366,2"
]

(* The notebook tools' names in both forms (code mode, and a direct call's OpenCode name) show the server *)
VerificationTest[
    {
        acpMCPDisplayName /@ {
            "WolframNotebooks.InsertCells", "WolframNotebooks_InsertCells", "WolframNotebooks.ReadNotebook",
            "Wolfram.ReadNotebook", "Wolfram_WolframAlpha", "github.create_issue", "github_create_issue"
        },
        acpNotebookToolName /@ { "WolframNotebooks.InsertCells", "WolframNotebooks_DeleteCells", "WolframNotebooksX_Y", "WolframNotebooks.a.b", None }
    },
    {
        {
            "WolframNotebooks: InsertCells", "WolframNotebooks: InsertCells", "WolframNotebooks: ReadNotebook",
            "Read Notebook", "Wolfram|Alpha", "github: create_issue", "github_create_issue"
        },
        { "InsertCells", "DeleteCells", None, None, None }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-MCPDisplayName@@Tests/ACPTranscript.wlt:2369,1-2386,2"
]

(* The notebook arguments of a permission request, for the titles in the permission panel: a script's literal ones,
   a direct call's, none for other tools *)
VerificationTest[
    acpPermissionNotebooks /@ {
        <| "toolCall" -> <| "name" -> "execute", "rawInput" -> <| "code" ->
            "await tools.WolframNotebooks.DeleteCells({notebook: \"ab12cd34\"});\n" <>
            "await tools.WolframNotebooks.InsertCells({notebook: id});\n" <>
            "await tools[\"WolframNotebooks\"][\"ReadNotebook\"]({notebook: \"My Notes\"});\n" <>
            "await tools.Other.Tool({notebook: \"other\"});"
        |> |> |>,
        <| "toolCall" -> <| "name" -> "WolframNotebooks_InsertCells", "rawInput" -> <| "notebook" -> "5de1d007", "markdown" -> "x" |> |> |>,
        <| "toolCall" -> <| "name" -> "edit", "rawInput" -> <| "notebook" -> "5de1d007" |> |> |>,
        <| |>
    },
    { { "ab12cd34", "My Notes" }, { "5de1d007" }, { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PermissionNotebooks@@Tests/ACPTranscript.wlt:2390,1-2405,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*OpenCode Tool Titles*)
VerificationTest[
    acpOCTool // ClearAll;
    acpOCTool[ name_, input_, status_: "completed", rest___ ] := <|
        "Type" -> "Tool", "ToolCallID" -> "x", "Name" -> acpCanonicalToolName @ name, "RawName" -> name, "Kind" -> "other",
        "Title" -> name, "AgentTitle" -> name, "Status" -> status, "ClientOutcome" -> None, "RawInput" -> input,
        "RawOutput" -> None, "Content" -> { }, "Diffs" -> { }, "Locations" -> { }, "Permission" -> None, "ExitCode" -> None, "Child" -> None, rest
    |>;
    (* OpenCode 2.x skill tool: input { "id" }, metadata { "name", "directory" } (the title is just "skill") *)
    {
        acpToolTitle @ acpOCTool[ "skill", <| |>, "pending" ],
        acpToolTitle @ acpOCTool[ "skill", <| "id" -> "wolfram-notebooks" |>, "in_progress" ],
        acpToolTitle @ acpOCTool[ "skill", <| "id" -> "wolfram-notebooks" |> ],
        acpToolTitle @ acpOCTool[ "skill", <| "name" -> "notebooks" |> ],
        acpToolTitle @ acpOCTool[ "skill", <| |>, "completed", "RawOutput" -> <| "metadata" -> <| "name" -> "From Metadata", "directory" -> "/x" |> |> ],
        acpToolTitle @ acpOCTool[ "skill", <| |> ],
        acpToolTitle @ acpOCTool[ "skill", <| "id" -> "wolfram-notebooks" |>, "failed" ],
        acpToolAction @ acpOCTool[ "skill", <| "id" -> "wolfram-notebooks" |> ]
    },
    {
        "Loading a skill\[Ellipsis]",
        "Loading skill wolfram-notebooks",
        "Loaded skill wolfram-notebooks",
        "Loaded skill notebooks",
        "Loaded skill From Metadata",
        "Loaded a skill",
        "Couldn't load skill wolfram-notebooks",
        "load skill wolfram-notebooks"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-Skill@@Tests/ACPTranscript.wlt:2410,1-2440,2"
]

VerificationTest[
    Module[ { turn = <| "ProjectDirectory" -> "/project" |> },
        {
            acpToolTitle[ acpOCTool[ "list", <| "path" -> "/project/src" |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "list", <| |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "list", <| "path" -> "/project/src" |>, "in_progress" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "codesearch", <| "query" -> "React useState hook" |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "lsp", <| "operation" -> "goToDefinition", "filePath" -> "/project/src/a.ts", "line" -> 3 |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "lsp", <| "operation" -> "hover" |>, "in_progress" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "question", <| "questions" -> { <| "header" -> "Database", "question" -> "Which database should I use?" |> } |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "question", <| "questions" -> { <| "question" -> "First?" |>, <| "question" -> "Second?" |>, <| "question" -> "Third?" |> } |>, "in_progress" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "question", <| |>, "pending" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "todoread", <| |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "todowrite", <| "todos" -> { } |>, "in_progress" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "models", <| "query" -> "claude" |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "invalid", <| "tool" -> "bash2", "error" -> "unknown tool" |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "task", <| "description" -> "Explore the code", "agent" -> "explore", "prompt" -> "..." |>, "in_progress" ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "subagent", <| |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "websearch", <| |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "bash", <| |> ], Automatic, turn ],
            acpToolTitle[ acpOCTool[ "frobnicate", <| |> ], Automatic, turn ]
        }
    ],
    {
        "Listed src",
        "Listed the project folder",
        "Listing src",
        "Searched the code for \"React useState hook\"",
        "Looked up `goToDefinition` in src/a.ts",
        "Looking up `hover`",
        "Asked \"Which database should I use?\"",
        "Asking \"First?\" (+2 more)",
        "Preparing a question\[Ellipsis]",
        "Read the to-do list",
        "Updating the to-do list",
        "Searched the models for \"claude\"",
        "Invalid tool call: `bash2`",
        "Subagent: Explore the code",
        "Ran a subagent",
        "Searched the web",
        "Ran a command",
        "Used frobnicate"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-OpenCodeTools@@Tests/ACPTranscript.wlt:2442,1-2487,2"
]

(* Without any input, the title never uses the bare tool name as its object ("Used skill skill") and never ends with a
   dangling preposition ("Stopped: search for") *)
VerificationTest[
    Module[ { names, titles },
        names = Join[ Keys @ Wolfram`Chatbook`ACP`Transcript`Private`$toolLabelGroups, { "bash", "task", "apply_patch" } ];
        titles[ name_ ] := Join[
            acpToolTitle[ acpOCTool[ name, <| |>, # ], Automatic, <| |> ] & /@ { "pending", "in_progress", "completed", "failed" },
            acpToolTitle[ acpOCTool[ name, <| |>, "failed", "ClientOutcome" -> # ], Automatic, <| |> ] & /@ { "Declined", "Stopped" }
        ];
        {
            Select[ names, ToLowerCase @ Wolfram`Chatbook`ACP`Transcript`Private`toolVerbObject[ acpOCTool[ #, <| |> ], <| |> ][ "Object" ] === ToLowerCase @ # & ],
            Select[ names, AnyTrue[ titles @ #, Function[ t, StringContainsQ[ t, # <> " " <> # ] || StringEndsQ[ t, " " ~~ ("for"|"about"|"to"|"in") ] ] ] & ]
        }
    ],
    { { }, { } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolTitles-NoBareNameEcho@@Tests/ACPTranscript.wlt:2491,1-2506,2"
]

VerificationTest[
    {
        acpToolSummary @ acpOCTool[ "todowrite", <| "todos" -> { <| "content" -> "a", "status" -> "completed" |>, <| "content" -> "b", "status" -> "pending" |>, <| "content" -> "c", "status" -> "completed" |> } |> ],
        acpToolSummary @ acpOCTool[ "todowrite", <| |> ],
        acpToolSummary @ acpOCTool[ "list", <| "path" -> "/project" |>, "completed", "Content" -> { <| "type" -> "content", "content" -> <| "type" -> "text", "text" -> "a\nb\nc" |> |> } ]
    },
    { "2 of 3 done", "", "3 lines" },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ToolSummaries-OpenCodeTools@@Tests/ACPTranscript.wlt:2508,1-2517,2"
]

VerificationTest[
    {
        acpClientInterruptionTextQ /@ { "The user declined this tool call", "  Tool execution interrupted\n", "cancelled", "Command cancelled", "The user dismissed this question" },
        acpClientInterruptionTextQ /@ { "Permission denied", "The user declined this tool call because...", None }
    },
    { { True, True, True, True, True }, { False, False, False } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-ClientInterruptionText@@Tests/ACPTranscript.wlt:2519,1-2527,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Synthetic fixture: skill, todowrite, execute with images, bold code spans*)
VerificationTest[
    turnFmt = acpReplay[ "synthetic_answer_formatting" ];
    {
        acpTurnSplit @ turnFmt,
        { acpToolTitle @ #, acpToolSummary @ # } & /@ Cases[ Lookup[ turnFmt[ "Entities" ], turnFmt[ "Order" ] ], KeyValuePattern[ "Type" -> "Tool" ] ],
        StringContainsQ[ acpTurnToMarkdown @ turnFmt, "**`Prime[Range[10]]`:**" ] (* markdown export keeps the original text *)
    },
    {
        <| "Work" -> { { "Tool", "call_skill_1" }, { "Tool", "call_todo_1" }, { "Tool", "call_exec_1" } }, "Answer" -> { { "Message", "msg_answer_1" } }, "Tail" -> { } |>,
        { { "Loaded skill wolfram-notebooks", "" }, { "Updated the to-do list", "1 of 3 done" }, { "Used Wolfram Language Evaluator", "2 calls" } },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-SyntheticFormatting@@Tests/ACPTranscript.wlt:2532,1-2546,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote Turns*)

(* A turn of a remote window knows its host (acpTurnRemote); new turns are local *)
VerificationTest[
    {
        acpNewTurn[ ][ "Remote" ],
        acpTurnRemote @ <| "Settings" -> <| |> |>,
        acpTurnRemote @ <|
            "Settings"   -> <| "SSHSettings" -> <| "MachineName" -> "ec2-1.compute.example.com", "Username" -> "ubuntu" |> |>,
            "RemoteHome" -> "/home/ubuntu"
        |>,
        (* a home that is not an absolute path is not used *)
        acpTurnRemote @ <| "Settings" -> <| "SSHSettings" -> "devbox" |>, "RemoteHome" -> "home\nx" |>
    },
    {
        None,
        None,
        <| "Host" -> "ubuntu@ec2-1.compute.example.com", "Short" -> "ec2-1", "Home" -> "/home/ubuntu" |>,
        <| "Host" -> "devbox", "Short" -> "devbox", "Home" -> None |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-TurnRemote@@Tests/ACPTranscript.wlt:2553,1-2572,2"
]

(* Tool paths relative to the project folder, else their last name; the same for the POSIX paths of a local turn (this
   computer's paths on Unix) and of a remote turn (whatever this computer's system) *)
VerificationTest[
    Function[ turn,
        Wolfram`Chatbook`ACP`Transcript`Private`displayPath[ #, turn ] & /@ {
            "/home/u/proj/src/a.wl",
            "/home/u/proj",
            "/etc/hosts",
            "/srv/data/",
            "/",
            "relative/b.txt"
        }
    ] /@ {
        <| "ProjectDirectory" -> "/home/u/proj" |>,
        <| "ProjectDirectory" -> "/home/u/proj", "Remote" -> <| "Host" -> "dev", "Short" -> "dev", "Home" -> "/home/u" |> |>
    },
    ConstantArray[ { "src/a.wl", "proj", "hosts", "data", "/", "relative/b.txt" }, 2 ],
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-DisplayPath-POSIX@@Tests/ACPTranscript.wlt:2576,1-2593,2"
]

(* A local turn's paths are this computer's (C:\Users\me\proj on Windows): the last name of the project folder is
   taken with FileNameTake; a remote turn's paths are POSIX paths, where a backslash is part of a name. The second part
   runs as on a Windows computer (FileNameTake's OperatingSystem option), so it checks both rules on any system. *)
VerificationTest[
    With[
        {
            path   = Wolfram`Chatbook`ACP`Transcript`Private`displayPath,
            remote = <| "Host" -> "dev", "Short" -> "dev", "Home" -> "/home/u" |>,
            root   = FileNameJoin @ { $TemporaryDirectory, "proj" }
        },
        {
            {
                path[ root, <| "ProjectDirectory" -> root |> ],
                path[ "/home/u/a\\b", <| "ProjectDirectory" -> "/home/u/proj", "Remote" -> remote |> ],
                path[ "/home/u/a\\b", <| "ProjectDirectory" -> "/home/u/a\\b", "Remote" -> remote |> ]
            },
            Internal`InheritedBlock[ { FileNameTake },
                SetOptions[ FileNameTake, OperatingSystem -> "Windows" ];
                {
                    path[ "C:\\Users\\me\\proj", <| "ProjectDirectory" -> "C:\\Users\\me\\proj" |> ],
                    path[ "/home/u/a\\b", <| "ProjectDirectory" -> "/home/u/proj", "Remote" -> remote |> ],
                    path[ "/home/u/a\\b", <| "ProjectDirectory" -> "/home/u/a\\b", "Remote" -> remote |> ],
                    path[ "/home/u/proj", <| "ProjectDirectory" -> "/home/u/proj", "Remote" -> remote |> ]
                }
            ]
        }
    ],
    { { "proj", "a\\b", "a\\b" }, { "proj", "a\\b", "a\\b", "proj" } },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-DisplayPath-LocalAndRemoteNames@@Tests/ACPTranscript.wlt:2598,1-2625,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Prompt Blocks*)

(* The content blocks of session/prompt (Attachments.wl's acpPromptBlocks, pure): the typed text, then one
   <attachment ...> block per attachment, in one text block; images after it *)
VerificationTest[
    $promptPNG    = ExportByteArray[ RandomImage[ 1, { 8, 6 } ], "PNG" ];
    $promptImages = <| "promptCapabilities" -> <| "image" -> True, "embeddedContext" -> True |> |>;
    $promptNoImages = <| "promptCapabilities" -> <| "image" -> False |> |>;
    $promptAttachments = {
        <|
            "Kind" -> "Notebook", "Name" -> "Spec.nb", "Path" -> "/home/u/Spec.nb", "Text" -> "# Spec\n\n[image 1] and [image 2]",
            "Images" -> {
                <| "Number" -> 2, "MimeType" -> "image/jpeg", "Data" -> ByteArray[ { 255, 216, 255 } ] |>,
                <| "Number" -> 1, "MimeType" -> "image/png", "Data" -> $promptPNG |>
            }
        |>,
        <| "Kind" -> "File", "Name" -> "data.csv", "Path" -> "/home/u/data.csv", "Text" -> "a,b\n1,2", "Images" -> { } |>,
        <| "Kind" -> "File", "Name" -> "plot.png", "Path" -> "/home/u/plot.png", "Text" -> "[image 3]",
           "Images" -> { <| "Number" -> 3, "MimeType" -> "image/png", "Data" -> $promptPNG |> } |>
    },
    _,
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-Definitions@@Tests/ACPTranscript.wlt:2633,1-2652,2"
]

(* Without attachments the prompt is exactly the one text block that was always sent, whatever the agent accepts *)
VerificationTest[
    {
        acpPromptBlocks[ "Fix the bug", { }, $promptImages, False ],
        acpPromptBlocks[ "Fix the bug", { }, None, True ],
        acpPromptBlocks[ "/compact", { }, $promptNoImages, False ],
        acpPromptBlocks[ "Fix the bug", None, $promptImages, False ],
        acpPromptBlocks[ "", { }, None, False ]
    },
    {
        { <| "type" -> "text", "text" -> "Fix the bug" |> },
        { <| "type" -> "text", "text" -> "Fix the bug" |> },
        { <| "type" -> "text", "text" -> "/compact" |> },
        { <| "type" -> "text", "text" -> "Fix the bug" |> },
        { <| "type" -> "text", "text" -> "" |> }
    },
    SameTest -> SameQ,
    TestID   -> "ACPTranscript-PromptBlocks-NoAttachments@@Tests/ACPTranscript.wlt:2655,1-2672,2"
]

(* The text block first (OpenCode's slash commands and the mock agent's scenario selection read it), then the images in
   the order of their numbers, as base64; the path of a file only for a local window *)
VerificationTest[
    Module[ { local, remote },
        local  = acpPromptBlocks[ "scenario:base-hello Review these", $promptAttachments, $promptImages, False ];
        remote = acpPromptBlocks[ "Review these", $promptAttachments, $promptImages, True ];
        {
            local[[ All, "type" ]],
            local[[ 1, "text" ]],
            local[[ 2 ;;, "mimeType" ]],
            BaseDecode @ local[[ 2, "data" ]] === $promptPNG,
            StringContainsQ[ remote[[ 1, "text" ]], "path=" ],
            StringStartsQ[ remote[[ 1, "text" ]], "Review these\n\n<attachment type=\"notebook\" name=\"Spec.nb\">\n" ]
        }
    ],
    {
        { "text", "image", "image", "image" },
        "scenario:base-hello Review these\n\n\
<attachment type=\"notebook\" name=\"Spec.nb\" path=\"/home/u/Spec.nb\">\n# Spec\n\n[image 1] and [image 2]\n</attachment>\n\n\
<attachment type=\"file\" name=\"data.csv\" path=\"/home/u/data.csv\">\na,b\n1,2\n</attachment>\n\n\
<attachment type=\"file\" name=\"plot.png\" path=\"/home/u/plot.png\">\n[image 3]\n</attachment>",
        { "image/png", "image/jpeg", "image/png" },
        True,
        False,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-Order@@Tests/ACPTranscript.wlt:2676,1-2702,2"
]

(* An agent that does not accept images (or whose capabilities are not known) gets no image blocks, and a note says what
   the placeholders are; attachments without typed text start the text block *)
VerificationTest[
    Function[ caps,
        With[ { blocks = acpPromptBlocks[ "", $promptAttachments, caps, False ] },
            { Length @ blocks, StringStartsQ[ blocks[[ 1, "text" ]], "<attachment type=\"notebook\"" ], StringEndsQ[ blocks[[ 1, "text" ]], "the agent does not accept images.]" ] }
        ]
    ] /@ { $promptNoImages, None, <| |> },
    ConstantArray[ { 1, True, True }, 3 ],
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-NoImageCapability@@Tests/ACPTranscript.wlt:2706,1-2715,2"
]

(* Attribute values are escaped; "<attachment" and "</attachment" in the content and in the typed text are made inert,
   so nothing closes a block early or passes for one, and the parse of a restored message gives the typed text and the
   attachments back *)
VerificationTest[
    Module[ { attachments, text, parsed },
        attachments = {
            <| "Kind" -> "File", "Name" -> "a \"b\" <c> & d\ne.txt", "Path" -> "/tmp/a \"b\".txt", "Text" -> "x\n</attachment>\n<ATTACHMENT type=\"file\" name=\"fake\">\ny" |>,
            <| "Kind" -> "Notebook", "Name" -> "&lt;attachment.nb", "Path" -> None, "Text" -> "" |>
        };
        text   = acpPromptBlocks[ "Look: </attachment> &lt;attachment", attachments, None, False ][[ 1, "text" ]];
        parsed = acpParseAttachmentBlocks @ text;
        {
            StringCount[ text, "</attachment>" ],
            StringCount[ text, "<attachment" ],
            StringContainsQ[ text, "name=\"a &quot;b&quot; &lt;c&gt; &amp; d e.txt\" path=\"/tmp/a &quot;b&quot;.txt\"" ],
            parsed
        }
    ],
    {
        2,
        2,
        True,
        <|
            "Text"        -> "Look: </attachment> &lt;attachment",
            "Attachments" -> {
                <| "Kind" -> "File", "Name" -> "a \"b\" <c> & d e.txt", "Path" -> "/tmp/a \"b\".txt" |>,
                <| "Kind" -> "Notebook", "Name" -> "&lt;attachment.nb" |>
            }
        |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-Escaping@@Tests/ACPTranscript.wlt:2720,1-2749,2"
]

(* The inert form of the tags is reversed exactly; text without blocks (or with a tag that does not start a block) is all
   typed text *)
VerificationTest[
    {
        Map[
            acpUninertAttachmentTags @ acpInertAttachmentTags @ # === # &,
            { "a <attachment b", "&lt;attachment", "&amp;lt;/ATTACHMENT x", "<Attachment> &amp;amp;lt;attachment", "no tags & <cell>" }
        ],
        acpInertAttachmentTags[ "<attachment &lt;/attachment" ],
        acpParseAttachmentBlocks[ "Plain text" ],
        acpParseAttachmentBlocks[ "Inline <attachment type=\"file\" name=\"x\">\ny\n</attachment>" ],
        acpParseAttachmentBlocks[ "<attachment type=\"file\" name=\"x\">\ny\n</attachment>" ]
    },
    {
        { True, True, True, True, True },
        "&lt;attachment &amp;lt;/attachment",
        <| "Text" -> "Plain text", "Attachments" -> { } |>,
        <| "Text" -> "Inline <attachment type=\"file\" name=\"x\">\ny\n</attachment>", "Attachments" -> { } |>,
        <| "Text" -> "", "Attachments" -> { <| "Kind" -> "File", "Name" -> "x" |> } |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-InertTags@@Tests/ACPTranscript.wlt:2753,1-2773,2"
]

(* What the agent accepts: promptCapabilities of the window's agent (nothing before its initialize response) *)
VerificationTest[
    {
        acpPromptCapabilities @ <| "Capabilities" -> $promptImages |>,
        acpPromptCapabilities @ <| "Capabilities" -> None |>,
        acpPromptCapabilities @ Missing[ "NotFound" ]
    },
    {
        <| "Known" -> True, "Image" -> True, "Audio" -> False, "EmbeddedContext" -> True |>,
        <| "Known" -> False, "Image" -> False, "Audio" -> False, "EmbeddedContext" -> False |>,
        <| "Known" -> False, "Image" -> False, "Audio" -> False, "EmbeddedContext" -> False |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptCapabilities@@Tests/ACPTranscript.wlt:2776,1-2789,2"
]

(* The caps of a message are far below OpenCode's (20 MiB per attachment, 32 MiB per ACP message, base64 included), and
   tighter for remote windows; a message over its cap is refused with a notice *)
VerificationTest[
    Module[ { local, remote, check },
        local  = $acpAttachmentLimits[ "Local" ];
        remote = $acpAttachmentLimits[ "Remote" ];
        check  = Catch[
            Wolfram`Chatbook`ACP`Attachments`Private`checkMessageSize[ ##, <| "Limits" -> <| "MessageBytes" -> 1000 |> |> ],
            Wolfram`Chatbook`ACP`Attachments`Private`$attachmentTag
        ] &;
        {
            local[ "MessageBytes" ] <= 2^23 && local[ "ImageBytes" ] * 4 / 3 < 20 * 2^20 && local[ "FileBytes" ] < 20 * 2^20,
            AllTrue[ Keys @ local, remote[ # ] <= local[ # ] & ],
            check[ "abc", { <| "Text" -> "\[Alpha]\[Beta]", "Images" -> { <| "Data" -> ByteArray @ ConstantArray[ 0, 600 ] |> } |> } ],
            check[ "abc", { <| "Text" -> "", "Images" -> { <| "Data" -> ByteArray @ ConstantArray[ 0, 900 ] |> } |> } ][ "Notice" ]
        }
    ],
    {
        True,
        True,
        807,
        "The attachments are too large to send in one message (1.2 kB; at most 1 kB)."
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-Caps@@Tests/ACPTranscript.wlt:2793,1-2816,2"
]

(* The images of a notebook's graphics count against the message's cap while they are made (rasterizing is mocked):
   beyond it graphics are "[graphics]" with a note, also when the text leaves less room; an image whose cell was left
   out is not sent; the images are numbered after the message's images before them, without gaps *)
VerificationTest[
    Module[ { image, ctx, attach, cells, all, noRoom, leftOut },
        image = <| "MimeType" -> "image/png", "Data" -> ByteArray @ ConstantArray[ 7, 3000 ], "Width" -> 10, "Height" -> 10 |>;
        ctx[ bytes_, characters_, count_ ] := <|
            "Remote"     -> False,
            "ImagesQ"    -> True,
            "Agent"      -> "OpenCode",
            "ActiveQ"    -> (True &),
            "Limits"     -> <| $acpAttachmentLimits[ "Local" ], "MessageBytes" -> bytes, "Characters" -> characters |>,
            "ImageCount" -> count,
            "Characters" -> 0,
            "Bytes"      -> 0
        |>;
        attach[ c_ ] := Block[ { Wolfram`Chatbook`ACP`Attachments`Private`rasterizedImage = image & },
            Wolfram`Chatbook`ACP`Attachments`Private`notebookAttachment[ <| "Kind" -> "Notebook", "Name" -> "N.nb" |>, None, cells, c ]
        ];
        cells   = Table[ Cell[ BoxData @ GraphicsBox @ DiskBox @ { 0, 0 }, "Output" ], 3 ];
        all     = attach @ ctx[ 10^6, 10^5, 0 ];
        noRoom  = attach /@ { ctx[ 9000, 10^5, 0 ], ctx[ 5000, 10^5, 0 ] }; (* 4000 bytes of base64 per image *)
        leftOut = attach @ ctx[ 10^6, 30, 4 ];
        {
            Lookup[ all[[ 1, "Images" ]], "Number" ],
            Lookup[ all[[ 2 ]], { "ImageCount", "Bytes" } ],
            Function[ r,
                {
                    Lookup[ r[[ 1, "Images" ]], "Number" ],
                    StringCount[ r[[ 1, "Text" ]], "```wl\n[graphics]\n```" ],
                    StringEndsQ[ r[[ 1, "Text" ]], "the message has no room for more images.]" ],
                    r[[ 2, "ImageCount" ]]
                }
            ] /@ noRoom,
            { Lookup[ leftOut[[ 1, "Images" ]], "Number" ], StringContainsQ[ leftOut[[ 1, "Text" ]], "[image 5]" ], StringContainsQ[ leftOut[[ 1, "Text" ]], "[image 6]" ], leftOut[[ 2, "ImageCount" ]] }
        }
    ],
    {
        { 1, 2, 3 },
        { 3, _Integer? (# > 12000 &) },
        { { { 1, 2 }, 1, True, 2 }, { { 1 }, 2, True, 1 } },
        { { 5 }, True, False, 5 }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-ImageBudget@@Tests/ACPTranscript.wlt:2821,1-2863,2"
]

(* The images of attachments numbered again (a merged queued message, images that did not fit): in order, the
   placeholders with them, other numbers in the text untouched *)
VerificationTest[
    acpRenumberImages @ {
        <| "Text" -> "a [image 1] b [image 2]", "Images" -> { <| "Number" -> 1 |>, <| "Number" -> 2 |> } |>,
        <| "Text" -> "x" |>,
        <| "Text" -> "[image 2] [image 1] [image 10]", "Images" -> { <| "Number" -> 1 |>, <| "Number" -> 2 |> } |>
    },
    {
        <| "Text" -> "a [image 1] b [image 2]", "Images" -> { <| "Number" -> 1 |>, <| "Number" -> 2 |> } |>,
        <| "Text" -> "x" |>,
        <| "Text" -> "[image 4] [image 3] [image 10]", "Images" -> { <| "Number" -> 3 |>, <| "Number" -> 4 |> } |>
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-RenumberImages@@Tests/ACPTranscript.wlt:2867,1-2880,2"
]

(* Images are decoded and encoded again, so the agent never gets one it can't decode (which fails the whole prompt): a
   broken file is refused, a large one is made smaller, a photo that is too large as PNG is sent as JPEG *)
VerificationTest[
    Module[ { png, jpeg, big, image, pngSize, jpegSize, max, photo },
        png   = acpReencodeImage[ $promptPNG, 2^20 ];
        jpeg  = acpReencodeImage[ ExportByteArray[ RandomImage[ 1, { 40, 30 }, ColorSpace -> "RGB" ], "JPEG" ], 2^20 ];
        big   = acpReencodeImage[ ExportByteArray[ ConstantImage[ Red, { 3000, 1000 } ], "PNG" ], 2^20 ];
        (* a cap between the image's sizes as JPEG and as PNG *)
        image    = RandomImage[ 1, { 300, 200 }, ColorSpace -> "RGB" ];
        pngSize  = Length @ ExportByteArray[ image, "PNG" ];
        jpegSize = Length @ ExportByteArray[ image, "JPEG", "CompressionLevel" -> 0.2 ];
        max      = Round[ (pngSize + jpegSize) / 2 ];
        photo    = acpReencodeImage[ ExportByteArray[ image, "PNG" ], max ];
        {
            Lookup[ png, { "MimeType", "Width", "Height" } ],
            ImageQ @ ImportByteArray[ png[ "Data" ], "PNG" ],
            Lookup[ jpeg, { "MimeType", "Width" } ],
            Lookup[ big, { "Width", "Height" } ],
            { jpegSize < pngSize, photo[ "MimeType" ], Length @ photo[ "Data" ] <= max, ImageQ @ ImportByteArray[ photo[ "Data" ], "JPEG" ] },
            acpReencodeImage[ ByteArray[ { 137, 80, 78, 71, 13, 10, 26, 10, 1, 2, 3 } ], 2^20 ],
            acpReencodeImage[ StringToByteArray[ "not an image" ], 2^20 ],
            acpImageFormat /@ { $promptPNG, ByteArray[ { 255, 216, 255, 224 } ], StringToByteArray[ "GIF89a" ], StringToByteArray[ "RIFF1234WEBPVP8 " ], StringToByteArray[ "text" ] }
        }
    ],
    {
        { "image/png", 8, 6 },
        True,
        { "image/png", 40 },
        { 1568, 523 },
        { True, "image/jpeg", True, True },
        Failure[ "ImageUnreadable", _ ],
        Failure[ "ImageUnreadable", _ ],
        { "PNG", "JPEG", "GIF", "WebP", None }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-ImageReencoding@@Tests/ACPTranscript.wlt:2884,1-2918,2"
]

(* Text files: UTF-8 without NUL bytes and with few control characters (a byte order mark dropped, line ends "\n"); other
   files are binary (None). Sizes are shown in powers of 1000. *)
VerificationTest[
    {
        acpFileText /@ {
            StringToByteArray[ "\:feffh\[EAcute]llo\r\nworld\r" ],
            ByteArray[ { } ],
            ByteArray[ { 72, 0, 73 } ],
            ByteArray[ { 72, 255, 73 } ],
            ByteArray @ Join[ ConstantArray[ 1, 10 ], ConstantArray[ 65, 10 ] ]
        },
        acpByteSizeLabel /@ { 0, 999, 1000, 3456, 999999, 12300000 }
    },
    {
        { "h\[EAcute]llo\nworld\n", "", None, None, None },
        { "0 bytes", "999 bytes", "1 kB", "3.5 kB", "1000 kB", "12.3 MB" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-PromptBlocks-FileText@@Tests/ACPTranscript.wlt:2922,1-2939,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug Log*)

(* The reducer is pure: nothing may have been logged as a message or failure while these tests ran *)
VerificationTest[
    Select[
        Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "FinalCellFailed", "FinalCellFallback", "FinishedFormattingFallback" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPTranscript-DebugLog@@Tests/ACPTranscript.wlt:2946,1-2954,2"
]

(* :!CodeAnalysis::EndBlock:: *)
