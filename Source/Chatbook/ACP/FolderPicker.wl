(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`FolderPicker`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* The remote folder picker (see docs/acp-window.md): a remote window ("SSHSettings") chooses its project folder on the
   remote machine in this window, which lists folders there over ssh. One picker per ACP window: a deployed notebook
   over the ACP window, found by its TaggingRules ({"ACPFolderPicker", "Owner"}), with one docked cell (title, Cancel and
   Choose, the host and "Show hidden", the path row with Up, Home, the path field, Go and Refresh, and the status line)
   and one list cell (the folders, then the files).

   Every listing is one ssh connection (Remote.wl's acpRemoteRun, list.sh's cb_ls); entering, Up, Home, Go and Refresh
   start a new one, debounced. How this follows the runtime rules (R1-R8 in docs/acp-window.md, "Threading rules"):
   * Nothing blocks (R1): clicks only change the store and schedule the listing (acpSchedule); ssh runs in the runner,
     polled by the pump; its result is applied by the runner's continuation in the pump (acpFolderPickerOnResult), which
     may write to the front end (it is not a reader handler, R2).
   * The picker's state is the window record's "FolderPicker" store, changed with acpWindowUpdate (R4). Housekeeping
     ("ACPFolderPicker") ends a listing whose continuation was lost (R5); the pump keeps running while a picker lists
     (State.wl's publisherNeededQ).
   * The path field is an InputField bound to the picker's TaggingRules in the front end (no kernel call per keystroke)
     and never inside a Dynamic that re-renders; the status, the buttons and the list are derived views that re-render
     only when the part of the store they show changes (R6). The typed text and the listed path are in the TaggingRules,
     so the picker is rebuilt after a kernel restart (acpFolderPickerRecover, R8).
   * Remote text (names, paths, the home folder, ssh's errors) reaches boxes only through acpRemoteDisplayName or
     acpErrorView, is never interpreted (no ToExpression), and buttons name folders by a hashed key, never by name. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpFolderPickerTimeout    = 30;                                (* seconds of one listing *)
$acpFolderPickerDebounce   = Quantity[ 150, "Milliseconds" ];   (* navigation listings start this long after the click *)
$acpFolderPickerPageSize   = 50;                                (* folders shown at first, and more per "Show more" *)
$acpFolderPickerFilesShown = 20;                                (* other entries shown *)
$acpFolderPickerMaxOutput  = 2^21;                              (* bytes of a listing's output (the frame cap is 1 MB) *)

(* The picker window's size at magnification 0.85 *)
$acpFolderPickerWidth  := $acpFolderPickerWidth  = Switch[ $OperatingSystem, "MacOSX", 520, _, 440 ];
$acpFolderPickerHeight := $acpFolderPickerHeight = Switch[ $OperatingSystem, "MacOSX", 600, _, 560 ];

$pickerHousekeepingTicks = 5;   (* 1 s *)
$pickerLostGrace         = 15;  (* seconds after a listing's longest legitimate run (pickerLostAfter) until it counts as lost *)
$pickerNameLength        = 60;  (* characters of a name shown in a row (the tooltip has all) *)
$pickerRowIndent         = 8;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English defaults for the strings of this file (see acpLabel in Transcript.wl). Every key must also be in the .tr
   files as "ACP" <> key (checked by Tests/ACPWindow.wlt). *)
$acpFolderPickerStrings = <|
    "FolderPickerWindowTitle"      -> "Choose a project folder on `host`",
    "FolderPickerTitle"            -> "Choose a project folder",
    "FolderPickerHost"             -> "on `host`",
    "FolderPickerPathHint"         -> "Folder path, e.g. ~/projects/app",
    "FolderPickerUp"               -> "Up one folder",
    "FolderPickerHome"             -> "Your home folder on `host`",
    "FolderPickerGo"               -> "Open this path",
    "FolderPickerRefresh"          -> "List the folder again",
    "FolderPickerShowHidden"       -> "Show hidden",
    "FolderPickerChoose"           -> "Choose",
    "FolderPickerChooseTooltip"    -> "Use `path` as the project folder",
    "FolderPickerCancel"           -> "Cancel",
    "FolderPickerConnecting"       -> "Connecting to `host`\[Ellipsis]",
    "FolderPickerLoading"          -> "Listing `path`\[Ellipsis]",
    "FolderPickerCurrent"          -> "Current folder",
    "FolderPickerRealPath"         -> "Link to `path`",
    "FolderPickerEmpty"            -> "This folder is empty.",
    "FolderPickerNoFolders"        -> "No folders in this folder.",
    "FolderPickerHiddenOnly"       -> "This folder has only hidden items.",
    "FolderPickerShowMore"         -> "Show `n` more folders",
    "FolderPickerShowMoreOne"      -> "Show `n` more folder",
    "FolderPickerMoreFiles"        -> "and `n` more files",
    "FolderPickerMoreFilesOne"     -> "and `n` more file",
    "FolderPickerSummary"          -> "`folders`, `files`",
    "FolderPickerFolderCount"      -> "`n` folders",
    "FolderPickerFolderCountOne"   -> "`n` folder",
    "FolderPickerFileCount"        -> "`n` files",
    "FolderPickerFileCountOne"     -> "`n` file",
    "FolderPickerListedTooltip"    -> "The folder shown: `path`",
    "FolderPickerTooManyFolders"   -> "Only the first `n` folders are listed. Type a path to open another one.",
    "FolderPickerTooManyFiles"     -> "This folder has more than `n` other items.",
    "FolderPickerLocked"           -> "You don't have permission to open this folder.",
    "FolderPickerLink"             -> "Symbolic link",
    "FolderPickerBrokenLink"       -> "Broken symbolic link",
    "FolderPickerUnusableName"     -> "This name is not valid UTF-8 text, so it can't be used in a path.",
    "FolderPickerUnreadable"       -> "You can open this folder but not list its contents.",
    "FolderPickerUnlisted"         -> "This folder can't be read over SSH (on a Mac, privacy settings may block it).",
    "FolderPickerFallback"         -> "`requested` doesn't exist anymore; showing `shown`.",
    "FolderPickerErrorMissing"     -> "The folder `path` doesn't exist.",
    "FolderPickerErrorNotFolder"   -> "`path` is not a folder.",
    "FolderPickerErrorNoAccess"    -> "You don't have permission to open `path`.",
    "FolderPickerErrorBadPath"     -> "Enter a path that starts with / or ~/.",
    "FolderPickerErrorTilde"       -> "Only ~ and ~/\[Ellipsis] are supported, not ~user.",
    "FolderPickerErrorTimeout"     -> "Listing the folder on `host` took too long.",
    "FolderPickerErrorFailed"      -> "The folder could not be listed on `host`.",
    "FolderPickerErrorTmp"         -> "The folder could not be listed: `host` has no writable temporary folder (TMPDIR or /tmp).",
    "FolderPickerRetry"            -> "Try again",
    "FolderPickerCopyError"        -> "Copy",
    "FolderPickerCopyErrorTooltip" -> "Copy the advice and the text of ssh",
    "FolderPickerCopyCommand"      -> "Copy command",
    "FolderPickerCopyCommandTooltip" -> "Copy the ssh command to run in a terminal",
    "FolderPickerChooseControl"    -> "A folder whose path contains line breaks or other control characters can't be a project folder.",
    "FolderPickerChooseUnreadable" -> "The agent can't work in a folder it can't list.",
    "FolderPickerChooseWait"       -> "Wait until the folder is listed."
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Store*)

(* The window record's "FolderPicker" key: None, or while a picker is open (acpFolderPickerOf fills in the defaults):
     "Open"          -> True
     "Notebook"      -> the picker window (None without a front end)
     "SSH", "HostKey"-> the canonical SSH settings of the last listing (each listing takes the window's current ones)
                        and the host key the picker lists on (a host change closes the picker)
     "Status"        -> "Loading" (a listing runs) | "Ready" (a listing is shown) | "Error" (nothing listed, an error)
     "Request"       -> the running request: <| "Token", "Path", "Base", "Kind" -> "Open" | "Enter" | "Up" | "Home" | "Go" |
                        "Refresh", "StartedAt", "Fallback", "Automatic" |>, or None; "LastRequest": the last one
     "Path"          -> the listed folder (the logical path, $PWD after cd -L) | None; "RealPath": its pwd -P
     "Home"          -> the remote home folder (from the listing, else the window's) | None
     "Entries"       -> the listed entries (acpRemoteListingParse's, plus "Key"), folders first, in natural order
     "Counts", "Capped", "Warning", "ListingStatus" -> the listing's
     "Notice"        -> the fallback notice | None
     "Error"         -> None | <| "Code", "Message", ... |>: a navigation error (the previous listing stays), the picker's own
                        error ("Source" -> "FolderPicker"), or the error info of a failed ssh run (Remote.wl)
     "ShowHidden"    -> whether hidden entries are shown (persisted, {"FolderPickerShowHidden"})
     "Shown"         -> how many folders are shown
     "InputShown"    -> the path field's text as the last listing set it (Go with that text lists the path again)
     "Version"       -> counts the listings (the list view's signature)
     "Automatic"     -> True if Chatbook opened the picker by itself (its first listing respects the host latch) *)
$pickerDefaults = <|
    "Open"          -> False,
    "Notebook"      -> None,
    "SSH"           -> None,
    "HostKey"       -> None,
    "Status"        -> "Loading",
    "Request"       -> None,
    "LastRequest"   -> None,
    "Path"          -> None,
    "RealPath"      -> None,
    "Home"          -> None,
    "Entries"       -> { },
    "Counts"        -> None,
    "Capped"        -> <| "Folders" -> None, "Files" -> None |>,
    "Warning"       -> None,
    "ListingStatus" -> None,
    "Notice"        -> None,
    "Error"         -> None,
    "ShowHidden"    -> False,
    "Shown"         -> $acpFolderPickerPageSize,
    "InputShown"    -> "",
    "Version"       -> 0,
    "Automatic"     -> False
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerOf*)

(* The picker store of a window record (with the defaults filled in), or None if no picker is open *)
acpFolderPickerOf // beginDefinition;
acpFolderPickerOf[ window_Association ] := Replace[ Lookup[ window, "FolderPicker", None ], { s_Association :> Join[ $pickerDefaults, s ], _ -> None } ];
acpFolderPickerOf[ nbo_NotebookObject ] := acpFolderPickerOf @ acpWindowGet @ nbo;
acpFolderPickerOf[ _ ] := None;
acpFolderPickerOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pickerUpdate*)

(* Applies f[store, window] to the store of an existing window record with an open picker; f gives the new store.
   Anything else leaves the record unchanged. *)
pickerUpdate // beginDefinition;

pickerUpdate[ owner_NotebookObject, f_ ] := acpWindowUpdate[
    owner,
    Function[ w,
        If[ KeyExistsQ[ w, "Status" ] && AssociationQ @ Lookup[ w, "FolderPicker", None ],
            With[ { new = f[ acpFolderPickerOf @ w, w ] }, If[ AssociationQ @ new, <| w, "FolderPicker" -> new |>, Missing[ "Unchanged" ] ] ],
            Missing[ "NotFound" ]
        ]
    ]
];

pickerUpdate // endDefinition;


(* pickerUpdate for the result of one request: only while token is the store's running request *)
pickerUpdateRequest // beginDefinition;

pickerUpdateRequest[ owner_NotebookObject, token_String, f_ ] :=
    pickerUpdate[ owner, If[ requestTokenQ[ #1, token ], f[ #1, #2 ], Missing[ "Stale" ] ] & ];

pickerUpdateRequest // endDefinition;


requestTokenQ // beginDefinition;
requestTokenQ[ store_Association, token_ ] := Lookup[ Replace[ store[ "Request" ], Except[ _Association ] -> <| |> ], "Token", None ] === token;
requestTokenQ[ _, _ ] := False;
requestTokenQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pickerInitStore*)

(* A new store for a picker of the window (open, nothing listed yet). The preference is read first: the update function
   runs inside PreemptProtect and makes no front end calls. *)
pickerInitStore // beginDefinition;

pickerInitStore[ owner_NotebookObject, ssh_Association, notebook_, automatic_ ] := With[
    { showHidden = TrueQ @ acpPersistedSetting[ { "FolderPickerShowHidden" }, False ], key = acpSSHHostKey @ ssh },
    acpWindowUpdate[
        owner,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ],
                <|
                    w,
                    "FolderPicker" -> <|
                        $pickerDefaults,
                        "Open"       -> True,
                        "Notebook"   -> notebook,
                        "SSH"        -> ssh,
                        "HostKey"    -> key,
                        "Home"       -> acpWindowRemoteHome @ w,
                        "ShowHidden" -> showHidden,
                        "Automatic"  -> TrueQ @ automatic
                    |>
                |>,
                Missing[ "NotFound" ]
            ]
        ]
    ]
];

pickerInitStore // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerWindowOf*)
acpFolderPickerWindowOf // beginDefinition;

acpFolderPickerWindowOf[ owner_NotebookObject ] := If[ $FrontEnd === Null,
    None,
    SelectFirst[
        Replace[ Notebooks[ ], Except[ _List ] -> { } ],
        Quiet @ CurrentValue[ #, { TaggingRules, "ACPFolderPicker", "Owner" } ] === owner &,
        None
    ]
];

acpFolderPickerWindowOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerOpen*)

(* A click on the folder of a remote window's toolbar ("Choose folder..." without one; UI.wl's "ChooseDirectory" action),
   or Chatbook by itself for a new remote window without a folder ("Automatic" -> True, acpFolderPickerAutoOpen). An open picker is raised. A user open
   clears the host's failure latch (Remote.wl); an automatic one does nothing while the host is latched, while the
   window shows an error (the toolbar shows it already) or once the window has a folder. The first listing starts at the
   window's folder, else the host's last folder, else the home folder, and lists the nearest folder above it that can be
   opened if it can't be (fallback). Gives the picker window ("Opened" without a front end), "Raised", or a Missing. *)
acpFolderPickerOpen // beginDefinition;

acpFolderPickerOpen[ owner_NotebookObject, opts: (_Rule | _RuleDelayed)... ] := Catch @ Module[
    { automatic, window, ssh, key, existing, store, notebook },

    automatic = TrueQ @ Lookup[ { opts }, "Automatic", False ];
    acpCheckSession @ owner;
    window = acpEnsureWindowRecord @ owner;
    If[ ! AssociationQ @ window, Throw @ Missing[ "NotFound" ] ];
    ssh = acpWindowSSH @ window;
    If[ ! AssociationQ @ ssh, Throw @ Missing[ "NotRemote" ] ];
    key = acpSSHHostKey @ ssh;

    If[ automatic,
        Which[
            acpRemoteHostLatchedQ @ key, Throw @ Missing[ "Latched" ],
            Lookup[ window, "Status" ] === "Error", Throw @ Missing[ "Error" ],
            StringQ @ Lookup[ window, "ProjectDirectory", None ], Throw @ Missing[ "HasDirectory" ]
        ],
        acpRemoteClearHostError @ key
    ];

    (* An open picker is raised (after a kernel restart it gets its store back first) *)
    store    = acpFolderPickerOf @ window;
    existing = acpFolderPickerWindowOf @ owner;
    If[ MatchQ[ existing, _NotebookObject ],
        If[ ! AssociationQ @ store || store[ "HostKey" ] =!= key, acpFolderPickerRecover @ owner ];
        existing = acpFolderPickerWindowOf @ owner;
        If[ MatchQ[ existing, _NotebookObject ], pickerRaise @ existing; Throw @ "Raised" ]
    ];
    If[ $FrontEnd === Null && AssociationQ @ store && store[ "HostKey" ] === key, Throw @ "Raised" ];

    pickerInitStore[ owner, ssh, None, automatic ];
    notebook = pickerShowWindow[ owner, ssh ];
    If[ MatchQ[ notebook, _NotebookObject ], pickerUpdate[ owner, <| #1, "Notebook" -> notebook |> & ] ];
    pickerStart[ owner, pickerStartPath[ window, ssh ], None, "Open", True, automatic ];
    acpPublish[ ];
    If[ MatchQ[ notebook, _NotebookObject ], notebook, "Opened" ]
];

acpFolderPickerOpen // endDefinition;


(* Where the first listing starts: the window's folder, else the host's last folder, else the home folder *)
pickerStartPath // beginDefinition;

pickerStartPath[ window_Association, ssh_ ] := FirstCase[
    {
        Lookup[ window, "ProjectDirectory", None ],
        Replace[ acpLastProjectDirectoryKey @ ssh, { key_List :> acpPersistedSetting[ key, None ], _ -> None } ]
    },
    _String? acpRemoteProjectDirectoryQ,
    "~"
];

pickerStartPath // endDefinition;


(* The picker window (front end calls, as the Sessions window's): the change symbols its views track are created first
   (a symbol first made while the front end evaluates a Dynamic would not be tracked) *)
pickerShowWindow // beginDefinition;

pickerShowWindow[ owner_NotebookObject, ssh_Association ] := If[ $FrontEnd === Null,
    None,
    Module[ { notebook },
        pickerEnsureSymbols @ owner;
        acpFileIcon @ { "Directory" }; (* loads the icons once, here rather than in the view's first rendering *)
        notebook = NotebookPut @ acpFolderPickerNotebook[ owner, acpFolderPickerGeometry @ owner, ssh ];
        If[ MatchQ[ notebook, _NotebookObject ],
            sessionsMoveToActiveDesktop @ notebook;
            Quiet @ SetSelectedNotebook @ notebook;
            Quiet @ FrontEnd`MoveCursorToInputField[ notebook, "ACPFolderPickerPath" ]
        ];
        notebook
    ]
];

pickerShowWindow // endDefinition;


pickerRaise // beginDefinition;

pickerRaise[ picker_NotebookObject ] := (
    sessionsMoveToActiveDesktop @ picker;
    Quiet @ SetSelectedNotebook @ picker;
    Null
);

pickerRaise // endDefinition;


(* The change symbols of the picker's views *)
$pickerViewNames = { "FolderPickerStatus", "FolderPickerButtons", "FolderPickerList" };

pickerEnsureSymbols // beginDefinition;

pickerEnsureSymbols[ owner_NotebookObject ] := (
    acpWindowSymbol @ owner;
    Scan[ acpEntitySymbol[ acpWindowKey @ owner, # ] &, $pickerViewNames ];
    Null
);

pickerEnsureSymbols // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerAutoOpen*)

(* A remote window without a folder can do nothing: its picker opens by itself, once (scheduled), after the window was
   created (UI.wl's acpCreateWindow) and after a host switch that left it without a folder (acpReuseWindow). Not after a
   rebuild (kernel restart). Gives True if the open was scheduled. *)
acpFolderPickerAutoOpen // beginDefinition;

acpFolderPickerAutoOpen[ owner_NotebookObject ] := With[ { window = acpWindowGet @ owner },
    If[ AssociationQ @ window && AssociationQ @ acpWindowSSH @ window && ! StringQ @ Lookup[ window, "ProjectDirectory", None ],
        acpSchedule @ acpFolderPickerOpen[ owner, "Automatic" -> True ];
        True,
        False
    ]
];

acpFolderPickerAutoOpen // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerCloseWindow*)

(* Closes the picker of the ACP window (Choose, Cancel, a host switch, the ACP window closed): the window, the store, and
   the running listing (a fresh request token: the runner ends it at its next poll). Closing from the kernel does not run
   the picker's "WindowClose" event, so the store is told here. *)
acpFolderPickerCloseWindow // beginDefinition;

acpFolderPickerCloseWindow[ owner_NotebookObject ] := With[ { picker = acpFolderPickerWindowOf @ owner },
    If[ MatchQ[ picker, _NotebookObject ], Quiet @ NotebookClose @ picker ];
    pickerClosed @ owner
];

acpFolderPickerCloseWindow // endDefinition;


(* The picker is gone: no store, and no current request *)
pickerClosed // beginDefinition;

pickerClosed[ owner_NotebookObject ] := (
    acpSetCurrentRequest[ { "FolderPicker", owner }, CreateUUID[ "fp-closed-" ] ];
    acpWindowUpdate[
        owner,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ] && Lookup[ w, "FolderPicker", None ] =!= None,
                <| w, "FolderPicker" -> None |>,
                Missing[ "Unchanged" ]
            ]
        ]
    ];
    Null
);

pickerClosed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerRecover*)

(* After a kernel restart (scheduled by UI.wl's acpRefreshWindowUI, and on a click into the picker): the picker window
   survived, its store did not. A picker of another host (or of a window that is no longer remote) is closed; otherwise
   the store is made again (from the picker's TaggingRules and the preferences), the docked cell and the list cell are
   replaced (their views tracked symbols of the old kernel), and the listed folder is listed again (with fallback).
   Gives "Recovered", "Closed", or None (no picker, or already recovered). *)
acpFolderPickerRecover // beginDefinition;

acpFolderPickerRecover[ owner_NotebookObject ] := Catch @ Module[ { picker, window, ssh, store, path },
    picker = acpFolderPickerWindowOf @ owner;
    If[ ! MatchQ[ picker, _NotebookObject ], Throw @ None ];
    window = acpEnsureWindowRecord @ owner;
    ssh    = acpWindowSSH @ window;
    If[ ! AssociationQ @ ssh || acpSSHHostKey @ ssh =!= Quiet @ CurrentValue[ picker, { TaggingRules, "ACPFolderPicker", "HostKey" } ],
        Quiet @ NotebookClose @ picker;
        pickerClosed @ owner;
        Throw @ "Closed"
    ];
    store = acpFolderPickerOf @ window;
    If[ AssociationQ @ store && store[ "Notebook" ] === picker, Throw @ None ];

    path = Replace[
        Quiet @ CurrentValue[ picker, { TaggingRules, "ACPFolderPicker", "Path" } ],
        Except[ _String? pickerPathQ ] :> pickerStartPath[ window, ssh ]
    ];
    pickerInitStore[ owner, ssh, picker, True ];
    pickerEnsureSymbols @ owner;
    Quiet @ SetOptions[ picker, DockedCells -> { pickerDockedCell[ owner, ssh ] } ];
    pickerReplaceListCell[ picker, owner ];
    pickerStart[ owner, path, None, "Refresh", True, True ];
    "Recovered"
];

acpFolderPickerRecover // endDefinition;


pickerReplaceListCell // beginDefinition;

pickerReplaceListCell[ picker_NotebookObject, owner_NotebookObject ] := Module[ { old },
    old = Replace[ Quiet @ Cells[ picker, CellTags -> "ACPFolderPickerList" ], Except[ _List ] -> { } ];
    If[ MatchQ[ old, { __CellObject } ],
        contextBlock @ NotebookWrite[ First @ old, pickerListCell @ owner, None, AutoScroll -> False ];
        If[ Length @ old > 1, NotebookDelete @ Rest @ old ]
    ];
    Null
];

pickerReplaceListCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Placement*)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpFolderPickerPlacement*)

(* Where the picker goes (pure), like an OS folder dialog over its parent window: centered on the ACP window and kept on
   the display, 40 points below the ACP window's top (its title stays visible), at most as tall as the ACP window
   leaves room for (at least 300 points). owner: the ACP window's geometry (acpOwnerGeometry: "Left", "Width", "Top",
   "Height" in WindowMargins coordinates); display: { xmin, xmax }; size: the picker's { width, height }. Without a
   usable geometry the front end places it (WindowMargins -> Automatic). *)
acpFolderPickerPlacement // beginDefinition;

acpFolderPickerPlacement[ owner_Association, { xmin_? NumberQ, xmax_? NumberQ }, { w_? NumberQ, h_ } ] := Module[
    { l, ow, t, oh },
    { l, ow, t, oh } = Lookup[ owner, { "Left", "Width", "Top", "Height" }, None ];
    If[ ! AllTrue[ { l, ow, t }, NumberQ ], Return[ defaultPlacement @ { w, h }, Module ] ];
    <|
        "WindowMargins" -> { { Clip[ Round[ l + (ow - w) / 2 ], { xmin, Max[ xmin, xmax - w ] } ], Automatic }, { Automatic, t + 40 } },
        "WindowSize"    -> { w, If[ NumberQ @ oh && NumberQ @ h, Min[ h, Max[ 300, oh - 40 ] ], h ] }
    |>
];

acpFolderPickerPlacement[ _, _, size_ ] := defaultPlacement @ size;

acpFolderPickerPlacement // endDefinition;


defaultPlacement // beginDefinition;
defaultPlacement[ { w_, h_ } ] := <| "WindowMargins" -> Automatic, "WindowSize" -> { w, h } |>;
defaultPlacement[ _ ] := <| "WindowMargins" -> Automatic, "WindowSize" -> { $acpFolderPickerWidth, $acpFolderPickerHeight } |>;
defaultPlacement // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpFolderPickerGeometry*)

(* The placement of a new picker over the ACP window (front end calls in acpOwnerGeometry, Sessions.wl), plus the
   "Magnification" of the ACP window; the size scales with it like the Sessions window's *)
acpFolderPickerGeometry // beginDefinition;

acpFolderPickerGeometry[ owner_NotebookObject ] := Module[ { geometry, mag },
    geometry = acpOwnerGeometry @ owner;
    mag      = Replace[ Lookup[ geometry, "Magnification", 0.85 ], Except[ _? NumberQ ] -> 0.85 ];
    Append[
        acpFolderPickerPlacement[
            geometry,
            Lookup[ geometry, "Display", None ],
            Ceiling[ { $acpFolderPickerWidth, $acpFolderPickerHeight } * mag / 0.85 ]
        ],
        "Magnification" -> mag
    ]
];

acpFolderPickerGeometry // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerNotebook*)

(* The picker window (pure): the docked cell and the list cell; the options of the Sessions window (a deployed window
   that is never saved, excluded from the Notebook Assistant's notebook context, with the ACP window's kernel), plus the
   owner and the host key in the TaggingRules (found again after a kernel restart), the path field's text ("Input", bound
   to the field in the front end) and the listed folder ("Path"). The notebook is not selectable, the docked cell is (its
   path field takes typing). geometry: acpFolderPickerGeometry. *)
acpFolderPickerNotebook // beginDefinition;

acpFolderPickerNotebook[ owner_NotebookObject, geometry_Association, ssh_Association ] := Notebook[
    { pickerListCell @ owner },
    Sequence @@ {
        If[ MatchQ[ geometry[ "WindowMargins" ], { { _, _ }, { _, _ } } ], WindowMargins -> geometry[ "WindowMargins" ], Nothing ],
        WindowSize              -> Replace[ geometry[ "WindowSize" ], Except[ { _, _ } ] -> { $acpFolderPickerWidth, $acpFolderPickerHeight } ],
        Magnification           -> Replace[ geometry[ "Magnification" ], Except[ _? NumberQ ] -> 0.85 ],
        WindowTitle             -> acpLabel[ "FolderPickerWindowTitle", <| "host" -> acpRemoteDisplayName @ pickerText @ acpSSHShortHost @ ssh |> ],
        Evaluator               -> sessionsEvaluator @ owner,
        TaggingRules            -> <|
            "ACPFolderPicker"      -> <| "Owner" -> owner, "HostKey" -> acpSSHHostKey @ ssh, "Input" -> "", "Path" -> None |>,
            "ChatNotebookSettings" -> <| "ExcludeFromChat" -> True |>
        |>,
        Background              -> $sessionsBackground,
        DockedCells             -> { pickerDockedCell[ owner, ssh ] },
        CellInsertionPointCell  -> None,
        CellInsertionPointColor -> $sessionsBackground,
        ClosingAutoSave         -> False,
        "ClosingSaveDialog"     -> False,
        Deployed                -> True,
        Editable                -> False,
        NotebookEventActions    -> pickerEventActions @ owner,
        Saveable                -> False,
        Selectable              -> False,
        ShowCellBracket         -> False,
        StyleDefinitions        -> "Default.nb",
        WindowElements          -> { "VerticalScrollBar" },
        WindowFrameElements     -> { "CloseBox", "ResizeArea" },
        WindowToolbars          -> { }
    }
];

acpFolderPickerNotebook // endDefinition;


(* Escape cancels; closing the window tells the store *)
pickerEventActions // beginDefinition;

pickerEventActions[ owner_NotebookObject ] := Replace[
    { acpActionCode[ "FolderPickerClosed", owner ], acpActionCode[ "FolderPickerCancel", owner ] },
    { Hold[ closed_ ], Hold[ cancel_ ] } :> { ParentList, "WindowClose" :> closed, "EscapeKeyDown" :> cancel }
];

pickerEventActions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pickerDockedCell*)

(* Title with Cancel and Choose, the host with "Show hidden", the path row (Up, Home, the path field, Go, Refresh) and the
   status line, which has the header's whole width (a tall error then leaves no empty column beside it). Only the
   buttons and the status line re-render (derived views); the path field never does. Lines wrap at the window's width:
   a docked cell gets LineBreakWithin -> False from the "DockedCell" style, which would let a long message or path (an
   ssh error, the fallback notice) widen the header past the window and push the buttons out of it. Wrapped lines start
   at the left edge (LineIndent -> 0). *)
pickerDockedCell // beginDefinition;

pickerDockedCell[ owner_NotebookObject, ssh_Association ] := Cell[
    BoxData @ pickerBoxes @ Column[
        {
            Grid[
                { {
                    Style[ acpLabel[ "FolderPickerTitle" ], FontSize -> 14, FontWeight -> "DemiBold", FontColor -> $sessionsFont ],
                    Item[ "", ItemSize -> Fit ],
                    pickerDynamic[ owner, "FolderPickerButtons", pickerButtonsSignature, pickerButtonsView ]
                } },
                Alignment -> { Left, Center },
                Spacings  -> { 0, 0 }
            ],
            Grid[
                { {
                    Style[
                        acpLabel[ "FolderPickerHost", <| "host" -> acpRemoteDisplayName @ pickerText @ acpSSHHostLabel @ ssh |> ],
                        FontSize  -> 12,
                        FontColor -> $sessionsMuted
                    ],
                    Item[ "", ItemSize -> Fit ],
                    pickerViewDynamic[ owner, "FolderPickerButtons", pickerToggleView ]
                } },
                Alignment -> { Left, Center },
                Spacings  -> { 0.5, 0 }
            ],
            Grid[
                { {
                    pickerIconButton[ $pickerUpIcon, acpLabel[ "FolderPickerUp" ], { "FolderPickerUp", owner }, "ACPFolderPickerUp" ],
                    pickerIconButton[
                        $pickerHomeIcon,
                        acpLabel[ "FolderPickerHome", <| "host" -> acpRemoteDisplayName @ pickerText @ acpSSHShortHost @ ssh |> ],
                        { "FolderPickerHome", owner },
                        "ACPFolderPickerHome"
                    ],
                    Item[ pickerPathField @ owner, ItemSize -> Fit ],
                    pickerGoButton @ owner,
                    pickerIconButton[ $sessionsRefreshIcon, acpLabel[ "FolderPickerRefresh" ], { "FolderPickerRefresh", owner }, "ACPFolderPickerRefresh" ]
                } },
                Alignment -> { Left, Center },
                Spacings  -> { 0.25, 0 }
            ],
            pickerDynamic[ owner, "FolderPickerStatus", pickerStatusSignature, pickerStatusView ]
        },
        Alignment -> Left,
        Spacings  -> 0.5
    ],
    Background           -> $sessionsHeader,
    CellFrame            -> { { 0, 0 }, { 1, 0 } },
    CellFrameColor       -> $sessionsDivider,
    CellFrameMargins     -> { { 12, 10 }, { 8, 8 } },
    CellMargins          -> 0,
    CellTags             -> "ACPFolderPickerHeader",
    FontColor            -> $sessionsFont,
    FontFamily           -> "Source Sans Pro",
    FontSize             -> 13,
    LineBreakWithin      -> Automatic,
    LineIndent           -> 0,
    LineSpacing          -> { 1, 0 },
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    Selectable           -> True,
    ShowAutoStyles       -> False,
    ShowCellBracket      -> False,
    ShowStringCharacters -> False
];

pickerDockedCell // endDefinition;


(* The path field: bound to the picker's TaggingRules in the front end (no kernel call per keystroke; the text survives
   kernel restarts). Return is Go, Escape is Cancel. Go is given the picker window, whose field it reads. It stays one
   line (the header wraps lines, a field would grow with a long path), and its hint has no spacing around "/". *)
pickerPathField // beginDefinition;

pickerPathField[ owner_NotebookObject ] := Replace[
    { acpActionCode[ "FolderPickerGo", owner, EvaluationNotebook[ ] ], acpActionCode[ "FolderPickerCancel", owner ] },
    { Hold[ go_ ], Hold[ cancel_ ] } :> EventHandler[
        InputField[
            Dynamic @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACPFolderPicker", "Input" } ],
            String,
            BaseStyle        -> { FontFamily -> "Source Sans Pro", FontSize -> 13, LineBreakWithin -> False, AutoSpacing -> False },
            BoxID            -> "ACPFolderPickerPath",
            ContinuousAction -> True,
            FieldHint        -> acpLabel[ "FolderPickerPathHint" ],
            ImageSize        -> { Full, Automatic }
        ],
        { "ReturnKeyDown" :> go, "EscapeKeyDown" :> cancel },
        PassEventsDown -> True,
        PassEventsUp   -> False
    ]
];

pickerPathField // endDefinition;


pickerGoButton // beginDefinition;

pickerGoButton[ owner_NotebookObject ] := Replace[
    acpActionCode[ "FolderPickerGo", owner, EvaluationNotebook[ ] ],
    Hold[ code_ ] :> Button[
        blueHueButtonAppearance[ Tooltip[ $pickerGoIcon, acpLabel[ "FolderPickerGo" ] ], { Automatic, 24 }, { { 5, 5 }, { 0, 0 } } ],
        code,
        Appearance -> "Suppressed",
        BoxID      -> "ACPFolderPickerGo",
        Method     -> "Preemptive"
    ]
];

pickerGoButton // endDefinition;


pickerIconButton // beginDefinition;

pickerIconButton[ icon_, tooltip_String, { args__ }, boxID_String ] := acpActionButton[
    blueHueButtonAppearance[ Tooltip[ icon, tooltip ], { Automatic, 24 }, { { 5, 5 }, { 0, 0 } } ],
    { args },
    BoxID -> boxID
];

pickerIconButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pickerListCell*)

(* The list: one self-contained cell (as the Sessions window's content cell), tagged so that a recovery can replace it *)
pickerListCell // beginDefinition;

pickerListCell[ owner_NotebookObject ] := Cell[
    BoxData @ pickerBoxes @ pickerDynamic[ owner, "FolderPickerList", pickerListSignature, pickerListView ],
    Background           -> $sessionsBackground,
    CellFrame            -> 0,
    CellFrameMargins     -> 0,
    CellMargins          -> 0,
    CellTags             -> "ACPFolderPickerList",
    Deployed             -> True,
    Editable             -> False,
    FontColor            -> $sessionsFont,
    FontFamily           -> "Source Sans Pro",
    FontSize             -> 13,
    LineSpacing          -> { 1, 0 },
    PrivateFontOptions   -> { "OperatorSubstitution" -> False },
    Selectable           -> False,
    ShowAutoStyles       -> False,
    ShowCellBracket      -> False,
    ShowStringCharacters -> False,
    TaggingRules         -> <| "ACPFolderPicker" -> <| "Owner" -> owner |> |>
];

pickerListCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Listing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerStart*)

(* Lists path (relative paths are relative to base; None: the home folder) in the picker: kind is "Open", "Enter", "Up",
   "Home", "Go" or "Refresh". Kernel only (tests call it without a front end). A ~user path or a path that can't be one
   is a navigation error without a request. Otherwise the request replaces the running one (acpSetCurrentRequest: the
   runner ends a superseded run, draining it if ssh is still signing in), and its listing starts after the debounce
   delay (navigation; the first listing at once), so that clicks in quick succession make one ssh connection. fallback:
   list the nearest folder above path that can be opened if path can't be (the first listing). automatic: Chatbook
   started it (the host latch applies). Gives the request's token, or a Missing. *)
acpFolderPickerStart // beginDefinition;

acpFolderPickerStart[ owner_NotebookObject, path_, base_, kind_String ] :=
    pickerStart[ owner, path, base, kind, kind === "Open", False ];

acpFolderPickerStart // endDefinition;


pickerStart // beginDefinition;

pickerStart[ owner_NotebookObject, path0_, base0_, kind_String, fallback_, automatic_ ] := Catch @ Module[
    { store, path, base, token, request },
    store = acpFolderPickerOf @ acpWindowGet @ owner;
    If[ ! AssociationQ @ store, Throw @ Missing[ "NoPicker" ] ];
    path = Replace[ path0, File[ p_String ] :> p ];
    base = Replace[ base0, Except[ _String? pickerPathQ ] -> None ];
    Which[
        ! StringQ @ path, Throw @ Missing[ "NoPath" ],
        tildeUserQ @ path, Throw @ pickerNavigationError[ owner, pickerError[ "Tilde", path, store ], None ],
        ! pickerPathQ @ path, Throw @ pickerNavigationError[ owner, pickerError[ "BadPath", path, store ], None ]
    ];
    token   = CreateUUID[ "fp-" ];
    request = <|
        "Token"     -> token,
        "Path"      -> path,
        "Base"      -> base,
        "Kind"      -> kind,
        "StartedAt" -> AbsoluteTime[ ],
        "Fallback"  -> TrueQ @ fallback,
        "Automatic" -> TrueQ @ automatic
    |>;
    pickerUpdate[ owner, <| #1, "Request" -> request, "LastRequest" -> request, "Status" -> "Loading", "Error" -> None, "Notice" -> None |> & ];
    acpSetCurrentRequest[ { "FolderPicker", owner }, token ];
    With[ { t = token },
        If[ kind === "Open",
            acpSchedule @ pickerRun[ owner, t ],
            acpSchedule[ pickerRun[ owner, t ], $acpFolderPickerDebounce ]
        ]
    ];
    token
];

pickerStart // endDefinition;


(* ~user (any ~ other than ~ and ~/...): not supported *)
tildeUserQ // beginDefinition;
tildeUserQ[ path_String ] := StringStartsQ[ path, "~" ] && path =!= "~" && ! StringStartsQ[ path, "~/" ];
tildeUserQ // endDefinition;


(* A path that can be listed: not empty, no NUL character (it can't be quoted), at most $acpRemoteMaxPathLength *)
pickerPathQ // beginDefinition;
pickerPathQ[ path_String ] := StringLength @ StringTrim @ path > 0 && StringFreeQ[ path, "\000" ] && StringLength @ path <= $acpRemoteMaxPathLength;
pickerPathQ[ _ ] := False;
pickerPathQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*pickerRun*)

(* The listing of a request (in the pump, after the debounce delay): nothing if a newer request replaced it meanwhile (no
   ssh at all); otherwise one acpRemoteRun with a body of its own nonce. It uses the window's settings as they are now:
   ShowNotebookAssistance on the open window may have fixed "Arguments" or "Executable" for the same host (no host
   switch, so the picker stayed open), and "Try again" must use the fix. They are written back to the store, so that its
   result (the home key, the host in messages) sees the same settings. Settings of another host (or none) mean that the
   host changed under the picker: it closes, as on a host switch. The latch (B5.6) applies only to the listing of an
   automatic open; every click is a user action, which clears it. *)
pickerRun // beginDefinition;

pickerRun[ owner_NotebookObject, token_String ] := Catch @ Module[ { window, store, request, ssh, lnonce, body },
    window  = acpWindowGet @ owner;
    store   = acpFolderPickerOf @ window;
    request = If[ AssociationQ @ store, store[ "Request" ], None ];
    If[ ! AssociationQ @ request || request[ "Token" ] =!= token || acpRunCancelledQ[ owner, { { "FolderPicker", owner }, token } ],
        Throw @ Missing[ "Superseded" ]
    ];
    ssh = acpWindowSSH @ window;
    If[ ! AssociationQ @ ssh || acpSSHHostKey @ ssh =!= store[ "HostKey" ],
        acpFolderPickerCloseWindow @ owner;
        Throw @ Missing[ "HostChanged" ]
    ];
    If[ ssh =!= store[ "SSH" ], pickerUpdate[ owner, <| #1, "SSH" -> ssh |> & ] ];
    lnonce = "L" <> StringDelete[ CreateUUID[ ], "-" ];
    body   = acpRemoteListBody[ lnonce, request[ "Path" ], request[ "Base" ], request[ "Fallback" ] ];
    With[ { o = owner, t = token, n = lnonce },
        acpRemoteRun[
            ssh,
            body,
            acpFolderPickerOnResult[ o, t, n, # ] &,
            <|
                "Timeout"   -> $acpFolderPickerTimeout,
                "MaxOutput" -> $acpFolderPickerMaxOutput,
                "Automatic" -> TrueQ @ request[ "Automatic" ],
                "Owner"     -> o,
                "Request"   -> { { "FolderPicker", o }, t },
                "Label"     -> "FolderList"
            |>
        ]
    ]
];

pickerRun // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerOnResult*)

(* The result of a listing (acpRemoteRun's continuation, in the pump). Stale results are dropped: the picker is gone,
   another request replaced this one, or the run was cancelled. Then, from the result:
     * a run that failed: the error info of Remote.wl (the toolbar's ErrorSSH... messages), or the picker's own
       errors for a timeout ("Timeout") and a host without a temporary folder (stop "tmpdir": "Tmp");
     * a listing that can't be read: "Failed" (with the listing's stderr);
     * a requested folder that can't be listed: a navigation error (the previous listing stays);
     * a listing (OK, unreadable, or a folder above the requested one: fallback): the store shows it.
   The previous listing stays in every case but the last, so Choose still works for it; without one the store is
   "Error". The path field shows the listed folder (front end writes, allowed here: this is not a reader handler), the
   listing's home folder (V6: the parser keeps only an absolute path) is persisted for the host and given to the ACP
   window (pickerKeepHome). *)
acpFolderPickerOnResult // beginDefinition;

acpFolderPickerOnResult[ owner_NotebookObject, token_String, lnonce_String, result_Association ] := Catch @ Module[
    { store, outcome },
    store = acpFolderPickerOf @ acpWindowGet @ owner;
    If[ Lookup[ result, "Status", None ] === "Cancelled" || ! requestTokenQ[ store, token ], Throw @ Missing[ "Stale" ] ];
    outcome = pickerOutcome[ store, result, lnonce ];
    Switch[ outcome[ "Kind" ],
        "Listing"   , pickerApplyListing[ owner, token, store, outcome[ "Listing" ], result ],
        "Navigation", pickerNavigationError[ owner, outcome[ "Error" ], token ];
                      pickerLogFailure[ outcome[ "Error" ], result ],
        _           , pickerApplyError[ owner, token, outcome[ "Error" ] ];
                      pickerLogFailure[ outcome[ "Error" ], result ]
    ];
    acpPublish[ ];
    outcome[ "Kind" ]
];

acpFolderPickerOnResult // endDefinition;


(* What a result means for the picker (pure): <| "Kind" -> "Listing" | "Navigation" | "Error", "Listing", "Error" |> *)
pickerOutcome // beginDefinition;

pickerOutcome[ store_Association, result_Association, lnonce_String ] := Module[ { status, frame, listing },
    status = Lookup[ result, "Status", None ];
    Which[
        Lookup[ result, "Stop", None ] === "tmpdir",
            <| "Kind" -> "Error", "Error" -> pickerError[ "Tmp", None, store ] |>,
        MatchQ[ status, "TimedOut" | "RemoteTimedOut" ],
            <| "Kind" -> "Error", "Error" -> pickerError[ "Timeout", None, store ] |>,
        status =!= "OK",
            <| "Kind" -> "Error", "Error" -> Replace[ Lookup[ result, "Error", None ], Except[ _Association ] :> pickerError[ "Failed", None, store ] ] |>,
        True,
            frame   = Replace[ Lookup[ Replace[ Lookup[ result, "Frames", <| |> ], Except[ _Association ] -> <| |> ], "list", None ], Except[ _Association ] -> <| |> ];
            listing = acpRemoteListingParse[ Lookup[ frame, "Output", ByteArray[ { } ] ], lnonce ];
            Which[
                MemberQ[ { "OK", "Unreadable" }, listing[ "Status" ] ] && StringQ @ listing[ "Path" ],
                    <| "Kind" -> "Listing", "Listing" -> listing |>,
                MemberQ[ { "Missing", "NotFolder", "NoAccess", "BadPath" }, listing[ "Status" ] ],
                    <| "Kind" -> "Navigation", "Error" -> pickerError[ listing[ "Status" ], listing[ "Requested" ], store ] |>,
                True,
                    <| "Kind" -> "Error", "Error" -> <| pickerError[ "Failed", None, store ], "Detail" -> frameErrorText @ frame |> |>
            ]
    ]
];

pickerOutcome // endDefinition;


(* The standard error of the listing frame (the detail of "Failed"), shortened and made display-safe *)
frameErrorText // beginDefinition;

frameErrorText[ frame_Association ] := Replace[
    Lookup[ frame, "Error", None ],
    {
        b_ByteArray /; Length @ b > 0 :> acpRemoteDisplayName @ StringTake[
            StringTrim @ Quiet @ ByteArrayToString[ Take[ b, -UpTo[ 1000 ] ], "ISOLatin1" ],
            UpTo[ 500 ]
        ],
        _ :> None
    }
];

frameErrorText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Errors*)

(* The picker's own errors: <| "Code", "Message", "Source" -> "FolderPicker", "Navigation" |>. Navigation errors (a folder
   that can't be listed, a path that can't be one) keep the previous listing and have no "Try again". path: the folder,
   abbreviated with the store's home for the message. *)
pickerError // beginDefinition;

pickerError[ code_String, path_, store_ ] := <|
    "Code"       -> code,
    "Message"    -> pickerErrorMessage[ code, path, store ],
    "Source"     -> "FolderPicker",
    "Navigation" -> MemberQ[ { "Missing", "NotFolder", "NoAccess", "BadPath", "Tilde" }, code ]
|>;

pickerError // endDefinition;


pickerErrorMessage // beginDefinition;

pickerErrorMessage[ code: "Missing" | "NotFolder" | "NoAccess", path_, store_ ] :=
    acpLabel[ "FolderPickerError" <> code, <| "path" -> pickerPathText[ path, store ] |> ];

pickerErrorMessage[ code: "BadPath" | "Tilde", _, _ ] := acpLabel[ "FolderPickerError" <> code ];

pickerErrorMessage[ code: "Timeout" | "Tmp" | "Failed", _, store_ ] :=
    acpLabel[ "FolderPickerError" <> code, <| "host" -> pickerStoreHost @ store |> ];

pickerErrorMessage // endDefinition;


(* A path for display: abbreviated with the home folder, made display-safe *)
pickerPathText // beginDefinition;
pickerPathText[ path_, store_ ] := acpRemoteDisplayName @ acpRemoteAbbreviate[ pickerText @ path, Lookup[ Replace[ store, Except[ _Association ] -> <| |> ], "Home", None ] ];
pickerPathText // endDefinition;


(* The host of a store for messages ("user@host", display-safe) *)
pickerStoreHost // beginDefinition;
pickerStoreHost[ store_Association ] := acpRemoteDisplayName @ pickerText @ acpSSHHostLabel @ store[ "SSH" ];
pickerStoreHost[ _ ] := "?";
pickerStoreHost // endDefinition;


(* Remote text as a string: a name that is not valid UTF-8 is Missing["Undecodable", latin1] *)
pickerText // beginDefinition;
pickerText[ s_String ] := s;
pickerText[ Missing[ _, s_String ] ] := s;
pickerText[ _ ] := "?";
pickerText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Applying results*)

(* A navigation error (or an error of a path before any request: request None): the previous listing stays (or the store
   is "Error" without one), the path field shows the listed folder again, and the running request is replaced *)
pickerNavigationError // beginDefinition;

pickerNavigationError[ owner_NotebookObject, error_Association, token_ ] := Module[ { f },
    f = <| #1, "Status" -> If[ StringQ @ #1[ "Path" ], "Ready", "Error" ], "Request" -> None, "Error" -> error |> &;
    If[ StringQ @ token,
        pickerUpdateRequest[ owner, token, f ],
        acpSetCurrentRequest[ { "FolderPicker", owner }, CreateUUID[ "fp-" ] ];
        pickerUpdate[ owner, f ]
    ];
    pickerShowPath @ owner;
    acpPublish[ ];
    error
];

pickerNavigationError // endDefinition;


(* A failed listing: the error; the previous listing stays (Choose works for it), without one the store is "Error" *)
pickerApplyError // beginDefinition;

pickerApplyError[ owner_NotebookObject, token_String, error_Association ] := (
    pickerUpdateRequest[
        owner,
        token,
        <| #1, "Status" -> If[ StringQ @ #1[ "Path" ], "Ready", "Error" ], "Request" -> None, "Error" -> error |> &
    ];
    pickerShowPath @ owner;
    error
);

pickerApplyError // endDefinition;


(* A listing: the store shows it; the path field shows its folder; the home folder is kept *)
pickerApplyListing // beginDefinition;

pickerApplyListing[ owner_NotebookObject, token_String, store_Association, listing_Association, result_Association ] := Module[
    { home, path, entries, shown, notice, applied },

    home    = Replace[ listing[ "Home" ], Except[ _String ] :> store[ "Home" ] ];
    path    = listing[ "Path" ];
    entries = pickerEntries @ listing;
    shown   = acpRemoteDisplayName @ acpRemoteAbbreviate[ path, home ];
    notice  = If[ StringQ @ listing[ "Fallback" ] && listing[ "RequestedStatus" ] =!= "OK",
        acpLabel[
            "FolderPickerFallback",
            <| "requested" -> pickerPathText[ listing[ "Requested" ], <| "Home" -> home |> ], "shown" -> shown |>
        ],
        None
    ];

    applied = pickerUpdateRequest[
        owner,
        token,
        <|
            #1,
            "Status"        -> "Ready",
            "Request"       -> None,
            "Path"          -> path,
            "RealPath"      -> Replace[ listing[ "RealPath" ], Except[ _String ] -> None ],
            "Home"          -> home,
            "Entries"       -> entries,
            "Counts"        -> listing[ "Counts" ],
            "Capped"        -> listing[ "Capped" ],
            "Warning"       -> listing[ "Warning" ],
            "ListingStatus" -> listing[ "Status" ],
            "Notice"        -> notice,
            "Error"         -> None,
            "Shown"         -> $acpFolderPickerPageSize,
            "InputShown"    -> shown,
            "Version"       -> #1[ "Version" ] + 1
        |> &
    ];
    If[ ! AssociationQ @ applied, Return[ Missing[ "Stale" ], Module ] ];

    pickerSetInput[ owner, shown, path ];
    pickerKeepHome[ owner, store, listing[ "Home" ] ];
    acpLog[ "FolderPickerListed", <| "Status" -> listing[ "Status" ], "Seconds" -> Lookup[ result, "Duration", None ], "Entries" -> Length @ entries |> ];
    path
];

pickerApplyListing // endDefinition;


(* The listing's home folder (already checked by the parser: absolute, no control characters) is persisted for the host
   if it changed, and becomes the ACP window's "RemoteHome" (same host). It replaces a home the window already has: the
   listing has just seen the host, while the window's home may be a stale persisted one (an ssh alias that now points
   to another machine), which would expand "~" folders to a home that no longer exists. *)
pickerKeepHome // beginDefinition;

pickerKeepHome[ owner_NotebookObject, store_Association, home_String ] := With[ { key = acpRemoteHomeKey @ store[ "SSH" ] },
    If[ ListQ @ key && acpPersistedSetting[ key, None ] =!= home, acpSetPersistedSetting[ key, home ] ];
    acpWindowUpdate[
        owner,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ] && acpWindowRemoteHome @ w =!= home && acpWindowHostKey @ w === store[ "HostKey" ],
                <| w, "RemoteHome" -> home |>,
                Missing[ "Unchanged" ]
            ]
        ]
    ];
    Null
];

pickerKeepHome[ _, _, _ ] := Null;

pickerKeepHome // endDefinition;


pickerLogFailure // beginDefinition;

pickerLogFailure[ error_Association, result_Association ] := acpLog[
    "FolderPickerListFailed",
    <| "Code" -> Lookup[ error, "Code", None ], "ExitCode" -> Lookup[ result, "ExitCode", None ] |>
];

pickerLogFailure // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*The path field*)

(* The path field shows the listed folder again (after an error) *)
pickerShowPath // beginDefinition;

pickerShowPath[ owner_NotebookObject ] := With[ { store = acpFolderPickerOf @ acpWindowGet @ owner },
    If[ AssociationQ @ store && StringQ @ store[ "Path" ], pickerSetInput[ owner, store[ "InputShown" ], store[ "Path" ] ] ];
    Null
];

pickerShowPath // endDefinition;


(* The picker's TaggingRules (front end writes): the path field's text, and the listed folder (for a recovery) *)
pickerSetInput // beginDefinition;

pickerSetInput[ owner_NotebookObject, text_String, path_String ] := With[
    { picker = Lookup[ Replace[ acpFolderPickerOf @ acpWindowGet @ owner, None -> <| |> ], "Notebook", None ] },
    If[ $FrontEnd =!= Null && MatchQ[ picker, _NotebookObject ],
        Quiet[ CurrentValue[ picker, { TaggingRules, "ACPFolderPicker", "Input" } ] = text ];
        Quiet[ CurrentValue[ picker, { TaggingRules, "ACPFolderPicker", "Path" } ] = path ]
    ];
    Null
];

pickerSetInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*pickerEntries*)

(* The entries of a listing for the store: folders first, then the other entries, each in natural order (case does not
   matter, digit runs by value), with "Key": a hash of the name for the buttons (never the name itself; unique) *)
pickerEntries // beginDefinition;

pickerEntries[ listing_Association ] := Module[ { entries, folders, others, sorted, keys },
    entries = Select[ Replace[ listing[ "Entries" ], Except[ _List ] -> { } ], AssociationQ[ # ] && StringQ @ #[ "Name" ] & ];
    folders = Select[ entries, #[ "Kind" ] === "Folder" & ];
    others  = Select[ entries, #[ "Kind" ] =!= "Folder" & ];
    sorted  = Join[ naturalSort @ folders, naturalSort @ others ];
    keys    = uniqueKeys[ pickerKey /@ Lookup[ sorted, "Name", { } ] ];
    MapThread[ <| #1, "Key" -> #2 |> &, { sorted, keys } ]
];

pickerEntries // endDefinition;


naturalSort // beginDefinition;
naturalSort[ { } ] := { };
naturalSort[ entries_List ] := entries[[ acpNaturalOrdering @ Lookup[ entries, "Name" ] ]];
naturalSort // endDefinition;


(* Button arguments name entries by a key made from the name, so that no remote text is put into button code *)
pickerKey // beginDefinition;
pickerKey[ name_String ] := IntegerString[ Hash[ name, "SHA256" ], 36 ];
pickerKey // endDefinition;


(* Keys are unique: a repeated one (two names with the same hash) gets its position appended *)
uniqueKeys // beginDefinition;

uniqueKeys[ keys_List ] := If[ DuplicateFreeQ @ keys,
    keys,
    MapIndexed[ If[ Count[ keys[[ ;; First @ #2 ]], #1 ] > 1, #1 <> "-" <> ToString @ First @ #2, #1 ] &, keys ]
];

uniqueKeys // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerAction*)

(* The picker's buttons and keys (ChatbookAction["ACP", name, owner, args...], preemptive, isolated by acpAction). Each
   first checks the kernel session (a click after a kernel restart recovers the ACP window); without a store (a kernel
   restart) the picker is recovered and the click is ignored. *)
acpFolderPickerAction // beginDefinition;

acpFolderPickerAction[ name_String, owner_NotebookObject, args___ ] := (
    acpCheckSession @ owner;
    acpEnsureWindowRecord @ owner;
    With[
        {
            result = If[ MemberQ[ { "FolderPickerCancel", "FolderPickerClosed" }, name ] || AssociationQ @ acpFolderPickerOf @ acpWindowGet @ owner,
                pickerAction[ name, owner, args ],
                acpFolderPickerRecover @ owner;
                Missing[ "NoPicker" ]
            ]
        },
        acpPublish[ ];
        result
    ]
);

acpFolderPickerAction // endDefinition;


pickerAction // beginDefinition;

(* Cancel and Close need no store (the others are only called with one) *)
pickerAction[ "FolderPickerCancel", owner_ ] := (acpFolderPickerCloseWindow @ owner; "Cancelled");

pickerAction[ "FolderPickerClosed", owner_ ] := (pickerClosed @ owner; "Closed");

(* A folder of the listing (only one that can be opened) *)
pickerAction[ "FolderPickerEnter", owner_, key_String ] := With[ { store = acpFolderPickerOf @ acpWindowGet @ owner },
    Replace[
        SelectFirst[ store[ "Entries" ], #[ "Key" ] === key && #[ "Kind" ] === "Folder" &, None ],
        {
            entry_Association /; TrueQ @ entry[ "Usable" ] && ! TrueQ @ entry[ "Locked" ] && StringQ @ store[ "Path" ] :>
                pickerStart[ owner, acpRemoteChild[ store[ "Path" ], entry[ "Name" ] ], None, "Enter", False, False ],
            _ :> Missing[ "NotFound" ]
        }
    ]
];

(* Up from the listed folder, or from the folder a running request lists (Up, Up, Up within the debounce delay goes up
   three levels with one connection) *)
pickerAction[ "FolderPickerUp", owner_ ] := Replace[
    pickerCurrentTarget @ acpFolderPickerOf @ acpWindowGet @ owner,
    {
        "/" :> Missing[ "Root" ],
        path_String :> pickerStart[ owner, acpRemoteParent @ path, None, "Up", False, False ],
        _ :> Missing[ "NotListed" ]
    }
];

pickerAction[ "FolderPickerHome", owner_ ] := pickerStart[ owner, "~", None, "Home", False, False ];

(* Go: the path field's text (read from the picker window, or given as a string) *)
pickerAction[ "FolderPickerGo", owner_, picker_NotebookObject ] :=
    pickerGo[ owner, Quiet @ CurrentValue[ picker, { TaggingRules, "ACPFolderPicker", "Input" } ] ];

pickerAction[ "FolderPickerGo", owner_, text_String ] := pickerGo[ owner, text ];

(* The listed folder again; without a listing the last request (with its fallback) *)
pickerAction[ "FolderPickerRefresh", owner_ ] := With[ { store = acpFolderPickerOf @ acpWindowGet @ owner },
    Which[
        StringQ @ store[ "Path" ],
            pickerStart[ owner, store[ "Path" ], None, "Refresh", False, False ],
        AssociationQ @ store[ "LastRequest" ],
            pickerStart[ owner, store[ "LastRequest", "Path" ], store[ "LastRequest", "Base" ], "Refresh", store[ "LastRequest", "Fallback" ], False ],
        True,
            pickerStart[ owner, "~", None, "Refresh", True, False ]
    ]
];

(* Hidden entries are always listed: "Show hidden" only filters the view (persisted, written by the pump) *)
pickerAction[ "FolderPickerToggleHidden", owner_ ] := Module[ { new },
    new = ! TrueQ @ acpFolderPickerOf[ acpWindowGet @ owner ][ "ShowHidden" ];
    pickerUpdate[ owner, <| #1, "ShowHidden" -> new, "Shown" -> $acpFolderPickerPageSize |> & ];
    With[ { v = new }, acpSchedule @ acpSetPersistedSetting[ { "FolderPickerShowHidden" }, v ] ];
    new
];

pickerAction[ "FolderPickerShowMore", owner_ ] := (
    pickerUpdate[ owner, <| #1, "Shown" -> Replace[ #1[ "Shown" ], Except[ _Integer ] -> $acpFolderPickerPageSize ] + $acpFolderPickerPageSize |> & ];
    acpFolderPickerOf[ acpWindowGet @ owner ][ "Shown" ]
);

pickerAction[ "FolderPickerChoose", owner_ ] := acpFolderPickerChoose @ owner;

(* "Copy" of an ssh error: the hint and ssh's text, as the toolbar's "Copy" gives them (acpErrorParts); "Copy command": the
   terminal command for the SSH settings of the listing (the command that the hint of an unknown host key names) *)
pickerAction[ "FolderPickerCopyError", owner_ ] := pickerCopy @ acpErrorParts[
    Replace[ acpFolderPickerOf[ acpWindowGet @ owner ][ "Error" ], Except[ _Association ] -> <| |> ]
][ "Details" ];

pickerAction[ "FolderPickerCopyCommand", owner_ ] := pickerCopy @ acpSSHTerminalCommand @ acpFolderPickerOf[ acpWindowGet @ owner ][ "SSH" ];

pickerAction[ name_, _, ___ ] := Missing[ "UnknownAction", name ];

pickerAction // endDefinition;


(* Only from a button (preemptive, never a reader handler); gives the text *)
pickerCopy // beginDefinition;
pickerCopy[ text_String ] := (If[ $FrontEnd =!= Null, CopyToClipboard @ text ]; text);
pickerCopy[ _ ] := Missing[ "NothingToCopy" ];
pickerCopy // endDefinition;


(* Go with the field's text: nothing for an empty field; the listed folder again for the text the last listing put there
   (it shows the path made display-safe, so the raw path is used); that text with more path components after it (the
   user appended "/sub") is the raw path with those components, since a folder whose name was made display-safe exists
   only under its raw name; otherwise the text as a path, relative to the listed folder. The raw part is not trimmed (a
   folder name may end in a space). *)
pickerGo // beginDefinition;

pickerGo[ owner_NotebookObject, text_String ] := With[ { store = acpFolderPickerOf @ acpWindowGet @ owner },
    Which[
        StringTrim @ text === "",
            Missing[ "Empty" ],
        text === store[ "InputShown" ] && StringQ @ store[ "Path" ],
            pickerStart[ owner, store[ "Path" ], None, "Refresh", False, False ],
        shownPrefixQ[ text, store ],
            pickerStart[ owner, store[ "Path" ] <> StringTrim @ StringDrop[ text, StringLength @ store[ "InputShown" ] ], None, "Go", False, False ],
        True,
            pickerStart[ owner, StringTrim @ text, store[ "Path" ], "Go", False, False ]
    ]
];

pickerGo[ _, _ ] := Missing[ "NoInput" ];

pickerGo // endDefinition;


(* Whether text is the path field's text of the last listing followed by "/" (a component boundary: text that changes
   the last name, such as "~/proj/a" -> "~/proj/ab", is not) *)
shownPrefixQ // beginDefinition;

shownPrefixQ[ text_String, store_Association ] := With[ { shown = store[ "InputShown" ] },
    StringQ @ store[ "Path" ] && StringQ @ shown && shown =!= "" && StringStartsQ[ text, shown <> "/" ]
];

shownPrefixQ[ _, _ ] := False;

shownPrefixQ // endDefinition;


(* The folder the picker shows or is about to show: the target of a running request (an absolute path, lexical as cd -L
   is; ~ expanded with the home folder if known), else the listed folder *)
pickerCurrentTarget // beginDefinition;

pickerCurrentTarget[ store_Association ] := Replace[
    If[ store[ "Status" ] === "Loading", pickerTargetPath[ store[ "Request" ], store[ "Home" ] ], None ],
    Except[ _String? (StringStartsQ[ "/" ]) ] :> store[ "Path" ]
];

pickerCurrentTarget[ _ ] := None;

pickerCurrentTarget // endDefinition;


pickerTargetPath // beginDefinition;

pickerTargetPath[ request_Association, home_ ] := With[
    { path = acpRemoteExpandHome[ request[ "Path" ], home ], base = request[ "Base" ] },
    Which[
        ! StringQ @ path, None,
        StringStartsQ[ path, "/" ], acpRemoteLexicalPath @ path,
        StringStartsQ[ path, "~" ], path,
        StringQ @ base && StringStartsQ[ base, "/" ], acpRemoteLexicalPath[ base <> "/" <> path ],
        True, path
    ]
];

pickerTargetPath[ _, _ ] := None;

pickerTargetPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFolderPickerChoose*)

(* Choose: the listed folder becomes the ACP window's project folder (a new chat there; the launch then persists it for
   the host), the picker closes and the ACP window gets the focus. Only for a folder that is listed, can be listed, is
   on the window's host and can be a project folder (no control characters), and not while the agent works or a session
   loads (a notice says so). The same folder again reconnects a window in "Error" (e.g. a RemoteFolderAccess that was
   fixed meanwhile). Chosen paths are logical paths ($PWD after cd -L, like local folders) and are taken as they are
   ("Raw": a folder name may end in a space). Gives the folder, Null, or a Missing. *)
acpFolderPickerChoose // beginDefinition;

acpFolderPickerChoose[ owner_NotebookObject ] := Catch @ Module[ { window, store, path },
    window = acpWindowGet @ owner;
    store  = acpFolderPickerOf @ window;
    If[ ! AssociationQ @ store || store[ "Status" ] =!= "Ready" || ! StringQ @ store[ "Path" ], Throw @ Missing[ "NotReady" ] ];
    If[ store[ "ListingStatus" ] === "Unreadable" || store[ "Warning" ] === "Unlisted", Throw @ Missing[ "Unreadable" ] ];
    If[ store[ "HostKey" ] =!= acpWindowHostKey @ window, Throw @ Missing[ "HostChanged" ] ];
    path = store[ "Path" ];
    If[ ! acpRemoteProjectDirectoryQ @ path, Throw @ Missing[ "InvalidPath" ] ];
    Which[
        acpRestoringQ @ window,
            acpSetNotice[ owner, acpLabel[ "NoticeDirectoryWhileRestoring" ] ];
            Throw @ Null,
        pickerRunningQ @ window,
            acpSetNotice[ owner, acpLabel[ "NoticeDirectoryWhileRunning" ] ];
            Throw @ Null
    ];
    acpFolderPickerCloseWindow @ owner;
    If[ path === Lookup[ window, "ProjectDirectory" ],
        If[ Lookup[ window, "Status" ] === "Error", acpReconnect @ owner ],
        acpChangeProjectDirectory[ owner, path, <| "Raw" -> True |> ]
    ];
    sessionsFocusOwner[ owner, "New" ];
    path
];

acpFolderPickerChoose // endDefinition;


(* Whether a turn runs in the window (as UI.wl's acpRunningQ) *)
pickerRunningQ // beginDefinition;
pickerRunningQ[ window_Association ] := StringQ @ Lookup[ window, "CurrentTurn", None ];
pickerRunningQ[ _ ] := False;
pickerRunningQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*View*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Dynamic Views*)

(* A derived view of the owner's window record (as the Sessions window's sessionsDynamic): an invisible watcher tracks the
   window symbol and bumps the view's symbol when the signature changes; the view tracks only that symbol. Both load
   Chatbook first: after a kernel restart the picker is still open and its Dynamics are evaluated by a kernel that may
   not have loaded Chatbook yet (the views then show the state without a store until acpFolderPickerRecover rebuilds the
   cells). *)
pickerDynamic // beginDefinition;

pickerDynamic[ owner_NotebookObject, name_String, signature_, view_ ] :=
    pickerDynamic[ acpWindowSymbol @ owner, acpEntitySymbol[ acpWindowKey @ owner, name ], owner, name, signature, view ];

pickerDynamic[ HoldComplete[ w_Symbol ], HoldComplete[ d_Symbol ], owner_, name_, signature_, view_ ] := Row @ {
    Dynamic[
        w;
        Needs[ "Wolfram`Chatbook`" -> None ];
        acpSyncDerivedView[ owner, name, signature ];
        Spacer[ { 0, 0 } ],
        TrackedSymbols :> { w }
    ],
    Dynamic[
        d;
        Needs[ "Wolfram`Chatbook`" -> None ];
        acpRenderView[ view, owner ],
        TrackedSymbols :> { d }
    ]
};

pickerDynamic // endDefinition;


(* A second view of a derived view's state (it re-renders with it; the watcher is the other one's) *)
pickerViewDynamic // beginDefinition;

pickerViewDynamic[ owner_NotebookObject, name_String, view_ ] := pickerViewDynamic[ acpEntitySymbol[ acpWindowKey @ owner, name ], owner, view ];

pickerViewDynamic[ HoldComplete[ d_Symbol ], owner_, view_ ] := Dynamic[
    d;
    Needs[ "Wolfram`Chatbook`" -> None ];
    acpRenderView[ view, owner ],
    TrackedSymbols :> { d }
];

pickerViewDynamic // endDefinition;


(* Boxes made with only System` and Global` on $ContextPath, so that every symbol in them is written with its full
   context name and still resolves when the front end evaluates it *)
pickerBoxes // beginDefinition;
pickerBoxes[ expr_ ] := Block[ { $Context = "Global`", $ContextPath = { "System`", "Global`" } }, ToBoxes @ expr ];
pickerBoxes // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Signatures*)

(* The parts of the window record each view shows (R6): the status line, the buttons, the list. The entries are not part
   of the list's signature: "Version" changes with them. *)
pickerStatusSignature // beginDefinition;

pickerStatusSignature[ window_Association ] := With[ { store = acpFolderPickerOf @ window },
    If[ AssociationQ @ store,
        {
            Lookup[ store, { "Status", "Error", "Notice", "Path", "RealPath", "Home", "ListingStatus", "Warning", "Capped" } ],
            If[ store[ "Status" ] === "Loading", Lookup[ Replace[ store[ "Request" ], Except[ _Association ] -> <| |> ], { "Kind", "Path", "Base" }, None ], None ],
            StringQ @ store[ "Path" ] && store[ "Path" ] === Lookup[ window, "ProjectDirectory", None ]
        },
        { None, acpWindowHostLabel @ window }
    ]
];

pickerStatusSignature[ _ ] := None;

pickerStatusSignature // endDefinition;


pickerButtonsSignature // beginDefinition;

pickerButtonsSignature[ window_Association ] := With[ { store = acpFolderPickerOf @ window },
    If[ AssociationQ @ store,
        {
            Lookup[ store, { "Status", "Path", "ListingStatus", "Warning", "ShowHidden", "HostKey" } ],
            acpRemoteProjectDirectoryQ @ store[ "Path" ],
            acpRestoringQ @ window,
            pickerRunningQ @ window,
            acpWindowHostKey @ window
        },
        None
    ]
];

pickerButtonsSignature[ _ ] := None;

pickerButtonsSignature // endDefinition;


pickerListSignature // beginDefinition;

pickerListSignature[ window_Association ] := With[ { store = acpFolderPickerOf @ window },
    If[ AssociationQ @ store,
        { Lookup[ store, { "Version", "ShowHidden", "Shown" } ], store[ "Status" ] === "Loading" },
        None
    ]
];

pickerListSignature[ _ ] := None;

pickerListSignature // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Colors and Styles*)
$pickerTextStyle := {
    FontColor          -> $sessionsFont,
    FontFamily         -> "Source Sans Pro",
    FontSize           -> 13,
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Status*)

(* The status line: connecting / listing (with a spinner), an error (with "Try again" unless it is a navigation error), the
   fallback notice, or "Link to ..." for a folder whose physical path differs, with a "Current folder" badge when the
   listed folder is the window's. A navigation error keeps the previous listing, so the name of its folder stays above
   the red line (the list below is still that folder's). *)
pickerStatusView // beginDefinition;

pickerStatusView[ owner_NotebookObject ] := pickerStatusView[ owner, acpWindowGet @ owner ];

pickerStatusView[ owner_NotebookObject, window_ ] := Module[ { store, host },
    store = If[ AssociationQ @ window, acpFolderPickerOf @ window, None ];
    host  = acpRemoteDisplayName @ pickerText @ If[ AssociationQ @ window, acpWindowHostLabel @ window, None ];
    Which[
        ! AssociationQ @ store,
            pickerSpinnerLine @ acpLabel[ "FolderPickerConnecting", <| "host" -> host |> ],
        AssociationQ @ store[ "Error" ] && TrueQ @ store[ "Error", "Navigation" ] && StringQ @ store[ "Path" ],
            Column[ { pickerListedLine[ store, window ], pickerErrorView[ owner, store[ "Error" ] ] }, Alignment -> Left, Spacings -> 0.3 ],
        AssociationQ @ store[ "Error" ],
            pickerErrorView[ owner, store[ "Error" ] ],
        store[ "Status" ] === "Loading",
            pickerSpinnerLine @ If[ StringQ @ store[ "Path" ],
                acpLabel[ "FolderPickerLoading", <| "path" -> pickerPathText[ pickerTargetPath[ store[ "Request" ], store[ "Home" ] ], store ] |> ],
                acpLabel[ "FolderPickerConnecting", <| "host" -> host |> ]
            ],
        True,
            pickerReadyLine[ store, window ]
    ]
];

pickerStatusView // endDefinition;


pickerSpinnerLine // beginDefinition;

pickerSpinnerLine[ text_String ] := Row @ {
    ProgressIndicator[ Appearance -> "Percolate", ImageSize -> { 30, 8 } ],
    Spacer[ 6 ],
    Style[ text, FontSize -> 12, FontColor -> $sessionsMuted ]
};

pickerSpinnerLine // endDefinition;


(* A navigation error is a red line; other errors also offer "Try again". The error of a failed ssh run is the full error
   view (the message, the hint and ssh's text, all wrapped) with "Try again" and a copy button: "Copy command" when the
   hint says to run the ssh command in a terminal (an unknown host key), else "Copy" for the hint and ssh's text. *)
pickerErrorView // beginDefinition;

pickerErrorView[ owner_NotebookObject, error_Association ] /; Lookup[ error, "Source", None ] === "FolderPicker" := If[
    TrueQ @ error[ "Navigation" ],
    pickerRedLine @ error[ "Message" ],
    Column[
        {
            pickerRedLine @ error[ "Message" ],
            If[ StringQ @ Lookup[ error, "Detail", None ],
                Style[ acpSafeText @ error[ "Detail" ], FontSize -> 11, FontColor -> $sessionsMuted, LineBreakWithin -> Automatic ],
                Nothing
            ],
            pickerRetryButton @ owner
        },
        Alignment -> Left,
        Spacings  -> 0.4
    ]
];

pickerErrorView[ owner_NotebookObject, error_Association ] := Column[
    {
        acpErrorView[ error, None, "Full" ],
        Row[ { pickerRetryButton @ owner, pickerCopyButton[ owner, error ] }, Spacer[ 6 ] ]
    },
    Alignment -> Left,
    Spacings  -> 0.2
];

pickerErrorView // endDefinition;


(* The buttons carry no text: the actions copy from the store (pickerAction) *)
pickerCopyButton // beginDefinition;

pickerCopyButton[ owner_NotebookObject, KeyValuePattern[ "Code" -> "SSHHostKeyUnknown" ] ] := Tooltip[
    acpActionButton[
        sessionsButtonLabel[ acpLabel[ "FolderPickerCopyCommand" ], "Secondary" ],
        { "FolderPickerCopyCommand", owner },
        BoxID -> "ACPFolderPickerCopyCommand"
    ],
    acpLabel[ "FolderPickerCopyCommandTooltip" ]
];

pickerCopyButton[ owner_NotebookObject, error_Association ] /; StringQ @ acpErrorParts[ error ][ "Details" ] := Tooltip[
    acpActionButton[
        sessionsButtonLabel[ acpLabel[ "FolderPickerCopyError" ], "Secondary" ],
        { "FolderPickerCopyError", owner },
        BoxID -> "ACPFolderPickerCopyError"
    ],
    acpLabel[ "FolderPickerCopyErrorTooltip" ]
];

pickerCopyButton[ _, _ ] := Nothing;

pickerCopyButton // endDefinition;


pickerRedLine // beginDefinition;
pickerRedLine[ text_String ] := Style[ acpSafeText @ text, FontSize -> 12, FontColor -> acpColor[ "RedText" ], LineBreakWithin -> Automatic ];
pickerRedLine[ _ ] := Nothing;
pickerRedLine // endDefinition;


pickerRetryButton // beginDefinition;

pickerRetryButton[ owner_NotebookObject ] := acpActionButton[
    sessionsButtonLabel[ acpLabel[ "FolderPickerRetry" ], "Secondary" ],
    { "FolderPickerRefresh", owner },
    BoxID -> "ACPFolderPickerRetry"
];

pickerRetryButton // endDefinition;


(* The listed folder's name (the path field shows the start of a long path, so the folder itself may not be visible
   there) with the "Current folder" badge, then the fallback notice or "Link to ..." *)
pickerReadyLine // beginDefinition;

pickerReadyLine[ store_Association, window_Association ] := Column[
    {
        pickerListedLine[ store, window ],
        Which[
            StringQ @ store[ "Notice" ],
                Style[ store[ "Notice" ], FontSize -> 12, FontColor -> acpColor[ "AmberText" ] ],
            StringQ @ store[ "RealPath" ] && StringQ @ store[ "Path" ] && store[ "RealPath" ] =!= store[ "Path" ],
                Style[
                    acpLabel[ "FolderPickerRealPath", <| "path" -> pickerPathText[ store[ "RealPath" ], store ] |> ],
                    FontSize  -> 12,
                    FontColor -> $sessionsMuted
                ],
            True,
                Nothing
        ]
    },
    Alignment -> Left,
    Spacings  -> 0.3
];

pickerReadyLine // endDefinition;


pickerListedLine // beginDefinition;

pickerListedLine[ store_Association, window_Association ] := Row[
    {
        pickerListedName @ store,
        If[ StringQ @ store[ "Path" ] && store[ "Path" ] === Lookup[ window, "ProjectDirectory", None ], pickerCurrentBadge[ ], Nothing ]
    },
    Spacer[ 6 ]
];

pickerListedLine // endDefinition;


(* The listed folder's name (display-safe; "~" for the home folder, "/" for the root; a long name shortened), with its
   path in the tooltip *)
pickerListedName // beginDefinition;

pickerListedName[ store_Association ] /; StringQ @ store[ "Path" ] := Module[ { shown, name },
    shown = acpRemoteAbbreviate[ store[ "Path" ], store[ "Home" ] ];
    name  = sessionsShorten[ acpRemoteDisplayName @ If[ shown === "~", "~", acpRemotePathName @ store[ "Path" ] ], $pickerNameLength ];
    Tooltip[
        Row[ { RawBoxes @ acpFileIcon @ { "Directory" }, Style[ name, FontSize -> 12, FontWeight -> "DemiBold", FontColor -> $sessionsFont ] }, Spacer[ 4 ] ],
        acpLabel[ "FolderPickerListedTooltip", <| "path" -> pickerPathText[ store[ "Path" ], store ] |> ]
    ]
];

pickerListedName[ _ ] := Nothing;

pickerListedName // endDefinition;


pickerCurrentBadge // beginDefinition;

pickerCurrentBadge[ ] := Framed[
    Style[ acpLabel[ "FolderPickerCurrent" ], FontSize -> 11, FontColor -> $sessionsAccent ],
    FrameMargins   -> { { 4, 4 }, { 0, 0 } },
    FrameStyle     -> $sessionsAccent,
    RoundingRadius -> 3
];

pickerCurrentBadge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Buttons*)

(* Cancel and Choose. Choose is disabled (its tooltip says why) until a folder is listed, for a folder that can't be
   listed or can't be a project folder, and while the agent works or a session loads. *)
pickerButtonsView // beginDefinition;

pickerButtonsView[ owner_NotebookObject ] := pickerButtonsView[ owner, acpWindowGet @ owner ];

pickerButtonsView[ owner_NotebookObject, window_ ] := Module[ { store, reason },
    store  = If[ AssociationQ @ window, acpFolderPickerOf @ window, None ];
    reason = pickerChooseBlocked[ window, store ];
    Row[
        {
            acpActionButton[ sessionsButtonLabel[ acpLabel[ "FolderPickerCancel" ], "Secondary" ], { "FolderPickerCancel", owner }, BoxID -> "ACPFolderPickerCancel" ],
            If[ StringQ @ reason,
                Tooltip[ pickerDisabledButton @ acpLabel[ "FolderPickerChoose" ], reason ],
                Tooltip[
                    acpActionButton[
                        sessionsButtonLabel[ acpLabel[ "FolderPickerChoose" ], "Primary" ],
                        { "FolderPickerChoose", owner },
                        BoxID -> "ACPFolderPickerChoose"
                    ],
                    acpLabel[ "FolderPickerChooseTooltip", <| "path" -> acpRemoteDisplayName @ store[ "Path" ] |> ]
                ]
            ]
        },
        Spacer[ 6 ]
    ]
];

pickerButtonsView // endDefinition;


(* Why Choose is disabled (pure; the checks of acpFolderPickerChoose), or None *)
pickerChooseBlocked // beginDefinition;

pickerChooseBlocked[ window_Association, store_Association ] := Which[
    store[ "Status" ] =!= "Ready" || ! StringQ @ store[ "Path" ], acpLabel[ "FolderPickerChooseWait" ],
    store[ "ListingStatus" ] === "Unreadable" || store[ "Warning" ] === "Unlisted", acpLabel[ "FolderPickerChooseUnreadable" ],
    store[ "HostKey" ] =!= acpWindowHostKey @ window, acpLabel[ "FolderPickerChooseWait" ],
    ! acpRemoteProjectDirectoryQ @ store[ "Path" ], acpLabel[ "FolderPickerChooseControl" ],
    acpRestoringQ @ window, acpLabel[ "NoticeDirectoryWhileRestoring" ],
    pickerRunningQ @ window, acpLabel[ "NoticeDirectoryWhileRunning" ],
    True, None
];

pickerChooseBlocked[ _, _ ] := acpLabel[ "FolderPickerChooseWait" ];

pickerChooseBlocked // endDefinition;


(* A button that does nothing (muted) *)
pickerDisabledButton // beginDefinition;

pickerDisabledButton[ label_String ] := Framed[
    Style[ label, FontColor -> $sessionsMuted, FontSize -> 12 ],
    Background     -> $sessionsButton,
    FrameMargins   -> { { 8, 8 }, { 1, 1 } },
    FrameStyle     -> $sessionsButtonFrame,
    RoundingRadius -> 3
];

pickerDisabledButton // endDefinition;


(* "Show hidden": a check box and its label (the buttons view's state) *)
pickerToggleView // beginDefinition;

pickerToggleView[ owner_NotebookObject ] := pickerToggleView[ owner, acpWindowGet @ owner ];

pickerToggleView[ owner_NotebookObject, window_ ] := With[
    {
        store = If[ AssociationQ @ window, acpFolderPickerOf @ window, None ]
    },
    acpActionButton[
        Row[
            {
                pickerCheckBox @ TrueQ @ Lookup[ Replace[ store, None -> <| |> ], "ShowHidden", False ],
                Style[ acpLabel[ "FolderPickerShowHidden" ], FontSize -> 12, FontColor -> $sessionsFont ]
            },
            Spacer[ 4 ]
        ],
        { "FolderPickerToggleHidden", owner },
        BaseStyle -> $pickerTextStyle,
        BoxID     -> "ACPFolderPickerShowHidden",
        Enabled   -> AssociationQ @ store
    ]
];

pickerToggleView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*List*)

(* The listing: the folders (a page of them, then "Show 50 more folders"), the other entries (muted, the first 20, then
   "and N more files"), the caps of the script, and the counts. While a listing runs the previous one is muted and its
   rows do nothing. Hidden entries are filtered here ("Show hidden"). *)
pickerListView // beginDefinition;

pickerListView[ owner_NotebookObject ] := pickerListView[ owner, acpWindowGet @ owner ];

pickerListView[ owner_NotebookObject, window_ ] := Module[ { store, loading, entries, folders, others, shown, lines },
    store = If[ AssociationQ @ window, acpFolderPickerOf @ window, None ];
    If[ ! AssociationQ @ store || ! StringQ @ store[ "Path" ], Return[ Pane[ "", ImageSize -> { Full, 40 } ], Module ] ];
    loading = store[ "Status" ] === "Loading";
    entries = If[ TrueQ @ store[ "ShowHidden" ], store[ "Entries" ], Select[ store[ "Entries" ], ! TrueQ @ #[ "Hidden" ] & ] ];
    folders = Select[ entries, #[ "Kind" ] === "Folder" & ];
    others  = Select[ entries, #[ "Kind" ] =!= "Folder" & ];
    shown   = Replace[ store[ "Shown" ], Except[ _Integer? Positive ] -> $acpFolderPickerPageSize ];
    lines   = Which[
        store[ "ListingStatus" ] === "Unreadable",
            { pickerEmptyLine @ acpLabel[ "FolderPickerUnreadable" ] },
        store[ "Warning" ] === "Unlisted",
            { pickerEmptyLine @ acpLabel[ "FolderPickerUnlisted" ] },
        store[ "Entries" ] === { },
            { pickerEmptyLine @ acpLabel[ "FolderPickerEmpty" ] },
        entries === { },
            { pickerEmptyLine @ acpLabel[ "FolderPickerHiddenOnly" ] },
        True,
            Flatten @ {
                If[ folders === { },
                    pickerEmptyLine @ acpLabel[ "FolderPickerNoFolders" ],
                    pickerFolderRow[ owner, #, loading ] & /@ Take[ folders, UpTo[ shown ] ]
                ],
                If[ Length @ folders > shown, pickerShowMoreRow[ owner, Min[ $acpFolderPickerPageSize, Length @ folders - shown ], loading ], Nothing ],
                pickerFileRow[ #, loading ] & /@ Take[ others, UpTo[ $acpFolderPickerFilesShown ] ],
                pickerMoreFilesLine[ store, Length @ others ],
                pickerCapLines @ store,
                pickerSummaryLine @ store
            }
    ];
    Pane[
        Column[ lines, Alignment -> Left, ItemSize -> Full, Spacings -> 0 ],
        FrameMargins -> { { 4, 4 }, { 6, 8 } },
        ImageSize    -> Full
    ]
];

pickerListView // endDefinition;


(* A folder: a button that lists it; muted and without a button if it can't be opened (locked) or its name can't be a
   path (not UTF-8); a link has a muted arrow *)
pickerFolderRow // beginDefinition;

pickerFolderRow[ owner_NotebookObject, entry_Association, loading_ ] := Module[ { name, usable, locked, color, label },
    name   = acpRemoteDisplayName @ entry[ "Name" ];
    usable = TrueQ @ entry[ "Usable" ];
    locked = TrueQ @ entry[ "Locked" ];
    color  = If[ ! usable || locked || TrueQ @ loading, $sessionsMuted, $sessionsFont ];
    label  = pickerRowLabel[ RawBoxes @ acpFileIcon @ { "Directory" }, name, color, If[ locked, $pickerLockIcon, Nothing ], pickerLinkMark @ entry ];
    Which[
        ! usable,
            Tooltip[ sessionsRowFrame[ { { label, "" } }, None, $pickerRowIndent ], acpLabel[ "FolderPickerUnusableName" ] ],
        locked,
            Tooltip[ sessionsRowFrame[ { { label, "" } }, None, $pickerRowIndent ], acpLabel[ "FolderPickerLocked" ] ],
        TrueQ @ loading,
            sessionsRowFrame[ { { label, "" } }, None, $pickerRowIndent ],
        True,
            acpActionButton[
                Mouseover[
                    sessionsRowFrame[ { { label, "" } }, None, $pickerRowIndent ],
                    sessionsRowFrame[ { { label, "" } }, $sessionsHover, $pickerRowIndent ]
                ],
                { "FolderPickerEnter", owner, entry[ "Key" ] },
                Alignment -> Left,
                BaseStyle -> $pickerTextStyle,
                BoxID     -> "ACPFolderPickerEnter-" <> entry[ "Key" ],
                ImageSize -> Full
            ]
    ]
];

pickerFolderRow // endDefinition;


(* Files and other entries are muted and do nothing (they help to recognize a project) *)
pickerFileRow // beginDefinition;

pickerFileRow[ entry_Association, _ ] := With[
    {
        row = sessionsRowFrame[
            {
                {
                    pickerRowLabel[ RawBoxes @ acpFileIcon @ entry[ "Name" ], acpRemoteDisplayName @ entry[ "Name" ], $sessionsMuted, Nothing, pickerLinkMark @ entry ],
                    ""
                }
            },
            None,
            $pickerRowIndent
        ]
    },
    If[ entry[ "Kind" ] === "BrokenLink", Tooltip[ row, acpLabel[ "FolderPickerBrokenLink" ] ], row ]
];

pickerFileRow // endDefinition;


(* Icon, name (one line, shortened, the whole name in a tooltip), and marks *)
pickerRowLabel // beginDefinition;

pickerRowLabel[ icon_, name_String, color_, marks___ ] := With[ { short = sessionsShorten[ name, $pickerNameLength ] },
    Grid[
        { { icon, sessionsTitleView[ short, If[ short =!= name, name, None ], color ], marks } },
        Alignment -> { Left, Center },
        ItemSize  -> { { Automatic, Fit, Automatic } },
        Spacings  -> { 0.4, 0 }
    ]
];

pickerRowLabel // endDefinition;


pickerLinkMark // beginDefinition;

pickerLinkMark[ entry_Association ] := If[ TrueQ @ entry[ "Link" ] && entry[ "Kind" ] =!= "BrokenLink",
    Tooltip[ Style[ "\:21aa", FontSize -> 12, FontColor -> $sessionsMuted ], acpLabel[ "FolderPickerLink" ] ],
    Nothing
];

pickerLinkMark // endDefinition;


pickerShowMoreRow // beginDefinition;

pickerShowMoreRow[ owner_NotebookObject, n_Integer, loading_ ] := Pane[
    acpActionButton[
        Style[ pickerCountLabel[ "FolderPickerShowMore", n ], FontSize -> 12, FontColor -> If[ TrueQ @ loading, $sessionsMuted, $sessionsAccent ] ],
        { "FolderPickerShowMore", owner },
        Alignment -> Left,
        BaseStyle -> $pickerTextStyle,
        BoxID     -> "ACPFolderPickerShowMore",
        Enabled   -> ! TrueQ @ loading
    ],
    Alignment    -> Left,
    FrameMargins -> { { $pickerRowIndent + 4, 8 }, { 4, 4 } },
    ImageSize    -> Full
];

pickerShowMoreRow // endDefinition;


(* "and N more files": the other entries (as counted by the script) that are not shown *)
pickerMoreFilesLine // beginDefinition;

pickerMoreFilesLine[ store_Association, listed_Integer ] := With[
    { n = Max[ pickerOtherCount[ store, listed ] - Min[ listed, $acpFolderPickerFilesShown ], 0 ] },
    If[ n > 0, pickerMutedLine @ pickerCountLabel[ "FolderPickerMoreFiles", n ], Nothing ]
];

pickerMoreFilesLine // endDefinition;


(* The caps of the script: more folders than are listed, and more other entries than were looked at *)
pickerCapLines // beginDefinition;

pickerCapLines[ store_Association ] := Module[ { capped, counts, folders },
    capped  = Replace[ store[ "Capped" ], Except[ _Association ] -> <| |> ];
    counts  = Replace[ store[ "Counts" ], Except[ _Association ] -> <| |> ];
    folders = Max[ Lookup[ counts, "Folders", 0 ], If[ TrueQ @ store[ "ShowHidden" ], Lookup[ counts, "HiddenFolders", 0 ], 0 ] ];
    {
        If[ IntegerQ @ Lookup[ capped, "Folders", None ] || IntegerQ @ folders && folders > $acpRemoteListMaxFolders,
            pickerMutedLine @ acpLabel[ "FolderPickerTooManyFolders", <| "n" -> $acpRemoteListMaxFolders |> ],
            Nothing
        ],
        If[ IntegerQ @ Lookup[ capped, "Files", None ],
            pickerMutedLine @ acpLabel[ "FolderPickerTooManyFiles", <| "n" -> capped[ "Files" ] |> ],
            Nothing
        ]
    }
];

pickerCapLines // endDefinition;


(* "24 folders, 14 files", "1 folder, 1 file" (the script's counts, without hidden entries unless they are shown) *)
pickerSummaryLine // beginDefinition;

pickerSummaryLine[ store_Association ] := Module[ { counts, hidden },
    counts = store[ "Counts" ];
    hidden = TrueQ @ store[ "ShowHidden" ];
    If[ AssociationQ @ counts && AllTrue[ Lookup[ counts, { "Folders", "HiddenFolders", "Files", "HiddenFiles" } ], IntegerQ ],
        Pane[
            Style[
                acpLabel[
                    "FolderPickerSummary",
                    <|
                        "folders" -> pickerCountLabel[ "FolderPickerFolderCount", counts[ "Folders" ] + If[ hidden, counts[ "HiddenFolders" ], 0 ] ],
                        "files"   -> pickerCountLabel[ "FolderPickerFileCount", counts[ "Files" ] + If[ hidden, counts[ "HiddenFiles" ], 0 ] ]
                    |>
                ],
                FontSize  -> 11,
                FontColor -> $sessionsMuted
            ],
            FrameMargins -> { { $pickerRowIndent + 4, 8 }, { 2, 8 } },
            ImageSize    -> Full
        ],
        Nothing
    ]
];

pickerSummaryLine // endDefinition;


(* A count in its singular or plural text: key <> "One" for 1, key for other counts (both templates with `n`) *)
pickerCountLabel // beginDefinition;
pickerCountLabel[ key_String, 1 ] := acpLabel[ key <> "One", <| "n" -> 1 |> ];
pickerCountLabel[ key_String, n_Integer ] := acpLabel[ key, <| "n" -> n |> ];
pickerCountLabel // endDefinition;


(* The number of other entries the view would show (the script's counts, else the listed ones) *)
pickerOtherCount // beginDefinition;

pickerOtherCount[ store_Association, listed_Integer ] := With[ { counts = store[ "Counts" ] },
    If[ AssociationQ @ counts && IntegerQ @ counts[ "Files" ] && IntegerQ @ counts[ "HiddenFiles" ],
        Max[ listed, counts[ "Files" ] + If[ TrueQ @ store[ "ShowHidden" ], counts[ "HiddenFiles" ], 0 ] ],
        listed
    ]
];

pickerOtherCount // endDefinition;


pickerEmptyLine // beginDefinition;

pickerEmptyLine[ text_String ] := Pane[
    Style[ text, FontSize -> 12, FontSlant -> Italic, FontColor -> $sessionsMuted, LineBreakWithin -> Automatic ],
    FrameMargins -> { { $pickerRowIndent + 4, 8 }, { 6, 6 } },
    ImageSize    -> Full
];

pickerEmptyLine // endDefinition;


pickerMutedLine // beginDefinition;

pickerMutedLine[ text_String ] := Pane[
    Style[ text, FontSize -> 12, FontColor -> $sessionsMuted, LineBreakWithin -> Automatic ],
    FrameMargins -> { { $pickerRowIndent + 4, 8 }, { 4, 4 } },
    ImageSize    -> Full
];

pickerMutedLine // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Icons*)

$pickerIconOptions := Sequence[
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.15 ],
    ImageSize        -> { 13, 13 },
    PlotRange        -> { { -0.1, 1.1 }, { -0.1, 1.1 } }
];

(* An arrow up *)
$pickerUpIcon := Graphics[
    {
        $sessionsAccent, AbsoluteThickness[ 1.4 ], CapForm[ "Round" ], JoinForm[ "Round" ],
        Line @ { { 0.5, 0.05 }, { 0.5, 0.95 } },
        Line @ { { 0.15, 0.6 }, { 0.5, 0.95 }, { 0.85, 0.6 } }
    },
    $pickerIconOptions
];

(* A house *)
$pickerHomeIcon := Graphics[
    {
        $sessionsAccent, AbsoluteThickness[ 1.3 ], CapForm[ "Round" ], JoinForm[ "Round" ],
        Line @ { { 0.0, 0.5 }, { 0.5, 0.98 }, { 1.0, 0.5 } },
        Line @ { { 0.15, 0.62 }, { 0.15, 0.02 }, { 0.85, 0.02 }, { 0.85, 0.62 } },
        Line @ { { 0.4, 0.02 }, { 0.4, 0.35 }, { 0.6, 0.35 }, { 0.6, 0.02 } }
    },
    $pickerIconOptions
];

(* An arrow to the right *)
$pickerGoIcon := Graphics[
    {
        $sessionsAccent, AbsoluteThickness[ 1.4 ], CapForm[ "Round" ], JoinForm[ "Round" ],
        Line @ { { 0.05, 0.5 }, { 0.95, 0.5 } },
        Line @ { { 0.6, 0.15 }, { 0.95, 0.5 }, { 0.6, 0.85 } }
    },
    $pickerIconOptions
];

(* A padlock (a folder that can't be opened) *)
$pickerLockIcon := Graphics[
    {
        $sessionsMuted, AbsoluteThickness[ 1.2 ],
        Circle[ { 0.5, 0.58 }, 0.24, { 0, Pi } ],
        Line @ { { 0.26, 0.58 }, { 0.26, 0.48 } },
        Line @ { { 0.74, 0.58 }, { 0.74, 0.48 } },
        Rectangle[ { 0.12, 0.0 }, { 0.88, 0.5 }, RoundingRadius -> 0.08 ]
    },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.15 ],
    ImageSize        -> { 11, 11 },
    PlotRange        -> { { -0.05, 1.05 }, { -0.05, 1.05 } }
];

(* A check box *)
pickerCheckBox // beginDefinition;

pickerCheckBox[ checked_ ] := Graphics[
    {
        EdgeForm @ { AbsoluteThickness[ 1 ], If[ TrueQ @ checked, $sessionsAccent, $sessionsMuted ] },
        FaceForm @ If[ TrueQ @ checked, $sessionsAccent, None ],
        Rectangle[ { 0, 0 }, { 1, 1 }, RoundingRadius -> 0.2 ],
        If[ TrueQ @ checked,
            { White, AbsoluteThickness[ 1.6 ], CapForm[ "Round" ], JoinForm[ "Round" ], Line @ { { 0.22, 0.52 }, { 0.43, 0.3 }, { 0.8, 0.72 } } },
            { }
        ]
    },
    AspectRatio      -> 1,
    BaselinePosition -> Scaled[ 0.1 ],
    ImageSize        -> { 12, 12 },
    PlotRange        -> { { -0.1, 1.1 }, { -0.1, 1.1 } }
];

pickerCheckBox // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* A listing whose continuation was lost (the store stays "Loading" for longer than pickerLostAfter[] seconds, which a
   live listing never takes) ends with FolderPickerErrorTimeout, and its run is replaced. The pump keeps running while a
   picker lists (State.wl's publisherNeededQ), so this fallback always runs. *)
pickerHousekeeping // beginDefinition;

pickerHousekeeping[ ] := With[ { now = AbsoluteTime[ ] },
    KeyValueMap[ pickerWindowHousekeeping[ #1, #2, now ] &, $acpWindows ];
    Null
];

pickerHousekeeping // endDefinition;


pickerWindowHousekeeping // beginDefinition;

pickerWindowHousekeeping[ owner_NotebookObject, window_Association, now_ ] := Module[ { store, request },
    store   = acpFolderPickerOf @ window;
    request = If[ AssociationQ @ store, store[ "Request" ], None ];
    If[ AssociationQ @ store && store[ "Status" ] === "Loading" && AssociationQ @ request &&
        now - Replace[ request[ "StartedAt" ], Except[ _? NumberQ ] -> now ] > pickerLostAfter[ ],
        acpIsolated[
            acpSetCurrentRequest[ { "FolderPicker", owner }, CreateUUID[ "fp-lost-" ] ];
            pickerApplyError[ owner, request[ "Token" ], pickerError[ "Timeout", None, store ] ];
            acpLog[ "FolderPickerListFailed", <| "Code" -> "Timeout", "ExitCode" -> None, "Lost" -> True |> ]
        ]
    ]
];

pickerWindowHousekeeping[ _, _, _ ] := Null;

pickerWindowHousekeeping // endDefinition;


(* Seconds after its start (pickerStart's "StartedAt") after which a listing counts as lost. acpRemoteRun bounds the
   wait for a free host slot and the ssh run separately, each by "Timeout" (Remote.wl's remoteStart, and acpProcessRun
   from the start of ssh), and the debounce, the slot retries and the polls come on top: a live listing can deliver
   its result about twice $acpFolderPickerTimeout after it started (slow sign-ins while other runs hold the slots).
   Ending it sooner would cancel a healthy run and show the timeout error just before its listing arrives. *)
pickerLostAfter // beginDefinition;
pickerLostAfter[ ] := 2 * $acpFolderPickerTimeout + $pickerLostGrace;
pickerLostAfter // endDefinition;


acpRegisterHousekeeping[ "ACPFolderPicker", pickerHousekeeping, $pickerHousekeepingTicks ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
