(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`PermissionDetails`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* The permission details window (see docs/acp-window.md, "Permissions"): the permission panel shows only a few lines of
   a large request (Rendering.wl), and its "View full diff" ("View full command", "View full script") link opens all of
   it here: ChatbookAction[ "ACP", "PermissionDetails", nbo, key ] (acpPermissionDetails).

   Rules:
   * Read only: the window shows the request; it is answered in the panel. Its content is static (front-end-only
     openers, and lazily rendered diffs that load Chatbook), so it stays readable after the request was answered and
     after a kernel restart.
   * One window per ACP window, found by its TaggingRules ({"ACPPermissionDetails", "Owner"}, so also after a kernel
     restart): another link replaces its content and keeps its place. It closes with the ACP window (acpWindowClosed).
   * The link names the request with acpPermissionKey (a hash of the request instance), never with the agent's text; the
     request is looked up among the window's pending requests.
   * A deployed notebook like the review window (Review.wl: the same stylesheet, placement, cards and display-safe text),
     excluded from chat and from the notebook tools.
   * The whole diff, bounded: the first $detailsGridRows rows of each file's diff in a card (cards after the first one
     start closed if they are long, and are rendered when opened), the rest of its rows as plain text after the card,
     and at most $detailsMaxText characters of text in a window. The window is built in steps of about
     $detailsStepTime seconds in the pump (detailsStep), as the review window is: a file's card is one step, its text
     follows in items of $detailsTextLines lines, whose rows are made when they are written (Rendering.wl's
     acpDiffRowSource), so a step of a file of 100,000 lines is not longer than one of a small file.
   * A window whose content can't be written to the end (a step failed, or the kernel was restarted while it was
     written: acpPermissionDetailsRecover) says that it is incomplete instead of "Loading..." for good.
   * The diff lines, paths, commands and scripts are the agent's text: made display-safe (acpReviewSafeLines,
     acpRemoteDisplayName: the front end's linear syntax neutralized, bidi controls shown as markers). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$detailsGridRows   = 400;     (* rows of a file's diff in its card, as in the review window *)
$detailsOpenRows   = 300;     (* cards after the first start closed with more rows than this... *)
$detailsOpenBudget = 1200;    (* ...or when the open cards would have more rows than this in all *)
$detailsTextLines  = 500;     (* lines per text cell (the rest of a large diff, a command, a script) *)
$detailsMaxText    = 2*10^6;  (* characters of text in a window; the rest is left out with a note *)
$detailsLineLength = 300;     (* characters of a diff line (the lines of commands and scripts are not cut) *)
$detailsStepTime   = 0.15;    (* seconds of work per step of building the window (see detailsStep) *)
$detailsCodeFont   = "Source Code Pro";
$detailsLoadingTag = "ACPPermissionDetailsLoading"; (* the cell tag of the window's "Loading..." before the first step *)
$detailsBackground = LightDarkSwitched[ GrayLevel[ 1.0 ], GrayLevel[ 0.12 ] ]; (* the review window's *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* Details windows of this kernel session: NotebookObject -> <| "Token" -> the token of its latest content, "Job" -> the
   content that is being written (see detailsStep) |>. Entries of closed windows are dropped when a window opens. *)
If[ ! AssociationQ @ $detailsWindows, $detailsWindows = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Opening*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionDetails*)

(* ChatbookAction[ "ACP", "PermissionDetails", nbo, key ] (the panel's link, preemptive): shows the pending request whose
   acpPermissionKey is key in the details window of the ACP window nbo. Gives the details window, or a Missing if the
   request is no longer pending (it was answered meanwhile) or has nothing to show. *)
acpPermissionDetails // beginDefinition;

acpPermissionDetails[ owner_NotebookObject, key_String ] := Catch @ Module[ { window, pending, reqID, data },
    acpCheckSession @ owner;
    window  = acpWindowGet @ owner;
    pending = If[ AssociationQ @ window, Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ], <| |> ];
    reqID   = SelectFirst[ Keys @ pending, acpPermissionKey[ #, Replace[ pending[ # ], Except[ _Association ] -> <| |> ] ] === key &, Missing[ "NotPending" ] ];
    If[ MissingQ @ reqID, acpLog[ "PermissionDetailsNotPending", <| "Notebook" -> owner |> ]; Throw @ reqID ];
    data = acpPermissionDetailsData[ window, reqID, pending[ reqID ] ];
    If[ data[ "Kind" ] === None, Throw @ Missing[ "NothingToShow" ] ];
    detailsOpen[ owner, data ]
];

acpPermissionDetails // endDefinition;


(* Shows "Loading..." in the details window of owner (a new one, placed like the review window, or the open one, which
   keeps its place), and builds its content in the pump *)
detailsOpen // beginDefinition;

detailsOpen[ owner_NotebookObject, data_Association ] := Module[ { details, token, nb },
    $detailsWindows = KeySelect[ $detailsWindows, MemberQ[ Notebooks[ ], # ] & ];
    details = acpPermissionDetailsWindowOf @ owner;
    token   = CreateUUID[ "details-" ];
    nb      = acpPermissionDetailsNotebook[
        data,
        owner,
        If[ MatchQ[ details, _NotebookObject ], False, acpReviewWindowGeometry @ owner ],
        { detailsLoadingCell[ ] },
        True
    ];
    If[ MatchQ[ details, _NotebookObject ],
        acpReviewPut[ details, nb ];
        SetSelectedNotebook @ details,
        details = NotebookPut @ nb
    ];
    If[ ! MatchQ[ details, _NotebookObject ], Return[ Missing[ "NotOpened" ], Module ] ];
    (* protected, so that a step of an earlier job can't see the new token before the job is stored *)
    PreemptProtect[ $detailsWindows[ details ] = <| "Token" -> token, "Job" -> detailsNewJob[ data, owner ] |> ];
    With[ { d = details, t = token }, acpSchedule @ detailsStep[ d, t ] ];
    details
];

detailsOpen // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionDetailsWindowOf*)

(* The details window of an ACP window (found by its TaggingRules), or None *)
acpPermissionDetailsWindowOf // beginDefinition;

acpPermissionDetailsWindowOf[ owner_NotebookObject ] := If[ $FrontEnd === Null,
    None,
    SelectFirst[ Notebooks[ ], Quiet @ CurrentValue[ #, { TaggingRules, "ACPPermissionDetails", "Owner" } ] === owner &, None ]
];

acpPermissionDetailsWindowOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionDetailsCloseWindow*)

(* Closes the details window of an ACP window that closes (acpWindowClosed, acpCloseWindow in UI.wl) *)
acpPermissionDetailsCloseWindow // beginDefinition;

acpPermissionDetailsCloseWindow[ owner_NotebookObject ] := With[ { details = acpPermissionDetailsWindowOf @ owner },
    If[ MatchQ[ details, _NotebookObject ],
        KeyDropFrom[ $detailsWindows, details ];
        Quiet @ NotebookClose @ details
    ];
    Null
];

acpPermissionDetailsCloseWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionDetailsRecover*)

(* After a kernel restart (scheduled by UI.wl's acpRefreshWindowUI, like the other windows' recoveries): the job of a
   details window that was still being written is gone with the old kernel, and the link that opened it with the pending
   request. A window of the ACP window owner whose TaggingRules still say "Loading" and that has no job in this kernel
   says that its content is incomplete (detailsIncomplete). *)
acpPermissionDetailsRecover // beginDefinition;

acpPermissionDetailsRecover[ owner_NotebookObject ] := With[ { details = acpPermissionDetailsWindowOf @ owner },
    If[ And[
            MatchQ[ details, _NotebookObject ],
            ! AssociationQ @ Lookup[ Lookup[ $detailsWindows, details, <| |> ], "Job", None ],
            TrueQ @ Quiet @ CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Loading" } ]
        ],
        acpLog[ "PermissionDetailsInterrupted", <| "Notebook" -> owner |> ];
        detailsIncomplete @ details
    ];
    Null
];

acpPermissionDetailsRecover // endDefinition;


(* A window whose content can't be written to the end (a step failed, or the kernel that wrote it was restarted): its
   header loses "Loading..." and says that the content is incomplete, and so does a note after the last cell (in place
   of the "Loading..." of a window that got no content yet). The header comes from the window's TaggingRules. *)
detailsIncomplete // beginDefinition;

detailsIncomplete[ details_NotebookObject ] := Module[ { header, note, loading },
    header  = Replace[
        Quiet @ CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Header" } ],
        { rules: { ___Rule } :> Association @ rules, a_Association :> a, _ :> <| |> }
    ];
    note    = detailsCaptionCell @ acpLabel[ "PermissionDetailsIncomplete" ];
    loading = Replace[ Quiet @ Cells[ details, CellTags -> $detailsLoadingTag ], Except[ { ___CellObject } ] -> { } ];
    If[ loading =!= { },
        Quiet @ NotebookWrite[ First @ loading, note, None, AutoScroll -> False ];
        Quiet @ NotebookDelete @ Rest @ loading,
        acpReviewAppendCells[ details, { note } ]
    ];
    detailsSetHeader[ details, header, "Incomplete" ];
    Null
];

detailsIncomplete // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Building the Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*detailsStep*)

(* Writes the content in steps, one per pump tick, each about $detailsStepTime seconds of work (at least one item): the
   first step replaces the window's notebook (reviewPut: it keeps its place and shows the top), later steps append
   cells. The header says "Loading..." until the last step (also in the window's TaggingRules, {"ACPPermissionDetails",
   "Loading"}). A job is dropped when another link replaces it or the window is closed. A step that fails ends the job:
   the window says that its content is incomplete (detailsIncomplete), as after a kernel restart. *)
detailsStep // beginDefinition;

detailsStep[ details_NotebookObject, token_String ] := Module[ { job, step, failed = False },
    job = Lookup[ Lookup[ $detailsWindows, details, <| |> ], "Job", None ];
    If[ ! detailsCurrentQ[ details, token ] || ! AssociationQ @ job, Return[ Null, Module ] ];
    If[ ! MemberQ[ Notebooks[ ], details ], KeyDropFrom[ $detailsWindows, details ]; Return[ Null, Module ] ];
    step = acpCatchAll[
        detailsWriteStep[ details, token, job ],
        (acpLog[ "PermissionDetailsStepFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; $Failed) &
    ];
    (* Unless another link replaced the job meanwhile (the link is preemptive): *)
    PreemptProtect @ If[ detailsCurrentQ[ details, token ],
        Which[
            ! AssociationQ @ step,
                $detailsWindows[ details ] = KeyDrop[ $detailsWindows[ details ], "Job" ];
                failed = True,
            step[ "Next" ] > Length @ step[ "Items" ],
                $detailsWindows[ details ] = KeyDrop[ $detailsWindows[ details ], "Job" ],
            True,
                $detailsWindows[ details ] = <| $detailsWindows[ details ], "Job" -> step |>;
                With[ { d = details, t = token }, acpSchedule @ detailsStep[ d, t ] ]
        ]
    ];
    If[ failed, acpCatchAll @ detailsIncomplete @ details ];
    Null
];

detailsStep // endDefinition;


(* The cells of one step, written to the window: the job after it *)
detailsWriteStep // beginDefinition;

detailsWriteStep[ details_NotebookObject, token_String, job0_Association ] := Module[ { cells, job, done },
    { cells, job } = detailsCellsStep[ job0, AbsoluteTime[ ] + $detailsStepTime ];
    done = job[ "Next" ] > Length @ job[ "Items" ];
    Which[
        ! detailsCurrentQ[ details, token ],
            Null,
        ! TrueQ @ job[ "Put" ],
            acpReviewPut[ details, acpPermissionDetailsNotebook[ job[ "Data" ], job[ "Owner" ], False, cells, ! done ] ];
            job[ "Put" ] = True,
        True,
            acpReviewAppendCells[ details, cells ];
            If[ done, detailsSetHeader[ details, detailsHeader @ job[ "Data" ], False ] ]
    ];
    job
];

detailsWriteStep // endDefinition;


detailsCurrentQ // beginDefinition;
detailsCurrentQ[ details_NotebookObject, token_ ] := Lookup[ Lookup[ $detailsWindows, details, <| |> ], "Token", None ] === token;
detailsCurrentQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Jobs*)

(* The job of a request (see acpPermissionDetailsData): its items are the files of a diff (each adds the chunks of its
   text after it, see detailsItemCells), or the chunks of the command or script *)
detailsNewJob // beginDefinition;

detailsNewJob[ data_Association, owner_ ] := <|
    "Data"     -> data,
    "Owner"    -> owner,
    "Items"    -> If[ data[ "Kind" ] === "Diff",
        MapIndexed[ <| "File" -> #1, "Index" -> First @ #2 |> &, Replace[ data[ "Files" ], Except[ _List ] -> { } ] ],
        detailsTextChunks @ StringSplit[ Replace[ data[ "Text" ], Except[ _String ] -> "" ], "\n", All ]
    ],
    "Next"     -> 1,
    "Put"      -> False,
    "Budget"   -> $detailsMaxText,
    "OpenRows" -> 0
|>;

detailsNewJob // endDefinition;


(* Items of $detailsTextLines lines each, in a group (the lines of a command or script): the lines of each item, with
   the number of lines and characters after the item in its group, for the note of what a window leaves out (sizes: the
   characters of each line) *)
detailsTextChunks // beginDefinition;

detailsTextChunks[ { } ] := { };

detailsTextChunks[ lines_List ] := Module[ { ranges, counts, sums, chars },
    ranges = detailsRanges @ Length @ lines;
    counts = ranges[[ All, 2 ]] - ranges[[ All, 1 ]] + 1;
    (* the characters of a chunk's lines, with a line break each *)
    sums   = Accumulate @ StringLength @ lines;
    chars  = sums[[ ranges[[ All, 2 ]] ]] - Prepend[ sums[[ Most @ ranges[[ All, 2 ]] ]], 0 ] + counts;
    MapThread[
        <| "Group" -> "Text", "Lines" -> lines[[ #1[[ 1 ]] ;; #1[[ 2 ]] ]], "LeftLines" -> #2, "LeftChars" -> #3 |> &,
        { ranges, detailsLeftCounts @ counts, detailsLeftCounts @ chars }
    ]
];

detailsTextChunks // endDefinition;


(* The rows of a file's diff after the first skip ones (those of its card), in items of $detailsTextLines rows: ranges
   of rows of its source (acpDiffRowSource), whose rows are made when the item is written. The characters after an item
   ("LeftChars") are counted only when a window's text budget runs out there (detailsLeftChars): a step of a file of
   100,000 lines makes only the rows of its card. *)
detailsRowChunks // beginDefinition;

detailsRowChunks[ source_Association, skip_Integer, info_Association ] := Module[ { ranges, counts },
    ranges = detailsRanges[ source[ "Count" ] - skip ];
    counts = ranges[[ All, 2 ]] - ranges[[ All, 1 ]] + 1;
    MapThread[
        <| info, "Source" -> source, "Range" -> #1 + skip, "LeftLines" -> #2, "LeftChars" -> Automatic |> &,
        { ranges, detailsLeftCounts @ counts }
    ]
];

detailsRowChunks // endDefinition;


(* The ranges { a, b } of the items of n lines *)
detailsRanges // beginDefinition;
detailsRanges[ n_Integer ] /; n <= 0 := { };
detailsRanges[ n_Integer ] := Table[ { a, Min[ a + $detailsTextLines - 1, n ] }, { a, 1, n, $detailsTextLines } ];
detailsRanges // endDefinition;


(* The sums of the counts after each one *)
detailsLeftCounts // beginDefinition;
detailsLeftCounts[ { } ] := { };
detailsLeftCounts[ counts_List ] := Reverse @ Most @ FoldList[ Plus, 0, Reverse @ counts ];
detailsLeftCounts // endDefinition;


(* The characters after an item in its group: those of the rows of the source after the item's rows (in a text cell:
   the numbers, the mark and the line, cut, with a line break each) *)
detailsLeftChars // beginDefinition;

detailsLeftChars[ KeyValuePattern[ "LeftChars" -> n_Integer ] ] := n;

detailsLeftChars[ KeyValuePattern @ { "Source" -> source_Association, "Range" -> { _, b_Integer }, "Widths" -> widths_List } ] :=
    With[
        {
            columns = Total[ If[ # > 0, # + 1, 0 ] & /@ widths ] + 2,
            lengths = acpDiffSourceLineLengths[ source, { b + 1, source[ "Count" ] } ]
        },
        Total[ columns + Clip[ lengths, { 0, $detailsLineLength + 1 } ] ] + Length @ lengths
    ];

detailsLeftChars // endDefinition;


(* The cells of items until the deadline (at least one item): { cells, job } *)
detailsCellsStep // beginDefinition;

detailsCellsStep[ job0_Association, deadline_ ] := Module[ { job = job0, cells = Internal`Bag[ ], first = job0[ "Next" ], new },
    While[ job[ "Next" ] <= Length @ job[ "Items" ] && (job[ "Next" ] === first || AbsoluteTime[ ] < deadline),
        { new, job } = detailsItemCells[ job[ "Items" ][[ job[ "Next" ] ]], job ];
        Scan[ Internal`StuffBag[ cells, # ] &, new ];
        job[ "Next" ] = job[ "Next" ] + 1
    ];
    { Internal`BagPart[ cells, All ], job }
];

detailsCellsStep // endDefinition;


(* All cells of a request at once (for tests; the window is built in steps) *)
detailsCells // beginDefinition;
detailsCells[ data_Association ] := First @ detailsCellsStep[ detailsNewJob[ data, None ], Infinity ];
detailsCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*detailsItemCells*)

(* The cells of one item: { cells, job } (the job's text budget, open rows and items are updated) *)
detailsItemCells // beginDefinition;

(* A file of a diff: a card with the first $detailsGridRows rows (with line numbers); the rest of its rows follow as
   text (also after a card that starts closed: the window shows the whole diff), in items after this one. Only the
   card's rows are made here: the items make theirs from the diff's row source (acpDiffRowSource), so that a step of a
   file of 100,000 lines is not longer than one of a small file. *)
detailsItemCells[ KeyValuePattern @ { "File" -> file_Association, "Index" -> i_Integer }, job_Association ] := Module[
    { diff, source, stats, shown, rest, open, data, note, body, widths },
    diff   = file[ "Diff" ];
    source = acpDiffRowSource @ diff;
    stats  = acpDiffStats @ diff;
    shown  = acpDiffSourceRows[ source, { 1, Min[ source[ "Count" ], $detailsGridRows ] } ];
    rest   = source[ "Count" ] - Length @ shown;
    open   = i === 1 || Length @ shown <= $detailsOpenRows && job[ "OpenRows" ] + Length @ shown <= $detailsOpenBudget;
    (* the data of the diff view, which a closed card keeps (in its code) until it is opened: display-safe text only *)
    data   = <| "Path" -> acpNeutralizeLinearSyntax @ file[ "Path" ], "Rows" -> detailsSafeRows @ shown, "Omitted" -> 0 |>;
    note   = If[ detailsAlignedQ @ diff, Nothing, Style[ acpLabel[ "DiffNotAligned" ], FontColor -> acpColor[ "Muted" ], FontSize -> 11 ] ];
    body   = Column[ { If[ open, acpReviewDiffView @ data, acpReviewLazyDiff @ data ], note }, Spacings -> 0.5 ];
    (* the widths of the number columns of all rows (a column without numbers, e.g. the old one of a new file, is left
       out) *)
    widths = Replace[ source[ "MaxNumbers" ], { m_Integer? Positive :> IntegerLength @ m, _ -> 0 }, { 1 } ];
    {
        Flatten @ {
            acpReviewFileCard[
                <|
                    "Path"    -> file[ "Path" ],
                    "Badge"   -> Switch[ file[ "Badge" ], "NewFile", acpLabel[ "BadgeNewFile" ], "ContentsWritten", acpLabel[ "BadgeContentsWritten" ], _, None ],
                    "Added"   -> First @ stats,
                    "Deleted" -> Last @ stats
                |>,
                body,
                open,
                "ACPPermissionDetailsFile-" <> ToString @ i
            ],
            If[ rest === 0, Nothing, detailsCaptionCell @ acpLabel[ "PermissionDetailsContinued", <| "n" -> rest |> ] ]
        },
        <|
            detailsInsertItems[ job, detailsRowChunks[ source, Length @ shown, <| "Group" -> i, "Widths" -> widths |> ] ],
            "OpenRows" -> job[ "OpenRows" ] + If[ open, Length @ shown, 0 ]
        |>
    }
];

(* Rows of the rest of a diff as text: lines like "  12   14 + line" (old and new line numbers, then +, - or a space,
   then the line; the hunk headers and the "..." of skipped lines as they are) *)
detailsItemCells[ item: KeyValuePattern @ { "Source" -> source_Association, "Range" -> range_List, "Widths" -> widths_List }, job_Association ] :=
    With[ { rows = PadRight[ #, 4, None ] & /@ acpDiffSourceRows[ source, range ] },
        detailsChunkCells[
            MapThread[
                StringJoin[ numberColumn[ #1[[ 3 ]], widths[[ 1 ]] ], numberColumn[ #1[[ 4 ]], widths[[ 2 ]] ], rowMark @ #1[[ 1 ]], #2 ] &,
                { rows, acpReviewSafeLines[ rows[[ All, 2 ]], $detailsLineLength ] }
            ],
            item,
            job
        ]
    ];

(* Lines of the command or the script: display-safe and not cut (what is approved is all of it) *)
detailsItemCells[ item: KeyValuePattern[ "Lines" -> lines_List ], job_Association ] :=
    detailsChunkCells[ acpReviewSafeLines[ lines, Infinity ], item, job ];

detailsItemCells // endDefinition;


(* Adds items after the current one *)
detailsInsertItems // beginDefinition;

detailsInsertItems[ job_Association, { } ] := job;

detailsInsertItems[ job_Association, items_List ] := <|
    job,
    "Items" -> Join[ Take[ job[ "Items" ], job[ "Next" ] ], items, Drop[ job[ "Items" ], job[ "Next" ] ] ]
|>;

detailsInsertItems // endDefinition;


(* Rows with display-safe lines cut to $detailsLineLength characters *)
detailsSafeRows // beginDefinition;
detailsSafeRows[ { } ] := { };
detailsSafeRows[ rows_List ] := MapThread[ ReplacePart[ #1, 2 -> #2 ] &, { rows, acpReviewSafeLines[ rows[[ All, 2 ]], $detailsLineLength ] } ];
detailsSafeRows // endDefinition;


(* False for a line diff whose changed lines were not all compared line by line (see acpLineDiff) *)
detailsAlignedQ // beginDefinition;

detailsAlignedQ[ diff_Association ] := Or[
    StringQ @ Lookup[ diff, "Patch", None ],
    TrueQ @ Lookup[ diff, "Write", False ],
    TrueQ @ acpLineDiffInfo[
        Replace[ Lookup[ diff, "OldText", None ], Except[ _String ] -> "" ],
        Replace[ Lookup[ diff, "NewText", None ], Except[ _String ] -> "" ]
    ][ "Aligned" ]
];

detailsAlignedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Text*)

numberColumn // beginDefinition;
numberColumn[ _, 0 ] := "";
numberColumn[ n_Integer, w_Integer ] := StringPadLeft[ IntegerString @ n, w ] <> " ";
numberColumn[ _, w_Integer ] := StringRepeat[ " ", w + 1 ];
numberColumn // endDefinition;


rowMark // beginDefinition;
rowMark[ "+" ] := "+ ";
rowMark[ "-" ] := "- ";
rowMark[ "=" ] := "  ";
rowMark[ _ ] := "";
rowMark // endDefinition;


(* A text cell of the display-safe lines of a chunk item, while the window's budget of characters lasts; past it, the
   part that fits and a note of what is left out of the chunk's group (whose later items are dropped): { cells, job } *)
detailsChunkCells // beginDefinition;

detailsChunkCells[ lines_List, item_Association, job_Association ] := Module[ { budget, text },
    budget = job[ "Budget" ];
    text   = StringRiffle[ lines, "\n" ];
    Which[
        budget <= 0,
            {
                { detailsCaptionCell @ acpLabel[ "TruncatedMoreLines", <| "n" -> Length @ lines + item[ "LeftLines" ] |> ] },
                detailsDropGroup[ job, item[ "Group" ] ]
            },
        StringLength @ text > budget,
            {
                {
                    detailsTextCell @ StringTake[ text, budget ],
                    detailsCaptionCell @ acpLabel[ "TruncatedMoreCharacters", <| "n" -> StringLength @ text - budget + detailsLeftChars @ item |> ]
                },
                <| detailsDropGroup[ job, item[ "Group" ] ], "Budget" -> 0 |>
            },
        True,
            { { detailsTextCell @ text }, <| job, "Budget" -> budget - StringLength @ text |> }
    ]
];

detailsChunkCells // endDefinition;


(* Drops the items after the current one that belong to a group *)
detailsDropGroup // beginDefinition;

detailsDropGroup[ job_Association, group_ ] := <|
    job,
    "Items" -> Join[ Take[ job[ "Items" ], job[ "Next" ] ], Select[ Drop[ job[ "Items" ], job[ "Next" ] ], Lookup[ #, "Group", None ] =!= group & ] ]
|>;

detailsDropGroup // endDefinition;


(* Plain text in the code font, wrapped at the window's width: a string cell, which takes little time to lay out. A
   command is not prose: no spell checking (it underlined "dev" in /dev/null). *)
detailsTextCell // beginDefinition;

detailsTextCell[ text_String ] := Cell[
    text,
    "ACPReviewFile",
    Background           -> LightDarkSwitched[ GrayLevel[ 0.98 ], GrayLevel[ 0.13 ] ],
    CellFrame            -> 1,
    CellFrameColor       -> acpColor[ "CardFrame" ],
    CellFrameMargins     -> { { 8, 8 }, { 5, 5 } },
    FontFamily           -> $detailsCodeFont,
    FontSize             -> 12,
    LineBreakWithin      -> Automatic,
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    ShowAutoSpellCheck   -> False,
    ShowStringCharacters -> False
];

detailsTextCell // endDefinition;


detailsCaptionCell // beginDefinition;
detailsCaptionCell[ text_String ] := Cell[ BoxData @ acpReviewCellBoxes @ Style[ text, FontColor -> acpColor[ "Muted" ], FontSlant -> Italic ], "ACPReviewNotice" ];
detailsCaptionCell // endDefinition;


detailsLoadingCell // beginDefinition;

detailsLoadingCell[ ] := Cell[
    BoxData @ acpReviewCellBoxes @ Row @ { ProgressIndicator[ Appearance -> "Percolate" ], "  ", acpLabel[ "PermissionDetailsLoading" ] },
    "ACPReviewMessage",
    CellTags -> $detailsLoadingTag
];

detailsLoadingCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionDetailsNotebook*)

(* The details notebook (pure) for the data of a request (see acpPermissionDetailsData) with the given cells. owner: the
   ACP window. new: for a new window its geometry (see acpReviewWindowGeometry) or True (the default size); False for an
   open window. loading: whether the header says "Loading...". Not a chat notebook: deployed, read only, excluded from
   chat (and so from the notebook tools), the owner's kernel as its evaluator. *)
acpPermissionDetailsNotebook // beginDefinition;

acpPermissionDetailsNotebook[ data_Association, owner_, new_, cells_List, loading_ ] := Notebook[
    cells,
    Sequence @@ {
        DockedCells             -> { detailsDockedCell[ detailsHeader @ data, TrueQ @ loading ] },
        StyleDefinitions        -> acpReviewStyleSheet @ Union[ { "Directory" }, acpFileIconName /@ Cases[ Lookup[ data, "Files", { } ], KeyValuePattern[ "Path" -> p_String ] :> p ] ],
        (* the header is kept for the recovery after a kernel restart (acpPermissionDetailsRecover) *)
        TaggingRules            -> <|
            "ACPPermissionDetails" -> <| "Owner" -> owner, "Header" -> detailsHeader @ data, "Loading" -> TrueQ @ loading |>,
            "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
        |>,
        WindowTitle             -> acpRemoteDisplayName @ Replace[ data[ "Headline" ], Except[ _String ] -> "" ],
        Evaluator               -> acpReviewEvaluator @ owner,
        Sequence @@ acpReviewWindowOptions @ new,
        CellGrouping            -> Manual,
        CellInsertionPointCell  -> None,
        CellInsertionPointColor -> $detailsBackground,
        ClosingAutoSave         -> False,
        Deployed                -> True,
        Editable                -> False,
        Saveable                -> False,
        ShowCellBracket         -> False,
        WindowElements          -> { "VerticalScrollBar", "MagnificationPopUp" },
        WindowToolbars          -> { }
    }
];

acpPermissionDetailsNotebook // endDefinition;


(* The header: the request's headline (display-safe, wrapped) and the number of files (or of lines), with
   "Loading..." while the content is written (state True), or the note that it is incomplete ("Incomplete") *)
detailsDockedCell // beginDefinition;

detailsDockedCell[ header_Association, state_ ] := Cell[
    BoxData @ acpReviewCellBoxes @ Framed[
        Column[
            {
                Style[
                    acpRemoteDisplayName @ Replace[ Lookup[ header, "Headline", "" ], Except[ _String ] -> "" ],
                    FontWeight      -> "DemiBold",
                    FontSize        -> 14,
                    LineBreakWithin -> Automatic
                ],
                Style[
                    Row[
                        Flatten @ {
                            Replace[ Lookup[ header, "Count", None ], { s_String :> acpRemoteDisplayName @ s, _ -> Nothing } ],
                            Switch[ state,
                                True        , acpLabel[ "PermissionDetailsLoading" ],
                                "Incomplete", acpLabel[ "PermissionDetailsIncomplete" ],
                                _           , Nothing
                            ]
                        },
                        " \[CenterDot] "
                    ],
                    FontColor -> acpColor[ "Muted" ],
                    FontSize  -> 12
                ]
            },
            Alignment -> Left,
            Spacings  -> 0.3
        ],
        FrameMargins -> 0,
        FrameStyle   -> None,
        ImageSize    -> Full
    ],
    "ACPReviewHeader"
];

detailsDockedCell // endDefinition;


(* What the header shows of a request (see acpPermissionDetailsData): its headline (the agent's text: display-safe, and
   made so again when it is shown, since the window's TaggingRules keep it) and the number of files or lines *)
detailsHeader // beginDefinition;

detailsHeader[ data_Association ] := <|
    "Headline" -> acpRemoteDisplayName @ Replace[ Lookup[ data, "Headline", "" ], Except[ _String ] -> "" ],
    "Count"    -> Replace[ detailsCountLabel @ data, Except[ _String ] -> None ]
|>;

detailsHeader // endDefinition;


(* The header of the window, and the loading flag in its TaggingRules *)
detailsSetHeader // beginDefinition;

detailsSetHeader[ details_NotebookObject, header_Association, state_ ] := (
    Quiet @ SetOptions[ details, DockedCells -> { detailsDockedCell[ header, state ] } ];
    Quiet[ CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Loading" } ] = TrueQ @ state ];
    Null
);

detailsSetHeader // endDefinition;


detailsCountLabel // beginDefinition;

detailsCountLabel[ KeyValuePattern @ { "Kind" -> "Diff", "Files" -> files_List } ] :=
    If[ Length @ files === 1, acpLabel[ "ReviewFileCountOne" ], acpLabel[ "ReviewFileCount", <| "n" -> Length @ files |> ] ];

detailsCountLabel[ KeyValuePattern[ "Text" -> text_String ] ] := With[ { n = Length @ StringSplit[ text, "\n", All ] },
    If[ n === 1, acpLabel[ "SummaryLine" ], acpLabel[ "SummaryLines", <| "n" -> n |> ] ]
];

detailsCountLabel[ _ ] := Nothing;

detailsCountLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
