(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPPermissionDetails.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPPermissionDetails.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-LoadACPContext@@Tests/ACPPermissionDetails.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)

(* The permission details window (PermissionDetails.wl): the "View full ..." link of the permission panel opens the whole
   diff (command, script) of a pending request in a read-only window. These tests check the data, the notebook and its
   cells without a front end; one test opens a real window and is skipped without a front end. *)
VerificationTest[
    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = True;
    $pdtLogStart = AbsoluteTime[ ];
    $pdtOwner    = NotebookObject[ "ACPPermissionDetailsTest", 1 ];
    $pdtOptions  = {
        <| "optionId" -> "once"  , "kind" -> "allow_once"  , "name" -> "Allow once"   |>,
        <| "optionId" -> "always", "kind" -> "allow_always", "name" -> "Always allow" |>,
        <| "optionId" -> "reject", "kind" -> "reject_once" , "name" -> "Reject"       |>
    };
    pdtLine[ i_ ] := "    result_" <> ToString[ i ] <> " = compute(alpha * " <> ToString[ i ] <> ")";
    pdtFile[ n_ ] := StringRiffle[ pdtLine /@ Range[ n ], "\n" ] <> "\n";
    (* a pending request as the window record keeps it (OpenCode 2.0.26: whole files in the diffs) *)
    pdtRequest[ toolCall_Association ] := <| "TurnID" -> None, "ArrivedAt" -> 1000.25, "Params" -> <| "toolCall" -> toolCall, "options" -> $pdtOptions |> |>;
    pdtDiffRequest[ name_, diffs_List ] := pdtRequest @ <|
        "toolCallId" -> "call_pdt", "name" -> name, "title" -> diffs[[ 1, 1 ]], "kind" -> "edit", "status" -> "pending",
        "locations"  -> { <| "path" -> diffs[[ 1, 1 ]] |> },
        "content"    -> ( <| "type" -> "diff", "path" -> #1, "oldText" -> #2, "newText" -> #3 |> & @@@ diffs )
    |>;
    pdtShellRequest[ command_String ] := pdtRequest @ <| "toolCallId" -> "call_sh", "name" -> "bash", "title" -> "command", "kind" -> "execute", "rawInput" -> <| "command" -> command |> |>;
    pdtScriptRequest[ code_String ] := pdtRequest @ <| "toolCallId" -> "call_js", "name" -> "execute", "title" -> "execute", "kind" -> "other", "rawInput" -> <| "code" -> code |> |>;
    pdtWindow[ pending_Association ] := <|
        "Notebook" -> $pdtOwner, "Status" -> "Running", "ProjectDirectory" -> "/project",
        "AgentInfo" -> <| "Name" -> "OpenCode", "Version" -> "2.0.26" |>, "PendingPermissions" -> pending
    |>;
    pdtData[ info_Association ] := acpPermissionDetailsData[ pdtWindow @ <| 3 -> info |>, 3, info ];
    pdtCells[ info_Association ] := Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsCells @ pdtData @ info;
    (* the rows of the diff grids, the texts of the string cells, and the box strings of cells *)
    pdtGridRows[ expr_ ] := Cases[ expr, GridBox[ rows_, ___, GridBoxBackground -> _, ___ ] :> Length @ rows, Infinity ];
    pdtTexts[ cells_ ] := Cases[ cells, Cell[ s_String, "ACPReviewFile", ___ ] :> s ];
    pdtStrings[ expr_ ] := Cases[ expr, s_String :> StringTrim[ s, "\"" ], Infinity ];
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Definitions@@Tests/ACPPermissionDetails.wlt:36,1-70,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Data*)

(* What the window shows for a request: the diffs (paths relative to the project folder, a badge for new files), the
   command, the script; nothing for a request without any (e.g. a call of the notebook tools) *)
VerificationTest[
    Module[ { write, edit, shell, script, tool },
        write  = pdtData @ pdtDiffRequest[ "write", { { "/project/src/big.py", Null, "a\nb\n" } } ];
        edit   = pdtData @ pdtDiffRequest[ "edit", { { "/project/a.py", "x\n", "y\n" }, { "/elsewhere/b.py", "p\n", "q\n" } } ];
        shell  = pdtData @ pdtShellRequest[ "echo hi\nls" ];
        script = pdtData @ pdtScriptRequest[ "  return 1;\n" ];
        tool   = pdtData @ pdtRequest @ <| "toolCallId" -> "c", "name" -> "WolframNotebooks_InsertCells", "rawInput" -> <| "notebook" -> "x", "markdown" -> "y" |> |>;
        {
            KeyTake[ write, { "Kind", "Headline", "Agent", "Remote", "Text" } ],
            #[ "Path" ] & /@ write[ "Files" ],
            #[ "Badge" ] & /@ write[ "Files" ],
            KeyTake[ First @ write[ "Files" ], "Diff" ][ "Diff", "NewText" ],
            #[ "Path" ] & /@ edit[ "Files" ],
            #[ "Badge" ] & /@ edit[ "Files" ],
            KeyTake[ shell, { "Kind", "Headline", "Text" } ],
            KeyTake[ script, { "Kind", "Text" } ],
            tool[ "Kind" ]
        }
    ],
    {
        <| "Kind" -> "Diff", "Headline" -> "OpenCode wants to write src/big.py", "Agent" -> "OpenCode", "Remote" -> False, "Text" -> None |>,
        { "src/big.py" },
        { "NewFile" },
        "a\nb\n",
        { "a.py", "/elsewhere/b.py" },
        { None, None },
        <| "Kind" -> "Command", "Headline" -> "OpenCode wants to run a command", "Text" -> "echo hi\nls" |>,
        <| "Kind" -> "Script", "Text" -> "return 1;" |>,
        None
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Data@@Tests/ACPPermissionDetails.wlt:78,1-110,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Notebook*)

(* A read-only window like the review window: deployed, not editable or saveable, excluded from chat (and so from the
   notebook tools), the owner's kernel, a magnification menu, found again by its TaggingRules *)
VerificationTest[
    Module[ { data, nb, opts, header },
        data   = pdtData @ pdtDiffRequest[ "write", { { "/project/big.py", Null, "a\n" } } ];
        nb     = acpPermissionDetailsNotebook[ data, $pdtOwner, <| "WindowSize" -> { 700, 600 }, "WindowMargins" -> { { 10, Automatic }, { Automatic, 20 } } |>, { }, True ];
        opts   = Association @ Rest[ List @@ nb ];
        header = First @ opts[ DockedCells ];
        {
            First @ nb,
            Lookup[ opts, { Deployed, Editable, Saveable, ClosingAutoSave, WindowSize, WindowMargins } ],
            MemberQ[ opts[ WindowElements ], "MagnificationPopUp" ],
            opts[ TaggingRules ],
            opts[ WindowTitle ],
            StringQ @ opts[ Evaluator ],
            MatchQ[ opts[ StyleDefinitions ], _Notebook ],
            pdtStrings @ header,
            pdtStrings @ First @ Lookup[ Association @ Rest[ List @@ acpPermissionDetailsNotebook[ data, $pdtOwner, False, { }, False ] ], DockedCells ]
        }
    ],
    {
        { },
        { True, False, False, False, { 700, 600 }, { { 10, Automatic }, { Automatic, 20 } } },
        True,
        <|
            "ACPPermissionDetails" -> <|
                "Owner"   -> $pdtOwner,
                "Header"  -> <| "Headline" -> "OpenCode wants to write big.py", "Count" -> "1 file" |>,
                "Loading" -> True
            |>,
            "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
        |>,
        "OpenCode wants to write big.py",
        True,
        True,
        { ___, "OpenCode wants to write big.py", ___, "1 file", ___, "Loading\[Ellipsis]", ___ },
        _? (FreeQ[ #, "Loading\[Ellipsis]" ] &)
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Notebook@@Tests/ACPPermissionDetails.wlt:118,1-156,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cells*)

(* A new file of 2,000 lines: a card (open) with its first 400 rows, then the rest of them as text, 500 lines per cell,
   with the new line numbers *)
VerificationTest[
    Module[ { cells, texts, card },
        cells = pdtCells @ pdtDiffRequest[ "write", { { "/project/big.py", Null, pdtFile[ 2000 ] } } ];
        texts = pdtTexts @ cells;
        card  = First @ cells;
        {
            Length @ cells,
            pdtGridRows @ card,
            MemberQ[ pdtStrings @ card, "+2000" ],
            MemberQ[ pdtStrings @ card, "new file" ],
            (* the card starts open *)
            ! FreeQ[ card, DynamicModuleBox[ { Typeset`open$$ = True }, ___ ] ],
            Cases[ cells, Cell[ BoxData[ b_ ], "ACPReviewNotice", ___ ] :> pdtStrings @ b ],
            Length /@ StringSplit[ texts, "\n" ],
            First @ StringSplit[ First @ texts, "\n" ],
            Last @ StringSplit[ Last @ texts, "\n" ]
        }
    ],
    {
        6,
        { 400 },
        True,
        True,
        True,
        { { ___, "The rest of the diff as text (1600 more lines):", ___ } },
        { 500, 500, 500, 100 },
        " 401 +     result_401 = compute(alpha * 401)",
        "2000 +     result_2000 = compute(alpha * 2000)"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Cells-NewFile@@Tests/ACPPermissionDetails.wlt:164,1-195,2"
]

(* An edit of one line of a large file: one card with that line, its context and the old and new line numbers *)
VerificationTest[
    Module[ { old, new, cells, rows },
        old   = pdtFile[ 3000 ];
        new   = StringReplace[ old, pdtLine[ 1500 ] <> "\n" -> "    changed = 1\n" ];
        cells = pdtCells @ pdtDiffRequest[ "edit", { { "/project/big.py", old, new } } ];
        rows  = acpDiffRows[ <| "Path" -> "big.py", "OldText" -> old, "NewText" -> new |>, True ];
        {
            Length @ cells,
            pdtGridRows @ cells,
            Select[ rows, MatchQ[ First @ #, "+" | "-" ] & ],
            MemberQ[ pdtStrings @ cells, "+1" ] && MemberQ[ pdtStrings @ cells, "\[Minus]1" ]
        }
    ],
    { 1, { 10 }, { { "-", "    result_1500 = compute(alpha * 1500)", 1500, None }, { "+", "    changed = 1", None, 1500 } }, True },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Cells-Edit@@Tests/ACPPermissionDetails.wlt:198,1-214,2"
]

(* Several files: the whole diff. The first card is open; later cards start closed when their diff is long, and are
   rendered when they are first opened (their first 400 rows); the rest of every file's rows follows its card as text,
   also after a closed card *)
VerificationTest[
    Module[ { cells, cards, lazy, texts },
        cells = pdtCells @ pdtDiffRequest[
            "patch",
            {
                { "/project/a.py", Null, pdtFile[ 450 ] },
                { "/project/b.py", Null, pdtFile[ 600 ] },
                { "/project/c.py", "x\n", "y\n" }
            }
        ];
        cards = Cases[ cells, c: Cell[ _BoxData, "ACPReviewFile", ___ ] :> c ];
        (* the data of the diff rendered when the card is opened (ChatbookAction[ "ACP", "ReviewDiffView", data ]) *)
        lazy  = Cases[ cards[[ 2 ]], data_Association /; KeyExistsQ[ data, "Rows" ] :> data, Infinity ];
        texts = pdtTexts @ cells;
        {
            Length @ cards,
            Cases[ #, DynamicModuleBox[ { Typeset`open$$ = open_ }, ___ ] :> open, Infinity, 1 ] & /@ cards,
            pdtGridRows /@ cards,
            { Length @ lazy[[ 1, "Rows" ]], lazy[[ 1, "Omitted" ]] },
            FreeQ[ lazy, t_String /; StringContainsQ[ t, "result_401 " ] ],
            (* the cells in order: card, caption, text (a.py: rows 401 to 450), card, caption, text (b.py: 401 to 600), card *)
            Replace[ cells, { Cell[ _String, "ACPReviewFile", ___ ] -> "Text", Cell[ _, "ACPReviewNotice", ___ ] -> "Caption", Cell[ _, "ACPReviewFile", ___ ] -> "Card" }, { 1 } ],
            Length /@ StringSplit[ texts, "\n" ],
            StringContainsQ[ texts[[ 1 ]], "result_401 " ] && StringContainsQ[ texts[[ 1 ]], "result_450 " ],
            StringContainsQ[ texts[[ 2 ]], "result_401 " ] && StringContainsQ[ texts[[ 2 ]], "result_600 " ],
            Lookup[ Options[ #, CellTags ] & /@ cards, CellTags ]
        }
    ],
    {
        3,
        { { True }, { False }, { True } },
        { { 400 }, { }, { 2 } },
        { 400, 0 },
        True,
        { "Card", "Caption", "Text", "Card", "Caption", "Text", "Card" },
        { 50, 200 },
        True,
        True,
        { { "ACPPermissionDetailsFile-1" }, { "ACPPermissionDetailsFile-2" }, { "ACPPermissionDetailsFile-3" } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Cells-ManyFiles@@Tests/ACPPermissionDetails.wlt:219,1-261,2"
]

(* Past the window's budget of characters the rest of that file's text is left out with a note; later files still get
   their cards *)
VerificationTest[
    Module[ { cells },
        cells = Block[ { Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsMaxText = 30000 },
            pdtCells @ pdtDiffRequest[ "patch", { { "/project/a.py", "x\n", "y\n" }, { "/project/b.py", Null, pdtFile[ 1000 ] }, { "/project/c.py", Null, pdtFile[ 900 ] } } ]
        ];
        {
            Cases[ cells, Cell[ _BoxData, "ACPReviewFile", ___, CellTags -> tags_, ___ ] :> tags ],
            Total[ StringLength /@ pdtTexts @ cells ],
            Cases[ cells, Cell[ BoxData[ b_ ], "ACPReviewNotice", ___ ] :> Select[ pdtStrings @ b, StringStartsQ[ "\[Ellipsis]" ] ] ]
        }
    ],
    {
        { { "ACPPermissionDetailsFile-1" }, { "ACPPermissionDetailsFile-2" }, { "ACPPermissionDetailsFile-3" } },
        30000,
        { { }, { }, { s_String /; StringEndsQ[ s, " more characters" ] } }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Cells-Budget@@Tests/ACPPermissionDetails.wlt:265,1-283,2"
]

(* A command (or a script) as text: all of its lines, none cut, 500 per cell; past the window's budget of characters a
   note says how much is left out *)
VerificationTest[
    Module[ { long, command, cells, small },
        long    = "echo " <> StringRepeat[ "w", 1000 ];
        command = StringRiffle[ Join[ { long }, Table[ "echo step " <> ToString[ i ], { i, 1199 } ] ], "\n" ];
        cells   = pdtCells @ pdtShellRequest @ command;
        small   = Block[ { Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsMaxText = 3000 }, pdtCells @ pdtShellRequest @ command ];
        {
            Length /@ StringSplit[ pdtTexts @ cells, "\n" ],
            StringRiffle[ pdtTexts @ cells, "\n" ] === command,
            StringLength @ StringRiffle[ pdtTexts @ small, "" ],
            Cases[ small, Cell[ BoxData[ b_ ], "ACPReviewNotice", ___ ] :> pdtStrings @ b ],
            StringRiffle[ pdtTexts @ pdtCells @ pdtScriptRequest[ "const a = 1;\nreturn a;" ], "\n" ]
        }
    ],
    {
        { 500, 500, 200 },
        True,
        3000,
        { { ___, s_String /; StringStartsQ[ s, "\[Ellipsis] " ] && StringEndsQ[ s, " more characters" ], ___ } },
        "const a = 1;\nreturn a;"
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Cells-Command@@Tests/ACPPermissionDetails.wlt:287,1-310,2"
]

(* Everything from the agent is shown display-safe: diff lines, paths, the headline (window title), commands; the front
   end's linear syntax neutralized, bidi controls as markers *)
VerificationTest[
    Module[ { rlo, evil, pua, diff, shell, nb },
        rlo   = FromCharacterCode[ 16^^202E ];
        evil  = FromCharacterCode[ { 63425, 63433, 63432 } ] <> "DynamicBox[Print[1]]" <> FromCharacterCode[ 63424 ];
        pua   = s_String /; StringContainsQ[ s, Characters @ FromCharacterCode @ Range[ 63424, 63437 ] ];
        diff  = pdtData @ pdtDiffRequest[ "edit", { { "/project/a" <> rlo <> "txt.py", "x\n", "y " <> rlo <> evil <> "\n" } } ];
        shell = pdtCells @ pdtShellRequest[ "echo " <> rlo <> evil ];
        nb    = acpPermissionDetailsNotebook[ diff, $pdtOwner, True, Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsCells @ diff, False ];
        {
            FreeQ[ { nb, shell }, pua ],
            FreeQ[ { nb, shell }, s_String /; StringContainsQ[ s, rlo ] ],
            FreeQ[ nb, _DynamicBox? (! FreeQ[ #, Print ] &) ],
            MemberQ[ pdtStrings @ nb, s_ /; StringContainsQ[ s, "y \:27e6U+202E\:27e7" ] ],
            MemberQ[ pdtStrings @ nb, s_ /; StringContainsQ[ s, "a\:27e6U+202E\:27e7txt.py" ] ],
            StringContainsQ[ Lookup[ Association @ Rest[ List @@ nb ], WindowTitle ], "\:27e6U+202E\:27e7" ],
            StringStartsQ[ First @ pdtTexts @ shell, "echo \:27e6U+202E\:27e7" ]
        }
    ],
    { True, True, True, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-DisplaySafe@@Tests/ACPPermissionDetails.wlt:314,1-335,2"
]

(* Lines made display-safe and cut (also for the permission panel's rows): a marker is never cut in half; Infinity cuts
   nothing *)
VerificationTest[
    Module[ { rlo = FromCharacterCode[ 16^^202E ] },
        {
            acpReviewSafeLines[ { "abc" <> rlo <> "def", "", "plain" }, 300 ],
            acpReviewSafeLines[ { StringRepeat[ "x", 8 ] <> rlo <> "y" }, 10 ],
            acpReviewSafeLines[ { StringRepeat[ "x", 20 ] }, 10 ],
            acpReviewSafeLines[ { StringRepeat[ "x", 20 ] <> rlo }, Infinity ],
            acpReviewSafeLines[ { }, 10 ]
        }
    ],
    {
        { "abc\:27e6U+202E\:27e7def", "", "plain" },
        { "xxxxxxxx\[Ellipsis]" },
        { "xxxxxxxxxx\[Ellipsis]" },
        { StringRepeat[ "x", 20 ] <> "\:27e6U+202E\:27e7" },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-SafeLines@@Tests/ACPPermissionDetails.wlt:339,1-358,2"
]

(* Commands and code are not spell checked (a red line under "dev" of /dev/null): the text cells, and every cell of the
   review stylesheet that the window uses *)
VerificationTest[
    Module[ { cells, sheet },
        cells = pdtCells @ pdtShellRequest[ "cat notes.txt > /dev/null" ];
        sheet = Wolfram`Chatbook`ACP`Review`Private`reviewStyleSheet[ { } ];
        {
            AllTrue[ Cases[ cells, c: Cell[ _String, "ACPReviewFile", ___ ] :> c ], MemberQ[ #, ShowAutoSpellCheck -> False ] & ],
            Length @ Cases[ cells, Cell[ _String, "ACPReviewFile", ___ ] ] > 0,
            MemberQ[ FirstCase[ sheet, c: Cell[ StyleData[ "ACPReviewBase" ], ___ ] :> c, None, Infinity ], ShowAutoSpellCheck -> False ]
        }
    ],
    { True, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-NoSpellCheck@@Tests/ACPPermissionDetails.wlt:362,1-375,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Opening*)

(* The link's action looks the request up by its key among the window's pending requests: a request that was answered
   (or another request with the same JSON-RPC id) is not shown; a request with nothing to show opens nothing *)
VerificationTest[
    Module[ { info, other, tool, opened = { } },
        info  = pdtShellRequest[ "ls" ];
        other = Append[ info, "ArrivedAt" -> 2000.0 ];
        tool  = pdtRequest @ <| "toolCallId" -> "c", "name" -> "WolframNotebooks_InsertCells", "rawInput" -> <| "notebook" -> "x" |> |>;
        Block[
            {
                $acpWindows = <| $pdtOwner -> Append[ pdtWindow @ <| 3 -> info, 4 -> tool |>, "KernelSessionID" -> $SessionID ] |>,
                acpCheckSession = Null &,
                Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsOpen = (AppendTo[ opened, { ## } ]; "opened") &
            },
            {
                acpPermissionDetails[ $pdtOwner, acpPermissionKey[ 3, info ] ],
                opened[[ All, 2, "Text" ]],
                acpPermissionDetails[ $pdtOwner, acpPermissionKey[ 3, other ] ],
                acpPermissionDetails[ $pdtOwner, acpPermissionKey[ 4, tool ] ],
                acpPermissionDetails[ $pdtOwner, "nokey" ],
                Length @ opened
            }
        ]
    ],
    { "opened", { "ls" }, Missing[ "NotPending" ], Missing[ "NothingToShow" ], Missing[ "NotPending" ], 1 },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Action@@Tests/ACPPermissionDetails.wlt:383,1-407,2"
]

(* The window is written in steps (one item per step here): the first replaces the notebook ("Loading..." in its header
   while items are left), the others append cells, the last updates the header. A step of a job that another link
   replaced does nothing. *)
VerificationTest[
    Module[ { details, data, calls = { }, scheduled = 0, steps = 0 },
        details = NotebookObject[ "ACPPermissionDetailsWindow", 2 ];
        data    = pdtData @ pdtDiffRequest[ "patch", Table[ { "/project/f" <> ToString[ i ] <> ".py", "a\n", "b\n" }, { i, 3 } ] ];
        Block[
            {
                Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows  = <| |>,
                Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsStepTime = 0.,
                Notebooks            = { details } &,
                acpReviewPut         = (AppendTo[ calls, { "Put", Length @ First @ #2, Lookup[ Association @ Rest[ List @@ #2 ], DockedCells ] } ] &),
                acpReviewAppendCells = (AppendTo[ calls, { "Append", Length @ #2 } ] &),
                SetOptions           = (AppendTo[ calls, { "SetOptions", ## } ] &),
                acpSchedule
            },
            SetAttributes[ acpSchedule, HoldAll ];
            acpSchedule[ ___ ] := scheduled++;
            Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows[ details ] = <|
                "Token" -> "t1",
                "Job"   -> Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsNewJob[ data, $pdtOwner ]
            |>;
            (* a step of an earlier job *)
            Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsStep[ details, "t0" ];
            While[ steps < 10 && KeyExistsQ[ Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows[ details ], "Job" ],
                steps++;
                Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsStep[ details, "t1" ]
            ];
            {
                steps,
                scheduled,
                calls[[ All, 1 ]],
                calls[[ 1, 2 ]],
                MemberQ[ pdtStrings @ calls[[ 1, 3 ]], "Loading\[Ellipsis]" ],
                ! MemberQ[ pdtStrings @ calls[[ -1 ]], "Loading\[Ellipsis]" ] && ! FreeQ[ calls[[ -1 ]], DockedCells ]
            }
        ]
    ],
    { 3, 2, { "Put", "Append", "Append", "SetOptions" }, 1, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Steps@@Tests/ACPPermissionDetails.wlt:412,1-451,2"
]

(* A large file is written in many steps: its card (and the caption of its text) in one, then its text in items of 500
   lines, one or more per step (one here, with no time per step), so that no step blocks the pump for long *)
VerificationTest[
    Module[ { job, sizes = { }, cells },
        job = Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsNewJob[ pdtData @ pdtDiffRequest[ "write", { { "/project/big.py", Null, pdtFile[ 20000 ] } } ], None ];
        While[ job[ "Next" ] <= Length @ job[ "Items" ] && Length @ sizes < 100,
            { cells, job } = Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsCellsStep[ job, 0 ];
            AppendTo[ sizes, Length @ cells ]
        ];
        { Length @ sizes, First @ sizes, Union @ Rest @ sizes, Length @ job[ "Items" ] }
    ],
    { 41, 2, { 1 }, 41 },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Steps-Chunks@@Tests/ACPPermissionDetails.wlt:455,1-467,2"
]

(* In a front end (CI runs the tests in one; skipped without): the link opens one window per ACP window, placed on the
   display, read only, with the request's diff; another request replaces its content in the same window; closing the
   ACP window's details closes it. The pump's steps are run here (the test front end's pump has no front end). *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { owner, info, other, details, again, cells, result },
            owner = CreateDocument[ { }, Visible -> False, WindowTitle -> "ACPPermissionDetailsOwner" ];
            info  = pdtDiffRequest[ "write", { { "/project/big.py", Null, pdtFile[ 600 ] } } ];
            other = pdtShellRequest[ "echo other" ];
            result = Block[
                {
                    $acpWindows     = <| owner -> Append[ pdtWindow @ <| 3 -> info, 4 -> other |>, "Notebook" -> owner ] |>,
                    acpCheckSession = Null &,
                    acpSchedule
                },
                SetAttributes[ acpSchedule, HoldAll ];
                acpSchedule[ ___ ] := Null;
                details = acpPermissionDetails[ owner, acpPermissionKey[ 3, info ] ];
                While[ KeyExistsQ[ Lookup[ Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows, details, <| |> ], "Job" ],
                    Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsStep[ details, Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows[ details, "Token" ] ]
                ];
                cells = Length @ Cells @ details;
                {
                    MatchQ[ details, _NotebookObject ],
                    acpPermissionDetailsWindowOf @ owner === details,
                    CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Owner" } ] === owner,
                    AbsoluteCurrentValue[ details, # ] & /@ { Deployed, Editable, Saveable },
                    MemberQ[ AbsoluteCurrentValue[ details, WindowElements ], "MagnificationPopUp" ],
                    cells,
                    again = acpPermissionDetails[ owner, acpPermissionKey[ 4, other ] ];
                    again === details,
                    Count[ Notebooks[ ], nb_ /; Quiet @ CurrentValue[ nb, { TaggingRules, "ACPPermissionDetails", "Owner" } ] === owner ]
                }
            ];
            acpPermissionDetailsCloseWindow @ owner;
            AppendTo[ result, MemberQ[ Notebooks[ ], details ] ];
            NotebookClose @ owner;
            result
        ]
    ],
    { True, True, True, { True, False, False }, True, 3, True, 1, False } | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Window-FrontEnd@@Tests/ACPPermissionDetails.wlt:472,1-513,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Large Files*)

(* The rows of a diff made in parts (Rendering.wl's acpDiffRowSource, which the window uses so that a step of a large file
   makes only the rows it writes) are those of acpDiffRows, for every kind of diff: line diffs of random edits (collapsed
   context, ellipsis rows), a new file, a file emptied, no change, all lines the same, "contents written", a patch *)
VerificationTest[
    Module[ { random, diffs, check },
        SeedRandom[ 20261021 ];
        random[ n_ ] := RandomChoice[ { "a", "b", "c", "d", "", "  x = 1" }, n ];
        diffs = Join[
            Table[
                With[ { old = random @ RandomInteger[ { 0, 300 } ] },
                    <|
                        "Path"    -> "r.txt",
                        "OldText" -> StringRiffle[ old, "\n" ],
                        "NewText" -> StringRiffle[ Delete[ Insert[ old, "new", RandomInteger[ { 1, Length @ old + 1 } ] ], If[ Length @ old > 3, { { 1 } }, { } ] ], "\n" ]
                    |>
                ],
                { 12 }
            ],
            {
                <| "Path" -> "n.txt", "OldText" -> None, "NewText" -> pdtFile[ 700 ] |>,
                <| "Path" -> "d.txt", "OldText" -> pdtFile[ 50 ], "NewText" -> "" |>,
                <| "Path" -> "u.txt", "OldText" -> pdtFile[ 50 ], "NewText" -> pdtFile[ 50 ] |>,
                <| "Path" -> "s.txt", "OldText" -> StringRiffle[ ConstantArray[ "same", 40 ], "\n" ], "NewText" -> StringRiffle[ ConstantArray[ "same", 41 ], "\n" ] |>,
                <| "Path" -> "w.txt", "OldText" -> None, "NewText" -> pdtFile[ 30 ], "Write" -> True |>,
                <| "Path" -> "p.txt", "OldText" -> None, "NewText" -> None, "Patch" -> "--- a/p.txt\n+++ b/p.txt\n@@ -3,3 +3,4 @@\n a\n-b\n+c\n+d\n e" |>,
                <| "Path" -> "e.txt", "OldText" -> "", "NewText" -> "" |>,
                (* the last row shown is line 9; the ellipsis row after it (line 10) has no numbers *)
                <| "Path" -> "x.txt", "OldText" -> pdtFile[ 12 ], "NewText" -> StringReplace[ pdtFile[ 12 ], pdtLine[ 6 ] -> "changed" ] |>
            }
        ];
        check[ diff_ ] := Module[ { rows, source, n, parts },
            rows   = acpDiffRows[ diff, True ];
            source = acpDiffRowSource @ diff;
            n      = source[ "Count" ];
            parts  = acpDiffSourceRows[ source, # ] & /@ Partition[ Range @ n, UpTo[ 7 ] ][[ All, { 1, -1 } ]];
            And[
                n === Length @ rows,
                acpDiffSourceRows[ source, { 1, n } ] === rows,
                Join @@ parts === rows,
                acpDiffSourceLineLengths[ source, { 1, n } ] === StringLength @ rows[[ All, 2 ]],
                source[ "MaxNumbers" ] === (Max[ 0, Cases[ rows[[ All, # ]], _Integer ] ] & /@ { 3, 4 })
            ]
        ];
        { Length @ diffs, AllTrue[ diffs, check ] }
    ],
    { 20, True },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-RowSource@@Tests/ACPPermissionDetails.wlt:522,1-567,2"
]

(* A file of 100,000 lines: its item makes only the rows of its card, and its text follows in items of row ranges, whose
   rows are made when they are written; the characters that a note of the text budget counts are those of the rows after
   an item, as the whole rows would give them. Its first step is not much longer than that of a small file (before:
   about 1.3 s, all rows and chunks at once). *)
VerificationTest[
    Module[ { big, small, data, ranges = { }, item, job, rows, columns, left, firstStep, smallStep },
        big   = pdtFile[ 100000 ];
        small = pdtFile[ 1000 ];
        data[ text_ ] := pdtData @ pdtDiffRequest[ "write", { { "/project/big.py", Null, text } } ];
        (* the line diffs are cached, as the permission panel leaves them *)
        acpDiffRowSource @ <| "OldText" -> None, "NewText" -> # |> & /@ { big, small };
        job  = Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsNewJob[ data @ big, None ];
        item = Block[ { acpDiffSourceRows },
            acpDiffSourceRows[ source_, range_ ] := (AppendTo[ ranges, range ]; ConstantArray[ { "+", "x", None, 1 }, range[[ 2 ]] - range[[ 1 ]] + 1 ]);
            Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsItemCells[ job[ "Items" ][[ 1 ]], job ]
        ];
        rows    = acpDiffRows[ <| "OldText" -> None, "NewText" -> big |>, True ];
        columns = (6 + 1) + 2; (* the new line numbers (6 digits and a space), the mark and its space *)
        left    = Total[ columns + Min[ StringLength @ #[[ 2 ]], 301 ] & /@ Drop[ rows, 900 ] ] + Length @ rows - 900;
        firstStep[ text_ ] := Min @ Table[
            First @ AbsoluteTiming @ Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsCellsStep[
                Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsNewJob[ data @ text, None ],
                0
            ],
            2
        ];
        smallStep = firstStep @ small;
        {
            ranges,
            Length @ item[[ 2, "Items" ]],
            Union[ Keys /@ Rest @ item[[ 2, "Items" ]] ],
            item[[ 2, "Items", 2, "Range" ]],
            item[[ 2, "Items", -1, "Range" ]],
            Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsLeftChars @ item[[ 2, "Items", 2 ]] === left,
            firstStep @ big < 0.5 + 3 * smallStep
        }
    ],
    {
        { { 1, 400 } },
        201,
        { { "Group", "Widths", "Source", "Range", "LeftLines", "LeftChars" } },
        { 401, 900 },
        { 99901, 100000 },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Steps-LargeFile@@Tests/ACPPermissionDetails.wlt:573,1-617,2"
]

(* A step that fails ends the job: the header loses "Loading..." and says that the content is incomplete, a note follows
   the last cell, and no further step is scheduled *)
VerificationTest[
    Module[ { details, data, calls = { }, scheduled = 0 },
        details = NotebookObject[ "ACPPermissionDetailsWindow", 3 ];
        data    = pdtData @ pdtDiffRequest[ "write", { { "/project/big.py", Null, pdtFile[ 10 ] } } ];
        Block[
            {
                Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows = <| |>,
                Notebooks            = { details } &,
                Cells                = { } &,
                CurrentValue,
                acpDiffRowSource     = Throw[ "broken" ] &,
                acpReviewPut         = (AppendTo[ calls, { "Put" } ] &),
                acpReviewAppendCells = (AppendTo[ calls, { "Append", #2 } ] &),
                SetOptions           = (AppendTo[ calls, { "SetOptions", ## } ] &),
                acpSchedule
            },
            SetAttributes[ acpSchedule, HoldAll ];
            acpSchedule[ ___ ] := scheduled++;
            CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Header" } ] := <| "Headline" -> "OpenCode wants to write big.py", "Count" -> "1 file" |>;
            Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows[ details ] = <|
                "Token" -> "t1",
                "Job"   -> Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsNewJob[ data, $pdtOwner ]
            |>;
            Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsStep[ details, "t1" ];
            {
                Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows[ details ],
                scheduled,
                calls[[ All, 1 ]],
                pdtStrings @ calls[[ 1, 2 ]],
                Select[ pdtStrings @ calls[[ 2 ]], StringContainsQ[ "big.py" | "1 file" | "Incomplete" | "Loading" ] ],
                CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Loading" } ]
            }
        ]
    ],
    {
        <| "Token" -> "t1" |>,
        0,
        { "Append", "SetOptions" },
        { ___, "Incomplete: loading was interrupted", ___ },
        { "OpenCode wants to write big.py", "1 file", "Incomplete: loading was interrupted" },
        False
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-StepFails@@Tests/ACPPermissionDetails.wlt:621,1-665,2"
]

(* After a kernel restart (scheduled by the ACP window's recovery): a details window of the window that was still being
   written (its TaggingRules say "Loading", and this kernel has no job for it) says that it is incomplete, in place of its
   "Loading..." cell if it got no content; a window that was written to the end, or whose job runs, is left alone *)
VerificationTest[
    Module[ { details, owner, scheduled = { }, run },
        details = NotebookObject[ "ACPPermissionDetailsWindow", 4 ];
        owner   = NotebookObject[ "ACPPermissionDetailsOwner", 4 ];
        run[ loading_, jobs_, cells_ ] := Module[ { calls = { } },
            Block[
                {
                    Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows = jobs,
                    acpPermissionDetailsWindowOf = If[ # === owner, details, None ] &,
                    Cells                = cells &,
                    CurrentValue,
                    NotebookWrite        = (AppendTo[ calls, { "Write", #1 } ] &),
                    NotebookDelete       = (AppendTo[ calls, { "Delete", #1 } ] &),
                    acpReviewAppendCells = (AppendTo[ calls, { "Append" } ] &),
                    SetOptions           = (AppendTo[ calls, { "SetOptions", Select[ pdtStrings @ { ## }, StringContainsQ[ "Incomplete" | "Loading" ] ] } ] &)
                },
                CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Loading" } ] := loading;
                CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Header" } ] := { "Headline" -> "h", "Count" -> "1 file" };
                acpPermissionDetailsRecover @ owner;
                acpPermissionDetailsRecover @ NotebookObject[ "ACPPermissionDetailsOther", 4 ];
                calls
            ]
        ];
        Block[
            {
                acpSchedule                                        = Function[ e, AppendTo[ scheduled, HoldForm @ e ], HoldFirst ],
                Cells                                              = { } &,
                NotebookDelete                                     = Null &,
                Wolfram`Chatbook`Common`attachWorkspaceChatInput   = Null &,
                Wolfram`Chatbook`ACP`UI`Private`acpRefreshToolbar  = Null &
            },
            Wolfram`Chatbook`ACP`UI`Private`acpRefreshWindowUI @ owner
        ];
        {
            run[ True, <| |>, { } ],
            run[ True, <| |>, { CellObject[ "loading-1" ], CellObject[ "loading-2" ] } ],
            run[ True, <| details -> <| "Token" -> "t", "Job" -> <| |> |> |>, { } ],
            run[ False, <| |>, { } ],
            With[ { o = owner }, MemberQ[ scheduled, HoldForm @ acpPermissionDetailsRecover @ o ] ]
        }
    ],
    {
        { { "Append" }, { "SetOptions", { "Incomplete: loading was interrupted" } } },
        { { "Write", CellObject[ "loading-1" ] }, { "Delete", { CellObject[ "loading-2" ] } }, { "SetOptions", { "Incomplete: loading was interrupted" } } },
        { },
        { },
        True
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Recover@@Tests/ACPPermissionDetails.wlt:670,1-720,2"
]

(* The same in a front end (skipped without): a window that the kernel was still writing when it was restarted *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { owner, data, details, result },
            owner   = CreateDocument[ { }, Visible -> False, WindowTitle -> "ACPPermissionDetailsRecoverOwner" ];
            data    = pdtData @ pdtDiffRequest[ "write", { { "/project/big.py", Null, pdtFile[ 30 ] } } ];
            details = NotebookPut @ Append[
                acpPermissionDetailsNotebook[ data, owner, True, { Wolfram`Chatbook`ACP`PermissionDetails`Private`detailsLoadingCell[ ] }, True ],
                Visible -> False
            ];
            Block[ { Wolfram`Chatbook`ACP`PermissionDetails`Private`$detailsWindows = <| |> }, acpPermissionDetailsRecover @ owner ];
            result = {
                acpPermissionDetailsWindowOf @ owner === details,
                CurrentValue[ details, { TaggingRules, "ACPPermissionDetails", "Loading" } ],
                Select[ pdtStrings @ AbsoluteCurrentValue[ details, DockedCells ], StringContainsQ[ "big.py" | "1 file" | "Incomplete" | "Loading" ] ],
                Select[ pdtStrings @ First @ NotebookGet @ details, StringContainsQ[ "Incomplete" | "Loading" ] ]
            };
            NotebookClose @ details;
            NotebookClose @ owner;
            result
        ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        False,
        { "OpenCode wants to write big.py", "1 file", "Incomplete: loading was interrupted" },
        { "Incomplete: loading was interrupted" }
    },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Recover-FrontEnd@@Tests/ACPPermissionDetails.wlt:723,1-753,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* Every label of PermissionDetails.wl is in one of the English tables (and so in the .tr files, see ACPWindow.wlt) *)
VerificationTest[
    Complement[
        Union @ StringCases[
            ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "PermissionDetails.wl" },
            "acpLabel[ \"" ~~ key: Except[ "\"" ].. ~~ "\"" :> key
        ],
        Keys @ Join[ $acpStrings, $acpReviewStrings ]
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-Strings@@Tests/ACPPermissionDetails.wlt:760,1-771,2"
]

(* :!CodeAnalysis::EndBlock:: *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Debug Log*)

(* No message or failure was logged while these tests ran *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        #[ "Time" ] >= $pdtLogStart && MemberQ[ { "Message", "Uncaught" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPPermissionDetails-DebugLog@@Tests/ACPPermissionDetails.wlt:780,1-788,2"
]
