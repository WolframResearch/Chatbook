(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Review`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* "Review changes" (see docs/acp-window.md, "Reviewing changes"): the toolbar button and the review window, which lists
   the uncommitted changes of the project folder and shows their diffs. The data comes from Git.wl (acpGitChanges).

   Rules:
   * Read-only: the window lists changes, shows diffs, refreshes and opens files; it never changes the repository.
   * Git runs asynchronously (Git.wl). The window shows "Loading changes..." right away and is filled in by the request's
     continuation, which runs in the pump. Only the result of the window's latest request is shown.
   * The window needs no kernel state: openers are front-end-only DynamicModules, jumping to a file is done by the front
     end (NotebookLocate), and the buttons (Refresh, Open) and the diffs of files that start closed (rendered when they
     are first opened) call ChatbookAction["ACP", ...], which loads Chatbook if needed. $reviewWindows only holds the
     token of each window's latest request.
   * Bounded: at most $acpGitMaxFiles files (Git.wl), $reviewMaxLines lines per diff and $reviewMaxText characters of
     diff text per window. A result is shown in steps of at most about $reviewStepTime seconds (one per pump tick): the
     rows of the file list, then the notebook with the list, then the file cards in batches (reviewStep).
   * Text from the repository (paths, diffs, branch names, git's messages) never becomes boxes: the characters of the
     front end's linear syntax are neutralized (acpNeutralizeLinearSyntax). *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$reviewMaxLines       = 400;       (* diff lines shown per file *)
$reviewOpenMaxLines   = 300;       (* diffs with more lines start closed... *)
$reviewOpenMaxFiles   = 30;        (* ...and when more files changed, all of them do *)
$reviewMaxText        = 4 * 10^6;  (* characters of diff text in a window; the diffs of later files are not shown *)
$reviewMaxLineLength  = 300;       (* longer lines are cut (Rendering.wl shows at most 300 characters as well) *)
$reviewStepTime       = 0.15;      (* seconds of work per step of showing a result (see reviewStep) *)
$reviewWindowSize     = { 760, 820 };
$reviewIconSize       = 16;
$reviewCodeFont       = "Source Code Pro";
$reviewTextFont       = "Source Sans Pro";
$reviewMaxIconLabel   = 4;         (* extensions up to this length are written on the generic file icon *)
$reviewIconLabelColor = RGBColor[ 0.337, 0.835, 0.988 ];  (* the label color of DefinitionNotebookClient's icons *)
$reviewBackground     = LightDarkSwitched[ GrayLevel[ 1.0 ], GrayLevel[ 0.12 ] ];

(* "Open" opens Wolfram Language files in the front end and these in their default application. Other files (scripts,
   executables and anything unknown, which the system might run instead of showing) are shown in their folder. Folders
   whose names have an extension are never opened (a macOS app bundle such as Tool.app would be launched): their
   nearest plain parent folder is shown instead. *)
$reviewNotebookExtensions = { "cdf", "m", "mt", "nb", "wl", "wls", "wlt" };
$reviewSystemOpenExtensions = {
    "bmp", "c", "cc", "cfg", "conf", "cpp", "css", "csv", "gif", "h", "hpp", "htm", "html", "ico", "jpeg", "jpg",
    "json", "log", "markdown", "md", "pdf", "png", "rst", "svg", "text", "tif", "tiff", "toml", "tsv", "txt", "webp",
    "xml", "yaml", "yml"
};

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English defaults for every user-visible string in this file (see acpLabel in Transcript.wl). Every key must also be in
   the .tr files as "ACP" <> key (checked by Tests/ACPWindow.wlt). *)
$acpReviewStrings = <|
    (* Toolbar button *)
    "ReviewChangesButton"         -> "Review",
    "ReviewChangesTooltip"        -> "Review uncommitted changes: `files`",
    "ReviewFileCountOne"          -> "1 file",
    "ReviewFileCount"             -> "`n` files",

    (* Window and header *)
    "ReviewWindowTitle"           -> "Changes \[LongDash] `folder`",
    "ReviewWindowTitleNoFolder"   -> "Changes",
    "ReviewNoFolder"              -> "No project folder",
    "ReviewRefresh"               -> "Refresh",
    "ReviewRefreshTooltip"        -> "Check the project folder for changes again",
    "ReviewLoading"               -> "Loading changes\[Ellipsis]",
    "ReviewUpdated"               -> "Updated `time`",
    "ReviewFilesChangedOne"       -> "1 file changed",
    "ReviewFilesChanged"          -> "`n` files changed",
    "ReviewBranch"                -> "On branch `branch`",
    "ReviewDetached"              -> "HEAD detached at `oid`",
    "ReviewNoCommits"             -> "No commits yet",

    (* File list *)
    "ReviewGoToDiffTooltip"       -> "Go to the diff",
    "ReviewMoreFilesOne"          -> "and 1 more file",
    "ReviewMoreFiles"             -> "and `n` more files",
    "ReviewPatchIncomplete"       -> "Some diffs are not shown: Git's output was too large or took too long.",
    "ReviewCountsIncomplete"      -> "Line counts are not available.",
    "ReviewOpen"                  -> "Open",
    "ReviewOpenTooltip"           -> "Open `name`",
    "ReviewShowInFolderTooltip"   -> "Show `name` in its folder",
    "ReviewRenamedFrom"           -> "Renamed from `path`",
    "ReviewCopiedFrom"            -> "Copied from `path`",

    (* File status *)
    "ReviewStatusModified"        -> "Modified",
    "ReviewStatusAdded"           -> "Added",
    "ReviewStatusDeleted"         -> "Deleted",
    "ReviewStatusRenamed"         -> "Renamed",
    "ReviewStatusCopied"          -> "Copied",
    "ReviewStatusTypeChanged"     -> "Type changed",
    "ReviewStatusConflict"        -> "Conflict",
    "ReviewStatusUntracked"       -> "Untracked",
    "ReviewStatusSubmodule"       -> "Submodule",

    (* Notes shown instead of (or above) a diff *)
    "ReviewNoteBinary"            -> "Binary file, not shown.",
    "ReviewNoteModeChanged"       -> "The file mode changed from `old` to `new`.",
    "ReviewNoteRenamed"           -> "Renamed without changes.",
    "ReviewNoteCopied"            -> "Copied without changes.",
    "ReviewNoteEmpty"             -> "Empty file.",
    "ReviewNoteSubmodule"         -> "The submodule points to a different commit.",
    "ReviewNoteDirectory"         -> "A folder that is not tracked, for example another repository. Its files are not listed.",
    "ReviewNoteTooLarge"          -> "The file is too large to show.",
    "ReviewNoteNotRead"           -> "Not shown: the limit for reading new files was reached.",
    "ReviewNoteSymbolicLink"      -> "A symbolic link to `target`.",
    "ReviewNoteSymbolicLinkBroken" -> "A symbolic link to a file that does not exist.",
    "ReviewNoteNotRegular"        -> "Not a regular file.",
    "ReviewNoteUnreadable"        -> "The file could not be read.",
    "ReviewNoteNoDiff"            -> "Git shows no differences in the contents.",
    "ReviewNotePatchUnavailable"  -> "The diff is not available: Git's output was too large or took too long.",
    "ReviewNoteTooManyChanges"    -> "Not shown: there are too many changes to show all of them here.",

    (* Window states *)
    "ReviewMessageClean"          -> "No uncommitted changes",
    "ReviewMessageCleanDetail"    -> "The files in the project folder match the last commit.",
    "ReviewMessageNoDirectory"    -> "No project folder",
    "ReviewMessageNoDirectoryDetail" -> "Choose a project folder in the agent window first.",
    "ReviewMessageNotRepository"  -> "The project folder is not in a Git repository.",
    "ReviewMessageGitNotFound"    -> "Git was not found.",
    "ReviewMessageGitNotFoundDetail" -> "Install Git (https://git-scm.com) to review changes.",
    "ReviewMessageGitDisabled"    -> "Reviewing changes is turned off.",
    "ReviewMessageGitTooOld"      -> "Git `version` is too old.",
    "ReviewMessageGitTooOldDetail" -> "Reviewing changes needs Git 2.25 or later.",
    "ReviewMessageGitFailed"      -> "Git could not list the changes.",
    "ReviewMessageTimedOut"       -> "Git took too long to list the changes.",
    "ReviewMessageTooLarge"       -> "There are too many changes to list.",
    "ReviewMessageStartFailed"    -> "Git could not be started.",
    "ReviewMessageCancelled"      -> "The check was cancelled.",
    "ReviewMessageUnsafeConfig"   -> "The changes are not listed: the repository's Git configuration has a filter that can't be turned off safely."
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Stores*)

(* Review windows of this kernel session: review NotebookObject -> <| "Token" -> token of the latest request, "Header" ->
   the change set shown (without its files, for the header while the next request runs), "Job" -> the result that is
   being shown (see reviewStep) |>. Entries of closed windows are dropped when the next request starts. *)
If[ ! AssociationQ @ $reviewWindows, $reviewWindows = <| |> ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar Button*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewButtonSignature*)

(* The part of the window state the button shows (for UI.wl's directory row signature): None unless there are changes,
   so checks that find nothing new do not re-render the row. *)
acpReviewButtonSignature // beginDefinition;

acpReviewButtonSignature[ window_Association ] := With[ { git = acpGitSummary @ window },
    If[ git[ "Status" ] === "Changes", Lookup[ git, { "FileCount", "Added", "Deleted" } ], None ]
];

acpReviewButtonSignature[ _ ] := None;

acpReviewButtonSignature // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewButton*)

(* "Review +a -d" in the project folder row of the toolbar, only while the git summary has changes (Nothing otherwise). *)
acpReviewButton // beginDefinition;

acpReviewButton[ nbo_NotebookObject, window_Association ] := With[ { git = acpGitSummary @ window },
    If[ git[ "Status" ] === "Changes",
        acpActionButton[
            blueHueButtonAppearance[
                Tooltip[
                    reviewButtonLabel @ git,
                    acpLabel[ "ReviewChangesTooltip", <| "files" -> fileCountLabel @ git[ "FileCount" ] |> ]
                ],
                { Automatic, 22 },
                { { 5, 5 }, { 0, 0 } }
            ],
            { "ReviewChanges", nbo },
            BoxID -> "ACPReviewChangesButton"
        ],
        Nothing
    ]
];

acpReviewButton[ _, _ ] := Nothing;

acpReviewButton // endDefinition;


reviewButtonLabel // beginDefinition;

reviewButtonLabel[ git_Association ] := Grid[
    { Flatten @ {
        Style[ acpLabel[ "ReviewChangesButton" ], "NotebookAssistant`Sidebar`ToolbarButtonLabel" ],
        lineCountsView[ git[ "Added" ], git[ "Deleted" ], 11 ]
    } },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 1 },
    Spacings         -> { 0.3, 0 }
];

reviewButtonLabel // endDefinition;


(* "+a -d" in green and red (zero counts are left out); a list of items *)
lineCountsView // beginDefinition;

lineCountsView[ added_, deleted_, size_ ] := Flatten @ {
    If[ IntegerQ @ added && added > 0, Style[ "+" <> ToString @ added, FontColor -> acpColor[ "GreenText" ], FontSize -> size ], Nothing ],
    If[ IntegerQ @ deleted && deleted > 0, Style[ "\[Minus]" <> ToString @ deleted, FontColor -> acpColor[ "RedText" ], FontSize -> size ], Nothing ]
};

lineCountsView // endDefinition;


(* lineCountsView as one item, with the spacing of the card headers (a Row with a " " separator shows no space) *)
lineCountsRow // beginDefinition;

lineCountsRow[ added_, deleted_, size_ ] := Replace[
    lineCountsView[ added, deleted, size ],
    {
        { }     -> "",
        { one_ } :> one,
        items_  :> Grid[ { items }, Alignment -> { Left, Baseline }, BaselinePosition -> { 1, 1 }, Spacings -> { { 0, 0.5, 0 }, 0 } ]
    }
];

lineCountsRow // endDefinition;


fileCountLabel // beginDefinition;
fileCountLabel[ 1 ] := acpLabel[ "ReviewFileCountOne" ];
fileCountLabel[ n_ ] := acpLabel[ "ReviewFileCount", <| "n" -> n |> ];
fileCountLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewChanges*)

(* ChatbookAction["ACP", "ReviewChanges", nbo] (the toolbar button): opens the review window of the ACP window nbo, or
   raises the open one, and lists the changes again. acpReviewChanges[dir] does the same for a folder without an ACP
   window (e.g. for testing). Gives the review window. *)
acpReviewChanges // beginDefinition;

acpReviewChanges[ nbo_NotebookObject ] := Module[ { window },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    reviewOpen[ nbo, Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> None ] ]
];

acpReviewChanges[ File[ dir_String ] ] := acpReviewChanges @ dir;

acpReviewChanges[ dir_String ] := reviewOpen[ None, Quiet @ ExpandFileName @ dir ];

acpReviewChanges // endDefinition;


reviewOpen // beginDefinition;

reviewOpen[ owner_, dir_ ] := Module[ { review },
    review = reviewWindowOf[ owner, dir ];
    If[ MatchQ[ review, _NotebookObject ],
        SetSelectedNotebook @ review;
        reviewRequest[ review, owner, dir ],
        review = NotebookPut @ acpReviewNotebook[ <| "Status" -> "Loading", "Directory" -> dir |>, owner, True ];
        If[ MatchQ[ review, _NotebookObject ], reviewRequest[ review, owner, dir ] ]
    ];
    review
];

reviewOpen // endDefinition;


(* The open review window of an ACP window (found by its TaggingRules, so also after a kernel restart), or of a folder
   (without an ACP window), or None *)
reviewWindowOf // beginDefinition;

reviewWindowOf[ owner_NotebookObject, _ ] := SelectFirst[
    Notebooks[ ],
    Quiet @ CurrentValue[ #, { TaggingRules, "ACPReview", "Owner" } ] === owner &,
    None
];

reviewWindowOf[ None, dir_String ] := SelectFirst[
    Notebooks[ ],
    Quiet @ CurrentValue[ #, { TaggingRules, "ACPReview", "Owner" } ] === None &&
        Quiet @ CurrentValue[ #, { TaggingRules, "ACPReview", "Directory" } ] === dir &,
    None
];

reviewWindowOf[ _, _ ] := None;

reviewWindowOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewRefresh*)

(* ChatbookAction["ACP", "ReviewRefresh", review] (the Refresh button): lists the changes again. The changes of the owner
   window's current project folder are listed while the owner has a window record in this kernel; otherwise (e.g. after
   a kernel restart, or once the agent window was closed) those of the folder the window shows. *)
acpReviewRefresh // beginDefinition;

acpReviewRefresh[ review_NotebookObject ] := Module[ { owner, dir },
    owner = Quiet @ CurrentValue[ review, { TaggingRules, "ACPReview", "Owner" } ];
    dir   = Replace[ Quiet @ CurrentValue[ review, { TaggingRules, "ACPReview", "Directory" } ], Except[ _String ] -> None ];
    reviewRequest[ review, owner, dir ]
];

acpReviewRefresh // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reviewRequest*)

(* Starts listing the changes for a review window (the header shows that it is loading) *)
reviewRequest // beginDefinition;

reviewRequest[ review_NotebookObject, owner_, dir_ ] := Module[ { open, shown, continuation, token },
    open = Notebooks[ ];
    $reviewWindows = KeySelect[ $reviewWindows, MemberQ[ open, # ] & ];
    (* The header keeps showing the branch and counts of the shown changes while loading: *)
    shown = Lookup[ Lookup[ $reviewWindows, review, <| |> ], "Header", <| "Status" -> "Loading", "Directory" -> dir |> ];
    Quiet @ SetOptions[ review, DockedCells -> { acpReviewDockedCell[ shown, True ] } ];
    continuation = With[ { r = review }, reviewResult[ r, # ] & ];
    (* Protected, so that the result can't arrive before its token is stored. A request supersedes the window's running
       one (Git.wl kills its git command): the requests of an owner window are keyed by the owner, the others by the
       review window. A result that is still being shown is dropped (its job). *)
    PreemptProtect[
        token = Which[
            MatchQ[ owner, _NotebookObject ] && AssociationQ @ acpWindowGet @ owner, acpGitChanges[ owner, continuation ],
            StringQ @ dir, acpGitChanges[ dir, continuation, { "ACPReview", review } ],
            True, reviewNoDirectory @ continuation
        ];
        $reviewWindows[ review ] = <| KeyDrop[ Lookup[ $reviewWindows, review, <| |> ], "Job" ], "Token" -> token |>
    ];
    token
];

reviewRequest // endDefinition;


(* No owner window and no folder: a "NoDirectory" result (in the pump, like other results) *)
reviewNoDirectory // beginDefinition;

reviewNoDirectory[ continuation_ ] := With[ { token = CreateUUID[ "review-" ] },
    acpSchedule @ continuation @ <| "Token" -> token, "Status" -> "NoDirectory", "Directory" -> None |>;
    token
];

reviewNoDirectory // endDefinition;


(* The continuation of a request (in the pump): the result replaces the window's contents (scrolled to the top), unless
   a newer request was started meanwhile or the window was closed. Changes are shown in steps (reviewStep, from the
   next pump tick on); other results right away. *)
reviewResult // beginDefinition;

reviewResult[ review_NotebookObject, changes_Association ] := Module[ { owner, current },
    If[ ! reviewCurrentQ[ review, changes[ "Token" ] ], Return[ Null, Module ] ];
    If[ ! MemberQ[ Notebooks[ ], review ], KeyDropFrom[ $reviewWindows, review ]; Return[ Null, Module ] ];
    owner = Quiet @ CurrentValue[ review, { TaggingRules, "ACPReview", "Owner" } ];
    (* Protected, so that a request started meanwhile (the Refresh button is preemptive) is not overwritten: *)
    current = PreemptProtect @ If[ reviewCurrentQ[ review, changes[ "Token" ] ],
        $reviewWindows[ review ] = <|
            "Token"  -> changes[ "Token" ],
            "Header" -> KeyDrop[ changes, "Files" ],
            If[ changes[ "Status" ] === "Changes", "Job" -> reviewNewJob[ changes, owner ], Nothing ]
        |>;
        True,
        False
    ];
    Which[
        ! current, Null,
        changes[ "Status" ] === "Changes", With[ { r = review, t = changes[ "Token" ] }, acpSchedule @ reviewStep[ r, t ] ],
        True, reviewPut[ review, acpReviewNotebook[ changes, owner, False ] ]
    ]
];

reviewResult // endDefinition;


(* True if token is the token of the window's latest request *)
reviewCurrentQ // beginDefinition;
reviewCurrentQ[ review_NotebookObject, token_ ] := Lookup[ Lookup[ $reviewWindows, review, <| |> ], "Token", None ] === token;
reviewCurrentQ // endDefinition;


(* Replaces the window's notebook. After NotebookPut the window shows the end of the notebook; the top (the file list)
   is more useful. Scrolling with a front end token leaves the insertion point where it is: moving it before the first
   cell would scroll too, but the front end then shows its caret above the file list. *)
reviewPut // beginDefinition;

reviewPut[ review_NotebookObject, nb_Notebook ] := (
    NotebookPut[ nb, review ];
    FrontEndTokenExecute[ review, "ScrollNotebookStart" ];
    Null
);

reviewPut // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reviewStep*)

(* Shows a change set in steps, one per pump tick, each about $reviewStepTime seconds of work, so that a large change
   set does not hold up the pump (and the agent windows) for seconds: the rows of the file list ("Rows"), then the
   notebook with the list and the first cards ("Put"), then the remaining cards, written after the last cell ("Cards").
   A job is dropped when a newer request starts or the window is closed. The job: <| "Changes", "Owner", "Stage",
   "Rows" (the boxes of the list rows made so far), "Next" (the next file), "Budget" (characters of diff text left),
   "AllClosed" |>. *)
reviewStep // beginDefinition;

reviewStep[ review_NotebookObject, token_ ] := Module[ { job, stage, deadline, cells },
    job = Lookup[ Lookup[ $reviewWindows, review, <| |> ], "Job", None ];
    If[ ! reviewCurrentQ[ review, token ] || ! AssociationQ @ job, Return[ Null, Module ] ];
    If[ ! MemberQ[ Notebooks[ ], review ], KeyDropFrom[ $reviewWindows, review ]; Return[ Null, Module ] ];
    deadline = AbsoluteTime[ ] + $reviewStepTime;
    stage    = job[ "Stage" ];
    If[ stage === "Rows",
        job = reviewRowsStep[ job, deadline ];
        If[ Length @ job[ "Rows" ] === Length @ job[ "Changes" ][ "Files" ], job[ "Stage" ] = "Put" ]
    ];
    Which[
        (* The notebook, as soon as the rows are done (in the same step for a few files, if there is time left): *)
        job[ "Stage" ] === "Put" && (stage === "Put" || ! job[ "AllClosed" ] && AbsoluteTime[ ] < deadline),
            With[ { list = reviewListCells[ job[ "Rows" ], job[ "Changes" ] ] },
                { cells, job } = reviewCardsStep[ job, deadline ];
                If[ reviewCurrentQ[ review, token ], reviewPut[ review, reviewNotebook[ job[ "Changes" ], job[ "Owner" ], False, Join[ list, cells ] ] ] ]
            ];
            job[ "Stage" ] = "Cards",
        stage === "Cards",
            { cells, job } = reviewCardsStep[ job, deadline ];
            If[ reviewCurrentQ[ review, token ], reviewAppendCells[ review, cells ] ]
    ];
    (* Unless a newer request started meanwhile (the Refresh button is preemptive): *)
    PreemptProtect @ If[ reviewCurrentQ[ review, token ],
        If[ job[ "Stage" ] === "Cards" && job[ "Next" ] > Length @ job[ "Changes" ][ "Files" ],
            $reviewWindows[ review ] = KeyDrop[ $reviewWindows[ review ], "Job" ],
            $reviewWindows[ review ] = <| $reviewWindows[ review ], "Job" -> job |>;
            With[ { r = review, t = token }, acpSchedule @ reviewStep[ r, t ] ]
        ]
    ]
];

reviewStep // endDefinition;


reviewNewJob // beginDefinition;

reviewNewJob[ changes_Association, owner_ ] := With[ { files = Replace[ Lookup[ changes, "Files", { } ], Except[ _List ] -> { } ] },
    <|
        "Changes"   -> <| changes, "Files" -> files |>,
        "Owner"     -> owner,
        "Stage"     -> "Rows",
        "Rows"      -> { },
        "Next"      -> 1,
        "Budget"    -> $reviewMaxText,
        "AllClosed" -> Length @ files > $reviewOpenMaxFiles
    |>
];

reviewNewJob // endDefinition;


(* Rows of the file list until the deadline (at least one) *)
reviewRowsStep // beginDefinition;

reviewRowsStep[ job_Association, deadline_ ] := Module[ { files, rows, i },
    files = job[ "Changes" ][ "Files" ];
    rows  = Internal`Bag @ job[ "Rows" ];
    i     = Length @ job[ "Rows" ];
    While[ i < Length @ files && (i === Length @ job[ "Rows" ] || AbsoluteTime[ ] < deadline),
        i++;
        Internal`StuffBag[ rows, reviewListRow[ files[[ i ]], reviewFileTag @ i ] ]
    ];
    <| job, "Rows" -> Internal`BagPart[ rows, All ] |>
];

reviewRowsStep // endDefinition;


(* File cards until the deadline (at least one, unless there are none left): { cells, job } *)
reviewCardsStep // beginDefinition;

reviewCardsStep[ job_Association, deadline_ ] := Module[ { files, cells = Internal`Bag[ ], i, budget, first },
    files  = job[ "Changes" ][ "Files" ];
    i      = job[ "Next" ];
    first  = i;
    budget = job[ "Budget" ];
    While[ i <= Length @ files && (i === first || AbsoluteTime[ ] < deadline),
        Module[ { data },
            data = reviewDiffData @ files[[ i ]];
            If[ AssociationQ @ data,
                budget -= data[ "Size" ];
                If[ budget < 0, data = "TooManyChanges" ]
            ];
            Internal`StuffBag[ cells, reviewFileCell[ files[[ i ]], data, reviewFileTag @ i, job[ "AllClosed" ] ] ]
        ];
        i++
    ];
    { Internal`BagPart[ cells, All ], <| job, "Next" -> i, "Budget" -> budget |> }
];

reviewCardsStep // endDefinition;


(* Writes cells after the last cell of the window, without moving the selection or scrolling *)
reviewAppendCells // beginDefinition;

reviewAppendCells[ _NotebookObject, { } ] := Null;

reviewAppendCells[ review_NotebookObject, cells: { __Cell } ] := With[ { last = Last[ Cells @ review, None ] },
    If[ MatchQ[ last, _CellObject ],
        NotebookWrite[ System`NotebookLocationSpecifier[ last, "After" ], cells, None, AutoScroll -> False ]
    ];
    Null
];

reviewAppendCells // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewOpenFile*)

(* ChatbookAction["ACP", "ReviewOpenFile", path] (the Open links): Wolfram Language files open in the front end, documents
   and images in their default application, plain folders in the file manager; anything else is shown in its folder, so
   that "Open" never runs a program (see reviewOpenAction). *)
acpReviewOpenFile // beginDefinition;

acpReviewOpenFile[ path_String ] := Replace[
    reviewOpenAction @ path,
    {
        { "NotebookOpen", file_ } :> NotebookOpen @ file,
        { "SystemOpen" | "ShowInFolder", file_ } :> SystemOpen @ file,
        _ -> Null
    }
];

acpReviewOpenFile // endDefinition;


(* What "Open" does with a path: { "NotebookOpen" | "SystemOpen", target } (the file or folder itself), { "ShowInFolder",
   folder }, or None (it does not exist). Symbolic links are resolved first, so the file that would actually be opened
   decides. A folder whose name has an extension (or that looks like a bundle) is never opened: on macOS SystemOpen would
   launch an app bundle such as Tool.app; the nearest plain folder above it is shown instead. *)
reviewOpenAction // beginDefinition;

reviewOpenAction[ path_String ] := Module[ { target, folder },
    If[ ! TrueQ @ Quiet @ FileExistsQ @ path, Return[ None, Module ] ];
    target = Quiet @ AbsoluteFileName @ path;
    If[ ! StringQ @ target, Return[ None, Module ] ];
    Which[
        TrueQ @ Quiet @ DirectoryQ @ target,
            folder = reviewPlainFolder @ target;
            Which[ ! StringQ @ folder, None, folder === target, { "SystemOpen", target }, True, { "ShowInFolder", folder } ],
        MemberQ[ $reviewNotebookExtensions, ToLowerCase @ FileExtension @ target ],
            { "NotebookOpen", target },
        MemberQ[ $reviewSystemOpenExtensions, ToLowerCase @ FileExtension @ target ],
            { "SystemOpen", target },
        True,
            Replace[ reviewPlainFolder @ DirectoryName @ path, { f_String :> { "ShowInFolder", f }, _ -> None } ]
    ]
];

reviewOpenAction // endDefinition;


(* The folder itself, or the nearest folder above it, whose name has no extension and that is not a bundle *)
reviewPlainFolder // beginDefinition;

reviewPlainFolder[ dir0_String ] := Module[ { dir, parent, n = 0 },
    dir = Quiet @ AbsoluteFileName @ dir0;
    While[ StringQ @ dir && n++ < 256,
        If[ ! reviewBundleQ @ dir, Return[ dir, Module ] ];
        parent = DirectoryName @ dir;
        (* Without the trailing separator, except for roots ("/", "C:\\"): *)
        If[ StringLength @ parent > 1 && StringEndsQ[ parent, "/" | "\\" ] && ! StringMatchQ[ parent, LetterCharacter ~~ ":" ~~ ("/" | "\\") ],
            parent = StringDrop[ parent, -1 ]
        ];
        If[ parent === "" || parent === dir, Break[ ] ];
        dir = parent
    ];
    None
];

reviewPlainFolder[ _ ] := None;

reviewPlainFolder // endDefinition;


reviewBundleQ // beginDefinition;

reviewBundleQ[ dir_String ] := Or[
    FileExtension @ FileNameTake @ dir =!= "",
    TrueQ @ Quiet @ FileExistsQ @ FileNameJoin @ { dir, "Contents", "Info.plist" }
];

reviewBundleQ // endDefinition;


(* The tooltip of an Open link says what the click does; for paths that don't exist (yet), by their extension *)
reviewOpensFileQ // beginDefinition;

reviewOpensFileQ[ file_Association ] := Replace[
    reviewOpenAction @ file[ "FullPath" ],
    {
        { "NotebookOpen" | "SystemOpen", _ } -> True,
        { "ShowInFolder", _ } -> False,
        _ :> TrueQ @ file[ "Directory" ] || MemberQ[ Join[ $reviewNotebookExtensions, $reviewSystemOpenExtensions ], ToLowerCase @ FileExtension @ file[ "FullPath" ] ]
    }
];

reviewOpensFileQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewDiffView*)

(* The diff of a file in a card: as wide as the card, with line numbers. ChatbookAction["ACP", "ReviewDiffView", data]
   renders the diff of a file whose opener started closed when it is first opened (data is stored in the cell, see
   reviewDiffData). *)
acpReviewDiffView // beginDefinition;

acpReviewDiffView[ data_Association ] := acpDiffView[
    KeyTake[ data, { "Path", "Patch", "OldText", "NewText" } ],
    <|
        "MaxLines"    -> $reviewMaxLines,
        "Header"      -> False,
        "Omitted"     -> Lookup[ data, "Omitted", 0 ],
        "FullWidth"   -> True,
        "LineNumbers" -> True
    |>
];

acpReviewDiffView[ _ ] := "";

acpReviewDiffView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Review Notebook*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewNotebook*)

(* The review notebook for a change set (Git.wl), or for <| "Status" -> "Loading", "Directory" -> dir |>. owner: the ACP
   window. new: True for a new window (with a window size; the size of an open window is kept). *)
acpReviewNotebook // beginDefinition;

acpReviewNotebook[ changes_Association, owner_, new_ ] := reviewNotebook[ changes, owner, new, acpReviewCells @ changes ];

acpReviewNotebook // endDefinition;


(* The review notebook with the given cells. The stylesheet has the icons of all files of the change set (cards that
   are written later use them too). *)
reviewNotebook // beginDefinition;

reviewNotebook[ changes_Association, owner_, new_, cells_List ] := Module[ { dir, icons },
    dir   = Replace[ Lookup[ changes, "Directory", None ], Except[ _String ] -> None ];
    icons = Union[
        { "Directory" },
        If[ Lookup[ changes, "Status", None ] === "Changes",
            acpFileIconName /@ Cases[ Replace[ Lookup[ changes, "Files", { } ], Except[ _List ] -> { } ], KeyValuePattern[ "Path" -> p_String ] :> p ],
            { }
        ]
    ];
    Notebook[
        cells,
        Sequence @@ {
            DockedCells             -> { acpReviewDockedCell[ changes, False ] },
            StyleDefinitions        -> reviewStyleSheet @ icons,
            TaggingRules            -> <| "ACPReview" -> <| "Owner" -> owner, "Directory" -> dir |> |>,
            WindowTitle             -> reviewWindowTitle @ dir,
            Evaluator               -> reviewEvaluator @ owner,
            If[ TrueQ @ new, WindowSize -> $reviewWindowSize, Nothing ],
            CellGrouping            -> Manual,
            (* Nothing can be inserted: no "+" menu, and the insertion line between cells is drawn in the background
               color (the front end still shows its short caret where the user clicks) *)
            CellInsertionPointCell  -> None,
            CellInsertionPointColor -> $reviewBackground,
            ClosingAutoSave         -> False,
            Editable                -> False,
            Saveable                -> False,
            ShowCellBracket         -> False,
            (* Long lines wrap, so there is no horizontal scroll bar: *)
            WindowElements          -> { "VerticalScrollBar", "MagnificationPopUp" },
            WindowToolbars          -> { }
        }
    ]
];

reviewNotebook // endDefinition;


reviewWindowTitle // beginDefinition;
reviewWindowTitle[ dir_String ] := acpLabel[ "ReviewWindowTitle", <| "folder" -> acpNeutralizeLinearSyntax @ FileNameTake @ dir |> ];
reviewWindowTitle[ _ ] := acpLabel[ "ReviewWindowTitleNoFolder" ];
reviewWindowTitle // endDefinition;


(* The kernel that holds the ACP window's state *)
reviewEvaluator // beginDefinition;

reviewEvaluator[ owner_NotebookObject ] := Replace[
    If[ $FrontEnd === Null, None, Quiet @ AbsoluteCurrentValue[ owner, Evaluator ] ],
    Except[ _String ] -> "Local"
];

reviewEvaluator[ _ ] := "Local";

reviewEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewDockedCell*)

(* The header: the project folder, a Refresh button, and a status line (branch, counts, when the changes were listed or
   that they are loading). *)
acpReviewDockedCell // beginDefinition;

acpReviewDockedCell[ changes_Association, loading_ ] := Cell[
    BoxData @ reviewCellBoxes @ Framed[
        Column[
            {
                Grid[
                    {
                        {
                            reviewIcon[ "Directory" ],
                            reviewFolderLabel @ Lookup[ changes, "Directory", None ],
                            Item[ Spacer[ 0 ], ItemSize -> Fit ],
                            reviewRefreshButton[ ]
                        }
                    },
                    Alignment -> { Left, Center },
                    Spacings  -> { 0.4, 0 }
                ],
                reviewStatusLine[ changes, TrueQ @ loading || Lookup[ changes, "Status" ] === "Loading" ]
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

acpReviewDockedCell // endDefinition;


reviewFolderLabel // beginDefinition;

reviewFolderLabel[ dir_String ] := Tooltip[
    Style[ reviewDisplayPath @ dir, FontWeight -> "DemiBold", LineBreakWithin -> False ],
    dir
];

reviewFolderLabel[ _ ] := Style[ acpLabel[ "ReviewNoFolder" ], FontSlant -> Italic ];

reviewFolderLabel // endDefinition;


(* "~/..." for folders in the home folder (as in the toolbar) *)
reviewDisplayPath // beginDefinition;
reviewDisplayPath[ dir_String ] := acpNeutralizeLinearSyntax @ acpAbbreviatePath[ dir, None ];
reviewDisplayPath // endDefinition;


(* The button function finds its window with EvaluationNotebook[] (the header is built before the window exists) *)
reviewRefreshButton // beginDefinition;

reviewRefreshButton[ ] := Replace[
    acpActionCode[ "ReviewRefresh", EvaluationNotebook[ ] ],
    Hold[ code_ ] :> Button[
        blueHueButtonAppearance[
            Tooltip[ Style[ acpLabel[ "ReviewRefresh" ], "ACPReviewButtonLabel" ], acpLabel[ "ReviewRefreshTooltip" ] ],
            { Automatic, 24 },
            { { 6, 6 }, { 0, 0 } }
        ],
        code,
        Appearance -> "Suppressed",
        BoxID      -> "ACPReviewRefreshButton",
        Method     -> "Preemptive"
    ]
];

reviewRefreshButton // endDefinition;


reviewStatusLine // beginDefinition;

reviewStatusLine[ changes_Association, loading_ ] := Module[ { status, parts },
    status = Lookup[ changes, "Status", None ];
    parts  = If[ MatchQ[ status, "Changes" | "Clean" ], { reviewBranchLabel @ changes }, { } ];
    If[ status === "Changes",
        AppendTo[ parts, Row[ Riffle[ Flatten @ { fileCountChangedLabel @ changes[ "FileCount" ], lineCountsView[ changes[ "Added" ], changes[ "Deleted" ], Inherited ] }, " " ] ] ]
    ];
    Which[
        TrueQ @ loading,
            AppendTo[ parts, Row @ { ProgressIndicator[ Appearance -> "Percolate", ImageSize -> { 30, 8 } ], " ", acpLabel[ "ReviewLoading" ] } ],
        NumberQ @ Lookup[ changes, "CheckedAt", None ],
            AppendTo[ parts, acpLabel[ "ReviewUpdated", <| "time" -> DateString[ changes[ "CheckedAt" ], { "Hour24", ":", "Minute" } ] |> ] ]
    ];
    Style[ Row[ DeleteCases[ parts, None ], " \[CenterDot] " ], FontColor -> acpColor[ "Muted" ], FontSize -> 12 ]
];

reviewStatusLine // endDefinition;


reviewBranchLabel // beginDefinition;

reviewBranchLabel[ changes_Association ] := Module[ { branch, oid, parts },
    branch = Lookup[ changes, "Branch", None ];
    oid    = Lookup[ changes, "OID", None ];
    parts  = {
        Which[
            StringQ @ branch, acpLabel[ "ReviewBranch", <| "branch" -> acpNeutralizeLinearSyntax @ branch |> ],
            TrueQ @ Lookup[ changes, "Detached", False ] && StringQ @ oid, acpLabel[ "ReviewDetached", <| "oid" -> StringTake[ oid, UpTo[ 7 ] ] |> ],
            True, Nothing
        ],
        If[ TrueQ @ Lookup[ changes, "Initial", False ], acpLabel[ "ReviewNoCommits" ], Nothing ]
    };
    If[ parts === { }, None, Row[ parts, " \[CenterDot] " ] ]
];

reviewBranchLabel // endDefinition;


fileCountChangedLabel // beginDefinition;
fileCountChangedLabel[ 1 ] := acpLabel[ "ReviewFilesChangedOne" ];
fileCountChangedLabel[ n_ ] := acpLabel[ "ReviewFilesChanged", <| "n" -> n |> ];
fileCountChangedLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReviewCells*)

(* The cells of the review notebook: a file list and one cell per file, or a message *)
acpReviewCells // beginDefinition;

acpReviewCells[ changes_Association ] := Switch[ Lookup[ changes, "Status", None ],
    "Loading",
        { reviewMessageCell[ Row @ { ProgressIndicator[ Appearance -> "Percolate" ], "  ", acpLabel[ "ReviewLoading" ] } ] },
    "Changes",
        reviewChangeCells @ changes,
    "Clean",
        { reviewMessageCell[ acpLabel[ "ReviewMessageClean" ], acpLabel[ "ReviewMessageCleanDetail" ], "Neutral" ] },
    "NoDirectory",
        { reviewMessageCell[ acpLabel[ "ReviewMessageNoDirectory" ], acpLabel[ "ReviewMessageNoDirectoryDetail" ], "Neutral" ] },
    "NotRepository",
        { reviewMessageCell[ acpLabel[ "ReviewMessageNotRepository" ], None, "Neutral" ] },
    "Unavailable",
        { reviewUnavailableCell @ changes },
    _,
        { reviewErrorCell @ changes }
];

acpReviewCells // endDefinition;


reviewUnavailableCell // beginDefinition;

reviewUnavailableCell[ changes_Association ] := Switch[ Lookup[ Replace[ changes[ "Error" ], Except[ _Association ] -> <| |> ], "Code", None ],
    "Disabled",
        reviewMessageCell[ acpLabel[ "ReviewMessageGitDisabled" ], None, "Neutral" ],
    "GitTooOld",
        reviewMessageCell[
            acpLabel[ "ReviewMessageGitTooOld", <| "version" -> Replace[ changes[ "GitVersion" ], Except[ _String ] -> "" ] |> ],
            acpLabel[ "ReviewMessageGitTooOldDetail" ],
            "Amber"
        ],
    _,
        reviewMessageCell[ acpLabel[ "ReviewMessageGitNotFound" ], acpLabel[ "ReviewMessageGitNotFoundDetail" ], "Amber" ]
];

reviewUnavailableCell // endDefinition;


reviewErrorCell // beginDefinition;

reviewErrorCell[ changes_Association ] := Module[ { error, key },
    error = Replace[ Lookup[ changes, "Error", None ], Except[ _Association ] -> <| |> ];
    key   = Replace[
        Lookup[ error, "Code", None ],
        {
            "TimedOut"    -> "ReviewMessageTimedOut",
            "TooLarge"    -> "ReviewMessageTooLarge",
            "StartFailed" -> "ReviewMessageStartFailed",
            "Cancelled"   -> "ReviewMessageCancelled",
            "UnsafeConfig" -> "ReviewMessageUnsafeConfig",
            _             -> "ReviewMessageGitFailed"
        }
    ];
    reviewMessageCell[ acpLabel @ key, Replace[ Lookup[ error, "Detail", None ], s_String :> reviewCode @ s ], "Red" ]
];

reviewErrorCell // endDefinition;


reviewMessageCell // beginDefinition;

reviewMessageCell[ title_ ] := Cell[ BoxData @ reviewCellBoxes @ title, "ACPReviewMessage" ];

reviewMessageCell[ title_, detail_, style_String ] := Cell[
    BoxData @ reviewCellBoxes @ Framed[
        Column[
            {
                Style[ title, FontWeight -> "DemiBold", FontSize -> 14, FontColor -> Switch[ style, "Red", acpColor[ "ErrorFont" ], "Amber", acpColor[ "AmberFont" ], _, Inherited ] ],
                If[ detail === None, Nothing, Style[ detail, FontColor -> acpColor[ "Muted" ] ] ]
            },
            Spacings -> 0.5
        ],
        Background     -> Switch[ style, "Red", acpColor[ "ErrorBackground" ], "Amber", acpColor[ "AmberBackground" ], _, None ],
        FrameStyle     -> Switch[ style, "Red", acpColor[ "ErrorFrame" ], "Amber", acpColor[ "AmberFrame" ], _, None ],
        FrameMargins   -> { { 12, 12 }, { 10, 10 } },
        RoundingRadius -> 6
    ],
    "ACPReviewMessage"
];

reviewMessageCell // endDefinition;


reviewCode // beginDefinition;
reviewCode[ s_String ] := Style[ acpNeutralizeLinearSyntax @ s, FontFamily -> $reviewCodeFont, FontSize -> 12, LineBreakWithin -> Automatic ];
reviewCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reviewChangeCells*)

(* The file list (with notes about files that are not listed and incomplete output) followed by one cell per file, all
   at once (the review window shows them in steps, see reviewStep) *)
reviewChangeCells // beginDefinition;

reviewChangeCells[ changes_Association ] := Module[ { job, cells },
    job = reviewNewJob[ changes, None ];
    job = reviewRowsStep[ job, Infinity ];
    { cells, job } = reviewCardsStep[ job, Infinity ];
    Flatten @ { reviewListCells[ job[ "Rows" ], job[ "Changes" ] ], cells }
];

reviewChangeCells // endDefinition;


(* The list cell and the notices below it *)
reviewListCells // beginDefinition;

reviewListCells[ rows_List, changes_Association ] := Flatten @ {
    reviewListCell[ rows, changes ],
    If[ TrueQ @ Lookup[ changes, "PatchComplete", True ], Nothing, reviewNoticeCell @ acpLabel[ "ReviewPatchIncomplete" ] ],
    If[ TrueQ @ Lookup[ changes, "CountsComplete", True ], Nothing, reviewNoticeCell @ acpLabel[ "ReviewCountsIncomplete" ] ]
};

reviewListCells // endDefinition;


reviewFileTag // beginDefinition;
reviewFileTag[ i_Integer ] := "ACPReviewFile-" <> ToString @ i;
reviewFileTag // endDefinition;


reviewNoticeCell // beginDefinition;
reviewNoticeCell[ text_String ] := Cell[ BoxData @ reviewCellBoxes @ Style[ text, FontColor -> acpColor[ "AmberText" ] ], "ACPReviewNotice" ];
reviewNoticeCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reviewDiffData*)

(* What is shown as the diff of a file: <| "Path", "Patch" | "OldText" + "NewText", "Omitted" (lines left out), "Lines"
   (all lines), "Size" (characters kept) |>, or None (no diff: the file's note says why). At most $reviewMaxLines lines
   of at most $reviewMaxLineLength characters are kept. *)
reviewDiffData // beginDefinition;

reviewDiffData[ file_Association ] := Which[
    StringQ @ file[ "Patch" ] && ! TrueQ @ file[ "Binary" ],
        reviewTruncatedText[ file[ "Path" ], "Patch", file[ "Patch" ] ],
    file[ "Status" ] === "Untracked" && StringQ @ file[ "Content" ] && file[ "Content" ] =!= "",
        reviewTruncatedText[ file[ "Path" ], "NewText", file[ "Content" ] ],
    True,
        None
];

reviewDiffData // endDefinition;


reviewTruncatedText // beginDefinition;

reviewTruncatedText[ path_, key_String, text_String ] := Module[ { lines, kept, truncated },
    lines     = StringSplit[ StringDelete[ text, "\n" ~~ EndOfString ], "\n", All ];
    kept      = Take[ lines, UpTo @ $reviewMaxLines ];
    truncated = StringRiffle[
        If[ StringLength[ # ] > $reviewMaxLineLength, StringTake[ #, $reviewMaxLineLength ] <> "\[Ellipsis]", # ] & /@ kept,
        "\n"
    ];
    Join[
        <| "Path" -> path |>,
        If[ key === "NewText", <| "OldText" -> None, "NewText" -> truncated |>, <| key -> truncated |> ],
        <| "Omitted" -> Length @ lines - Length @ kept, "Lines" -> Length @ lines, "Size" -> StringLength @ truncated |>
    ]
];

reviewTruncatedText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reviewListCell*)

(* One row per file: icon, path (clicking it scrolls to the file's cell, in the front end), status and line counts (as
   in the cards). rows: the rows' items as boxes (reviewListRow). *)
reviewListCell // beginDefinition;

reviewListCell[ rows_List, changes_Association ] := Module[ { more },
    more = Replace[ Lookup[ changes, "MoreFiles", 0 ], Except[ _Integer ] -> 0 ];
    Cell[
        BoxData @ reviewCellBoxes @ Column[
            Flatten @ {
                Grid[ rows, Alignment -> { { Center, Left, Left, Left }, Baseline }, Spacings -> { { 0, 0.5, 1.5, 1.0 }, 0.45 } ],
                If[ more > 0, Style[ If[ more === 1, acpLabel[ "ReviewMoreFilesOne" ], acpLabel[ "ReviewMoreFiles", <| "n" -> more |> ] ], FontColor -> acpColor[ "Muted" ], FontSlant -> Italic ], Nothing ]
            },
            Spacings -> 0.6
        ],
        "ACPReviewList"
    ]
];

reviewListCell // endDefinition;


(* The items of a file's list row, converted to boxes (the rows of large change sets are made in steps) *)
reviewListRow // beginDefinition;

reviewListRow[ file_Association, tag_String ] := RawBoxes @* reviewBoxes /@ {
    reviewIcon @ acpFileIconName @ file[ "Path" ],
    reviewJumpLink[ reviewPathLabel[ file, False, False ], tag ],
    reviewStatusBadge @ file,
    lineCountsRow[ file[ "Added" ], file[ "Deleted" ], Inherited ]
};

reviewListRow // endDefinition;


(* A link that scrolls to the cell with the tag (run by the front end, no kernel needed), underlined under the mouse like
   the Open links. The Mouseover is outside the buttons (each pane has one), so the buttons' Evaluator -> None does not
   apply to it. *)
reviewJumpLink // beginDefinition;

reviewJumpLink[ label_, tag_String ] := Tooltip[
    MouseAppearance[
        Mouseover[ reviewJumpButton[ label, tag ], reviewJumpButton[ Style[ label, FontVariations -> { "Underline" -> True } ], tag ] ],
        "LinkHand"
    ],
    acpLabel[ "ReviewGoToDiffTooltip" ]
];

reviewJumpLink // endDefinition;


reviewJumpButton // beginDefinition;

reviewJumpButton[ label_, tag_String ] := Button[
    label,
    FrontEndExecute @ { FrontEnd`NotebookLocate @ tag },
    Appearance -> None,
    BaseStyle  -> { },
    Evaluator  -> None
];

reviewJumpButton // endDefinition;


(* The path with a muted folder part; renamed and copied files show their original path first (with a tooltip that says
   so, unless tooltip is False, e.g. for links that have their own) *)
reviewPathLabel // beginDefinition;

reviewPathLabel[ file_Association, bold_ ] := reviewPathLabel[ file, bold, True ];

reviewPathLabel[ file_Association, bold_, tooltip_ ] := Module[ { path, orig, label },
    path = reviewPathView[ file[ "Path" ], bold ];
    orig = acpNeutralizeLinearSyntax @ file[ "OrigPath" ];
    If[ StringQ @ orig,
        label = Row @ {
            Style[ orig, FontColor -> acpColor[ "Muted" ], FontFamily -> $reviewCodeFont, FontSize -> 12 ],
            Style[ " " <> FromCharacterCode[ 8594 ] <> " ", FontColor -> acpColor[ "Muted" ] ], (* a right arrow *)
            path
        };
        If[ TrueQ @ tooltip,
            Tooltip[ label, acpLabel[ If[ file[ "Status" ] === "Copied", "ReviewCopiedFrom", "ReviewRenamedFrom" ], <| "path" -> orig |> ] ],
            label
        ],
        path
    ]
];

reviewPathLabel // endDefinition;


reviewPathView // beginDefinition;

reviewPathView[ path0_String, bold_ ] := Module[ { path, trimmed, name, dir },
    path    = acpNeutralizeLinearSyntax @ path0;
    trimmed = StringDelete[ path, "/" ~~ EndOfString ];
    name    = Last[ StringSplit[ trimmed, "/" ], trimmed ] <> If[ StringEndsQ[ path, "/" ], "/", "" ];
    dir     = StringDrop[ path, -StringLength @ name ];
    Style[
        Row @ { If[ dir === "", Nothing, Style[ dir, FontColor -> acpColor[ "Muted" ] ] ], Style[ name, FontWeight -> If[ TrueQ @ bold, "DemiBold", Plain ] ] },
        FontFamily -> $reviewCodeFont,
        FontSize   -> 12
    ]
];

reviewPathView // endDefinition;


reviewStatusBadge // beginDefinition;

reviewStatusBadge[ file_Association ] := With[ { status = file[ "Status" ] },
    acpBadge[
        acpLabel[ "ReviewStatus" <> If[ StringQ @ status, status, "Modified" ] ],
        Switch[ status, "Added" | "Untracked", "Green", "Deleted", "Red", "Conflict", "Amber", _, "Neutral" ]
    ]
];

reviewStatusBadge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reviewFileCell*)

(* A card per file: a header that opens and closes the card (front end only), an Open link, and the diff or a note. Cards
   start open unless their diff is long or binary, or many files changed. The diffs of cards that start open are in the
   cell; the others are rendered by the kernel when the card is first opened (a closed PaneSelector pane is not
   evaluated), so a window with many or large changes stays small. *)
reviewFileCell // beginDefinition;

reviewFileCell[ file_Association, data_, tag_String, allClosed_ ] := Module[ { open, note, body },
    open = ! TrueQ @ allClosed && ! TrueQ @ file[ "Binary" ] && ! (AssociationQ @ data && data[ "Lines" ] > $reviewOpenMaxLines);
    note = reviewNote[ file, data ];
    body = Which[
        ! AssociationQ @ data, None,
        open                 , acpReviewDiffView @ data,
        True                 , reviewLazyDiff @ KeyDrop[ data, { "Lines", "Size" } ]
    ];
    Cell[
        BoxData @ StyleBox[
            reviewOpenerBoxes[
                reviewBoxes @ reviewFileHeader @ file,
                reviewOpenLinkBoxes @ file,
                reviewBoxes @ Column[ DeleteCases[ { note, body }, None ], Spacings -> 0.5 ],
                open
            ],
            "ACPReviewText"
        ],
        "ACPReviewFile",
        CellTags -> { tag }
    ]
];

reviewFileCell // endDefinition;


reviewFileHeader // beginDefinition;

reviewFileHeader[ file_Association ] := Grid[
    { Flatten @ {
        reviewIcon @ acpFileIconName @ file[ "Path" ],
        reviewPathLabel[ file, True ],
        reviewStatusBadge @ file,
        lineCountsView[ file[ "Added" ], file[ "Deleted" ], 12 ]
    } },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, 2 },
    Spacings         -> { 0.5, 0 }
];

reviewFileHeader // endDefinition;


(* The note above (or instead of) the diff, or None *)
reviewNote // beginDefinition;

reviewNote[ file_Association, data_ ] := Module[ { key, params = <| |>, modes },
    modes = Lookup[ file, { "OldMode", "NewMode" }, None ];
    key   = Which[
        data === "TooManyChanges",
            "ReviewNoteTooManyChanges",
        file[ "Note" ] === "Renamed",
            If[ file[ "Status" ] === "Copied", "ReviewNoteCopied", "ReviewNoteRenamed" ],
        file[ "Note" ] === "SymbolicLink",
            With[ { target = Lookup[ file, "LinkTarget", None ] },
                If[ StringQ @ target,
                    params = <| "target" -> acpNeutralizeLinearSyntax @ acpAbbreviatePath[ target, None ] |>;
                    "ReviewNoteSymbolicLink",
                    "ReviewNoteSymbolicLinkBroken"
                ]
            ],
        StringQ @ file[ "Note" ] && file[ "Note" ] =!= "ModeChanged",
            "ReviewNote" <> file[ "Note" ],
        (* Only the mode changed, or the mode and the contents (then the note is above the diff): *)
        AllTrue[ modes, StringQ ] && UnsameQ @@ modes && file[ "Status" ] =!= "TypeChanged",
            params = <| "old" -> modes[[ 1 ]], "new" -> modes[[ 2 ]] |>;
            "ReviewNoteModeChanged",
        data === None,
            "ReviewNoteNoDiff",
        True,
            None
    ];
    If[ StringQ @ key,
        Style[ acpLabel[ key, params ], FontColor -> acpColor[ "Muted" ], FontSlant -> Italic ],
        None
    ]
];

reviewNote // endDefinition;


(* Rendered when the card is first opened. data is part of the cell, so this needs no kernel state. *)
reviewLazyDiff // beginDefinition;

reviewLazyDiff[ data_Association ] := With[ { d = data },
    Dynamic[
        Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "ReviewDiffView", d ],
        SynchronousUpdating -> False,
        TrackedSymbols      :> { }
    ]
];

reviewLazyDiff // endDefinition;


(* Open (or show in its folder) the file; nothing for deleted files *)
reviewOpenLinkBoxes // beginDefinition;

reviewOpenLinkBoxes[ file_Association ] := With[ { path = file[ "FullPath" ] },
    If[ file[ "Status" ] === "Deleted" || ! StringQ @ path,
        reviewBoxes @ Spacer[ 0 ],
        ReplaceAll[
            reviewTemplate[ "OpenLink" ],
            {
                $slotPath    -> path,
                $slotTooltip -> ToBoxes @ acpLabel[
                    If[ reviewOpensFileQ @ file, "ReviewOpenTooltip", "ReviewShowInFolderTooltip" ],
                    <| "name" -> acpNeutralizeLinearSyntax @ FileNameTake @ path |>
                ]
            }
        ]
    ]
];

reviewOpenLinkBoxes // endDefinition;


reviewOpenLink // beginDefinition;

reviewOpenLink[ tooltip_, path_ ] := acpActionButton[
    Tooltip[
        MouseAppearance[
            Mouseover[
                Style[ acpLabel[ "ReviewOpen" ], FontColor -> acpColor[ "ToolLabel" ], FontSize -> 12 ],
                Style[ acpLabel[ "ReviewOpen" ], FontColor -> acpColor[ "ToolLabel" ], FontSize -> 12, FontVariations -> { "Underline" -> True } ]
            ],
            "LinkHand"
        ],
        tooltip
    ],
    { "ReviewOpenFile", path },
    BaseStyle -> { }
];

reviewOpenLink // endDefinition;


(* reviewOpener in boxes, with boxes for the parts *)
reviewOpenerBoxes // beginDefinition;

reviewOpenerBoxes[ header_, link_, body_, open_ ] := ReplaceAll[
    reviewTemplate @ If[ TrueQ @ open, "OpenerOpen", "OpenerClosed" ],
    { $slotHeader -> header, $slotLink -> link, $slotBody -> body }
];

reviewOpenerBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*reviewTemplate*)

(* Converting an opener (or an Open link) to boxes takes several milliseconds, mostly for its fixed parts, so they are
   converted once per session with symbols ($slot...) in place of the parts, which are filled in with ReplaceAll. *)
reviewTemplate // beginDefinition;

reviewTemplate[ name_String ] := Lookup[ $reviewTemplates, name, $reviewTemplates[ name ] = makeReviewTemplate @ name ];

reviewTemplate // endDefinition;

$reviewTemplates = <| |>;


makeReviewTemplate // beginDefinition;
makeReviewTemplate[ "OpenerOpen"   ] := reviewBoxes @ reviewOpener[ RawBoxes @ $slotHeader, RawBoxes @ $slotLink, RawBoxes @ $slotBody, True ];
makeReviewTemplate[ "OpenerClosed" ] := reviewBoxes @ reviewOpener[ RawBoxes @ $slotHeader, RawBoxes @ $slotLink, RawBoxes @ $slotBody, False ];
makeReviewTemplate[ "OpenLink"     ] := reviewBoxes @ reviewOpenLink[ RawBoxes @ $slotTooltip, $slotPath ];
makeReviewTemplate // endDefinition;


(* A card with a front-end-only opener (like Rendering.wl's staticOpener): clicking the header shows or hides the body.
   The link is outside the clickable part of the header. The pane of a closed card has only the header (an empty row
   below it would still take up a line), so the header is in both panes; the body is in the open pane only. *)
reviewOpener // beginDefinition;

reviewOpener[ header_, link_, body_, open_ ] := With[
    {
        closedHeader = reviewOpenerHeader[ header, link, False ],
        openHeader   = reviewOpenerHeader[ header, link, True ],
        b            = body,
        init         = TrueQ @ open
    },
    DynamicModule[ { Typeset`open = init },
        Framed[
            PaneSelector[
                {
                    False -> closedHeader,
                    True  -> Column[ { openHeader, Pane[ b, ImageMargins -> { { 0, 0 }, { 0, 8 } } ] }, Alignment -> Left, Spacings -> 0 ]
                },
                Dynamic @ Typeset`open,
                ImageSize -> Automatic
            ],
            Background     -> acpColor[ "CardBackground" ],
            FrameStyle     -> Directive[ AbsoluteThickness[ 1 ], acpColor[ "CardFrame" ] ],
            FrameMargins   -> { { 8, 8 }, { 6, 6 } },
            ImageSize      -> Full,
            RoundingRadius -> 6
        ],
        DynamicModuleValues :> { }
    ]
];

reviewOpener // endDefinition;


(* Clicking the header (but not the link) toggles Typeset`open, the variable of reviewOpener's DynamicModule *)
reviewOpenerHeader // beginDefinition;

reviewOpenerHeader[ header_, link_, open_ ] := Grid[
    {
        {
            MouseAppearance[
                EventHandler[
                    Grid[
                        { { reviewChevron @ open, header } },
                        Alignment        -> { Left, Baseline },
                        BaselinePosition -> { 1, 2 },
                        Spacings         -> { 0.4, 0 }
                    ],
                    { "MouseDown" :> FEPrivate`Set[ Typeset`open, Not[ Typeset`open ] ] },
                    Method -> "Preemptive", PassEventsDown -> Automatic, PassEventsUp -> True
                ],
                "LinkHand"
            ],
            Item[ Spacer[ 0 ], ItemSize -> Fit ],
            link
        }
    },
    Alignment -> { Left, Baseline },
    Spacings  -> { 0.5, 0 }
];

reviewOpenerHeader // endDefinition;



(* A small triangle: pointing right (closed) or down (open) *)
reviewChevron // beginDefinition;

reviewChevron[ open_ ] := Graphics[
    { acpColor[ "ToolLabel" ], Polygon @ If[ TrueQ @ open, { { 0, 0.75 }, { 1, 0.75 }, { 0.5, 0.15 } }, { { 0.2, 0 }, { 0.2, 1 }, { 0.8, 0.5 } } ] },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.1 ],
    ImageSize        -> { 9, 9 },
    PlotRange        -> { { 0, 1 }, { 0, 1 } }
];

reviewChevron // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reviewBoxes*)

(* Boxes made with only System` and Global` on $ContextPath, so that every symbol in them (e.g. in button actions) is
   written with its full context name and still resolves when the boxes are evaluated later. *)
reviewBoxes // beginDefinition;
reviewBoxes[ expr_ ] := Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } }, ToBoxes @ expr ];
reviewBoxes // endDefinition;


(* The contents of a BoxData cell: the inline text style replaces the code font of StandardForm *)
reviewCellBoxes // beginDefinition;
reviewCellBoxes[ expr_ ] := StyleBox[ reviewBoxes @ expr, "ACPReviewText" ];
reviewCellBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*reviewStyleSheet*)

(* A private stylesheet: the review cell styles and one TemplateBox style per file icon used in the notebook, so that the
   boxes of each icon are stored once. *)
reviewStyleSheet // beginDefinition;

reviewStyleSheet[ icons_List ] := Notebook[
    Flatten @ {
        Cell @ StyleData[ StyleDefinitions -> "Default.nb" ],
        Cell[
            StyleData[ "Notebook" ],
            Background -> $reviewBackground
        ],
        Cell[
            StyleData[ "ACPReviewBase" ],
            FontFamily           -> $reviewTextFont,
            FontSize             -> 13,
            FontColor            -> LightDarkSwitched[ GrayLevel[ 0.15 ], GrayLevel[ 0.88 ] ],
            ShowStringCharacters -> False,
            LineSpacing          -> { 1.05, 0 },
            PrivateFontOptions   -> { "OperatorSubstitution" -> False },
            ShowCellBracket      -> False,
            Selectable           -> True
        ],
        Cell[
            StyleData[ "ACPReviewText" ],
            FontFamily         -> $reviewTextFont,
            LineSpacing        -> { 1.05, 0 },
            PrivateFontOptions -> { "OperatorSubstitution" -> False }
        ],
        Cell[ StyleData[ "ACPReviewHeader", StyleDefinitions -> StyleData[ "ACPReviewBase" ] ],
            Background       -> color @ "NA_Toolbar",
            CellFrame        -> { { 0, 0 }, { 1, 0 } },
            CellFrameColor   -> LightDarkSwitched[ GrayLevel[ 0.85 ], GrayLevel[ 0.3 ] ],
            CellFrameMargins -> { { 14, 10 }, { 6, 8 } },
            CellMargins      -> { { 0, 0 }, { 0, 0 } },
            FontSize         -> 13
        ],
        Cell[ StyleData[ "ACPReviewList", StyleDefinitions -> StyleData[ "ACPReviewBase" ] ],
            CellMargins -> { { 18, 18 }, { 10, 14 } }
        ],
        Cell[ StyleData[ "ACPReviewNotice", StyleDefinitions -> StyleData[ "ACPReviewBase" ] ],
            CellMargins -> { { 18, 18 }, { 4, 4 } },
            FontSize    -> 12
        ],
        Cell[ StyleData[ "ACPReviewFile", StyleDefinitions -> StyleData[ "ACPReviewBase" ] ],
            CellMargins -> { { 12, 12 }, { 4, 4 } }
        ],
        Cell[ StyleData[ "ACPReviewMessage", StyleDefinitions -> StyleData[ "ACPReviewBase" ] ],
            CellMargins -> { { 18, 18 }, { 12, 24 } }
        ],
        Cell[ StyleData[ "ACPReviewButtonLabel" ],
            FontFamily -> $reviewTextFont,
            FontSize   -> 13,
            FontColor  -> color @ "NA_BlueHueButtonIcon"
        ],
        iconStyle /@ icons
    },
    StyleDefinitions -> "PrivateStylesheetFormatting.nb"
];

reviewStyleSheet // endDefinition;


iconStyle // beginDefinition;

iconStyle[ name_String ] := With[ { icon = acpFileIcon @ { name } },
    Cell[ StyleData[ "ACPReviewIcon" <> name ], TemplateBoxOptions -> { DisplayFunction -> Function[ icon ] } ]
];

iconStyle // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*File Icons*)

(* File icons (about 16 points) for paths: DefinitionNotebookClient's file manager icons (as used by its FileTreeCells),
   and for other extensions a page in the same style with the extension written on it. Without the icons (e.g. a
   Wolfram Engine without the component), simple drawn pages are used. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFileIconName*)

(* The icon name for a path (relative or absolute, "/" or system separators; untracked folders end with "/"): a name of
   DefinitionNotebookClient's icons ("WL", "NB", "TXT", "Directory", ...) or "Ext" <> EXT for other extensions. *)
acpFileIconName // beginDefinition;

acpFileIconName[ path_String ] /; StringEndsQ[ path, "/" | "\\" ] := "Directory";

acpFileIconName[ path_String ] := Module[ { name, ext },
    name = Last[ StringSplit[ path, "/" | "\\" ], path ];
    ext  = ToLowerCase @ Last[ StringSplit[ name, ".", All ], "" ];
    If[ ! StringContainsQ[ StringTrim[ name, "." ], "." ], ext = "" ];
    Which[
        StringMatchQ[ name, "PacletInfo." ~~ ("wl" | "m"), IgnoreCase -> True ], "PacletInfo",
        KeyExistsQ[ $iconExtensions, ext ], $iconExtensions[ ext ],
        ext === "", "TXT",
        StringLength @ ext <= $reviewMaxIconLabel && StringMatchQ[ ext, (LetterCharacter | DigitCharacter).. ], "Ext" <> ToUpperCase @ ext,
        True, "ExtFile"
    ]
];

acpFileIconName[ _ ] := "ExtFile";

acpFileIconName // endDefinition;


(* Extensions with their own icon (as in DefinitionNotebookClient's fileFormat) *)
$iconExtensions = Association @ Flatten @ {
    Thread[ { "wl", "m", "wls", "wlt", "mt", "wxf", "wdx", "wlnet" } -> "WL" ],
    "mx"  -> "MX",
    "nb"  -> "NB",
    "cdf" -> "CDF",
    Thread[ { "txt", "text", "md", "c", "cpp", "h", "hpp", "sh" } -> "TXT" ],
    "js"  -> "JS",
    "css" -> "CSS",
    Thread[ { "html", "htm" } -> "HTML" ],
    "xml" -> "XML",
    "svg" -> "SVG",
    Thread[ { "png", "apng" } -> "PNG" ],
    Thread[ { "jpg", "jpeg", "jfif" } -> "JPEG" ],
    "gif" -> "GIF",
    "bmp" -> "BMP",
    Thread[ { "tif", "tiff" } -> "TIFF" ]
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFileIcon*)

(* acpFileIcon[path] gives the icon boxes (a GraphicsBox) for a path; acpFileIcon[{name}] for an icon name. *)
acpFileIcon // beginDefinition;

acpFileIcon[ path_String ] := acpFileIcon @ { acpFileIconName @ path };

acpFileIcon[ { name_String } ] := Lookup[ $fileIconCache, name, $fileIconCache[ name ] = makeFileIcon @ name ];

acpFileIcon // endDefinition;

If[ ! AssociationQ @ $fileIconCache, $fileIconCache = <| |> ];


(* Boxes of the review notebook that use the icon's TemplateBox style (see reviewStyleSheet) *)
reviewIcon // beginDefinition;
reviewIcon[ name_String ] := RawBoxes @ TemplateBox[ { }, "ACPReviewIcon" <> name ];
reviewIcon // endDefinition;


makeFileIcon // beginDefinition;

makeFileIcon[ name_String ] := Module[ { icons, label },
    icons = $fileManagerIcons;
    Which[
        AssociationQ @ icons && MatchQ[ icons[ name ], _GraphicsBox ],
            resizeIcon @ darkModeIcon @ icons[ name ],
        StringStartsQ[ name, "Ext" ],
            label = StringDrop[ name, 3 ];
            resizeIcon @ darkModeIcon @ pageIcon[ pagePrimitives @ icons, If[ label === "File", None, label ] ],
        name === "Directory" || name === "EmptyDirectory",
            resizeIcon @ darkModeIcon @ $drawnFolder,
        True,
            (* No icon resources: a page with the name as its label *)
            resizeIcon @ darkModeIcon @ pageIcon[ $drawnPage, If[ StringLength @ name <= $reviewMaxIconLabel, name, None ] ]
    ]
];

makeFileIcon // endDefinition;


(* DefinitionNotebookClient's icons (an association of 20x20 GraphicsBoxes), or None. Loaded once per session. *)
$fileManagerIcons := $fileManagerIcons = loadFileManagerIcons[ ];

loadFileManagerIcons // beginDefinition;

loadFileManagerIcons[ ] := Module[ { file, icons },
    file = Quiet @ Replace[
        PacletFind[ "DefinitionNotebookClient" ],
        { { paclet_PacletObject, ___ } :> paclet[ "AssetLocation", "FileManagerIcons" ], _ -> None }
    ];
    icons = If[ StringQ @ file && TrueQ @ Quiet @ FileExistsQ @ file,
        Quiet @ Check[ Developer`ReadWXFFile @ file, $Failed ],
        $Failed
    ];
    If[ AssociationQ @ icons && AllTrue[ icons, MatchQ[ _GraphicsBox ] ], icons, None ]
];

loadFileManagerIcons // endDefinition;


(* The page of the resource icons (outline, page and folded corner: every primitive of the "JS" icon but its label), or
   a drawn one *)
pagePrimitives // beginDefinition;

pagePrimitives[ icons_Association ] := Replace[
    icons[ "JS" ],
    {
        GraphicsBox[ { _Thickness, page: Repeated[ _StyleBox, { 4 } ], _StyleBox }, ___ ] :> { page },
        _ :> $drawnPage
    }
];

pagePrimitives[ _ ] := $drawnPage;

pagePrimitives // endDefinition;


$drawnPage = {
    StyleBox[ FilledCurveBox @ { { { 3., 2. }, { 18., 2. }, { 18., 14. }, { 13., 19. }, { 3., 19. } } }, FaceForm @ GrayLevel[ 0.65098 ] ],
    StyleBox[ FilledCurveBox @ { { { 4., 3. }, { 17., 3. }, { 17., 13.6 }, { 12.6, 18. }, { 4., 18. } } }, FaceForm @ GrayLevel[ 1. ] ],
    StyleBox[ FilledCurveBox @ { { { 13., 19. }, { 13., 14. }, { 18., 14. } } }, FaceForm @ GrayLevel[ 0.65098 ] ]
};

$drawnFolder = GraphicsBox[
    {
        StyleBox[ FilledCurveBox @ { { { 2., 4. }, { 18., 4. }, { 18., 15. }, { 9., 15. }, { 7.5, 17. }, { 2., 17. } } }, FaceForm @ GrayLevel[ 0.65098 ] ],
        StyleBox[ FilledCurveBox @ { { { 3., 5. }, { 17., 5. }, { 17., 13. }, { 3., 13. } } }, FaceForm @ GrayLevel[ 0.898039 ] ]
    },
    PlotRange -> { { 0., 20. }, { 0., 20. } }, AspectRatio -> Automatic
];


(* A page (primitives in 20x20 coordinates) with a label in the label color of the resource icons, at the place of
   their labels (GraphicsBox and InsetBox hold their arguments, hence the With) *)
pageIcon // beginDefinition;

pageIcon[ page_List, None ] := With[ { prims = Prepend[ page, Thickness[ 0.05 ] ] },
    GraphicsBox[ prims, PlotRange -> { { 0., 20. }, { 0., 20. } }, AspectRatio -> Automatic ]
];

pageIcon[ page_List, label_String ] := With[
    {
        text = StyleBox[
            label,
            FontFamily -> $reviewTextFont,
            FontSize   -> If[ StringLength @ label > 3, 4.2, 5.5 ],
            FontWeight -> Bold,
            FontColor  -> $reviewIconLabelColor
        ]
    },
    pageIcon[ page, None ] /. GraphicsBox[ { prims___ }, opts___ ] :> GraphicsBox[ { prims, InsetBox[ text, { 10.5, 6. } ] }, opts ]
];

pageIcon // endDefinition;


(* The white page of the icons is a dark gray page in dark mode *)
darkModeIcon // beginDefinition;
darkModeIcon[ box_GraphicsBox ] := box /. FaceForm[ GrayLevel[ g_? (# >= 0.99 &) ] ] :> FaceForm @ LightDarkSwitched[ GrayLevel[ g ], GrayLevel[ 0.22 ] ];
darkModeIcon // endDefinition;


resizeIcon // beginDefinition;

resizeIcon[ GraphicsBox[ prims_, opts___ ] ] := With[
    {
        size  = { $reviewIconSize, $reviewIconSize },
        other = Sequence @@ FilterRules[ { opts }, Except[ ImageSize | BaselinePosition ] ]
    },
    GraphicsBox[ prims, ImageSize -> size, BaselinePosition -> Scaled[ 0.15 ], other ]
];

resizeIcon // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
