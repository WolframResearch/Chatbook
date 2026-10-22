(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Initialization*)
VerificationTest[
    Needs[ "Wolfram`ChatbookTests`", FileNameJoin @ { DirectoryName @ $TestFileName, "Common.wl" } ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "GetDefinitions@@Tests/ACPReview.wlt:4,1-9,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "LoadContext@@Tests/ACPReview.wlt:11,1-16,2"
]

VerificationTest[
    Needs[ "Wolfram`Chatbook`ACP`Common`" ],
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPReview-LoadACPContext@@Tests/ACPReview.wlt:18,1-23,2"
]

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::PrivateContextSymbol:: *)
(* :!CodeAnalysis::Disable::SuspiciousSessionSymbol:: *)

(* Tests for ACP/Review.wl (see docs/acp-window.md, "Reviewing changes"): the toolbar button, the review notebook built
   from change sets (Git.wl), the file icons and the actions. They need no front end: labels use the English defaults,
   and front end functions are replaced by mocks where actions use them. The integration test runs the real git in a
   small temporary repository (skipped, Missing["TestSkipped"], when git is not found), isolated from the developer's git
   configuration like Tests/ACPGit.wlt. The remote tests ("Remote folders") show change sets of folders on another
   computer; their integration test lists a repository through the fake ssh (Data/ACP/fake-ssh; skipped on Windows,
   without /bin/sh or without git). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Definitions*)
VerificationTest[
    (* CI runs every test file in one kernel and one context: helpers that other test files define too are cleared
       first, so that none of their definitions is used here *)
    ClearAll[ boxStrings, calls, changed, containsTextQ, logCall, nulJoin, testWindow, waitUntil ];

    Wolfram`Chatbook`ACP`Transcript`Private`$acpNoFrontEndLabels = True;
    $acpLogStart = AbsoluteTime[ ]; (* see ACPReview-DebugLog *)

    $reviewScratch = CreateDirectory[ ];
    $owner         = NotebookObject[ "acp-review-test-owner" ];
    $review        = NotebookObject[ "acp-review-test-review" ];

    (* porcelain v2 -z, numstat -z and patch output (as in Tests/ACPGit.wlt) *)
    $h = "4b5a6b88196afa553fa7b2a6fbe1a6418f5cdd26";
    nulJoin[ fields_List ] := StringJoin[ # <> FromCharacterCode[ 0 ] & /@ fields ];
    changed[ xy_String, path_String ] := "1 " <> xy <> " N... 100644 100644 100644 " <> $h <> " " <> $h <> " " <> path;

    $patch = StringRiffle[
        {
            "diff --git a/src/a.txt b/src/a.txt",
            "index 4cb29ea..6addb9b 100644",
            "--- a/src/a.txt",
            "+++ b/src/a.txt",
            "@@ -1,3 +1,4 @@",
            " one",
            "-two",
            "+TWO",
            " three",
            "--- a removed comment",
            "+four",
            "diff --git a/new.txt b/new.txt",
            "new file mode 100644",
            "index 0000000..91d5523",
            "--- /dev/null",
            "+++ b/new.txt",
            "@@ -0,0 +1 @@",
            "+hello",
            "diff --git a/gone.txt b/gone.txt",
            "deleted file mode 100644",
            "index abaddc0..0000000",
            "--- a/gone.txt",
            "+++ /dev/null",
            "@@ -1 +0,0 @@",
            "-del",
            "diff --git a/old name.txt b/new name.txt",
            "similarity index 100%",
            "rename from old name.txt",
            "rename to new name.txt",
            "diff --git a/orig.txt b/copy.txt",
            "similarity index 100%",
            "copy from orig.txt",
            "copy to copy.txt",
            "diff --git a/img.bin b/img.bin",
            "index 6772730..8d0cd2a 100644",
            "Binary files a/img.bin and b/img.bin differ",
            "diff --git a/mode.sh b/mode.sh",
            "old mode 100644",
            "new mode 100755",
            "diff --git a/vendor/lib b/vendor/lib",
            "index 6062d22..86b6f6d 160000",
            "--- a/vendor/lib",
            "+++ b/vendor/lib",
            "@@ -1 +1 @@",
            "-Subproject commit 6062d2221df3ac7addfcd0bba5a1faf1ab2076f3",
            "+Subproject commit 86b6f6d6e835c187ef09c436b4bc99c466c63641",
            "diff --git a/tc.txt b/tc.txt",
            "deleted file mode 100644",
            "index 3cd5478..0000000",
            "--- a/tc.txt",
            "+++ /dev/null",
            "@@ -1 +0,0 @@",
            "-tc",
            "diff --git a/tc.txt b/tc.txt",
            "new file mode 120000",
            "index 0000000..9ce6ca3",
            "--- /dev/null",
            "+++ b/tc.txt",
            "@@ -0,0 +1 @@",
            "+src/a.txt",
            "\\ No newline at end of file",
            "diff --git a/empty.txt b/empty.txt",
            "new file mode 100644",
            "index 0000000..e69de29",
            ""
        },
        "\n"
    ];

    $csInput = <|
        "Directory" -> "/repo",
        "Root"      -> "/repo",
        "Prefix"    -> "",
        "Status"    -> nulJoin @ {
            "# branch.oid " <> $h,
            "# branch.head main",
            "u UU N... 100644 100644 100644 100644 " <> $h <> " " <> $h <> " " <> $h <> " conflict.txt",
            "2 C. N... 100644 100644 100644 " <> $h <> " " <> $h <> " C100 copy.txt",
            "orig.txt",
            changed[ "A.", "empty.txt" ],
            changed[ ".D", "gone.txt" ],
            changed[ ".M", "img.bin" ],
            changed[ ".M", "mode.sh" ],
            "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R100 new name.txt",
            "old name.txt",
            changed[ "A.", "new.txt" ],
            changed[ ".M", "src/a.txt" ],
            changed[ ".T", "tc.txt" ],
            "1 .M SC.. 160000 160000 160000 " <> $h <> " " <> $h <> " vendor/lib",
            "? data.bin",
            "? nested/",
            "? notes.md",
            "? zz-unread.txt"
        },
        "Numstat"   -> nulJoin @ {
            "0\t0\tempty.txt", "0\t1\tgone.txt", "-\t-\timg.bin", "0\t0\tmode.sh", "0\t0\t", "old name.txt", "new name.txt",
            "1\t0\tnew.txt", "2\t2\tsrc/a.txt", "1\t1\ttc.txt", "1\t1\tvendor/lib"
        },
        "Patch"     -> $patch,
        "Untracked" -> <|
            "notes.md" -> <| "Added" -> 2, "Binary" -> False, "Content" -> "x\ny\n", "Note" -> None |>,
            "data.bin" -> <| "Added" -> None, "Binary" -> True, "Content" -> None, "Note" -> "Binary" |>
        |>
    |>;
    $cs = acpGitBuildChangeSet @ $csInput;
    $nb = acpReviewNotebook[ $cs, $owner, True ];

    (* Notebook parts *)
    nbOption[ nb_Notebook, name_ ] := OptionValue[ List @@ Rest @ nb, name ];
    fileCells[ nb_Notebook ] := Cases[ First @ nb, c: Cell[ _, "ACPReviewFile", ___ ] :> c ];
    cellTags[ cell_Cell ] := Flatten @ { Lookup[ Options @ cell, CellTags, { } ] };
    (* Strings in boxes, without the quotes of box strings *)
    boxStrings[ expr_ ] := Cases[ expr, s_String :> StringTrim[ s, "\"" ], { 0, Infinity } ];
    containsTextQ[ expr_, text_String ] := AnyTrue[ boxStrings @ expr, StringContainsQ[ #, text ] & ];
    hasStringQ[ expr_, text_String ] := MemberQ[ boxStrings @ expr, text ];
    (* { action, args... } of every ChatbookAction["ACP", ...] in boxes (button actions and lazy diffs), without evaluating
       them (EvaluationNotebook[] is given as a string) *)
    actionCalls[ expr_ ] := ReleaseHold[
        Cases[
            expr,
            HoldPattern @ Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", action_String, args___ ] :> HoldComplete @ { action, args },
            Infinity
        ] /. HoldPattern @ EvaluationNotebook[ ] -> "EvaluationNotebook[]"
    ];
    (* The initial state of each card's opener (DynamicModuleBox variables have a $$ suffix) *)
    openStates[ nb_Notebook ] := Flatten[
        Cases[ #, DynamicModuleBox[ { Verbatim[ Set ][ _Symbol, v_ ] }, ___ ] :> v, Infinity, 1 ] & /@ fileCells @ nb
    ];
    (* Text in boxes (not style names and options) *)
    textStrings[ expr_ ] := Select[ boxStrings @ expr, StringContainsQ[ StringTrim @ #, " " ] && ! StringStartsQ[ #, "Source " ] & ];
    (* Symbols of Chatbook contexts in an expression (none should be left in boxes) *)
    chatbookSymbols[ expr_ ] := Union @ Cases[
        expr,
        s_Symbol /; AtomQ @ Unevaluated @ s && StringStartsQ[ Context @ Unevaluated @ s, "Wolfram`Chatbook" ] :> HoldForm @ s,
        { 0, Infinity },
        Heads -> True
    ];
    (* The card of a file of $nb *)
    cardOf[ path_String ] := fileCells[ $nb ][[ First @ FirstPosition[ Lookup[ $cs[ "Files" ], "Path" ], path ] ]];
    (* The line number columns of the (first) full-width diff in boxes: one row per diff line, with the old and new
       numbers ("" for none); a column without numbers is left out *)
    diffNumbers[ boxes_ ] := Replace[
        FirstCase[ boxes, GridBox[ rows_, ___, GridBoxItemSize -> { "Columns" -> { ___, Fit }, ___ }, ___ ] :> rows, None, Infinity ],
        rows_List :> (Replace[ Drop[ #, -2 ], { StyleBox[ n_String, ___ ] :> StringTrim[ n, "\"" ], n_String :> StringTrim[ n, "\"" ] }, { 1 } ] & /@ rows)
    ];
    (* The diff frames in boxes, with their ImageSize *)
    diffFrameSizes[ boxes_ ] := Cases[
        boxes,
        FrameBox[ c_, opts___ ] /; MemberQ[ { opts }, RoundingRadius -> 4 ] && ! FreeQ[ c, GridBoxBackground ] :> Lookup[ { opts }, ImageSize, Automatic ],
        { 0, Infinity }
    ];

    (* Call log for mocked functions *)
    $callLog = { };
    logCall[ name_String, args___ ] := (AppendTo[ $callLog, { name, args } ]; Null);
    calls[ name_String ] := Cases[ $callLog, { name, args___ } :> { args } ];

    (* Waiting with Pause lets the pump (scheduled evaluations) run: *)
    waitUntil // Attributes = { HoldFirst };
    waitUntil[ cond_, timeout_: 30 ] := Module[ { deadline = AbsoluteTime[ ] + timeout },
        While[ ! TrueQ @ cond && AbsoluteTime[ ] < deadline, Pause[ 0.05 ] ];
        TrueQ @ cond
    ];

    (* A window record with a git summary *)
    testWindow[ git_Association ] := <|
        Wolfram`Chatbook`ACP`UI`Private`acpInitialWindowRecord[ $owner, $TemporaryDirectory, "OpenCode", <| |> ],
        "Status" -> "Ready",
        "Git"    -> git
    |>;
    ,
    Null,
    SameTest -> MatchQ,
    TestID   -> "ACPReview-Definitions@@Tests/ACPReview.wlt:40,1-233,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Icons*)
VerificationTest[
    acpFileIconName /@ {
        "a.wl", "Kernel/b.m", "c.wls", "d.wlt", "e.mt", "f.wxf", "g.mx", "h.nb", "i.cdf", "PacletInfo.wl", "sub/pacletinfo.m",
        "j.txt", "k.md", "l.c", "m.hpp", "n.sh", "o.js", "p.css", "q.html", "r.htm", "s.xml", "t.svg", "u.png", "v.apng",
        "w.jpg", "x.JPEG", "y.gif", "z.bmp", "aa.tif", "ab.tiff", "nested/", "C:\\dir\\ac.py", "ad.json", "ae.toml",
        "af.swift", "Makefile", ".gitignore", "ag.tar.gz", "ah.", "ai.c++"
    },
    {
        "WL", "WL", "WL", "WL", "WL", "WL", "MX", "NB", "CDF", "PacletInfo", "PacletInfo",
        "TXT", "TXT", "TXT", "TXT", "TXT", "JS", "CSS", "HTML", "HTML", "XML", "SVG", "PNG", "PNG",
        "JPEG", "JPEG", "GIF", "BMP", "TIFF", "TIFF", "Directory", "ExtPY", "ExtJSON", "ExtTOML",
        "ExtFile", "TXT", "TXT", "ExtGZ", "TXT", "ExtFile"
    },
    SameTest -> MatchQ,
    TestID   -> "Icons-Names@@Tests/ACPReview.wlt:238,1-253,2"
]

(* DefinitionNotebookClient's icons (None on a system without the component) *)
VerificationTest[
    Wolfram`Chatbook`ACP`Review`Private`loadFileManagerIcons[ ],
    None | _Association? (Length[ # ] >= 20 && AllTrue[ #, MatchQ[ _GraphicsBox ] ] &),
    SameTest -> MatchQ,
    TestID   -> "Icons-Resource@@Tests/ACPReview.wlt:256,1-261,2"
]

VerificationTest[
    With[ { icons = acpFileIcon /@ { "a.wl", "b.nb", "c.py", "d.json", "e.swift", "f.png", "nested/", "README", "PacletInfo.wl" } },
        {
            MatchQ[ icons, { __GraphicsBox } ],
            Union @ Cases[ icons, (ImageSize -> s_) :> s, Infinity ],
            chatbookSymbols @ icons,
            FreeQ[ icons, _Missing | $Failed ],
            (* the label of other extensions *)
            ! FreeQ[ icons[[ 3 ]], InsetBox[ StyleBox[ "PY", ___ ], ___ ] ],
            FreeQ[ icons[[ 5 ]], _InsetBox ],
            (* a dark page in dark mode *)
            ! FreeQ[ icons[[ 3 ]], LightDarkSwitched ]
        }
    ],
    { True, { { 16, 16 } }, { }, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Icons-Boxes@@Tests/ACPReview.wlt:263,1-280,2"
]

(* Without DefinitionNotebookClient's icons, drawn pages are used *)
VerificationTest[
    Block[
        {
            Wolfram`Chatbook`ACP`Review`Private`$fileManagerIcons = None,
            Wolfram`Chatbook`ACP`Review`Private`$fileIconCache    = <| |>
        },
        With[ { icons = acpFileIcon /@ { "a.wl", "c.py", "nested/", "e.swift", "PacletInfo.wl" } },
            {
                MatchQ[ icons, { __GraphicsBox } ],
                chatbookSymbols @ icons,
                Cases[ icons, InsetBox[ StyleBox[ label_String, ___ ], ___ ] :> label, Infinity ]
            }
        ]
    ],
    { True, { }, { "WL", "PY" } },
    SameTest -> MatchQ,
    TestID   -> "Icons-Fallback@@Tests/ACPReview.wlt:283,1-300,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar Button*)
VerificationTest[
    acpReviewButtonSignature @ testWindow[ # ] & /@ {
        <| "Status" -> "Changes", "FileCount" -> 3, "Added" -> 40, "Deleted" -> 2 |>,
        <| "Status" -> "Clean" |>,
        <| "Status" -> "Unknown" |>,
        <| "Status" -> "Checking" |>,
        <| "Status" -> "Unavailable" |>,
        <| "Status" -> "NotRepository" |>,
        <| "Status" -> "Error" |>
    },
    { { 3, 40, 2 }, None, None, None, None, None, None },
    SameTest -> MatchQ,
    TestID   -> "Button-Signature@@Tests/ACPReview.wlt:305,1-318,2"
]

(* Checks that change nothing the button shows don't change the signature *)
VerificationTest[
    With[ { git = <| "Status" -> "Changes", "FileCount" -> 3, "Added" -> 40, "Deleted" -> 2 |> },
        SameQ @@ (Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowSignature @ testWindow[ # ] & /@ {
            git,
            <| git, "InFlight" -> True, "Token" -> "git-9", "StartedAt" -> 1.0 |>,
            <| git, "CheckedAt" -> 2.0, "Duration" -> 0.3, "Stale" -> True |>
        })
    ],
    True,
    SameTest -> MatchQ,
    TestID   -> "Button-DirectoryRowSignature@@Tests/ACPReview.wlt:321,1-332,2"
]

VerificationTest[
    Module[ { button },
        button = acpReviewButton[ $owner, testWindow @ <| "Status" -> "Changes", "FileCount" -> 3, "Added" -> 40, "Deleted" -> 2 |> ];
        {
            Head @ button,
            actionCalls @ button,
            Cases[ button, (BoxID -> id_) :> id, Infinity ],
            Union @ Select[ boxStrings @ ToBoxes @ button, MemberQ[ { "Review", "+40", "\[Minus]2", "Review uncommitted changes: 3 files" }, # ] & ],
            Cases[ button, (Method -> m_) :> m, Infinity ]
        }
    ],
    {
        Button,
        { { "ReviewChanges", $owner } },
        { "ACPReviewChangesButton" },
        { "+40", "Review", "Review uncommitted changes: 3 files", "\[Minus]2" },
        { "Preemptive" }
    },
    SameTest -> MatchQ,
    TestID   -> "Button-Changes@@Tests/ACPReview.wlt:334,1-354,2"
]

VerificationTest[
    {
        containsTextQ[ ToBoxes @ acpReviewButton[ $owner, testWindow @ <| "Status" -> "Changes", "FileCount" -> 1, "Added" -> 0, "Deleted" -> 5 |> ], "Review uncommitted changes: 1 file" ],
        containsTextQ[ ToBoxes @ acpReviewButton[ $owner, testWindow @ <| "Status" -> "Changes", "FileCount" -> 1, "Added" -> 0, "Deleted" -> 5 |> ], "+0" ],
        acpReviewButton[ $owner, testWindow @ <| "Status" -> # |> ] & /@ { "Clean", "Unknown", "Checking", "Unavailable", "NotRepository", "Error" }
    },
    { True, False, { Nothing, Nothing, Nothing, Nothing, Nothing, Nothing } },
    SameTest -> MatchQ,
    TestID   -> "Button-Hidden@@Tests/ACPReview.wlt:356,1-365,2"
]

(* The project folder row of the toolbar has the button only while there are changes *)
VerificationTest[
    Map[
        Function[ status,
            With[ { view = Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $owner, testWindow @ <| "Status" -> status, "FileCount" -> 2, "Added" -> 1, "Deleted" -> 1 |> ] },
                {
                    status,
                    Length @ Cases[ actionCalls @ view, { "ReviewChanges", _ } ],
                    Length @ Cases[ view, FileNameSetter[ _Dynamic, "Directory", ___ ], Infinity ]
                }
            ]
        ],
        { "Changes", "Clean", "Unknown", "Checking", "Unavailable", "NotRepository", "Error" }
    ],
    {
        { "Changes", 1, 1 },
        { "Clean", 0, 1 },
        { "Unknown", 0, 1 },
        { "Checking", 0, 1 },
        { "Unavailable", 0, 1 },
        { "NotRepository", 0, 1 },
        { "Error", 0, 1 }
    },
    SameTest -> MatchQ,
    TestID   -> "Button-DirectoryRow@@Tests/ACPReview.wlt:368,1-392,2"
]

(* The folder's label gets the room that the button leaves: the label has the whole path (the front end cuts it at its
   start), and its width (acpFitWidth, the first argument of its fitting DynamicBox) is less the button's text, measured
   in the front end, and the button's reserve *)
VerificationTest[
    With[ { dir = FileNameJoin @ { $TemporaryDirectory, StringRepeat[ "abcdefghij", 5 ] } },
        Module[ { args, widths },
            (* held: the width is a front end expression (Part of FEPrivate`StringWidth must not be evaluated) *)
            args = Cases[
                ToBoxes @ Wolfram`Chatbook`ACP`UI`Private`acpDirectoryRowView[ $owner, <| testWindow[ <| "Status" -> # |> ], "ProjectDirectory" -> dir |> ],
                DynamicBox[ Function[ _ ][ a__ ], ___ ] :> HoldComplete[ a ],
                Infinity
            ];
            widths = Extract[ #, { 1 }, HoldComplete ] & /@ args;
            {
                (* the strings of the boxes, not of their options *)
                DeleteDuplicates[ Cases[ Extract[ #, { 6 } ] /. (_Rule | _RuleDelayed) -> Nothing, s_String :> StringTrim[ s, "\"" ], { 0, Infinity } ] & /@ args ],
                DeleteDuplicates @ Cases[ widths, HoldPattern[ FEPrivate`StringWidth ][ s_String, ___ ] :> s, Infinity ],
                (* the folder does not exist: the warning's reserve too *)
                ! FreeQ[
                    widths,
                    N[
                        Last @ Wolfram`Chatbook`ACP`UI`Private`$folderRowReserve + Wolfram`Chatbook`ACP`UI`Private`$folderWarningReserve +
                            If[ # === "Changes", Wolfram`Chatbook`ACP`UI`Private`$reviewButtonReserve, 0 ]
                    ]
                ]
            }
        ] & /@ { "Changes", "Clean" }
    ],
    {
        { { { p1_String } }, { "Review" }, True } /; StringEndsQ[ p1, StringRepeat[ "abcdefghij", 5 ] ],
        { { { p2_String } }, { }, True } /; StringEndsQ[ p2, StringRepeat[ "abcdefghij", 5 ] ]
    },
    SameTest -> MatchQ,
    TestID   -> "Button-DirectoryRowPath@@Tests/ACPReview.wlt:397,1-428,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Review Notebook*)
VerificationTest[
    {
        Head @ $nb,
        nbOption[ $nb, WindowTitle ],
        nbOption[ $nb, TaggingRules ],
        nbOption[ $nb, # ] & /@ { Editable, Saveable, ShowCellBracket, CellGrouping, ClosingAutoSave, Evaluator },
        nbOption[ $nb, WindowSize ],
        KeyExistsQ[ Association[ List @@ Rest @ acpReviewNotebook[ $cs, $owner, False ] ], WindowSize ],
        MatchQ[ nbOption[ $nb, StyleDefinitions ], Notebook[ { Cell[ StyleData[ StyleDefinitions -> "Default.nb" ] ], ___ }, ___ ] ],
        MatchQ[ nbOption[ $nb, DockedCells ], { Cell[ _BoxData, "ACPReviewHeader" ] } ],
        (* no "+" menu, no visible insertion line (drawn in the background color), no horizontal scroll bar *)
        nbOption[ $nb, CellInsertionPointCell ],
        nbOption[ $nb, CellInsertionPointColor ] === FirstCase[ nbOption[ $nb, StyleDefinitions ], Cell[ StyleData[ "Notebook" ], ___, Background -> bg_, ___ ] :> bg, None, Infinity ],
        nbOption[ $nb, WindowElements ],
        (* deployed and not a user notebook for the Notebook Assistant; the text of the cells stays selectable *)
        nbOption[ $nb, Deployed ],
        FirstCase[ nbOption[ $nb, StyleDefinitions ], Cell[ StyleData[ "ACPReviewBase" ], ___, Deployed -> d_, ___ ] :> d, None, Infinity ]
    },
    {
        Notebook,
        "Changes \[LongDash] repo",
        <| "ACPReview" -> <| "Owner" -> $owner, "Directory" -> "/repo", "SSH" -> None |>, "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |> |>,
        { False, False, False, Manual, False, _String },
        { _Integer, _Integer },
        False,
        True,
        True,
        None,
        True,
        { "VerticalScrollBar", "MagnificationPopUp" },
        True,
        False
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Options@@Tests/ACPReview.wlt:433,1-468,2"
]

VerificationTest[
    With[ { cells = First @ $nb },
        {
            cells[[ 1, 2 ]],
            Length @ fileCells @ $nb,
            Length @ $cs[ "Files" ],
            cellTags /@ fileCells @ $nb,
            FreeQ[ $nb, _Missing | $Failed | _Failure ],
            chatbookSymbols @ $nb
        }
    ],
    {
        "ACPReviewList",
        15,
        15,
        Table[ { "ACPReviewFile-" <> ToString @ i }, { i, 15 } ],
        True,
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Cells@@Tests/ACPReview.wlt:470,1-491,2"
]

(* Every icon TemplateBox has its style in the private stylesheet, which holds the icon boxes *)
VerificationTest[
    Module[ { used, defined },
        used    = Union @ Cases[ $nb, TemplateBox[ { }, name_String /; StringStartsQ[ name, "ACPReviewIcon" ] ] :> name, Infinity ];
        defined = Cases[ nbOption[ $nb, StyleDefinitions ], Cell[ StyleData[ name_String ], TemplateBoxOptions -> { DisplayFunction -> Function[ _GraphicsBox ] } ] :> name, Infinity ];
        { Complement[ used, defined ], Complement[ defined, used ], used }
    ],
    { { }, { }, { "ACPReviewIconDirectory", "ACPReviewIconExtBIN", "ACPReviewIconTXT" } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-IconStyles@@Tests/ACPReview.wlt:494,1-503,2"
]

(* The file list: a jump link per file (run by the front end) to the file's cell *)
VerificationTest[
    Module[ { list },
        list = First @ Cases[ First @ $nb, c: Cell[ _, "ACPReviewList", ___ ] :> c ];
        {
            DeleteDuplicates @ Cases[ list, ButtonBox[ __, ButtonFunction :> FrontEndExecute[ { FrontEnd`NotebookLocate[ tag_String ] } ], ___, Evaluator -> None, ___ ] :> tag, Infinity ],
            containsTextQ[ list, "copy.txt" ] && containsTextQ[ list, "orig.txt" ],
            Select[ boxStrings @ list, StringStartsQ[ "and " ] ]
        }
    ],
    { Table[ "ACPReviewFile-" <> ToString @ i, { i, 15 } ], True, { } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-FileList@@Tests/ACPReview.wlt:506,1-518,2"
]

(* The jump links: a tooltip, and underlined under the mouse like the Open links. The Mouseover is outside the buttons
   (whose Evaluator -> None would apply to it otherwise); renamed files have no tooltip of their own in the list. *)
VerificationTest[
    Module[ { list, mouseovers },
        list       = First @ Cases[ First @ $nb, c: Cell[ _, "ACPReviewList", ___ ] :> c ];
        mouseovers = Cases[ list, PaneSelectorBox[ { False -> a_, True -> b_ }, Dynamic[ CurrentValue[ "MouseOver" ] ], ___ ] :> { a, b }, Infinity ];
        {
            Length @ mouseovers,
            Union[ Count[ #, _ButtonBox, { 0, Infinity } ] & /@ Flatten[ mouseovers, 1 ] ],
            Union[ MatchQ[ #[[ 2 ]], ButtonBox[ StyleBox[ _, FontVariations -> { "Underline" -> True }, ___ ], ___ ] ] & /@ mouseovers ],
            FreeQ[ Cases[ list, b_ButtonBox :> b, Infinity ], _PaneSelectorBox ],
            Length @ Cases[ list, TooltipBox[ _, tip_ /; StringContainsQ[ ToString @ tip, "Go to the diff" ], ___ ], Infinity ],
            containsTextQ[ list, "Copied from" ],
            hasStringQ[ cardOf[ "copy.txt" ], "Copied from orig.txt" ]
        }
    ],
    { 15, { 1 }, { True }, True, 15, False, True },
    SameTest -> MatchQ,
    TestID   -> "Notebook-FileListLinks@@Tests/ACPReview.wlt:522,1-539,2"
]

(* The line counts in the list are spaced like in the cards (a Row with a " " separator showed "+1\[Minus]1") *)
VerificationTest[
    Module[ { list, counts },
        list   = First @ Cases[ First @ $nb, c: Cell[ _, "ACPReviewList", ___ ] :> c ];
        counts = Cases[ list, GridBox[ { { StyleBox[ a_String, ___ ], StyleBox[ d_String, ___ ] } }, opts___ ] :> { a, d, Lookup[ { opts }, GridBoxSpacings, None ] }, Infinity ];
        {
            FreeQ[ list, TemplateBox[ _, "RowWithSeparators" ] ],
            counts[[ All, 1 ;; 2 ]],
            Union @ counts[[ All, 3 ]],
            (* the cards' header *)
            Cases[ cardOf[ "src/a.txt" ], GridBox[ { row_List /; MemberQ[ row, StyleBox[ "\"+2\"", ___ ] ] }, ___, GridBoxSpacings -> s_, ___ ] :> s, Infinity, 1 ]
        }
    ],
    {
        True,
        { { "\"+2\"", "\"\[Minus]2\"" }, { "\"+1\"", "\"\[Minus]1\"" } }, (* src/a.txt, tc.txt *)
        { { "Columns" -> { 0, 0.5, 0 }, "Rows" -> { { 0 } } } },
        { { "Columns" -> { { 0.5 } }, "Rows" -> { { 0 } } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-FileListCounts@@Tests/ACPReview.wlt:542,1-562,2"
]

(* Files are listed in natural path order in the list and in the cards: folder by folder, ignoring case, numbers by
   value *)
VerificationTest[
    Module[ { paths, cs, nb, list, cards },
        paths = { "Kernel/x.wl", "a.txt", "src/mod1.py", "src/mod10.py", "src/mod11.py", "src/mod12.py", "src/mod2.py", "src-old/b.py", "src.txt" };
        cs    = acpGitBuildChangeSet @ <| "Directory" -> "/repo", "Status" -> nulJoin[ changed[ ".M", # ] & /@ paths ] |>;
        nb    = acpReviewNotebook[ cs, $owner, True ];
        list  = First @ Cases[ First @ nb, c: Cell[ _, "ACPReviewList", ___ ] :> c ];
        cards = fileCells @ nb;
        {
            Lookup[ cs[ "Files" ], "Path" ],
            (* list rows: the file name of each row, in order *)
            Select[ boxStrings @ list, StringMatchQ[ #, __ ~~ "." ~~ LetterCharacter.. ] && ! StringContainsQ[ #, "/" ] & ] // DeleteDuplicates,
            (* cards: in the same order, with tags in order *)
            Flatten[ cellTags /@ cards ],
            And @@ MapThread[ containsTextQ[ #1, FileNameTake @ #2 ] &, { cards, Lookup[ cs[ "Files" ], "Path" ] } ]
        }
    ],
    {
        { "a.txt", "Kernel/x.wl", "src/mod1.py", "src/mod2.py", "src/mod10.py", "src/mod11.py", "src/mod12.py", "src-old/b.py", "src.txt" },
        { "a.txt", "x.wl", "mod1.py", "mod2.py", "mod10.py", "mod11.py", "mod12.py", "b.py", "src.txt" },
        Table[ "ACPReviewFile-" <> ToString @ i, { i, 9 } ],
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-FileOrder@@Tests/ACPReview.wlt:566,1-590,2"
]

(* Status badges and notes *)
VerificationTest[
    Module[ { files = Lookup[ $cs[ "Files" ], "Path" ], expected },
        expected = <|
            "conflict.txt"   -> { "Conflict"    , "Git shows no differences in the contents." },
            "copy.txt"       -> { "Copied"      , "Copied without changes." },
            "data.bin"       -> { "Untracked"   , "Binary file, not shown." },
            "empty.txt"      -> { "Added"       , "Empty file." },
            "gone.txt"       -> { "Deleted"     , None },
            "img.bin"        -> { "Modified"    , "Binary file, not shown." },
            "mode.sh"        -> { "Modified"    , "The file mode changed from 100644 to 100755." },
            "nested/"        -> { "Untracked"   , "A folder that is not tracked, for example another repository. Its files are not listed." },
            "new name.txt"   -> { "Renamed"     , "Renamed without changes." },
            "new.txt"        -> { "Added"       , None },
            "notes.md"       -> { "Untracked"   , None },
            "src/a.txt"      -> { "Modified"    , None },
            "tc.txt"         -> { "Type changed", None },
            "vendor/lib"     -> { "Submodule"   , "The submodule points to a different commit." },
            "zz-unread.txt"  -> { "Untracked"   , "Not shown: the limit for reading new files was reached." }
        |>;
        {
            Sort @ files === Sort @ Keys @ expected,
            Select[
                KeyValueMap[
                    Function[ { path, exp },
                        With[ { cell = cardOf @ path },
                            { path, hasStringQ[ cell, exp[[ 1 ]] ], If[ exp[[ 2 ]] === None, True, hasStringQ[ cell, exp[[ 2 ]] ] ] }
                        ]
                    ],
                    expected
                ],
                ! TrueQ[ #[[ 2 ]] && #[[ 3 ]] ] &
            ]
        }
    ],
    { True, { } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-StatusesAndNotes@@Tests/ACPReview.wlt:593,1-630,2"
]

(* Diffs: git's hunks, where a removed "-- comment" line ("--- ..." in the patch) is content; untracked text files as
   new files; type changes with both hunks *)
VerificationTest[
    With[ { cell = cardOf },
        {
            hasStringQ[ cell[ "src/a.txt" ], "-- a removed comment" ],
            hasStringQ[ cell[ "src/a.txt" ], "TWO" ],
            containsTextQ[ cell[ "src/a.txt" ], "diff --git" ] || containsTextQ[ cell[ "src/a.txt" ], "+++ b/" ],
            hasStringQ[ cell[ "notes.md" ], "x" ] && hasStringQ[ cell[ "notes.md" ], "y" ],
            hasStringQ[ cell[ "tc.txt" ], "tc" ] && hasStringQ[ cell[ "tc.txt" ], "src/a.txt" ],
            hasStringQ[ cell[ "gone.txt" ], "del" ],
            hasStringQ[ cell[ "vendor/lib" ], "Subproject commit 86b6f6d6e835c187ef09c436b4bc99c466c63641" ]
        }
    ],
    { True, True, False, True, True, True, True },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Diffs@@Tests/ACPReview.wlt:634,1-649,2"
]

(* Diffs in the cards fill the card's width and have line numbers from the hunk headers; deleted files have only old
   numbers, new and untracked files only new ones *)
VerificationTest[
    {
        diffNumbers @ cardOf[ "src/a.txt" ],
        diffNumbers @ cardOf[ "gone.txt" ],
        diffNumbers @ cardOf[ "new.txt" ],
        diffNumbers @ cardOf[ "notes.md" ],
        diffNumbers @ cardOf[ "tc.txt" ],
        Union @ Flatten[ diffFrameSizes /@ fileCells @ $nb ]
    },
    {
        { { "", "" }, { "1", "1" }, { "2", "" }, { "", "2" }, { "3", "3" }, { "4", "" }, { "", "4" } },
        { { "" }, { "1" } },
        { { "" }, { "1" } },
        { { "1" }, { "2" } },
        { { "", "" }, { "1", "" }, { "", "" }, { "", "1" } },
        { Full }
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-DiffLineNumbers@@Tests/ACPReview.wlt:653,1-672,2"
]

(* Open links for every file but deleted ones; WL files open in the front end, others in their application or folder *)
VerificationTest[
    Module[ { opens },
        (* the header (with the link) is in both panes of the opener *)
        opens = Union @ Cases[ actionCalls @ First @ $nb, { "ReviewOpenFile", path_ } :> path ];
        {
            Length @ opens,
            Complement[ Lookup[ $cs[ "Files" ], "FullPath" ], opens ],
            FreeQ[ opens, FileNameJoin @ { "/repo", "gone.txt" } ]
        }
    ],
    { 14, { FileNameJoin @ { "/repo", "gone.txt" } }, True },
    SameTest -> MatchQ,
    TestID   -> "Notebook-OpenLinks@@Tests/ACPReview.wlt:675,1-688,2"
]

(* Cards start open, except binary files *)
VerificationTest[
    {
        Length @ openStates @ $nb,
        Keys @ Select[ AssociationThread[ Lookup[ $cs[ "Files" ], "Path" ], openStates @ $nb ], ! # & ]
    },
    { 15, { "data.bin", "img.bin" } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-OpenersSmall@@Tests/ACPReview.wlt:691,1-699,2"
]

(* A long diff starts closed and is rendered when it is first opened (lazily, from data stored in the cell) *)
VerificationTest[
    Module[ { patch, cs, nb, card, lazy },
        patch = StringRiffle[ Join[ { "diff --git a/big.txt b/big.txt", "--- a/big.txt", "+++ b/big.txt", "@@ -1,500 +1,500 @@" }, Table[ "+line " <> ToString @ i, { i, 500 } ] ], "\n" ];
        cs    = acpGitBuildChangeSet @ <| "Directory" -> "/repo", "Status" -> nulJoin @ { changed[ ".M", "big.txt" ], changed[ ".M", "small.txt" ] }, "Patch" -> patch <> "\ndiff --git a/small.txt b/small.txt\n--- a/small.txt\n+++ b/small.txt\n@@ -1 +1 @@\n-a\n+b" |>;
        nb    = acpReviewNotebook[ cs, $owner, True ];
        card  = First @ fileCells @ nb;
        lazy  = Cases[ actionCalls @ card, { "ReviewDiffView", data_ } :> data ];
        {
            openStates @ nb,
            Cases[ card, DynamicBox[ _, ___, SynchronousUpdating -> False, ___ ], Infinity ] =!= { },
            KeyTake[ First @ lazy, { "Path", "Omitted" } ],
            Length @ StringSplit[ First[ lazy ][ "Patch" ], "\n" ],
            FreeQ[ card, "\"line 1\"" ], (* the rows are not rendered *)
            hasStringQ[ Last @ fileCells @ nb, "b" ] && Union @ actionCalls[ Last @ fileCells @ nb ] === { { "ReviewOpenFile", FileNameJoin @ { "/repo", "small.txt" } } },
            (* rendered when opened: 400 lines (the hunk header and 399 added lines, numbered), the rest in the note *)
            With[ { view = ToBoxes @ acpReviewDiffView @ First @ lazy },
                { Length @ diffNumbers @ view, Last @ diffNumbers @ view, diffFrameSizes @ view, containsTextQ[ view, "101 more lines" ] }
            ]
        }
    ],
    {
        { False, True },
        True,
        <| "Path" -> "big.txt", "Omitted" -> 101 |>, (* 501 lines from the first "@@" *)
        400,
        True,
        True,
        { 400, { "399" }, { Full }, True }
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-LazyDiff@@Tests/ACPReview.wlt:702,1-733,2"
]

(* Many files: all cards start closed *)
VerificationTest[
    Module[ { cs, nb },
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo",
            "Status"    -> nulJoin @ Table[ changed[ ".M", "f" <> IntegerString[ i, 10, 2 ] <> ".txt" ], { i, 31 } ],
            "Patch"     -> StringRiffle[
                Table[
                    With[ { f = "f" <> IntegerString[ i, 10, 2 ] <> ".txt" }, "diff --git a/" <> f <> " b/" <> f <> "\n--- a/" <> f <> "\n+++ b/" <> f <> "\n@@ -1 +1 @@\n-a\n+b" ],
                    { i, 31 }
                ],
                "\n"
            ]
        |>;
        nb = acpReviewNotebook[ cs, $owner, True ];
        { Length @ fileCells @ nb, Union @ openStates @ nb, Length @ Cases[ actionCalls @ nb, { "ReviewDiffView", _ } ] }
    ],
    { 31, { False }, 31 },
    SameTest -> MatchQ,
    TestID   -> "Notebook-OpenersManyFiles@@Tests/ACPReview.wlt:736,1-755,2"
]

(* Files that are not listed, and incomplete git output *)
VerificationTest[
    Module[ { notes },
        notes = Function[ { cs, start }, Select[ boxStrings @ First @ acpReviewNotebook[ cs, $owner, True ], StringStartsQ[ start ] ] ];
        {
            notes[ <| $cs, "MoreFiles" -> 1234 |>, "and " ],
            notes[ <| $cs, "MoreFiles" -> 1 |>, "and " ],
            notes[ $cs, "and " ],
            notes[ <| $cs, "PatchComplete" -> False, "CountsComplete" -> False |>, "Some diffs" | "Line counts" ],
            Length @ Cases[ First @ acpReviewNotebook[ <| $cs, "PatchComplete" -> False |>, $owner, True ], Cell[ _, "ACPReviewNotice", ___ ] ]
        }
    ],
    {
        { "and 1234 more files" },
        { "and 1 more file" },
        { },
        { "Some diffs are not shown: Git's output was too large or took too long.", "Line counts are not available." },
        1
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Truncation@@Tests/ACPReview.wlt:758,1-778,2"
]

(* The diff text kept in a window is bounded: later diffs are not shown *)
VerificationTest[
    (* diff text in file order: gone.txt 18 characters, new.txt 20, notes.md 3, src/a.txt 61, ... *)
    Block[ { Wolfram`Chatbook`ACP`Review`Private`$reviewMaxText = 50 },
        Module[ { nb = acpReviewNotebook[ $cs, $owner, True ], files = Lookup[ $cs[ "Files" ], "Path" ] },
            Keys @ Select[ AssociationThread[ files, containsTextQ[ #, "too many changes to show" ] & /@ fileCells @ nb ], TrueQ ]
        ]
    ],
    { "src/a.txt", "tc.txt", "vendor/lib" },
    SameTest -> MatchQ,
    TestID   -> "Notebook-TextBudget@@Tests/ACPReview.wlt:781,1-791,2"
]

(* The header: folder, branch, counts, time and a Refresh button that finds its window with EvaluationNotebook[] *)
VerificationTest[
    Module[ { docked = First @ nbOption[ $nb, DockedCells ] },
        {
            containsTextQ[ docked, "/repo" ],
            Select[ boxStrings @ docked, MemberQ[ { "On branch main", "15 files changed", "+6", "\[Minus]4" }, # ] & ],
            AnyTrue[ boxStrings @ docked, StringStartsQ[ "Updated " ] ],
            actionCalls @ docked,
            containsTextQ[ docked, "Loading changes" ],
            containsTextQ[ acpReviewDockedCell[ $cs, True ], "Loading changes" ]
        }
    ],
    { True, { "On branch main", "15 files changed", "+6", "\[Minus]4" }, True, { { "ReviewRefresh", "EvaluationNotebook[]" } }, False, True },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Header@@Tests/ACPReview.wlt:794,1-808,2"
]

VerificationTest[
    Function[ cs, Select[ boxStrings @ acpReviewDockedCell[ cs, False ], StringStartsQ[ "On branch" | "HEAD detached" | "No commits" ] ] ] /@ {
        <| $cs, "Branch" -> None, "Detached" -> True, "OID" -> $h |>,
        <| $cs, "Initial" -> True, "OID" -> None |>
    },
    { { "HEAD detached at 4b5a6b8" }, { "On branch main", "No commits yet" } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-HeaderBranch@@Tests/ACPReview.wlt:810,1-818,2"
]

(* Loading, clean, and the states where nothing can be listed *)
VerificationTest[
    Function[ changes,
        With[ { cells = First @ acpReviewNotebook[ changes, $owner, True ] },
            { Length @ cells, cells[[ 1, 2 ]], textStrings @ cells }
        ]
    ] /@ {
        <| "Status" -> "Loading", "Directory" -> "/repo" |>,
        <| $cs, "Status" -> "Clean", "Files" -> { }, "FileCount" -> 0 |>,
        <| "Status" -> "NoDirectory", "Directory" -> None |>,
        <| "Status" -> "NotRepository", "Directory" -> "/repo" |>,
        <| "Status" -> "Unavailable", "Directory" -> "/repo", "Error" -> <| "Code" -> "NotFound" |> |>,
        <| "Status" -> "Unavailable", "Directory" -> "/repo", "Error" -> <| "Code" -> "GitTooOld" |>, "GitVersion" -> "2.20.1" |>,
        <| "Status" -> "Unavailable", "Directory" -> "/repo", "Error" -> <| "Code" -> "Disabled" |> |>,
        <| "Status" -> "Error", "Directory" -> "/repo", "Error" -> <| "Code" -> "GitFailed", "Detail" -> "fatal: bad object HEAD" |> |>,
        <| "Status" -> "Error", "Directory" -> "/repo", "Error" -> <| "Code" -> "TimedOut", "Detail" -> None |> |>,
        <| "Status" -> "Error", "Directory" -> "/repo", "Error" -> <| "Code" -> "Cancelled" |> |>
    },
    {
        { 1, "ACPReviewMessage", { "Loading changes\[Ellipsis]" } },
        { 1, "ACPReviewMessage", { "No uncommitted changes", "The files in the project folder match the last commit." } },
        { 1, "ACPReviewMessage", { "No project folder", "Choose a project folder in the agent window first." } },
        { 1, "ACPReviewMessage", { "The project folder is not in a Git repository." } },
        { 1, "ACPReviewMessage", { "Git was not found.", "Install Git (https://git-scm.com) to review changes." } },
        { 1, "ACPReviewMessage", { "Git 2.20.1 is too old.", "Reviewing changes needs Git 2.25 or later." } },
        { 1, "ACPReviewMessage", { "Reviewing changes is turned off." } },
        { 1, "ACPReviewMessage", { "Git could not list the changes.", "fatal: bad object HEAD" } },
        { 1, "ACPReviewMessage", { "Git took too long to list the changes." } },
        { 1, "ACPReviewMessage", { "The check was cancelled." } }
    },
    SameTest -> MatchQ,
    TestID   -> "Notebook-States@@Tests/ACPReview.wlt:821,1-852,2"
]

VerificationTest[
    {
        nbOption[ acpReviewNotebook[ <| "Status" -> "NoDirectory", "Directory" -> None |>, $owner, True ], WindowTitle ],
        Select[ boxStrings @ acpReviewDockedCell[ <| "Status" -> "NoDirectory", "Directory" -> None |>, False ], StringStartsQ[ "No project" ] ]
    },
    { "Changes", { "No project folder" } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-NoFolder@@Tests/ACPReview.wlt:854,1-862,2"
]

(* A project folder in a subdirectory of the repository: paths relative to it, original paths outside of it *)
VerificationTest[
    Module[ { cs, nb },
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo/src",
            "Root"      -> "/repo",
            "Prefix"    -> "src/",
            "Status"    -> nulJoin @ { "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R90 src/x.txt", "lib/x.txt" },
            "Patch"     -> "diff --git a/lib/x.txt b/src/x.txt\nsimilarity index 90%\nrename from lib/x.txt\nrename to src/x.txt\n--- a/lib/x.txt\n+++ b/src/x.txt\n@@ -1 +1 @@\n-a\n+b"
        |>;
        nb = acpReviewNotebook[ cs, $owner, True ];
        {
            nbOption[ nb, WindowTitle ],
            containsTextQ[ First @ fileCells @ nb, "../lib/x.txt" ],
            containsTextQ[ First @ fileCells @ nb, "Renamed from ../lib/x.txt" ],
            Union @ actionCalls @ First @ fileCells @ nb
        }
    ],
    { "Changes \[LongDash] src", True, True, { { "ReviewOpenFile", FileNameJoin @ { "/repo", "src", "x.txt" } } } },
    SameTest -> MatchQ,
    TestID   -> "Notebook-Subdirectory@@Tests/ACPReview.wlt:865,1-885,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)
VerificationTest[
    Module[ { view },
        view = ToBoxes @ acpReviewDiffView @ <| "Path" -> "big.txt", "Patch" -> "@@ -1,2 +1,2 @@\n-a\n+b", "Omitted" -> 100 |>;
        {
            containsTextQ[ view, "big.txt" ],
            containsTextQ[ view, "100 more lines" ],
            containsTextQ[ view, "a" ] && containsTextQ[ view, "b" ],
            containsTextQ[ ToBoxes @ acpReviewDiffView @ <| "Path" -> "n.txt", "OldText" -> None, "NewText" -> "new\ntext", "Omitted" -> 0 |>, "new" ],
            acpReviewDiffView @ None,
            diffNumbers @ view,
            diffFrameSizes @ view
        }
    ],
    { False, True, True, True, "", { { "", "" }, { "1", "" }, { "", "1" } }, { Full } },
    SameTest -> MatchQ,
    TestID   -> "Action-DiffView@@Tests/ACPReview.wlt:890,1-906,2"
]

(* Open: WL files in the front end, documents in their application, anything else (e.g. scripts) in its folder *)
VerificationTest[
    Module[ { dir, files },
        dir   = AbsoluteFileName @ CreateDirectory @ FileNameJoin @ { $reviewScratch, "open" };
        files = FileNameJoin @ { dir, # } & /@ { "a.wl", "b.md", "c.py", "d.exe", "e.PNG" };
        Scan[ Export[ #, "x", "Text" ] &, files ];
        Block[ { $callLog = { }, NotebookOpen = logCall[ "NotebookOpen", ## ] &, SystemOpen = logCall[ "SystemOpen", ## ] & },
            Scan[ acpReviewOpenFile, Append[ files, dir ] ];
            acpReviewOpenFile @ FileNameJoin @ { dir, "missing.txt" };
            Replace[ $callLog, { name_, path_String } :> { name, StringDelete[ StringReplace[ path, dir -> "DIR" ], $PathnameSeparator ~~ EndOfString ] }, { 1 } ]
        ]
    ],
    {
        { "NotebookOpen", FileNameJoin @ { "DIR", "a.wl" } },
        { "SystemOpen", FileNameJoin @ { "DIR", "b.md" } },
        { "SystemOpen", "DIR" },
        { "SystemOpen", "DIR" },
        { "SystemOpen", FileNameJoin @ { "DIR", "e.PNG" } },
        { "SystemOpen", "DIR" }
    },
    SameTest -> MatchQ,
    TestID   -> "Action-OpenFile@@Tests/ACPReview.wlt:909,1-930,2"
]

(* Open never passes a folder with an extension (on macOS, an app bundle would be launched) or a link to one to
   SystemOpen; links are resolved first. The tooltip says what the click does. *)
VerificationTest[
    If[ $OperatingSystem === "Windows",
        Missing[ "TestSkipped" ],
        Module[ { dir, paths, linkQ, tooltip },
            dir = AbsoluteFileName @ CreateDirectory @ FileNameJoin @ { $reviewScratch, "bundles" };
            Export[ FileNameJoin @ { dir, "Tool.app", "README" }, "x", "Text" ];
            Export[ FileNameJoin @ { dir, "Tool.app", "Contents", "Info.plist" }, "x", "Text" ];
            Export[ FileNameJoin @ { dir, "Nested.app", "x.txt" }, "x", "Text" ];
            Export[ FileNameJoin @ { dir, "Plain", "Contents", "Info.plist" }, "x", "Text" ];
            Export[ FileNameJoin @ { dir, "run.command" }, "x", "Text" ];
            CreateDirectory @ FileNameJoin @ { dir, "sub" };
            (* symbolic links (made with the ln of the system) *)
            linkQ = And @@ Apply[
                RunProcess[ { "ln", "-s", #1, #2 }, ProcessDirectory -> dir ][ "ExitCode" ] === 0 &,
                { { "Tool.app", "docs.txt" }, { "run.command", "readme.md" }, { "sub", "folder-link" } },
                { 1 }
            ];
            paths = FileNameJoin @ { dir, # } & /@ { "Tool.app/README", "Nested.app", "Plain", "docs.txt", "readme.md", "folder-link", "sub" };
            tooltip = Function[ path,
                FirstCase[
                    Wolfram`Chatbook`ACP`Review`Private`reviewOpenLinkBoxes @ <| "Status" -> "Modified", "FullPath" -> path, "Directory" -> False |>,
                    s_String /; StringMatchQ[ s, ("\"Open " | "\"Show ") ~~ __ ] :> StringTrim[ s, "\"" ],
                    None,
                    Infinity
                ]
            ];
            Block[ { $callLog = { }, NotebookOpen = logCall[ "NotebookOpen", ## ] &, SystemOpen = logCall[ "SystemOpen", ## ] & },
                Scan[ acpReviewOpenFile, paths ];
                {
                    linkQ,
                    Replace[ $callLog, { name_, path_String } :> { name, StringReplace[ path, dir -> "DIR" ] }, { 1 } ],
                    tooltip /@ paths
                }
            ]
        ]
    ],
    Missing[ "TestSkipped" ] | {
        True,
        {
            { "SystemOpen", "DIR" },
            { "SystemOpen", "DIR" },
            { "SystemOpen", "DIR" },
            { "SystemOpen", "DIR" },
            { "SystemOpen", "DIR" },
            { "SystemOpen", "DIR/sub" },
            { "SystemOpen", "DIR/sub" }
        },
        {
            "Show README in its folder",
            "Show Nested.app in its folder",
            "Show Plain in its folder",
            "Show docs.txt in its folder",
            "Show readme.md in its folder",
            "Open folder-link",
            "Open sub"
        }
    },
    SameTest -> MatchQ,
    TestID   -> "Action-OpenFileBundles@@Tests/ACPReview.wlt:934,1-993,2"
]

(* The button opens a window that shows "Loading changes..." and starts a request, or raises the open one *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Common`acpCheckSession       = True &,
            Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord = (<| "Status" -> "Ready", "ProjectDirectory" -> "/repo" |> &),
            Wolfram`Chatbook`ACP`Review`Private`reviewRequest = logCall[ "Request", ## ] &,
            NotebookPut         = (logCall[ "NotebookPut", ## ]; $review) &,
            SetSelectedNotebook = logCall[ "SetSelectedNotebook", ## ] &
        },
        {
            Block[ { Wolfram`Chatbook`ACP`Review`Private`reviewWindowOf = None & },
                {
                    acpReviewChanges @ $owner,
                    MatchQ[
                        calls[ "NotebookPut" ],
                        { { Notebook[ { Cell[ _, "ACPReviewMessage" ] }, ___, WindowSize -> _, ___ ] } }
                    ],
                    containsTextQ[ calls[ "NotebookPut" ], "Loading changes" ],
                    calls[ "Request" ]
                }
            ],
            $callLog = { };
            Block[ { Wolfram`Chatbook`ACP`Review`Private`reviewWindowOf = $review & },
                { acpReviewChanges @ $owner, calls[ "NotebookPut" ], calls[ "SetSelectedNotebook" ], calls[ "Request" ] }
            ],
            (* a folder without an ACP window *)
            $callLog = { };
            Block[ { Wolfram`Chatbook`ACP`Review`Private`reviewWindowOf = None & },
                { acpReviewChanges @ File @ $TemporaryDirectory, calls[ "Request" ] }
            ]
        }
    ],
    {
        { $review, True, True, { { $review, $owner, "/repo" } } },
        { $review, { }, { { $review } }, { { $review, $owner, "/repo" } } },
        { $review, { { $review, None, ExpandFileName @ $TemporaryDirectory } } }
    },
    SameTest -> MatchQ,
    TestID   -> "Action-ReviewChanges@@Tests/ACPReview.wlt:996,1-1036,2"
]

(* Requests: with the owner window's record, with the folder only, or neither *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| |>,
            Notebooks  = { $review } &,
            SetOptions = logCall[ "SetOptions", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpSchedule   = logCall[ "Schedule", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpGitChanges = (logCall[ "GitChanges", #1 ]; "token-" <> ToString @ Length @ $callLog) &,
            Wolfram`Chatbook`ACP`Common`acpWindowGet  = Replace[ #, { $owner -> <| "Status" -> "Ready" |>, _ -> Missing[ "NotFound" ] } ] &
        },
        {
            Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, $owner, "/repo" ],
            Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, NotebookObject[ "gone" ], "/repo" ],
            StringQ @ Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, $failed, None ],
            calls[ "GitChanges" ],
            Length @ calls[ "Schedule" ],
            Length @ calls[ "SetOptions" ],
            containsTextQ[ calls[ "SetOptions" ], "Loading changes" ],
            Keys @ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows
        }
    ],
    {
        "token-2",
        "token-4",
        True,
        { { $owner }, { "/repo" } },
        1,
        3,
        True,
        { $review }
    },
    SameTest -> MatchQ,
    TestID   -> "Action-Requests@@Tests/ACPReview.wlt:1039,1-1073,2"
]

(* Results: only the window's latest request is shown (then the window is scrolled to the top: NotebookPut would leave it
   at the end); results for closed windows are dropped. Changes are shown by reviewStep, from the next pump tick on;
   other results right away. *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| $review -> <| "Token" -> "t2" |> |>,
            (* the small change set is shown in one step also on a loaded machine *)
            Wolfram`Chatbook`ACP`Review`Private`$reviewStepTime = 10,
            $openWindows         = { $review },
            Notebooks            = $openWindows &,
            NotebookPut          = logCall[ "NotebookPut", ## ] &,
            FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpSchedule = Function[ eval, logCall[ "Schedule" ], HoldFirst ]
        },
        {
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t1" |> ];
            $callLog,
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t2" |> ];
            $callLog[[ All, 1 ]],
            (* a step of a superseded result does nothing *)
            Wolfram`Chatbook`ACP`Review`Private`reviewStep[ $review, "t1" ];
            Wolfram`Chatbook`ACP`Review`Private`reviewStep[ $review, "t2" ];
            MatchQ[ calls[ "NotebookPut" ], { { _Notebook, $review } } ] && FreeQ[ calls[ "NotebookPut" ], WindowSize ],
            $callLog[[ All, 1 ]],
            calls[ "FrontEndTokenExecute" ],
            KeyExistsQ[ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review ], "Job" ],
            (* a result without changes is shown right away *)
            $callLog = { };
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review, "Token" ] = "t3";
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t3", "Status" -> "Clean", "Files" -> { } |> ];
            $callLog[[ All, 1 ]],
            (* the window was closed *)
            $callLog = { };
            $openWindows = { };
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t3" |> ];
            { $callLog, Wolfram`Chatbook`ACP`Review`Private`$reviewWindows }
        }
    ],
    {
        { },
        { "Schedule" },
        True,
        { "Schedule", "NotebookPut", "FrontEndTokenExecute" },
        { { $review, "ScrollNotebookStart" } },
        False,
        { "NotebookPut", "FrontEndTokenExecute" },
        { { }, <| |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Action-Results@@Tests/ACPReview.wlt:1078,1-1127,2"
]

(* A large result is shown in steps that each do little work: the rows of the file list, then the notebook with the list
   and the first card, then the other cards, written after the last cell (without moving the selection). The cells are
   those of acpReviewCells. A newer request drops the job. *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| $review -> <| "Token" -> "t1" |> |>,
            Wolfram`Chatbook`ACP`Review`Private`$reviewStepTime = 0,
            Notebooks            = { $review } &,
            Cells                = { CellObject[ "last" ] } &,
            NotebookPut          = logCall[ "NotebookPut", ## ] &,
            NotebookWrite        = logCall[ "NotebookWrite", ## ] &,
            FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpSchedule = Function[ eval, logCall[ "Schedule" ], HoldFirst ]
        },
        Module[ { steps = 0, puts, writes, job },
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t1" |> ];
            While[ KeyExistsQ[ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review ], "Job" ] && steps < 100,
                Wolfram`Chatbook`ACP`Review`Private`reviewStep[ $review, "t1" ];
                steps++
            ];
            puts   = calls[ "NotebookPut" ];
            writes = calls[ "NotebookWrite" ];
            (* a newer request drops the job *)
            Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t1" |> ];
            job = KeyExistsQ[ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review ], "Job" ];
            Block[ { SetOptions = Null &, Wolfram`Chatbook`ACP`Common`acpGitChanges = "t2" & },
                Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, None, "/repo" ]
            ];
            {
                steps,
                Length @ puts,
                Length @ writes,
                Union @ writes[[ All, { 1, 3, 4 } ]],
                Join[ First @ puts[[ 1, 1 ]], Flatten @ writes[[ All, 2 ]] ] === acpReviewCells @ $cs,
                job,
                KeyExistsQ[ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review ], "Job" ]
            }
        ]
    ],
    { 30, 1, 14, { { System`NotebookLocationSpecifier[ CellObject[ "last" ], "After" ], None, AutoScroll -> False } }, True, True, False },
    SameTest -> MatchQ,
    TestID   -> "Action-ResultSteps@@Tests/ACPReview.wlt:1132,1-1173,2"
]

(* While the next request runs, the header keeps the branch and counts of the changes shown *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| $review -> <| "Token" -> "t1" |> |>,
            Notebooks            = { $review } &,
            NotebookPut          = logCall[ "NotebookPut", ## ] &,
            FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &,
            SetOptions           = logCall[ "SetOptions", ## ] &,
            Wolfram`Chatbook`ACP`Common`acpGitChanges = "t2" &
        },
        Wolfram`Chatbook`ACP`Review`Private`reviewResult[ $review, <| $cs, "Token" -> "t1" |> ];
        {
            KeyExistsQ[ Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review, "Header" ], "Files" ],
            Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, None, "/repo" ],
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review, "Token" ],
            Select[ textStrings @ calls[ "SetOptions" ], StringStartsQ[ "On branch" | "15 files" | "Loading" ] ]
        }
    ],
    { False, "t2", "t2", { "On branch main", "15 files changed", "Loading changes\[Ellipsis]" } },
    SameTest -> MatchQ,
    TestID   -> "Action-RefreshKeepsHeader@@Tests/ACPReview.wlt:1176,1-1198,2"
]

(* Text from the repository never becomes boxes: the private-use characters of the front end's linear syntax are
   neutralized in paths, diffs, contents, branch names and git's messages (Git.wl does that when it decodes git's output;
   the review window does it again). ToBoxes would turn them into backslash escapes in box strings, which the front end
   parses. Button actions (the full path of the Open link) are not shown. *)
VerificationTest[
    Module[ { chars, payload, cs, nb, error, lazy, shown, bad },
        chars   = Characters @ FromCharacterCode @ Range[ 63424, 63437 ];
        payload = FromCharacterCode @ { 63425, 63433, 63432 } <> "StyleBox[\"X\", FontSize -> 1]" <> FromCharacterCode[ 63424 ];
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo",
            "Status"    -> nulJoin @ {
                "# branch.oid " <> $h,
                "# branch.head b" <> payload,
                "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R90 new" <> payload <> ".txt",
                "old" <> payload <> ".txt",
                "? u" <> payload <> ".txt"
            },
            "Patch"     -> "diff --git a/old.txt b/new.txt\nsimilarity index 90%\nrename from old" <> payload <> ".txt\nrename to new" <> payload <> ".txt\n@@ -1 +1 @@\n-a\n+" <> payload <> "\n",
            "Untracked" -> <| "u" <> payload <> ".txt" -> <| "Added" -> 1, "Binary" -> False, "Content" -> payload <> "\n", "Note" -> None |> |>
        |>;
        nb    = acpReviewNotebook[ cs, $owner, True ];
        error = acpReviewCells @ <| "Status" -> "Error", "Directory" -> "/repo", "Error" -> <| "Code" -> "GitFailed", "Detail" -> "fatal: " <> payload |> |>;
        lazy  = ToBoxes @ acpReviewDiffView @ <| "Path" -> "x", "Patch" -> "@@ -1 +1 @@\n-a\n+" <> payload, "Omitted" -> 0 |>;
        shown = { nb, error, lazy } /. HoldPattern[ ButtonFunction :> _ ] -> Null;
        bad   = Cases[ shown, s_String /; AnyTrue[ chars, StringContainsQ[ s, # ] & ] || StringContainsQ[ s, "\\!\\(" ], Infinity ];
        {
            Length @ fileCells @ nb,
            bad,
            Count[ shown, s_String /; StringContainsQ[ s, "\:fffd" ], Infinity ] >= 6
        }
    ],
    { 2, { }, True },
    SameTest -> MatchQ,
    TestID   -> "Notebook-LinearSyntax@@Tests/ACPReview.wlt:1204,1-1234,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Display-safe names*)

(* Names are shown display-safe, for local folders too: a bidi control or another invisible character in a path, a file
   name, a renamed file's old path, the folder, the branch or a link target shows as a visible [[U+XXXX]] (as
   acpRemoteDisplayName shows it), in the file list, the card headers, the tooltips, the header and the window title, so
   that "old<U+202E>txt.exe" can't pass for "oldexe.txt". Diff lines show the bidi controls the same way (the "Trojan
   Source" trick). The actions keep the raw values: the Open link opens the file itself, and a refresh lists the folder
   itself. *)
VerificationTest[
    Module[ { rlo, lri, pdi, zwsp, hidden, cs, nb, docked, shown, list, card, link },
        { rlo, lri, pdi, zwsp } = FromCharacterCode /@ { 16^^202E, 16^^2066, 16^^2069, 16^^200B };
        hidden = { rlo, lri, pdi, zwsp };
        cs = acpGitBuildChangeSet @ <|
            "Directory" -> "/repo" <> rlo,
            "Root"      -> "/repo" <> rlo,
            "Prefix"    -> "",
            "Status"    -> nulJoin @ {
                "# branch.oid " <> $h,
                "# branch.head b" <> rlo <> "x",
                "2 R. N... 100644 100644 100644 " <> $h <> " " <> $h <> " R90 new" <> lri <> ".txt",
                "old" <> rlo <> "txt.exe",
                changed[ ".M", "src" <> zwsp <> "/a.c" ],
                "? link.txt",
                "? rtl" <> rlo <> "gnp.py"
            },
            "Patch"     -> StringJoin[
                "diff --git a/src" <> zwsp <> "/a.c b/src" <> zwsp <> "/a.c\n",
                "--- a/src" <> zwsp <> "/a.c\n",
                "+++ b/src" <> zwsp <> "/a.c\n",
                "@@ -1 +1 @@\n",
                "-if (x) {\n",
                "+if (access != \"user" <> rlo <> " " <> lri <> "// Check if admin" <> pdi <> " " <> lri <> "\") {\n"
            ],
            "Untracked" -> <|
                "rtl" <> rlo <> "gnp.py" -> <| "Added" -> 1, "Binary" -> False, "Content" -> "x\n", "Note" -> None |>,
                "link.txt" -> <| "Added" -> 1, "Binary" -> False, "Content" -> None, "Note" -> "SymbolicLink", "LinkTarget" -> "/elsewhere/" <> rlo <> "x" |>
            |>
        |>;
        nb     = acpReviewNotebook[ cs, $owner, True ];
        docked = First @ nbOption[ nb, DockedCells ];
        (* everything that is shown: the cells, the header and the title (the actions are not shown) *)
        shown = { First @ nb, docked, nbOption[ nb, WindowTitle ] } /. HoldPattern[ ButtonFunction :> _ ] -> Null;
        list  = First @ Cases[ First @ nb, c: Cell[ _, "ACPReviewList", ___ ] :> c ];
        card  = SelectFirst[ fileCells @ nb, containsTextQ[ #, "gnp.py" ] &, None ];
        link  = SelectFirst[ fileCells @ nb, containsTextQ[ #, "link.txt" ] &, None ];
        {
            Cases[ shown, s_String /; StringContainsQ[ s, Alternatives @@ hidden ], Infinity ],
            (* the file list and the card headers *)
            hasStringQ[ list, "rtl\:27e6U+202E\:27e7gnp.py" ] && hasStringQ[ card, "rtl\:27e6U+202E\:27e7gnp.py" ],
            hasStringQ[ list, "old\:27e6U+202E\:27e7txt.exe" ] && hasStringQ[ list, "new\:27e6U+2066\:27e7.txt" ],
            hasStringQ[ list, "src\:27e6U+200B\:27e7/" ],
            (* tooltips: a renamed file's old path, the Open link *)
            containsTextQ[ First @ nb, "Renamed from old\:27e6U+202E\:27e7txt.exe" ],
            containsTextQ[ card, "rtl\:27e6U+202E\:27e7gnp.py in its folder" ],
            (* the title, the header (folder, its tooltip, branch) and a link target *)
            nbOption[ nb, WindowTitle ],
            Count[ boxStrings @ docked, "/repo\:27e6U+202E\:27e7" ] >= 2,
            containsTextQ[ docked, "On branch b\:27e6U+202E\:27e7x" ],
            containsTextQ[ link, "A symbolic link to /elsewhere/\:27e6U+202E\:27e7x." ],
            (* a diff line *)
            containsTextQ[ First @ nb, "user\:27e6U+202E\:27e7 \:27e6U+2066\:27e7// Check if admin\:27e6U+2069\:27e7 \:27e6U+2066\:27e7" ],
            (* the actions keep the raw paths *)
            MemberQ[ actionCalls @ card, { "ReviewOpenFile", "/repo" <> rlo <> "/rtl" <> rlo <> "gnp.py" } ],
            nbOption[ nb, TaggingRules ][ "ACPReview", "Directory" ] === "/repo" <> rlo
        }
    ],
    {
        { },
        True,
        True,
        True,
        True,
        True,
        "Changes \[LongDash] repo\:27e6U+202E\:27e7",
        True,
        True,
        True,
        True,
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Review-DisplaySafe-Names@@Tests/ACPReview.wlt:1246,1-1321,2"
]

(* A remote folder's header: the host and the path display-safe *)
VerificationTest[
    Module[ { rlo, remote, docked },
        rlo    = FromCharacterCode[ 16^^202E ];
        remote = <| "Host" -> "me@dev" <> rlo <> "box", "Short" -> "dev" <> rlo <> "box", "Home" -> "/home/u" |>;
        docked = acpReviewDockedCell[ <| "Status" -> "Loading", "Directory" -> "/home/u/r" <> rlo, "Remote" -> remote |>, True ];
        {
            Cases[ docked, s_String /; StringContainsQ[ s, rlo ], Infinity ],
            hasStringQ[ docked, "dev\:27e6U+202E\:27e7box:~/r\:27e6U+202E\:27e7" ],
            containsTextQ[ docked, "me@dev\:27e6U+202E\:27e7box:/home/u/r\:27e6U+202E\:27e7" ],
            nbOption[ acpReviewNotebook[ <| "Status" -> "Loading", "Directory" -> "/home/u/r" <> rlo, "Remote" -> remote |>, $owner, True, None ], WindowTitle ]
        }
    ],
    { { }, True, True, "Changes \[LongDash] r\:27e6U+202E\:27e7" },
    SameTest -> MatchQ,
    TestID   -> "Review-DisplaySafe-RemoteHeader@@Tests/ACPReview.wlt:1324,1-1339,2"
]

(* A long local folder never pushes Refresh out of the header: the folder is kept from its end (at most
   $reviewMaxFolderLabel characters, the whole path in the tooltip) in a Fit column whose pane draws a folder that is
   still too wide smaller; Refresh is outside that pane *)
VerificationTest[
    Module[ { long, docked, fit, label },
        long   = "/srv/" <> StringRiffle[ Table[ "folder-" <> ToString[ i ], { i, 15 } ], "/" ] <> "/project";
        docked = First @ nbOption[ acpReviewNotebook[ <| "Status" -> "Loading", "Directory" -> long |>, $owner, True, None ], DockedCells ];
        fit    = Cases[ docked, ItemBox[ PaneBox[ _, ___, ImageSizeAction -> "ShrinkToFit", ___ ], ___, ItemSize -> Fit, ___ ], Infinity ];
        label  = Cases[ fit, StyleBox[ s_String, ___, FontWeight -> "DemiBold", ___ ] :> StringTrim[ s, "\"" ], Infinity ];
        {
            Length @ fit,
            FreeQ[ fit, "ACPReviewRefreshButton" ] && ! FreeQ[ docked, "ACPReviewRefreshButton" ],
            label,
            StringLength /@ label,
            ! FreeQ[ fit, "\"" <> long <> "\"" ]
        }
    ],
    { 1, True, { _String? (StringEndsQ[ "/folder-15/project" ]) }, { _Integer? (# <= 80 &) }, True },
    SameTest -> MatchQ,
    TestID   -> "Review-Header-LongFolder@@Tests/ACPReview.wlt:1344,1-1361,2"
]

(* Diffs, file contents and git's messages: the bidi controls and the line and paragraph separators are shown; tabs,
   line breaks and ordinary text (emoji with joiners and variation selectors) are kept, and the line count is unchanged.
   Only the kept part of a long text is processed (a replacement in megabytes of text would hold up the pump). A marker
   makes a line longer: a long line is cut before a marker that would not fit, so that the diff view (which cuts lines
   at 300 characters too) shows a whole marker or none, never half of one. *)
VerificationTest[
    Module[ { rlo, lri, pdi, ls, emoji, hidden, patch, data, boxes, untracked, error, messages, args, long, x, cut, partial },
        { rlo, lri, pdi, ls } = FromCharacterCode /@ { 16^^202E, 16^^2066, 16^^2069, 16^^2028 };
        emoji  = FromCharacterCode @ { 16^^2705, 16^^FE0F, 32, 16^^1F468, 16^^200D, 16^^1F469 };
        hidden = Alternatives[ rlo, lri, pdi, ls ];
        patch  = StringJoin[
            "diff --git a/a.c b/a.c\n--- a/a.c\n+++ b/a.c\n@@ -1,2 +1,3 @@\n int a;\n-if (x) {\n",
            "+if (access != \"user" <> rlo <> " " <> lri <> "// Check if admin" <> pdi <> " " <> lri <> "\") {\n",
            "+\ttab" <> ls <> "sep\n",
            "+ok " <> emoji <> "\n"
        ];
        data      = Wolfram`Chatbook`ACP`Review`Private`reviewDiffData @ <| "Path" -> "a.c", "Status" -> "Modified", "Patch" -> patch |>;
        boxes     = ToBoxes @ acpReviewDiffView @ data;
        untracked = Wolfram`Chatbook`ACP`Review`Private`reviewDiffData @ <| "Path" -> "u.txt", "Status" -> "Untracked", "Content" -> "a" <> rlo <> "b\n" |>;
        error     = acpReviewCells @ <| "Status" -> "Error", "Directory" -> "/repo", "Error" -> <| "Code" -> "GitFailed", "Detail" -> "fatal: bad " <> rlo <> "path" |> |>;
        (* git's version, ssh's start failure, and a remote error's advice and ssh's output *)
        messages  = acpReviewCells /@ {
            <| "Status" -> "Unavailable", "Directory" -> "/repo", "Error" -> <| "Code" -> "GitTooOld" |>, "GitVersion" -> "2.20" <> rlo <> "1" |>,
            <|
                "Status"    -> "Error",
                "Directory" -> "/home/u/r",
                "Remote"    -> <| "Host" -> "me@devbox", "Short" -> "devbox", "Home" -> "/home/u" |>,
                "Error"     -> <| "Code" -> "StartFailed", "Error" -> <| "Message" -> "no " <> rlo <> "ssh" |> |>
            |>,
            <|
                "Status"    -> "Error",
                "Directory" -> "/home/u/r",
                "Remote"    -> <| "Host" -> "me@devbox", "Short" -> "devbox", "Home" -> "/home/u" |>,
                "Error"     -> <| "Code" -> "SSHFailed", "Error" -> <| "Hint" -> "try " <> rlo <> "this", "Output" -> "denied " <> rlo <> "key" |> |>
            |>
        };
        (* the text given to reviewSafeText for a diff of 20000 lines *)
        args = { };
        long = Block[
            {
                Wolfram`Chatbook`ACP`Review`Private`reviewSafeText = Function[ s, AppendTo[ args, StringLength @ s ]; s ]
            },
            Wolfram`Chatbook`ACP`Review`Private`reviewDiffData @ <|
                "Path"   -> "big.txt",
                "Status" -> "Modified",
                "Patch"  -> "@@ -1 +1,20000 @@\n" <> StringRepeat[ "+" <> StringRepeat[ "x", 400 ] <> "\n", 20000 ]
            |>
        ];
        (* lines of about 300 characters with an RLO near their end: in a patch (the "+" counts) and in an untracked file *)
        x   = StringRepeat[ "x", # ] &;
        cut = {
            Wolfram`Chatbook`ACP`Review`Private`reviewDiffData @ <|
                "Path"   -> "a",
                "Status" -> "Modified",
                "Patch"  -> "@@ -1 +1,2 @@\n+" <> x[ 296 ] <> rlo <> "abc\n+" <> x[ 290 ] <> rlo <> x[ 20 ] <> "\n"
            |>,
            Wolfram`Chatbook`ACP`Review`Private`reviewDiffData @ <|
                "Path"    -> "u",
                "Status"  -> "Untracked",
                "Content" -> x[ 296 ] <> rlo <> "abc\n" <> x[ 292 ] <> rlo <> "abc\n"
            |>
        };
        (* "\:27e6" not followed by the rest of a marker *)
        partial = RegularExpression[ "\\x{27E6}(?!U\\+[0-9A-F]{4,6}\\x{27E7})" ];
        {
            StringContainsQ[ data[ "Patch" ], hidden ],
            StringContainsQ[
                data[ "Patch" ],
                "\"user\:27e6U+202E\:27e7 \:27e6U+2066\:27e7// Check if admin\:27e6U+2069\:27e7 \:27e6U+2066\:27e7\")"
            ],
            StringContainsQ[ data[ "Patch" ], "+\ttab\:27e6U+2028\:27e7sep\n" ],
            StringContainsQ[ data[ "Patch" ], "+ok " <> emoji ],
            data[ "Lines" ] === Length @ StringSplit[ patch, "\n" ],
            Cases[ boxes, s_String /; StringContainsQ[ s, hidden ], Infinity ],
            untracked[ "NewText" ],
            Cases[ error, s_String /; StringContainsQ[ s, hidden ], Infinity ],
            containsTextQ[ error, "fatal: bad \:27e6U+202E\:27e7path" ],
            Cases[ messages, s_String /; StringContainsQ[ s, hidden ], Infinity ],
            containsTextQ[ messages[[ 1 ]], "Git 2.20\:27e6U+202E\:27e71 is too old." ],
            containsTextQ[ messages[[ 2 ]], "no \:27e6U+202E\:27e7ssh" ],
            containsTextQ[ messages[[ 3 ]], "try \:27e6U+202E\:27e7this" ],
            containsTextQ[ messages[[ 3 ]], "denied \:27e6U+202E\:27e7key" ],
            { long[ "Lines" ], long[ "Omitted" ], Max @ args <= 400 * 301 + 400 },
            StringSplit[ cut[[ 1, "Patch" ]], "\n" ] === {
                "@@ -1 +1,2 @@",
                "+" <> x[ 296 ] <> "\[Ellipsis]",
                "+" <> x[ 290 ] <> "\:27e6U+202E\:27e7x\[Ellipsis]"
            },
            StringSplit[ cut[[ 2, "NewText" ]], "\n" ] === { x[ 296 ] <> "\[Ellipsis]", x[ 292 ] <> "\:27e6U+202E\:27e7\[Ellipsis]" },
            Max[ StringLength /@ StringSplit[ StringJoin[ cut[[ 1, "Patch" ]], "\n", cut[[ 2, "NewText" ]] ], "\n" ] ],
            Cases[ ToBoxes[ acpReviewDiffView /@ cut ], s_String /; StringContainsQ[ s, partial | hidden ], Infinity ],
            containsTextQ[ ToBoxes @ acpReviewDiffView @ cut[[ 1 ]], x[ 290 ] <> "\:27e6U+202E\:27e7x\[Ellipsis]" ],
            containsTextQ[ ToBoxes @ acpReviewDiffView @ cut[[ 2 ]], x[ 292 ] <> "\:27e6U+202E\:27e7\[Ellipsis]" ]
        }
    ],
    {
        False,
        True,
        True,
        True,
        True,
        { },
        "a\:27e6U+202E\:27e7b",
        { },
        True,
        { },
        True,
        True,
        True,
        True,
        { 20001, 19601, True },
        True,
        True,
        301,
        { },
        True,
        True
    },
    SameTest -> MatchQ,
    TestID   -> "Review-DisplaySafe-DiffLines@@Tests/ACPReview.wlt:1368,1-1483,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window geometry*)

(* A new window: the default size clamped to the display's usable area (with room for the window frame), centered on it,
   so that it is fully on the display; on a display smaller than the minimum size, at its top left corner *)
VerificationTest[
    Module[ { place, fits },
        place = Wolfram`Chatbook`ACP`Review`Private`reviewPlacement[ #, { 760, 820 } ] &;
        (* the window with its frame ({ 16, 48 }) is inside the area *)
        fits = Function[ { area, g },
            With[ { m = g[ "WindowMargins" ], s = g[ "WindowSize" ] },
                And[
                    m[[ 1, 1 ]] >= area[[ 1, 1 ]], m[[ 1, 1 ]] + s[[ 1 ]] + 16 <= area[[ 1, 2 ]],
                    m[[ 2, 2 ]] >= area[[ 2, 1 ]], m[[ 2, 2 ]] + s[[ 2 ]] + 48 <= area[[ 2, 2 ]]
                ]
            ]
        ];
        {
            (* 1600x1000 pixels at 133%, where a window 820 points high opened with its top above the screen *)
            place @ { { 0, 1200 }, { 0, 750 } },
            (* enough room *)
            place @ { { 0, 1920 }, { 0, 1050 } },
            (* a second display, and a usable area below a menu bar *)
            place @ { { 1920, 3840 }, { 0, 1080 } },
            place @ { { 0, 1440 }, { 25, 900 } },
            fits @@@ {
                { { { 0, 1200 }, { 0, 750 } }, place @ { { 0, 1200 }, { 0, 750 } } },
                { { { 0, 1366 }, { 0, 546 } }, place @ { { 0, 1366 }, { 0, 546 } } },
                { { { 1920, 3840 }, { 0, 1080 } }, place @ { { 1920, 3840 }, { 0, 1080 } } }
            },
            place @ { { 0, 300 }, { 0, 200 } }
        }
    ],
    {
        <| "WindowSize" -> { 760, 686 }, "WindowMargins" -> { { 212, Automatic }, { Automatic, 8 } } |>,
        <| "WindowSize" -> { 760, 820 }, "WindowMargins" -> { { 572, Automatic }, { Automatic, 91 } } |>,
        <| "WindowSize" -> { 760, 820 }, "WindowMargins" -> { { 2492, Automatic }, { Automatic, 106 } } |>,
        <| "WindowSize" -> { 760, 811 }, "WindowMargins" -> { { 332, Automatic }, { Automatic, 33 } } |>,
        { True, True, True },
        <| "WindowSize" -> { 320, 240 }, "WindowMargins" -> { { 0, Automatic }, { Automatic, 0 } } |>
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Window-Placement@@Tests/ACPReview.wlt:1491,1-1529,2"
]

(* The display is the one the ACP window is on (else the first one), its usable area ("Region") or else its full area;
   without a front end or a usable answer, the default size and Automatic margins (the front end places the window) *)
VerificationTest[
    Module[ { displays, area, geometry },
        displays = {
            <| "Region" -> { { 0., 1200. }, { 0., 750. } }, "FullRegion" -> { { 0., 1200. }, { 0., 780. } } |>,
            <| "FullRegion" -> { { 1200., 3120. }, { 0., 1080. } } |>
        };
        area     = Wolfram`Chatbook`ACP`Review`Private`reviewDisplayArea;
        geometry = Function[ a, Block[ { Wolfram`Chatbook`ACP`Review`Private`reviewDisplayArea = a & }, Wolfram`Chatbook`ACP`Review`Private`reviewWindowGeometry @ $owner ] ];
        {
            area[ displays, 2 ],
            area[ displays, None ],
            area[ displays, Failure[ "NotFound", <| |> ] ],
            area[ displays, 3 ],
            area[ $Failed, 1 ],
            area[ { <| "Region" -> { { 0, 0 }, { 0, 0 } } |> }, 1 ],
            area[ { { "FullRegion" -> { { 0, 800 }, { 0, 600 } } } }, 1 ],
            geometry @ { { 1200., 3120. }, { 0., 1080. } },
            geometry @ None,
            Block[ { $FrontEnd = Null }, { area @ $owner, Wolfram`Chatbook`ACP`Review`Private`reviewWindowGeometry @ $owner } ]
        }
    ],
    {
        { { 1200., 3120. }, { 0., 1080. } },
        { { 0., 1200. }, { 0., 750. } },
        { { 0., 1200. }, { 0., 750. } },
        { { 0., 1200. }, { 0., 750. } },
        None,
        None,
        { { 0, 800 }, { 0, 600 } },
        <| "WindowSize" -> { 760, 820 }, "WindowMargins" -> { { 1772, Automatic }, { Automatic, 106 } } |>,
        <| "WindowSize" -> { 760, 820 }, "WindowMargins" -> Automatic |>,
        { None, <| "WindowSize" -> { 760, 820 }, "WindowMargins" -> Automatic |> }
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Window-Geometry@@Tests/ACPReview.wlt:1533,1-1568,2"
]

(* The button opens the new window with that geometry *)
VerificationTest[
    Module[ { put },
        put = Function[ area,
            Block[
                {
                    $callLog = { },
                    Wolfram`Chatbook`ACP`Common`acpCheckSession       = True &,
                    Wolfram`Chatbook`ACP`Common`acpEnsureWindowRecord = (<| "Status" -> "Ready", "ProjectDirectory" -> "/repo" |> &),
                    Wolfram`Chatbook`ACP`Review`Private`reviewRequest = logCall[ "Request", ## ] &,
                    Wolfram`Chatbook`ACP`Review`Private`reviewWindowOf = None &,
                    Wolfram`Chatbook`ACP`Review`Private`reviewDisplayArea = area &,
                    NotebookPut = (logCall[ "NotebookPut", ## ]; $review) &
                },
                acpReviewChanges @ $owner;
                Replace[ calls[ "NotebookPut" ], { { nb_Notebook } } :> Lookup[ Association[ List @@ Rest @ nb ], { WindowSize, WindowMargins }, None ] ]
            ]
        ];
        { put @ { { 0, 1200 }, { 0, 750 } }, put @ None }
    ],
    {
        { { 760, 686 }, { { 212, Automatic }, { Automatic, 8 } } },
        { { 760, 820 }, None }
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Window-NewWindow@@Tests/ACPReview.wlt:1571,1-1596,2"
]

(* A new result keeps the window where it is (NotebookPut alone would center it again); its size is kept by the front
   end. The position is the left and top of the resolved WindowMargins. *)
VerificationTest[
    Module[ { put, position },
        put = Function[ margins,
            Block[
                {
                    $callLog             = { },
                    NotebookPut          = logCall[ "NotebookPut", ## ] &,
                    FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &,
                    Wolfram`Chatbook`ACP`Review`Private`reviewWindowPosition = (logCall[ "Position", # ]; margins) &
                },
                Wolfram`Chatbook`ACP`Review`Private`reviewPut[ $review, Notebook[ { Cell[ "x" ] }, WindowTitle -> "t", WindowMargins -> 5 ] ];
                $callLog
            ]
        ];
        position = Wolfram`Chatbook`ACP`Review`Private`reviewWindowPosition;
        {
            put @ { { 100., Automatic }, { Automatic, 30. } },
            put @ None,
            position @ { { 100., 300. }, { 50., 30. } },
            position @ 20,
            position /@ { $Failed, Inherited, Automatic, { { 1, 2 }, { 3, Automatic } } },
            Block[ { $FrontEnd = Null }, position @ $review ]
        }
    ],
    {
        {
            { "Position", $review },
            { "NotebookPut", Notebook[ { Cell[ "x" ] }, WindowMargins -> { { 100., Automatic }, { Automatic, 30. } }, WindowTitle -> "t" ], $review },
            { "FrontEndTokenExecute", $review, "ScrollNotebookStart" }
        },
        {
            { "Position", $review },
            { "NotebookPut", Notebook[ { Cell[ "x" ] }, WindowTitle -> "t", WindowMargins -> 5 ], $review },
            { "FrontEndTokenExecute", $review, "ScrollNotebookStart" }
        },
        { { 100., Automatic }, { Automatic, 30. } },
        { { 20, Automatic }, { Automatic, 20 } },
        { None, None, None, None },
        None
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Window-KeepsPosition@@Tests/ACPReview.wlt:1600,1-1642,2"
]

(* In a front end (CI runs the tests in one; skipped without): the new window has the size of its geometry and is inside
   the display's usable area; a new result leaves it where it is, also after it was moved *)
VerificationTest[
    If[ $FrontEnd === Null,
        Missing[ "TestSkipped" ],
        Module[ { geometry, nb, area, size, placed, moved, kept },
            geometry = Wolfram`Chatbook`ACP`Review`Private`reviewWindowGeometry @ None;
            nb       = NotebookPut @ acpReviewNotebook[ <| "Status" -> "Loading", "Directory" -> $reviewScratch |>, None, geometry, None ];
            area     = Wolfram`Chatbook`ACP`Review`Private`reviewDisplayArea @ nb;
            size     = AbsoluteCurrentValue[ nb, WindowSize ];
            placed   = AbsoluteCurrentValue[ nb, WindowMargins ];
            SetOptions[ nb, WindowMargins -> { { area[[ 1, 1 ]] + 3, Automatic }, { Automatic, area[[ 2, 1 ]] + 3 } } ];
            moved = AbsoluteCurrentValue[ nb, WindowMargins ];
            Wolfram`Chatbook`ACP`Review`Private`reviewPut[ nb, acpReviewNotebook[ <| "Status" -> "Clean", "Directory" -> $reviewScratch |>, None, False, None ] ];
            kept = AbsoluteCurrentValue[ nb, WindowMargins ];
            NotebookClose @ nb;
            {
                Max @ Abs[ size - geometry[ "WindowSize" ] ] <= 1,
                placed[[ 1, 1 ]] >= area[[ 1, 1 ]] - 1 && placed[[ 1, 1 ]] + size[[ 1 ]] <= area[[ 1, 2 ]] + 1,
                placed[[ 2, 2 ]] >= area[[ 2, 1 ]] - 1 && placed[[ 2, 2 ]] + size[[ 2 ]] <= area[[ 2, 2 ]] + 1,
                kept === moved
            }
        ]
    ],
    { True, True, True, True } | Missing[ "TestSkipped" ],
    SameTest -> MatchQ,
    TestID   -> "Review-Window-FrontEnd@@Tests/ACPReview.wlt:1646,1-1671,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)
VerificationTest[
    Select[ $acpReviewStrings, ! StringQ @ # || StringLength @ # === 0 & ],
    <| |>,
    SameTest -> MatchQ,
    TestID   -> "Strings-NonEmpty@@Tests/ACPReview.wlt:1676,1-1681,2"
]

(* Every label key used in Review.wl, also the ones made from statuses and notes, has an English default (string
   literals "Review..." are keys, except action names and key prefixes) *)
VerificationTest[
    Complement[
        Union[
            DeleteCases[
                StringCases[
                    ReadString @ FileNameJoin @ { DirectoryName[ $TestFileName, 2 ], "Source", "Chatbook", "ACP", "Review.wl" },
                    "\"" ~~ key: ("Review" ~~ CharacterRange[ "A", "Z" ] ~~ LetterCharacter...) ~~ "\"" :> key
                ],
                "ReviewChanges" | "ReviewOpenFile" | "ReviewDiffView" | "ReviewStatus" | "ReviewNote"
            ],
            "ReviewStatus" <> # & /@ { "Modified", "Added", "Deleted", "Renamed", "Copied", "TypeChanged", "Conflict", "Untracked", "Submodule" },
            "ReviewNote" <> # & /@ { "Binary", "Empty", "Submodule", "Directory", "TooLarge", "NotRead", "NotRegular", "Unreadable", "NoDiff", "PatchUnavailable" },
            "ReviewMessage" <> # & /@ { "TimedOut", "TooLarge", "StartFailed", "Cancelled", "GitFailed" }
        ],
        Keys @ $acpReviewStrings
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "Strings-Coverage@@Tests/ACPReview.wlt:1685,1-1704,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Git*)

(* The whole pipeline with the real git: a request for a review window, the change set, and the notebook that replaces
   the window's contents (front end functions are mocks) *)
VerificationTest[
    Module[ { git, empty, saved, repo, setup, write, result },
        git = acpFindGit[ ];
        If[ ! StringQ @ git, Return[ Missing[ "TestSkipped" ], Module ] ];
        saved = AssociationMap[ Environment, { "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM" } ];
        (* a global config that only sets the global ignore and attributes files (git reads ~/.config/git/ignore and
           attributes otherwise) to an empty file *)
        empty = FileNameJoin @ { $reviewScratch, "empty.gitconfig" };
        BinaryWrite[ FileNameJoin @ { $reviewScratch, "empty" }, { } ];
        Close @ FileNameJoin @ { $reviewScratch, "empty" };
        BinaryWrite[
            empty,
            StringToByteArray[ "[core]\n\texcludesFile = " <> # <> "\n\tattributesFile = " <> # <> "\n", "UTF-8" ] & @ FileNameJoin @ { $reviewScratch, "empty" }
        ];
        Close @ empty;
        repo  = CreateDirectory @ FileNameJoin @ { $reviewScratch, "repo" };
        (* Test setup only (the paclet never writes to repositories): *)
        setup = RunProcess[
            Join[ { git, "-c", "user.name=Chatbook Tests", "-c", "user.email=chatbook-tests@example.com", "-c", "init.defaultBranch=main", "-c", "commit.gpgsign=false", "-c", "core.autocrlf=false" }, { ## } ],
            ProcessDirectory -> repo
        ][ "ExitCode" ] &;
        write = (Quiet @ CreateDirectory @ DirectoryName @ FileNameJoin @ { repo, #1 }; Export[ FileNameJoin @ { repo, #1 }, #2, "Text" ]) &;
        WithCleanup[
            SetEnvironment @ { "GIT_CONFIG_GLOBAL" -> empty, "GIT_CONFIG_NOSYSTEM" -> "1" },
            write[ "a.txt", "one\ntwo\nthree" ];
            write[ "gone.md", "bye" ];
            setup[ "init", "-q" ];
            setup[ "add", "." ];
            setup[ "commit", "-q", "-m", "initial" ];
            write[ "a.txt", "one\nTWO\nthree\n-- comment" ];
            DeleteFile @ FileNameJoin @ { repo, "gone.md" };
            write[ "src/new.py", "print(1)" ];
            Block[
                {
                    $callLog = { },
                    Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| |>,
                    Notebooks            = { $review } &,
                    SetOptions           = logCall[ "SetOptions", ## ] &,
                    NotebookPut          = logCall[ "NotebookPut", ## ] &,
                    FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &
                },
                Wolfram`Chatbook`ACP`Review`Private`reviewRequest[ $review, None, repo ];
                waitUntil[ calls[ "NotebookPut" ] =!= { } ];
                result = First[ calls[ "NotebookPut" ], None ]
            ],
            SetEnvironment @ Normal @ Replace[ saved, Except[ _String ] -> None, { 1 } ]
        ];
        {
            Last @ result,
            nbOption[ First @ result, WindowTitle ],
            Length @ fileCells @ First @ result,
            containsTextQ[ First @ result, "Deleted" ],
            hasStringQ[ First @ result, "-- comment" ],
            hasStringQ[ First @ result, "print(1)" ],
            Select[ boxStrings @ nbOption[ First @ result, DockedCells ], StringMatchQ[ ("On branch " ~~ __) | "3 files changed" ] ]
        }
    ],
    Missing[ "TestSkipped" ] | { $review, "Changes \[LongDash] repo", 3, True, True, True, { "On branch main", "3 files changed" } },
    SameTest -> MatchQ,
    TestID   -> "Git-ReviewRequest@@Tests/ACPReview.wlt:1712,1-1772,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Remote folders*)

(* A test of its own, so that the tests after it are read with the helpers' context on $ContextPath *)
VerificationTest[
    Get @ FileNameJoin @ { DirectoryName @ $TestFileName, "Data", "ACP", "FakeSSH.wl" };
    MemberQ[ $ContextPath, "Wolfram`ChatbookTests`ACPFakeSSH`" ],
    True,
    SameTest -> MatchQ,
    TestID   -> "ACPReview-LoadFakeSSH@@Tests/ACPReview.wlt:1779,1-1785,2"
]

(* The change set of a folder on another computer (Git.wl gives remote change sets a "Remote" and POSIX paths) *)
VerificationTest[
    $remoteInfo     = <| "Host" -> "me@devbox.example.com", "Short" -> "devbox", "Home" -> "/home/u" |>;
    $remoteSettings = <| "MachineName" -> "devbox.example.com", "Username" -> "me", "Arguments" -> { }, "Executable" -> Automatic |>;
    $remoteCS = acpGitBuildChangeSet @ <|
        $csInput,
        "Directory" -> "/home/u/repo",
        "Root"      -> "/home/u/repo",
        "Status"    -> $csInput[ "Status" ] <> nulJoin @ { "? link.txt" },
        "Untracked" -> <|
            $csInput[ "Untracked" ],
            "link.txt" -> <| "Added" -> 1, "Binary" -> False, "Content" -> None, "Note" -> "SymbolicLink", "LinkTarget" -> "/home/u/other/x.txt" |>
        |>,
        "Remote"    -> $remoteInfo
    |>;
    (* The integration test needs the fake ssh and git *)
    $remoteReviewQ = TrueQ @ $fakeSSHAvailableQ && StringQ @ acpFindGit[ ];
    If[ $remoteReviewQ, fakeSSHSetup @ FileNameJoin @ { $reviewScratch, "fake" } ];
    {
        Length @ $remoteCS[ "Files" ],
        $remoteCS[ "Remote" ] === $remoteInfo,
        Wolfram`Chatbook`Common`acpSSHSettings @ $remoteSettings === $remoteSettings
    },
    { 16, True, True },
    SameTest -> MatchQ,
    TestID   -> "ACPReview-RemoteDefinitions@@Tests/ACPReview.wlt:1788,1-1813,2"
]

(* Remote files have no Open link: they are not on this computer (a local file of the same name must not be opened) *)
VerificationTest[
    Module[ { nb = acpReviewNotebook[ $remoteCS, $owner, True, $remoteSettings ] },
        {
            Length @ fileCells @ nb,
            Cases[ actionCalls @ First @ nb, { "ReviewOpenFile", _ } ],
            Union @ Lookup[ $remoteCS[ "Files" ], "Remote" ],
            SelectFirst[ $remoteCS[ "Files" ], #[ "Path" ] === "src/a.txt" & ][ "FullPath" ],
            nbOption[ nb, TaggingRules ][ "ACPReview" ],
            (* local files keep theirs *)
            Length @ Union @ Cases[ actionCalls @ First @ $nb, { "ReviewOpenFile", _ } ] > 0
        }
    ],
    { 16, { }, { True }, "/home/u/repo/src/a.txt", <| "Owner" -> $owner, "Directory" -> "/home/u/repo", "SSH" -> $remoteSettings |>, True },
    SameTest -> MatchQ,
    TestID   -> "Review-Remote-NoOpenLink@@Tests/ACPReview.wlt:1816,1-1831,2"
]

(* The header shows a remote folder as host:path, abbreviated with the remote home folder and kept from its end (the
   tooltip has user@host:/absolute/path); invisible characters are shown; link targets are abbreviated with the remote
   home. Nothing is looked up on this computer. *)
VerificationTest[
    Module[ { fsCalls = { }, nb, loading, long, docked, longLabel, link },
        Internal`InheritedBlock[ { DirectoryQ, ExpandFileName, FileExistsQ },
            Unprotect[ DirectoryQ, ExpandFileName, FileExistsQ ];
            DirectoryQ[ p_String ] /; StringStartsQ[ p, "/home/u" ] := (AppendTo[ fsCalls, { "DirectoryQ", p } ]; False);
            ExpandFileName[ p_String ] /; StringStartsQ[ p, "/home/u" ] := (AppendTo[ fsCalls, { "ExpandFileName", p } ]; p);
            FileExistsQ[ p_String ] /; StringStartsQ[ p, "/home/u" ] := (AppendTo[ fsCalls, { "FileExistsQ", p } ]; False);
            nb      = acpReviewNotebook[ $remoteCS, $owner, True, $remoteSettings ];
            loading = acpReviewDockedCell[ <| "Status" -> "Loading", "Directory" -> "/home/u/repo", "Remote" -> $remoteInfo |>, True ];
            long    = acpReviewDockedCell[
                <| "Status" -> "Loading", "Directory" -> "/home/u/" <> StringRepeat[ "a", 100 ] <> "/proj\:202ex", "Remote" -> $remoteInfo |>,
                True
            ]
        ];
        docked    = First @ nbOption[ nb, DockedCells ];
        longLabel = SelectFirst[ boxStrings @ long, StringStartsQ[ "devbox:" ], None ];
        link      = SelectFirst[ fileCells @ nb, containsTextQ[ #, "link.txt" ] &, None ];
        {
            nbOption[ nb, WindowTitle ],
            hasStringQ[ docked, "devbox:~/repo" ],
            containsTextQ[ docked, "me@devbox.example.com:/home/u/repo" ],
            hasStringQ[ loading, "devbox:~/repo" ] && containsTextQ[ loading, "Loading changes" ],
            {
                StringStartsQ[ longLabel, "devbox:\[Ellipsis]" ],
                StringEndsQ[ longLabel, "/proj\:27e6U+202E\:27e7x" ],
                StringLength @ longLabel <= 80
            },
            containsTextQ[ link, "A symbolic link to ~/other/x.txt." ],
            fsCalls
        }
    ],
    { "Changes \[LongDash] repo", True, True, True, { True, True, True }, True, { } },
    SameTest -> MatchQ,
    TestID   -> "Review-Remote-HeaderPath@@Tests/ACPReview.wlt:1836,1-1870,2"
]

(* Remote errors: the host in the message, the advice and ssh's own text in the detail *)
VerificationTest[
    Module[ { info, cells },
        info  = acpErrorInfo[
            "SSHAuthFailed",
            None,
            None,
            <| "Host" -> "me@devbox.example.com", "Output" -> "me@devbox.example.com: Permission denied (publickey).", "Actions" -> { } |>
        ];
        (* the text of the cells (quotes are escaped in box strings) *)
        cells = Function[
            changes,
            StringReplace[ #, "\\\"" -> "\"" ] & /@ textStrings @ acpReviewCells @ <| "Directory" -> "/home/u/repo", "Remote" -> $remoteInfo, changes |>
        ];
        {
            cells @ <| "Status" -> "Error", "Error" -> <| "Code" -> "SSHFailed", "Step" -> "Connect", "ExitCode" -> 255, "Detail" -> info[ "Detail" ], "SSHCode" -> "SSHAuthFailed", "Error" -> info |> |>,
            cells @ <| "Status" -> "Error", "Error" -> <| "Code" -> "RemoteFailed", "Detail" -> None, "Error" -> None, "Stop" -> "tmpdir" |> |>,
            cells @ <| "Status" -> "Unavailable", "Error" -> <| "Code" -> "NotFound" |> |>,
            cells @ <| "Status" -> "Unavailable", "Error" -> <| "Code" -> "InvalidSSHSettings", "Detail" -> "Unknown key \"Foo\"." |> |>,
            cells @ <| "Status" -> "Error", "Error" -> <| "Code" -> "StartFailed", "SSHCode" -> "SSHNotFound", "Error" -> acpErrorInfo[ "SSHNotFound", None, None, <| |> ] |> |>,
            (* a local folder's messages are unchanged *)
            textStrings @ acpReviewCells @ <| "Status" -> "Unavailable", "Directory" -> "/repo", "Error" -> <| "Code" -> "NotFound" |> |>
        }
    ],
    {
        {
            "Could not connect to me@devbox.example.com.",
            _String? (StringStartsQ[ "Agent chats sign in without prompts" ]),
            "me@devbox.example.com: Permission denied (publickey)."
        },
        { "The changes on me@devbox.example.com could not be listed." },
        { "Git was not found on me@devbox.example.com.", "Install Git on that computer to review changes." },
        { "The \"SSHSettings\" of this window are not valid.", "Unknown key \"Foo\"." },
        { "The ssh program was not found on this computer.", _String? (StringStartsQ[ "Install the OpenSSH client" ]) },
        { "Git was not found.", "Install Git (https://git-scm.com) to review changes." }
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Remote-SSHFailedMessage@@Tests/ACPReview.wlt:1873,1-1910,2"
]

(* A refresh without the owner's record (e.g. after a kernel restart) lists the folder with the settings the review
   window kept in its TaggingRules, on that host *)
VerificationTest[
    Block[
        {
            $callLog = { },
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| |>,
            Notebooks    = { $review } &,
            SetOptions   = logCall[ "SetOptions", ## ] &,
            CurrentValue = Function[
                { nb, spec },
                Replace[
                    spec,
                    {
                        { TaggingRules, "ACPReview", "Owner" }     -> NotebookObject[ "acp-review-gone" ],
                        { TaggingRules, "ACPReview", "Directory" } -> "/home/u/repo",
                        { TaggingRules, "ACPReview", "SSH" }       -> $remoteSettings,
                        _ -> Inherited
                    }
                ]
            ],
            Wolfram`Chatbook`ACP`Common`acpGitChanges = (logCall[ "GitChanges", ## ]; "token-r") &
        },
        {
            acpReviewRefresh @ $review,
            calls[ "GitChanges" ][[ All, { 1, 3, 4 } ]],
            Select[ boxStrings @ calls[ "SetOptions" ], StringStartsQ[ "devbox:" ] ],
            Wolfram`Chatbook`ACP`Review`Private`$reviewWindows[ $review, "SSH" ]
        }
    ],
    { "token-r", { { "/home/u/repo", { "ACPReview", $review }, $remoteSettings } }, { "devbox:/home/u/repo" }, $remoteSettings },
    SameTest -> MatchQ,
    TestID   -> "Review-Remote-RefreshWithoutOwner@@Tests/ACPReview.wlt:1914,1-1945,2"
]

(* The same through the fake ssh: the repository is listed on the "remote" host and never looked at on this computer;
   the new notebook keeps the settings *)
VerificationTest[
    If[ ! TrueQ @ $remoteReviewQ,
        Missing[ "TestSkipped" ],
        Module[ { git, saved, empty, repo, setup, write, ssh, fsCalls = { }, result },
            git   = acpFindGit[ ];
            saved = AssociationMap[ Environment, { "GIT_CONFIG_GLOBAL", "GIT_CONFIG_NOSYSTEM", "FAKE_SSH_KEEP_ENV" } ];
            empty = FileNameJoin @ { $reviewScratch, "empty.gitconfig" };
            BinaryWrite[ FileNameJoin @ { $reviewScratch, "empty" }, { } ];
            Close @ FileNameJoin @ { $reviewScratch, "empty" };
            BinaryWrite[
                empty,
                StringToByteArray[ "[core]\n\texcludesFile = " <> # <> "\n\tattributesFile = " <> # <> "\n", "UTF-8" ] & @ FileNameJoin @ { $reviewScratch, "empty" }
            ];
            Close @ empty;
            repo  = CreateDirectory @ FileNameJoin @ { $reviewScratch, "remote-repo" };
            (* Test setup only (the paclet never writes to repositories): *)
            setup = RunProcess[
                Join[ { git, "-c", "user.name=Chatbook Tests", "-c", "user.email=chatbook-tests@example.com", "-c", "init.defaultBranch=main", "-c", "commit.gpgsign=false", "-c", "core.autocrlf=false" }, { ## } ],
                ProcessDirectory -> repo
            ][ "ExitCode" ] &;
            write = (Quiet @ CreateDirectory @ DirectoryName @ FileNameJoin @ { repo, #1 }; Export[ FileNameJoin @ { repo, #1 }, #2, "Text" ]) &;
            ssh   = Wolfram`Chatbook`Common`acpSSHSettings @ fakeSSHSettings[ ];
            WithCleanup[
                SetEnvironment @ {
                    "GIT_CONFIG_GLOBAL"   -> empty,
                    "GIT_CONFIG_NOSYSTEM" -> "1",
                    "FAKE_SSH_KEEP_ENV"   -> "TMPDIR GIT_CONFIG_GLOBAL GIT_CONFIG_NOSYSTEM"
                },
                write[ "a.txt", "one\ntwo" ];
                setup[ "init", "-q" ];
                setup[ "add", "." ];
                setup[ "commit", "-q", "-m", "initial" ];
                write[ "a.txt", "one\nTWO" ];
                write[ "new.txt", "new" ];
                Block[
                    {
                        $callLog = { },
                        Wolfram`Chatbook`ACP`Review`Private`$reviewWindows = <| |>,
                        Notebooks            = { $review } &,
                        SetOptions           = logCall[ "SetOptions", ## ] &,
                        NotebookPut          = logCall[ "NotebookPut", ## ] &,
                        FrontEndTokenExecute = logCall[ "FrontEndTokenExecute", ## ] &,
                        CurrentValue         = Function[
                            { nb, spec },
                            Replace[
                                spec,
                                {
                                    { TaggingRules, "ACPReview", "Owner" }     -> NotebookObject[ "acp-review-gone" ],
                                    { TaggingRules, "ACPReview", "Directory" } -> repo,
                                    { TaggingRules, "ACPReview", "SSH" }       -> ssh,
                                    _ -> Inherited
                                }
                            ]
                        ]
                    },
                    Internal`InheritedBlock[ { DirectoryQ, ExpandFileName, FileExistsQ },
                        Unprotect[ DirectoryQ, ExpandFileName, FileExistsQ ];
                        DirectoryQ[ p_String ] /; StringStartsQ[ p, repo ] := (AppendTo[ fsCalls, { "DirectoryQ", p } ]; False);
                        ExpandFileName[ p_String ] /; StringStartsQ[ p, repo ] := (AppendTo[ fsCalls, { "ExpandFileName", p } ]; p);
                        FileExistsQ[ p_String ] /; StringStartsQ[ p, repo ] := (AppendTo[ fsCalls, { "FileExistsQ", p } ]; False);
                        acpReviewRefresh @ $review;
                        waitUntil[ calls[ "NotebookPut" ] =!= { }, 60 ];
                        result = First[ calls[ "NotebookPut" ], None ]
                    ]
                ],
                SetEnvironment @ Normal @ Replace[ saved, Except[ _String ] -> None, { 1 } ]
            ];
            {
                Last @ result,
                nbOption[ First @ result, TaggingRules ][ "ACPReview" ],
                nbOption[ First @ result, WindowTitle ],
                Length @ fileCells @ First @ result,
                Cases[ actionCalls @ First @ result, { "ReviewOpenFile", _ } ],
                (* the folder and its tooltip *)
                Union @ Select[ boxStrings @ nbOption[ First @ result, DockedCells ], StringStartsQ[ "testhost:" ] ],
                fsCalls
            }
        ]
    ],
    Missing[ "TestSkipped" ] | {
        $review,
        <| "Owner" -> NotebookObject[ "acp-review-gone" ], "Directory" -> FileNameJoin @ { $reviewScratch, "remote-repo" }, "SSH" -> _Association |>,
        "Changes \[LongDash] remote-repo",
        2,
        { },
        { "testhost:" <> FileNameJoin @ { $reviewScratch, "remote-repo" } },
        { }
    },
    SameTest -> MatchQ,
    TestID   -> "Review-Remote-RefreshWithoutOwner-FakeSSH@@Tests/ACPReview.wlt:1949,1-2039,2"
]

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Cleanup*)
VerificationTest[
    {
        waitUntil[ Wolfram`Chatbook`ACP`Git`Private`$gitRuns === <| |>, 30 ],
        If[ TrueQ @ $remoteReviewQ, fakeSSHCleanup[ ] ];
        Quiet @ DeleteDirectory[ $reviewScratch, DeleteContents -> True ];
        DirectoryQ @ $reviewScratch
    },
    { True, False },
    SameTest -> MatchQ,
    TestID   -> "ACPReview-Cleanup@@Tests/ACPReview.wlt:2044,1-2054,2"
]

(* Isolated code swallows messages and failures into the debug log; nothing unexpected may have been logged *)
VerificationTest[
    Select[
        Internal`BagPart[ $acpDebugLog, All ],
        #[ "Time" ] >= $acpLogStart && MemberQ[ { "Message", "Uncaught", "MissingLabel", "UnknownAction" }, #[ "Where" ] ] &
    ],
    { },
    SameTest -> MatchQ,
    TestID   -> "ACPReview-DebugLog@@Tests/ACPReview.wlt:2057,1-2065,2"
]

(* :!CodeAnalysis::EndBlock:: *)
