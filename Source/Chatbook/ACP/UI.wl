(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`UI`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"                  ];
Needs[ "Wolfram`Chatbook`Common`"           ];
Needs[ "Wolfram`Chatbook`ChatModes`Common`" ];
Needs[ "Wolfram`Chatbook`ACP`Common`"       ];

(* ACP window UI (see docs/acp-window.md, "Files" and "Threading rules"): window creation, toolbar, input cell,
   send/stop/new chat, output cell writing, finalization.

   Rules (see State.wl):
   * Every front end entry point (buttons, menus, event handlers, Dynamic renderers) goes through acpAction or runs
     inside acpIsolated, so nothing thrown here can unwind a concurrent Notebook Assistant chat.
   * Nothing here blocks or waits for the agent. Agent traffic is handled by Connection.wl.
   * Front end views track the window change symbol (acpWindowSymbol). Views containing stateful widgets (menus, the
     directory chooser, permission buttons) only re-render when the part of the window state they show changes.
*)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$acpWindowWidth      := $acpWindowWidth = Switch[ $OperatingSystem, "MacOSX", 450, _, 360 ];
$acpStyleSheet        = FrontEnd`FileName[ { "Wolfram" }, "ACPChat.nb", CharacterEncoding -> "UTF-8" ];
$acpDefaultAgent      = "OpenCode";
$acpFinalizeDebounce  = 0.2;  (* seconds to wait after the end of a turn for trailing updates *)
$acpFinalizeFallback  = 1.0;  (* seconds after which housekeeping finalizes a turn that ended but was not finalized *)
$acpFinalizeTimeout   = 30;   (* seconds after which housekeeping finishes a turn whose finalization never completed *)
$acpMaxRecentModels   = 3;
$acpPreferencesPath   = { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP" };
$acpMaxPathLength     = 42;
$acpMaxPathLengthReview = 20; (* when the "Review" button is shown in the project folder row *)
$acpQueuedPreviewSize = 80;

(* UI-owned keys in window records (in addition to the ones described in docs/acp-window.md, "State model"):
     "Settings"     -> explicit ShowNotebookAssistance settings ("ACPAgent", "ACPAgentCommandLine", "ACPModel", ...)
     "Notice"       -> None | String: a transient message shown above the input field
     "QueuedPrompt" -> None | String: a prompt typed while a turn was running; sent after the turn is finalized
     "QueuedTurn"   -> None | turnID: a turn that was started before the connection was ready
   UI-owned keys in turn records:
     "FinalizeClaimed"   -> True once acpFinalizeTurn has started writing the final cell
     "FinalizeClaimedAt" -> AbsoluteTime[ ] of the claim (housekeeping finishes turns stuck in "Finalizing") *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English defaults for every user-visible string in this file. acpLabel[key] (Rendering.wl) looks up the front end text
   resource "ChatbookStrings" key "ACP"<>key first and falls back to this table (and to $acpStrings). Templates use
   named slots (`name`) filled by acpLabel[key, <| "name" -> value |>]. *)
$acpUIStrings = <|
    "WindowTitle"                    -> "Agent Chat",
    "WindowTitleNoProject"           -> "`agent`",
    "WindowTitleProject"             -> "`project` \[LongDash] `agent`",
    "WindowTitleApproval"            -> "Approval needed \[LongDash] `project`",
    "NewChat"                        -> "New",
    "NewChatTooltip"                 -> "Start a new chat",
    "ModelMenuDefault"               -> "Model",
    "ModelMenuTooltip"               -> "Model (`billing`)",
    "ModelMenuRecent"                -> "Recent",
    "ModelMenuUnavailable"           -> "`model` (unavailable)",
    "ModelMenuOtherProvider"         -> "Other",
    "ModeMenuTooltip"                -> "How the agent works",
    "EffortMenuTooltip"              -> "Reasoning effort",
    "MenusDisabledTooltip"           -> "Settings can't be changed while the agent is working",
    "MenusDisabledRestoring"         -> "Settings can't be changed while a session is loading",
    "ProjectDirectoryNone"           -> "No project folder",
    "ProjectDirectoryChange"         -> "Change\[Ellipsis]",
    "ProjectDirectoryChoose"         -> "Choose folder\[Ellipsis]",
    "ProjectDirectoryTooltip"        -> "Project folder: `path`",
    "ProjectDirectoryDialogTitle"    -> "Choose a project folder",
    "ProjectDirectoryWarningHome"    -> "This is your home folder: the agent can read and change everything in it.",
    "ProjectDirectoryWarningRoot"    -> "This is a filesystem root: the agent can read and change everything in it.",
    "ProjectDirectoryWarningMissing" -> "This folder does not exist.",
    "InputFieldHint"                 -> "Ask `agent` to do something\[Ellipsis]",
    "QueuedPrompt"                   -> "Queued, sent when the agent is done: `text`",
    "QueuedPromptRestoring"          -> "Queued, sent when the session is loaded: `text`",
    "QueuedPromptCancel"             -> "Remove the queued message",
    "NoticeDismiss"                  -> "Dismiss",
    "PlanModeBadge"                  -> "Plan mode",
    "NoticeNoDirectory"              -> "Choose a project folder first.",
    "NoticeCannotSend"               -> "Can't send the message: `reason`",
    "NoticeNotConnected"             -> "the agent is not connected.",
    "NoticeDirectoryWhileRunning"    -> "The project folder can't be changed while the agent is working.",
    "NoticeDirectoryWhileRestoring"  -> "The project folder can't be changed while a session is loading.",
    "NoticeChooseModel"              -> "Choose another model from the model menu above.",
    "NoticeSignIn"                   -> "Run \"opencode auth login\" in a terminal to sign in, then reconnect.",
    "NoticeLocateAgent"              -> "Install OpenCode (https://opencode.ai) or give its command line with the \"ACPAgentCommandLine\" setting, then reconnect.",
    "NoticeAgentExecutableMissing"   -> "The file `path` does not exist.",
    "NoticeReconnectAfterTurn"       -> "The new agent settings are applied when the agent is done.",
    "InterruptedKernelRestart"       -> "Interrupted \[LongDash] the kernel was restarted.",
    "FinalCellUnavailable"           -> "This response could not be displayed.",
    "QueuedTurnFailed"               -> "The message was not sent because `agent` is not connected."
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpWindowQ*)
acpWindowQ // beginDefinition;

acpWindowQ[ nbo_NotebookObject ] :=
    TrueQ @ Quiet @ AbsoluteCurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "ACPWindow" } ];

acpWindowQ[ cell_CellObject ] :=
    TrueQ @ Quiet @ CurrentChatSettings[ cell, "ACPWindow" ];

acpWindowQ[ _ ] := False;

acpWindowQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpAction*)

(* ChatbookAction["ACP", name, args...] -> acpAction[name, args...]. Every action is isolated (rule R3): it can
   run preemptively inside a Notebook Assistant chat, so nothing may escape from it. *)
acpAction // beginDefinition;
acpAction[ args___ ] := acpIsolated @ acpAction0 @ args;
acpAction // endDefinition;


(* Error view buttons (Rendering.wl) call ChatbookAction["ACP", action, nbo] directly *)
$$errorAction = "ChooseModel" | "SignIn" | "LocateAgent" | "ChooseDirectory";

(* Buttons of the Sessions window (Sessions.wl) *)
$$sessionsWindowAction = Alternatives[
    "SessionsCancelDelete",
    "SessionsConfirmDelete",
    "SessionsDelete",
    "SessionsDismissNotice",
    "SessionsNew",
    "SessionsOpen",
    "SessionsOpenFolder",
    "SessionsShowMore",
    "SessionsToggleProject"
];

acpAction0 // beginDefinition;
acpAction0[ "Send"               , nbo_NotebookObject                  ] := evaluateACPChat @ nbo;
acpAction0[ "Stop"               , nbo_NotebookObject                  ] := acpStopAction @ nbo;
acpAction0[ "NewChat"            , nbo_NotebookObject                  ] := acpNewChat @ nbo;
acpAction0[ "ToggleOpen"         , args___                             ] := acpToggleOpen @ args;
acpAction0[ "PermissionResponse" , nbo_NotebookObject, args__          ] := acpPermissionResponseAction[ nbo, args ];
acpAction0[ "SetConfigOption"    , nbo_NotebookObject, id_String, val_ ] := acpSetConfigOptionAction[ nbo, id, val ];
acpAction0[ "SetProjectDirectory", nbo_NotebookObject, dir_            ] := acpSetProjectDirectoryAction[ nbo, dir ];
acpAction0[ "Reconnect"          , nbo_NotebookObject                  ] := acpReconnectAction @ nbo;
acpAction0[ "ErrorAction"        , nbo_NotebookObject, action_         ] := acpErrorAction[ nbo, action ];
acpAction0[ action: $$errorAction  , nbo_NotebookObject                  ] := acpErrorAction[ nbo, action ];
acpAction0[ "WindowClosed"       , nbo_NotebookObject                  ] := acpWindowClosed @ nbo;
acpAction0[ "InitializeWindow"   , nbo_NotebookObject                  ] := acpInitializeWindowAction @ nbo;
acpAction0[ "DismissNotice"      , nbo_NotebookObject                  ] := acpSetNotice[ nbo, None ];
acpAction0[ "CancelQueuedPrompt" , nbo_NotebookObject                  ] := acpCancelQueuedPrompt @ nbo;
acpAction0[ "SetAgentExecutable" , nbo_NotebookObject, path_           ] := acpSetAgentExecutableAction[ nbo, path ];
acpAction0[ "ReviewChanges"      , nbo_NotebookObject                  ] := acpReviewChanges @ nbo;
acpAction0[ "ReviewRefresh"      , review_NotebookObject               ] := acpReviewRefresh @ review;
acpAction0[ "ReviewOpenFile"     , path_String                         ] := acpReviewOpenFile @ path;
acpAction0[ "ReviewDiffView"     , data_Association                    ] := acpReviewDiffView @ data;
acpAction0[ "RestoreSession"     , nbo_NotebookObject, sid_String, cwd_String ] := acpRestoreSessionAction[ nbo, sid, cwd ];
acpAction0[ "NewSessionIn"       , nbo_NotebookObject, cwd_String      ] := acpNewSessionInAction[ nbo, cwd ];
acpAction0[ "DeleteSession"      , nbo_NotebookObject, sid_String      ] := acpDeleteSessionAction[ nbo, sid ];
acpAction0[ "SessionsRefresh"    , nbo_NotebookObject                  ] := acpSessionsRefresh @ nbo;
acpAction0[ "SessionsClosed"     , nbo_NotebookObject                  ] := acpSessionsClosed @ nbo;
acpAction0[ "ToggleSessions"     , nbo_NotebookObject                  ] := acpToggleSessions @ nbo;
acpAction0[ name: $$sessionsWindowAction, nbo_NotebookObject, args___ ] := acpSessionsWindowAction[ name, nbo, args ];
acpAction0[ name_, args___ ] := (acpLog[ "UnknownAction", { name, args } ]; Missing[ "UnknownAction", name ]);
acpAction0 // endDefinition;

(* The action names handled by acpAction (used by tests) *)
$acpActionNames = {
    "CancelQueuedPrompt",
    "ChooseDirectory",
    "ChooseModel",
    "DeleteSession",
    "DismissNotice",
    "ErrorAction",
    "InitializeWindow",
    "LocateAgent",
    "NewChat",
    "NewSessionIn",
    "PermissionResponse",
    "Reconnect",
    "RestoreSession",
    "ReviewChanges",
    "ReviewDiffView",
    "ReviewOpenFile",
    "ReviewRefresh",
    "Send",
    "SessionsCancelDelete",
    "SessionsClosed",
    "SessionsConfirmDelete",
    "SessionsDelete",
    "SessionsDismissNotice",
    "SessionsNew",
    "SessionsOpen",
    "SessionsOpenFolder",
    "SessionsRefresh",
    "SessionsShowMore",
    "SessionsToggleProject",
    "SetAgentExecutable",
    "SetConfigOption",
    "SetProjectDirectory",
    "SignIn",
    "Stop",
    "ToggleOpen",
    "ToggleSessions",
    "WindowClosed"
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpActionCode*)

(* Front end code that runs an ACP action. It loads Chatbook first, so it also works after the kernel was quit. *)
acpActionCode // beginDefinition;
acpActionCode // Attributes = { HoldAll };

acpActionCode[ args___ ] := Hold[
    Needs[ "Wolfram`Chatbook`" -> None ];
    Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", args ]
];

acpActionCode // endDefinition;

(* acpActionButton[label, {action, args...}, opts] gives a preemptive Button that runs the ACP action. *)
acpActionButton // beginDefinition;

acpActionButton[ label_, { args___ }, opts___ ] := Replace[
    acpActionCode @ args,
    Hold[ code_ ] :> Button[ label, code, opts, Appearance -> "Suppressed", Method -> "Preemptive" ]
];

acpActionButton // endDefinition;

(* acpActionMenuItem[label, {action, args...}] gives label :> action for ActionMenu. *)
acpActionMenuItem // beginDefinition;
acpActionMenuItem[ label_, { args___ } ] := Replace[ acpActionCode @ args, Hold[ code_ ] :> (label :> code) ];
acpActionMenuItem // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Creation*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*showACPWindow*)

(* Called from ShowNotebookAssistance[source, "ACPWindow", opts] (settings are validated there). *)
showACPWindow // beginDefinition;

showACPWindow[ source: _NotebookObject|None, input_, evaluate_, new_, settings_Association ] := Enclose[
    Module[ { current, nbo },

        current = ConfirmMatch[ findCurrentWorkspaceChat[ "ACP" ], _NotebookObject | _Missing, "Existing" ];

        If[ TrueQ @ new && MatchQ[ current, _NotebookObject ],
            acpCloseWindow @ current;
            current = Missing[ "NotFound" ]
        ];

        nbo = ConfirmMatch[
            If[ MissingQ @ current,
                acpCreateWindow[ source, settings ],
                acpReuseWindow[ source, current, settings ]
            ],
            _NotebookObject,
            "Window"
        ];

        acpSetWindowInput[ nbo, input, evaluate ];
        nbo
    ],
    throwInternalFailure
];

showACPWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCreateWindow*)
acpCreateWindow // beginDefinition;

acpCreateWindow[ source_, settings_Association ] := Enclose[
    Module[ { dir, agent, nbo },
        dir   = acpDefaultProjectDirectory[ source, settings ];
        agent = acpSettingsAgent @ settings;

        (* The window is created invisible, so that its state (and the change symbols its views track) exists before
           the toolbar is built. Symbols created while the front end evaluates the toolbar's DestroyAfterEvaluation
           DynamicBox are not tracked by the front end (verified in 15.0.1), so views would never update. *)
        nbo = ConfirmMatch[
            NotebookPut @ Notebook[ { }, acpNotebookOptions[ dir, agent, settings ], Visible -> False ],
            _NotebookObject,
            "Notebook"
        ];

        ConfirmBy[ acpRegisterWindow[ nbo, dir, agent, settings ], AssociationQ, "Register" ];
        SetOptions[ nbo, Visible -> True ];

        If[ MatchQ[ source, _NotebookObject ],
            ConfirmMatch[ attachToLeft[ source, nbo ], _NotebookObject, "Attached" ],
            SetOptions[
                nbo,
                WindowMargins -> { { 0, Automatic }, { Automatic, 0 } },
                WindowSize    -> { $acpWindowWidth, Automatic }
            ];
            SetSelectedNotebook @ nbo
        ];

        acpUpdateWindowTitle @ nbo;
        acpEnsureConnected @ nbo;
        nbo
    ],
    throwInternalFailure
];

acpCreateWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpNotebookOptions*)
acpNotebookOptions // beginDefinition;

acpNotebookOptions[ dir_, agent_String, settings_Association ] := Sequence[
    Evaluator        -> acpCurrentEvaluator[ ],
    Saveable         -> False,
    StyleDefinitions -> $acpStyleSheet,
    TaggingRules     -> <|
        "ChatNotebookSettings" -> <|
            "ACPWindow"             -> True,
            "AppName"               -> "ACP",
            "AutoGenerateTitle"     -> False,
            "AutoSaveConversations" -> False,
            "ConversationUUID"      -> createUUID[ ],
            "SetCellDingbat"        -> False,
            "TabbedOutput"          -> False,
            "WorkspaceChat"         -> True
        |>,
        "ACP" -> <|
            "Agent"            -> agent,
            "Busy"             -> False,
            "Input"            -> "",
            "KernelSessionID"  -> $SessionID,
            "ProjectDirectory" -> dir,
            "Settings"         -> acpPersistedWindowSettings @ settings
        |>,
        "ConversationTitle" -> ""
    |>,
    WindowTitle -> acpWindowTitleString[ dir, agent, False ]
];

acpNotebookOptions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpCurrentEvaluator*)

(* The window must use the kernel that holds its state (the one evaluating ShowNotebookAssistance). *)
acpCurrentEvaluator // beginDefinition;

acpCurrentEvaluator[ ] := Replace[
    Quiet @ AbsoluteCurrentValue[ EvaluationNotebook[ ], Evaluator ],
    Except[ _String? StringQ ] -> "Local"
];

acpCurrentEvaluator // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpSettingsAgent*)
acpSettingsAgent // beginDefinition;
acpSettingsAgent[ settings_Association ] := Replace[ Lookup[ settings, "ACPAgent", Automatic ], Except[ _String ] -> $acpDefaultAgent ];
acpSettingsAgent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpDefaultProjectDirectory*)

(* Explicit setting -> last used directory -> directory of the (saved) source notebook -> None *)
acpDefaultProjectDirectory // beginDefinition;

acpDefaultProjectDirectory[ source_, settings_Association ] :=
    acpDefaultProjectDirectory[ source, Lookup[ settings, "ProjectDirectory", Automatic ] ];

acpDefaultProjectDirectory[ _, None ] := None;

acpDefaultProjectDirectory[ _, dir: _String | File[ _String ] ] := acpNormalizeDirectory @ dir;

acpDefaultProjectDirectory[ source_, Automatic ] := FirstCase[
    Unevaluated @ {
        acpPreference[ "LastProjectDirectory" ],
        If[ MatchQ[ source, _NotebookObject ], Quiet @ NotebookDirectory @ source, None ]
    },
    expr_ :> With[ { dir = acpNormalizeDirectory @ expr }, dir /; StringQ @ dir && DirectoryQ @ dir ],
    None
];

acpDefaultProjectDirectory // endDefinition;


acpNormalizeDirectory // beginDefinition;
acpNormalizeDirectory[ File[ dir_String ] ] := acpNormalizeDirectory @ dir;
acpNormalizeDirectory[ dir_String? StringQ ] /; StringLength @ StringTrim @ dir > 0 := Quiet @ ExpandFileName @ StringTrim @ dir;
acpNormalizeDirectory[ _ ] := None;
acpNormalizeDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpRegisterWindow*)
acpRegisterWindow // beginDefinition;

acpRegisterWindow[ nbo_NotebookObject, dir_, agent_String, settings_Association ] := With[
    {
        window = acpWindowUpdate[
            nbo,
            Function[ old, Join[ old, acpInitialWindowRecord[ nbo, dir, agent, settings ] ] ]
        ]
    },
    acpEnsureWindowSymbols @ nbo;
    window
];

acpRegisterWindow // endDefinition;


acpInitialWindowRecord // beginDefinition;

acpInitialWindowRecord[ nbo_NotebookObject, dir_, agent_String, settings_Association ] := <|
    "Notebook"           -> nbo,
    "Agent"              -> agent,
    "ProjectDirectory"   -> dir,
    "Status"             -> If[ acpValidProjectDirectoryQ @ dir, "Connecting", "NoDirectory" ],
    "Error"              -> None,
    "Connection"         -> None,
    "Session"            -> None,
    "SessionID"          -> None,
    "ResumableSessionID" -> None,
    "AgentInfo"          -> None,
    "Capabilities"       -> None,
    "ConfigOptions"      -> { },
    "PendingConfig"      -> <| |>,
    "Commands"           -> { },
    "MCPReady"           -> False,
    "Usage"              -> None,
    "CurrentTurn"        -> None,
    "Turns"              -> { },
    "PendingPermissions" -> <| |>,
    "Requests"           -> <| |>,
    "LastActivity"       -> AbsoluteTime[ ],
    "Settings"           -> settings,
    "Notice"             -> None,
    "QueuedPrompt"       -> None,
    "QueuedTurn"         -> None,
    "Restore"            -> None,
    "PendingRestore"     -> None
|>;

acpInitialWindowRecord // endDefinition;


acpValidProjectDirectoryQ // beginDefinition;
acpValidProjectDirectoryQ[ dir_String? StringQ ] := TrueQ @ Quiet @ DirectoryQ @ dir;
acpValidProjectDirectoryQ[ _ ] := False;
acpValidProjectDirectoryQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpEnsureWindowRecord*)

(* Kernel state is a cache: after a kernel restart (or for a window created by another session) the window record is
   rebuilt from the notebook's TaggingRules. Returns the window record. *)
acpEnsureWindowRecord // beginDefinition;

(* A record without a "Status" is partial (e.g. created by an unguarded acpWindowSet after a kernel restart); it is
   rebuilt too (acpRebuildWindowRecord keeps its keys and adds the missing ones). *)
acpEnsureWindowRecord[ nbo_NotebookObject ] := Replace[
    acpWindowGet @ nbo,
    Except[ _Association? (KeyExistsQ[ "Status" ]) ] :> acpRebuildWindowRecord @ nbo
];

acpEnsureWindowRecord // endDefinition;


acpRebuildWindowRecord // beginDefinition;

acpRebuildWindowRecord[ nbo_NotebookObject ] := Module[ { dir, agent, settings, record },
    dir      = acpNormalizeDirectory @ acpFE[ nbo, "ProjectDirectory", None ];
    agent    = Replace[ acpFE[ nbo, "Agent", $acpDefaultAgent ], Except[ _String ] -> $acpDefaultAgent ];
    settings = acpPersistedWindowSettings @ acpFE[ nbo, "Settings", <| |> ];
    record   = acpInitialWindowRecord[ nbo, dir, agent, settings ];
    record[ "Status" ] = If[ acpValidProjectDirectoryQ @ dir, "Disconnected", "NoDirectory" ];
    record[ "ResumableSessionID" ] = Replace[ acpFE[ nbo, "ResumableSessionID", None ], Except[ _String ] -> None ];
    acpEnsureWindowSymbols @ nbo;
    acpWindowUpdate[ nbo, Function[ old, If[ KeyExistsQ[ old, "Status" ], old, Join[ old, record ] ] ] ]
];

acpRebuildWindowRecord // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpPersistedWindowSettings*)

(* The explicit agent settings of a window. They are also stored in the notebook's TaggingRules ({"ACP", "Settings"}),
   so a window rebuilt after a kernel restart connects with the same command line and model. *)
$acpPersistedSettingNames = { "ACPAgent", "ACPAgentCommandLine", "ACPModel" };

acpPersistedWindowSettings // beginDefinition;
acpPersistedWindowSettings[ settings_Association ] := KeyTake[ settings, $acpPersistedSettingNames ];
acpPersistedWindowSettings[ rules: { ___Rule } ] := acpPersistedWindowSettings @ Association @ rules;
acpPersistedWindowSettings[ _ ] := <| |>;
acpPersistedWindowSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpEnsureWindowSymbols*)

(* Creates the change symbols tracked by the window's views from a normal (non-Dynamic) evaluation: the front end does
   not track symbols that were created during the evaluation of a DestroyAfterEvaluation DynamicBox (such as the
   toolbar in ACPChat.nb). *)
acpEnsureWindowSymbols // beginDefinition;

acpEnsureWindowSymbols[ nbo_NotebookObject ] := (
    acpWindowSymbol @ nbo;
    Scan[ acpEntitySymbol[ acpWindowKey @ nbo, # ] &, $acpDerivedViewNames ];
    Null
);

acpEnsureWindowSymbols // endDefinition;

$acpDerivedViewNames = { "ConfigMenus", "DirectoryRow", "Footer", "InputArea", "NewChat" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReuseWindow*)
acpReuseWindow // beginDefinition;

acpReuseWindow[ source_, nbo_NotebookObject, settings_Association ] := Enclose[
    Module[ { window, dir, dirChanged, changed },
        acpCheckSession @ nbo;
        window = ConfirmBy[ acpEnsureWindowRecord @ nbo, AssociationQ, "Window" ];
        dir = acpNormalizeDirectory @ Lookup[ settings, "ProjectDirectory", None ];

        (* Explicit agent settings (executable, model) are stored first, so a reconnect below (or the one done by a
           directory change) uses them: *)
        changed = acpMergeWindowSettings[ nbo, settings ];

        (* An explicit project directory for an existing window is applied (unless the agent is busy) *)
        dirChanged = False;
        If[ StringQ @ dir && dir =!= Lookup[ window, "ProjectDirectory" ],
            Which[
                acpRestoringQ @ window,
                    acpSetNotice[ nbo, acpLabel[ "NoticeDirectoryWhileRestoring" ] ],
                acpRunningQ @ window,
                    acpSetNotice[ nbo, acpLabel[ "NoticeDirectoryWhileRunning" ] ],
                True,
                    acpChangeProjectDirectory[ nbo, dir ];
                    dirChanged = True
            ]
        ];

        If[ MatchQ[ source, _NotebookObject ],
            ConfirmMatch[ attachToLeft[ source, nbo ], _NotebookObject, "Attached" ],
            SetSelectedNotebook @ nbo;
            moveToChatInputField[ nbo, True ]
        ];

        acpApplyWindowSettings[ nbo, changed, dirChanged ];
        nbo
    ],
    throwInternalFailure
];

acpReuseWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window Settings*)

(* Merges explicit agent settings into the window record and its TaggingRules. Gives the names of the settings that
   changed. A new "ACPModel" replaces a model chosen in the menu for the next connection. *)
acpMergeWindowSettings // beginDefinition;

acpMergeWindowSettings[ nbo_NotebookObject, settings_Association ] := Module[ { new, old, changed, merged },
    new     = acpPersistedWindowSettings @ settings;
    old     = Replace[ acpWindowGet[ nbo, "Settings", <| |> ], Except[ _Association ] -> <| |> ];
    changed = Select[ Keys @ new, Lookup[ old, #, Automatic ] =!= new[ # ] & ];
    If[ changed === { }, Return[ { }, Module ] ];
    merged = <| old, new |>;
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ], (* never create a partial record *)
                <|
                    w,
                    "Settings" -> merged,
                    If[ MemberQ[ changed, "ACPModel" ], "UserModel" -> None, Nothing ],
                    If[ MemberQ[ changed, "ACPAgent" ] && StringQ @ new[ "ACPAgent" ], "Agent" -> new[ "ACPAgent" ], Nothing ]
                |>,
                Missing[ "NotFound" ]
            ]
        ]
    ];
    acpFESet[ nbo, "Settings", acpPersistedWindowSettings @ merged ];
    If[ MemberQ[ changed, "ACPAgent" ] && StringQ @ new[ "ACPAgent" ], acpFESet[ nbo, "Agent", new[ "ACPAgent" ] ] ];
    changed
];

acpMergeWindowSettings // endDefinition;


(* Applies changed settings (see acpMergeWindowSettings): a new agent or executable (or a window in "Error", e.g. after
   AgentNotFound) reconnects, after the running turn if there is one; a new model is selected in the current session.
   Otherwise the window just makes sure it is connected. dirChanged: the window is already reconnecting for a new
   project directory. *)
acpApplyWindowSettings // beginDefinition;

acpApplyWindowSettings[ nbo_NotebookObject, changed_List, dirChanged_ ] := Module[ { window, modelID, model },
    window = acpWindowGet @ nbo;
    Which[
        ! AssociationQ @ window,
            Null,
        TrueQ @ dirChanged,
            acpEnsureConnected @ nbo,
        MemberQ[ changed, "ACPAgentCommandLine" | "ACPAgent" ] || Lookup[ window, "Status" ] === "Error",
            If[ acpRunningQ @ window || acpRestoringQ @ window,
                acpWindowSet[ nbo, "ReconnectRequested", True ];
                acpSetNotice[ nbo, acpLabel[ "NoticeReconnectAfterTurn" ] ],
                acpReconnect @ nbo
            ],
        MemberQ[ changed, "ACPModel" ],
            model   = Lookup[ Lookup[ window, "Settings", <| |> ], "ACPModel", None ];
            modelID = Replace[ acpConfigOption[ window, "model" ], { o_Association :> Lookup[ o, "id", None ], _ -> None } ];
            If[ StringQ @ model && StringQ @ modelID && ! acpRunningQ @ window,
                acpSetConfigOption[ nbo, modelID, model ] (* deferred while a restored session loads *)
            ];
            acpEnsureConnected @ nbo,
        True,
            acpEnsureConnected @ nbo
    ];
    acpPublish[ ];
    Null
];

acpApplyWindowSettings // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetAgentExecutableAction*)

(* The "Locate OpenCode..." file chooser of AgentNotFound errors: the chosen file becomes the program of the window's
   "ACPAgentCommandLine" setting (with the agent's arguments; kept across kernel restarts) and the window reconnects. *)
acpSetAgentExecutableAction // beginDefinition;

acpSetAgentExecutableAction[ nbo_NotebookObject, path0_ ] := Catch @ Module[ { path },
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    path = Replace[ path0, { File[ p_String ] :> p, p_String :> StringTrim @ p, _ :> Throw @ Null } ];
    If[ path === "", Throw @ Null ];
    If[ ! TrueQ @ Quiet @ FileExistsQ @ path || TrueQ @ Quiet @ DirectoryQ @ path,
        acpSetNotice[ nbo, acpLabel[ "NoticeAgentExecutableMissing", <| "path" -> path |> ] ];
        Throw @ Null
    ];
    acpSetNotice[ nbo, None ];
    acpApplyWindowSettings[ nbo, acpMergeWindowSettings[ nbo, <| "ACPAgentCommandLine" -> path |> ], False ];
    path
];

acpSetAgentExecutableAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCloseWindow*)

(* Programmatic close (e.g. "NewChat" -> True): disconnect first, since programmatic closing does not run the
   notebook's "WindowClose" event action. *)
acpCloseWindow // beginDefinition;

acpCloseWindow[ nbo_NotebookObject ] := (
    acpIsolated @ acpDisconnect[ nbo, "WindowClosed" ];
    acpIsolated @ acpSessionsCloseWindow @ nbo;
    Quiet @ NotebookClose @ nbo;
    acpForgetWindow @ nbo
);

acpCloseWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetWindowInput*)
acpSetWindowInput // beginDefinition;

acpSetWindowInput[ nbo_NotebookObject, input_, evaluate_ ] := (
    If[ validInputStringQ @ input, acpFESet[ nbo, "Input", input ] ];
    (* The prompt is queued if the agent is still connecting: *)
    If[ TrueQ @ evaluate, acpIsolated @ evaluateACPChat @ nbo ];
    nbo
);

acpSetWindowInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpInitializeWindowAction*)

(* Run (via a scheduled task) when the toolbar is first displayed: attaches the input field if it is missing and makes
   sure the agent is connecting. *)
acpInitializeWindowAction // beginDefinition;

acpInitializeWindowAction[ nbo_NotebookObject ] := (
    acpSchedule @ acpInitializeWindow @ nbo;
    Null
);

acpInitializeWindowAction // endDefinition;


acpInitializeWindow // beginDefinition;

acpInitializeWindow[ nbo_NotebookObject ] := Catch @ Module[ { cell },
    If[ ! acpNotebookExistsQ @ nbo, Throw @ Null ];
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    (* e.g. a notebook given the ACPChat stylesheet by hand: the input field would show Inherited *)
    If[ acpFE[ nbo, "Input", Inherited ] === Inherited, acpFESet[ nbo, "Input", "" ] ];
    If[ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ] === { },
        cell = attachWorkspaceChatInput[ nbo, If[ Cells @ nbo === { }, Top, Bottom ] ];
        If[ MatchQ[ cell, _CellObject ],
            FrontEnd`MoveCursorToInputField[ nbo, "AttachedChatInputField", cell, cell ]
        ]
    ];
    acpUpdateWindowTitle @ nbo;
    acpEnsureConnected @ nbo
];

acpInitializeWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowClosed*)

(* NotebookEventActions "WindowClose" (preemptive): only schedule the cleanup (which also closes the window's Sessions
   window). *)
acpWindowClosed // beginDefinition;

acpWindowClosed[ nbo_NotebookObject ] := (
    acpSchedule[ acpDisconnect[ nbo, "WindowClosed" ]; acpForgetWindow @ nbo; acpSessionsCloseWindow @ nbo ];
    Null
);

acpWindowClosed // endDefinition;


acpForgetWindow // beginDefinition;

acpForgetWindow[ nbo_NotebookObject ] := Module[ { turns },
    turns = Select[ Keys @ $acpTurns, acpTurnGet[ #, "Notebook" ] === nbo & ];
    Scan[ acpTurnDrop, turns ];
    acpTurnDrop @ acpWindowKey @ nbo; (* derived view symbols *)
    acpWindowDrop @ nbo;
    $derivedSignatures = KeySelect[ $derivedSignatures, First @ # =!= nbo & ];
    KeyDropFrom[ $windowTitles, Key @ nbo ];
    Null
];

acpForgetWindow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Window Title*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpUpdateWindowTitle*)
If[ ! AssociationQ @ $windowTitles, $windowTitles = <| |> ];

acpUpdateWindowTitle // beginDefinition;

acpUpdateWindowTitle[ nbo_NotebookObject ] := acpUpdateWindowTitle[ nbo, acpWindowGet @ nbo ];

acpUpdateWindowTitle[ nbo_NotebookObject, window_Association ] := Module[ { title },
    title = acpWindowTitleString[
        Lookup[ window, "ProjectDirectory", None ],
        Lookup[ window, "Agent", $acpDefaultAgent ],
        Length @ Lookup[ window, "PendingPermissions", <| |> ] > 0
    ];
    If[ Lookup[ $windowTitles, Key @ nbo ] =!= title,
        $windowTitles[ nbo ] = title;
        Quiet @ SetOptions[ nbo, WindowTitle -> title ]
    ];
    title
];

acpUpdateWindowTitle[ _, _Missing ] := Null;

acpUpdateWindowTitle // endDefinition;


(* The project folder can come from the agent (a session restored from the Sessions window): its name is neutralized *)
acpWindowTitleString // beginDefinition;

acpWindowTitleString[ dir_String, agent_, True ] :=
    acpLabel[ "WindowTitleApproval", <| "project" -> acpNeutralizeLinearSyntax @ FileNameTake @ dir, "agent" -> agent |> ];

acpWindowTitleString[ dir_String, agent_, _ ] :=
    acpLabel[ "WindowTitleProject", <| "project" -> acpNeutralizeLinearSyntax @ FileNameTake @ dir, "agent" -> agent |> ];

acpWindowTitleString[ _, agent_, _ ] :=
    acpLabel[ "WindowTitleNoProject", <| "agent" -> agent |> ];

acpWindowTitleString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Toolbar*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*makeACPChatDockedCell*)

(* ChatbookAction["MakeACPChatDockedCell"] from the ACPChat.nb stylesheet's toolbar DynamicBox (DestroyAfterEvaluation).
   No connection side effects: the Initialization only schedules acpInitializeWindow (attach the input field if
   missing, then acpEnsureConnected), and there is no Deinitialization. *)
makeACPChatDockedCell // beginDefinition;

(* The front end entry point (a preemptive evaluation that may interrupt a Notebook Assistant chat) is isolated (rule
   R3). If building the toolbar fails, a minimal toolbar still initializes the window (input field and connection). *)
makeACPChatDockedCell[ ] := With[ { nbo = EvaluationNotebook[ ] },
    Replace[
        acpIsolated @ makeACPChatDockedCell @ nbo,
        Except[ _Framed ] :> acpFallbackDockedCell @ nbo
    ]
];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
makeACPChatDockedCell[ nbo_NotebookObject ] := Framed[
    DynamicModule[ { },
        Column[
            {
                acpToolbarMainRow @ nbo,
                acpDirectoryRow @ nbo,
                acpStatusRow @ nbo
            },
            Alignment -> Left,
            Spacings  -> { 0, 0.15 }
        ],
        Initialization :> (
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "InitializeWindow", nbo ]
        )
    ],
    Background   -> color @ "NA_Toolbar",
    FrameStyle   -> color @ "NA_Toolbar",
    FrameMargins -> { { 2, 4 }, { 1, 1 } },
    ImageMargins -> 0,
    ImageSize    -> Scaled[ 1 ]
];
(* :!CodeAnalysis::EndBlock:: *)

makeACPChatDockedCell // endDefinition;


acpFallbackDockedCell // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
acpFallbackDockedCell[ nbo_NotebookObject ] := DynamicModule[ { },
    Spacer[ { 0, 0 } ],
    Initialization :> (
        Needs[ "Wolfram`Chatbook`" -> None ];
        Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "InitializeWindow", nbo ]
    )
];
(* :!CodeAnalysis::EndBlock:: *)

acpFallbackDockedCell[ _ ] := Spacer[ { 0, 0 } ];

acpFallbackDockedCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolbarDockedCell*)

(* A fresh toolbar docked cell (used to rebuild the toolbar after a kernel restart). The options match the toolbar cell
   in Developer/Resources/ACPStyles.wl. *)
acpToolbarDockedCell // beginDefinition;

acpToolbarDockedCell[ nbo_NotebookObject ] := Cell[
    BoxData @ ToBoxes @ makeACPChatDockedCell @ nbo,
    CellFrame        -> 0,
    CellFrameMargins -> 0,
    CellMargins      -> { { -1, -5 }, { -1, -1 } },
    CellTags         -> "ACPToolbar",
    Magnification    -> Dynamic @ AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ]
];

acpToolbarDockedCell // endDefinition;


acpRefreshToolbar // beginDefinition;

(* Always sets DockedCells, even if the new toolbar is the same expression: the front end must rebuild the toolbar so
   its Dynamics are evaluated (and track symbols) in this kernel and its DynamicModule state is reset. *)
acpRefreshToolbar[ nbo_NotebookObject ] := Catch @ Module[ { docked, new },
    docked = AbsoluteCurrentValue[ nbo, DockedCells ];
    If[ ! MatchQ[ docked, { ___Cell } ], Throw @ Null ];
    If[ ! MemberQ[ docked, Cell[ ___, CellTags -> "ACPToolbar", ___ ] ], Throw @ Null ];
    new = Replace[ docked, Cell[ ___, CellTags -> "ACPToolbar", ___ ] :> acpToolbarDockedCell @ nbo, { 1 } ];
    contextBlock @ SetOptions[ nbo, DockedCells -> new ]
];

acpRefreshToolbar // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolbarMainRow*)
acpToolbarMainRow // beginDefinition;

acpToolbarMainRow[ nbo_NotebookObject ] := Grid[
    { {
        acpWindowDerivedDynamic[ nbo, "NewChat", acpNewChatSignature, acpNewChatButton ],
        acpSessionsButton @ nbo, (* Sessions.wl *)
        Item[ Spacer[ 0 ], ItemSize -> Fit ],
        acpWindowDerivedDynamic[ nbo, "ConfigMenus", acpConfigMenusSignature, acpConfigMenusView ]
    } },
    Alignment -> { Automatic, Center },
    Spacings  -> 0.2
];

acpToolbarMainRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpNewChatButton*)

(* Disabled while a session is restored (Sessions.wl) *)
acpNewChatSignature // beginDefinition;
acpNewChatSignature[ window_Association ] := acpRestoringQ @ window;
acpNewChatSignature[ _ ] := None;
acpNewChatSignature // endDefinition;


acpNewChatButton // beginDefinition;

acpNewChatButton[ nbo_NotebookObject ] := acpNewChatButton[ nbo, acpWindowGet @ nbo ];

acpNewChatButton[ nbo_NotebookObject, window_ ] := acpActionButton[
    blueHueButtonAppearance[
        acpToolbarButtonLabel[ "WorkspaceToolbarIconNew", acpLabel[ "NewChat" ], acpLabel[ "NewChatTooltip" ] ],
        { Automatic, 24 },
        { { 5, 5 }, { 0, 0 } }
    ],
    { "NewChat", nbo },
    BoxID   -> "ACPNewChatButton",
    Enabled -> ! acpRestoringQ @ window
];

acpNewChatButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpToolbarButtonLabel*)
acpToolbarButtonLabel // beginDefinition;

acpToolbarButtonLabel[ iconName_String, label_, tooltip_ ] := Tooltip[
    Grid[
        { { chatbookIcon[ iconName, False, color @ "NA_BlueHueButtonIcon" ], label } },
        Alignment        -> { Left, Baseline },
        BaselinePosition -> { 1, 2 },
        BaseStyle        -> "NotebookAssistant`Sidebar`ToolbarButtonLabel",
        Spacings         -> { 0.3, 0 }
    ],
    tooltip
];

acpToolbarButtonLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Configuration Menus*)

(* Model, mode and effort menus built from the window's ConfigOptions (raw ACP configOptions). They are native
   ActionMenus (preemptive, they work in docked cells and have native submenus), disabled while a turn is running.
   Selecting an item runs ChatbookAction["ACP", "SetConfigOption", nbo, configId, value]. *)

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpConfigMenusSignature*)
acpConfigMenusSignature // beginDefinition;

acpConfigMenusSignature[ window_Association ] := Append[
    Lookup[ window, { "Status", "ConfigOptions", "PendingConfig", "FailedModels", "CurrentTurn", "Agent" }, None ],
    acpRestoringQ @ window
];

acpConfigMenusSignature[ _ ] := None;

acpConfigMenusSignature // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpConfigMenusView*)
acpConfigMenusView // beginDefinition;

acpConfigMenusView[ nbo_NotebookObject ] := acpConfigMenusView[ nbo, acpWindowGet @ nbo ];

acpConfigMenusView[ nbo_NotebookObject, window_Association ] := Module[ { enabled, menus },
    enabled = ! acpRunningQ @ window && ! acpRestoringQ @ window;
    menus = {
        acpModelMenu[ nbo, window, enabled ],
        acpModeMenu[ nbo, window, enabled ],
        acpEffortMenu[ nbo, window, enabled ]
    };
    If[ menus === { }, Spacer[ 0 ], Row[ menus, Spacer[ 2 ] ] ]
];

acpConfigMenusView[ _, _ ] := Spacer[ 0 ];

acpConfigMenusView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpConfigOption*)

(* The raw config option for a category ("model", "mode", "thought_level") *)
acpConfigOption // beginDefinition;

acpConfigOption[ window_Association, category_String ] := FirstCase[
    Replace[ Lookup[ window, "ConfigOptions", { } ], Except[ _List ] -> { } ],
    opt_Association /; Lookup[ opt, "category" ] === category :> opt,
    FirstCase[
        Replace[ Lookup[ window, "ConfigOptions", { } ], Except[ _List ] -> { } ],
        opt_Association /; Lookup[ opt, "id" ] === Lookup[ $acpConfigCategoryIDs, category ] :> opt,
        Missing[ "NotAvailable", category ]
    ]
];

acpConfigOption // endDefinition;

$acpConfigCategoryIDs = <| "model" -> "model", "mode" -> "mode", "thought_level" -> "effort" |>;

(* Flattened {<|"value", "name", "description"|>...} (option groups are flattened) *)
acpConfigOptionValues // beginDefinition;

acpConfigOptionValues[ opt_Association ] := Flatten[
    Replace[
        Replace[ Lookup[ opt, "options", { } ], Except[ _List ] -> { } ],
        {
            o: KeyValuePattern[ "value" -> _String ] :> { o },
            KeyValuePattern[ "options" -> sub_List ] :> Cases[ sub, KeyValuePattern[ "value" -> _String ] ],
            _ -> { }
        },
        { 1 }
    ],
    1
];

acpConfigOptionValues // endDefinition;

(* The value currently selected (a pending selection wins, so the menu reflects the user's choice immediately) *)
acpConfigCurrentValue // beginDefinition;

acpConfigCurrentValue[ window_Association, opt_Association ] := Lookup[
    Replace[ Lookup[ window, "PendingConfig", <| |> ], Except[ _Association ] -> <| |> ],
    Lookup[ opt, "id" ],
    Lookup[ opt, "currentValue", None ]
];

acpConfigCurrentValue // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpModelMenu*)
acpModelMenu // beginDefinition;

acpModelMenu[ nbo_, window_Association, enabled_ ] :=
    acpModelMenu[ nbo, window, enabled, acpConfigOption[ window, "model" ] ];

acpModelMenu[ nbo_, window_, enabled_, opt_Association ] := Module[
    { id, current, options, values, failed, recent, groups, items, billing },

    id      = Lookup[ opt, "id", "model" ];
    current = acpConfigCurrentValue[ window, opt ];
    options = acpConfigOptionValues @ opt;
    values  = Lookup[ options, "value" ];
    failed  = Replace[ Lookup[ window, "FailedModels", { } ], Except[ _List ] -> { } ];
    recent  = Take[ Select[ acpRecentModels @ Lookup[ window, "Agent", $acpDefaultAgent ], MemberQ[ values, # ] & ], UpTo[ $acpMaxRecentModels ] ];
    billing = acpBillingText @ current;

    groups = GroupBy[ options, acpModelProvider[ #[ "value" ] ] & ];

    items = Flatten @ {
        If[ recent =!= { },
            {
                acpMenuHeader @ acpLabel[ "ModelMenuRecent" ],
                acpModelMenuItem[ nbo, id, #, current, failed, options ] & /@ recent,
                Delimiter
            },
            { }
        ],
        If[ Length @ groups === 1,
            acpModelMenuItem[ nbo, id, #[ "value" ], current, failed, options ] & /@ First @ groups,
            KeyValueMap[
                Function[
                    { provider, opts },
                    acpProviderLabel[ provider, opts ] -> (acpModelMenuItem[ nbo, id, #[ "value" ], current, failed, options ] & /@ opts)
                ],
                groups
            ]
        ]
    };

    acpMenu[
        acpModelShortName[ current, options ],
        items,
        If[ TrueQ @ enabled, acpLabel[ "ModelMenuTooltip", <| "billing" -> billing |> ], acpMenusDisabledTooltip @ window ],
        enabled,
        "ACPModelMenu"
    ]
];

acpModelMenu[ _, _, _, _Missing ] := Nothing;

acpModelMenu // endDefinition;


acpModelMenuItem // beginDefinition;

acpModelMenuItem[ nbo_, id_, value_String, current_, failed_List, options_List ] := acpActionMenuItem[
    acpCheckedLabel[
        If[ MemberQ[ failed, value ],
            acpLabel[ "ModelMenuUnavailable", <| "model" -> acpModelShortName[ value, options ] |> ],
            acpModelShortName[ value, options ]
        ],
        value === current
    ],
    { "SetConfigOption", nbo, id, value }
];

acpModelMenuItem // endDefinition;


(* "openai/gpt-6.1-sol" -> "openai" *)
acpModelProvider // beginDefinition;
acpModelProvider[ value_String ] := If[ StringContainsQ[ value, "/" ], First @ StringSplit[ value, "/", 2 ], "" ];
acpModelProvider[ _ ] := "";
acpModelProvider // endDefinition;


(* Display name without the provider prefix: "openai/GPT-6.1 Sol" -> "GPT-6.1 Sol" *)
acpModelShortName // beginDefinition;

acpModelShortName[ value_String, options_List ] := Module[ { name },
    name = FirstCase[ options, KeyValuePattern @ { "value" -> value, "name" -> n_String } :> n, value ];
    If[ StringContainsQ[ name, "/" ], Last @ StringSplit[ name, "/", 2 ], name ]
];

acpModelShortName[ _, _ ] := acpLabel[ "ModelMenuDefault" ];

acpModelShortName // endDefinition;


(* The label of a provider's submenu, shown once: who pays for its models ("OpenAI (your account)", "Wolfram LLMKit",
   ...) if that is the same for all of them, otherwise the provider's name ("OpenCode" for a mix of free and Zen
   models). *)
acpProviderLabel // beginDefinition;

acpProviderLabel[ provider_String, opts_List ] := Module[ { billing },
    billing = DeleteCases[ DeleteDuplicates[ acpBillingText /@ Cases[ Lookup[ opts, "value", None ], _String ] ], "" ];
    Which[
        MatchQ[ billing, { _String } ], First @ billing,
        provider === "", acpLabel[ "ModelMenuOtherProvider" ],
        True, Lookup[ $acpProviderNames, ToLowerCase @ provider, provider ]
    ]
];

acpProviderLabel // endDefinition;

(* Display names of model providers (brand names, not localized) *)
$acpProviderNames = <|
    "anthropic" -> "Anthropic",
    "google"    -> "Google",
    "llmkit"    -> "Wolfram LLMKit",
    "openai"    -> "OpenAI",
    "opencode"  -> "OpenCode"
|>;


(* acpBillingLabel (Agents.wl) gives e.g. "Wolfram LLMKit", "OpenAI (your account)", "OpenCode (free)" *)
acpBillingText // beginDefinition;

acpBillingText[ value_String ] := Replace[
    acpIsolated @ acpBillingLabel @ value,
    Except[ _String? StringQ ] :> acpModelProvider @ value
];

acpBillingText[ _ ] := "";

acpBillingText // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpModeMenu*)
acpModeMenu // beginDefinition;

acpModeMenu[ nbo_, window_Association, enabled_ ] :=
    acpModeMenu[ nbo, window, enabled, acpConfigOption[ window, "mode" ] ];

acpModeMenu[ nbo_, window_, enabled_, opt_Association ] := Module[ { id, current, options },
    id      = Lookup[ opt, "id", "mode" ];
    current = acpConfigCurrentValue[ window, opt ];
    options = acpConfigOptionValues @ opt;
    If[ Length @ options < 2, Return[ Nothing, Module ] ];
    acpMenu[
        acpOptionName[ current, options ],
        Function[
            o,
            acpActionMenuItem[
                acpCheckedLabel[ Lookup[ o, "name", o[ "value" ] ], o[ "value" ] === current, Lookup[ o, "description", None ] ],
                { "SetConfigOption", nbo, id, o[ "value" ] }
            ]
        ] /@ options,
        If[ TrueQ @ enabled,
            Replace[
                FirstCase[ options, KeyValuePattern @ { "value" -> current, "description" -> d_String } :> d, None ],
                None :> acpLabel[ "ModeMenuTooltip" ]
            ],
            acpMenusDisabledTooltip @ window
        ],
        enabled,
        "ACPModeMenu"
    ]
];

acpModeMenu[ _, _, _, _Missing ] := Nothing;

acpModeMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpEffortMenu*)

(* Only shown if the current model offers at least two effort levels *)
acpEffortMenu // beginDefinition;

acpEffortMenu[ nbo_, window_Association, enabled_ ] :=
    acpEffortMenu[ nbo, window, enabled, acpConfigOption[ window, "thought_level" ] ];

acpEffortMenu[ nbo_, window_, enabled_, opt_Association ] := Module[ { id, current, options },
    id      = Lookup[ opt, "id", "effort" ];
    current = acpConfigCurrentValue[ window, opt ];
    options = acpConfigOptionValues @ opt;
    If[ Length @ options < 2, Return[ Nothing, Module ] ];
    acpMenu[
        acpOptionName[ current, options ],
        Function[
            o,
            acpActionMenuItem[
                acpCheckedLabel[ Lookup[ o, "name", o[ "value" ] ], o[ "value" ] === current ],
                { "SetConfigOption", nbo, id, o[ "value" ] }
            ]
        ] /@ options,
        If[ TrueQ @ enabled,
            Replace[ Lookup[ opt, "description", None ], Except[ _String ] :> acpLabel[ "EffortMenuTooltip" ] ],
            acpMenusDisabledTooltip @ window
        ],
        enabled,
        "ACPEffortMenu"
    ]
];

acpEffortMenu[ _, _, _, _Missing ] := Nothing;

acpEffortMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Menu Helpers*)
acpOptionName // beginDefinition;
acpOptionName[ value_, options_List ] := FirstCase[ options, KeyValuePattern @ { "value" -> value, "name" -> n_String } :> n, ToString @ value ];
acpOptionName // endDefinition;


acpCheckedLabel // beginDefinition;

acpCheckedLabel[ label_, checked_ ] := Row @ {
    Style[ "\[Checkmark]", ShowContents -> TrueQ @ checked ],
    " ",
    Style[ label, PrivateFontOptions -> { "OperatorSubstitution" -> False } ]
};

acpCheckedLabel[ label_, checked_, description_String ] := Tooltip[ acpCheckedLabel[ label, checked ], description ];

acpCheckedLabel[ label_, checked_, _ ] := acpCheckedLabel[ label, checked ];

acpCheckedLabel // endDefinition;


acpMenusDisabledTooltip // beginDefinition;
acpMenusDisabledTooltip[ window_ ] := If[ acpRestoringQ @ window, acpLabel[ "MenusDisabledRestoring" ], acpLabel[ "MenusDisabledTooltip" ] ];
acpMenusDisabledTooltip // endDefinition;


(* ActionMenu has no section headers, so headers are inert items *)
acpMenuHeader // beginDefinition;
acpMenuHeader[ label_ ] := Style[ label, FontColor -> GrayLevel[ 0.5 ], FontSlant -> Italic ] :> Null;
acpMenuHeader // endDefinition;


acpMenu // beginDefinition;

acpMenu[ label_, items_List, tooltip_, enabled_, boxID_String ] := Tooltip[
    ActionMenu[
        blueHueButtonAppearance[
            Grid[
                { {
                    Style[
                        label,
                        "NotebookAssistant`Sidebar`ToolbarButtonLabel",
                        FontColor          -> If[ TrueQ @ enabled, Inherited, GrayLevel[ 0.6 ] ],
                        PrivateFontOptions -> { "OperatorSubstitution" -> False }
                    ],
                    Style[ "\:25be", FontColor -> color @ "NA_BlueHueButtonIcon", FontSize -> 9 ]
                } },
                Alignment        -> { Left, Baseline },
                BaselinePosition -> { 1, 1 },
                Spacings         -> { 0.25, 0 }
            ],
            { Automatic, 24 },
            { { 4, 4 }, { 0, 0 } }
        ],
        items,
        Appearance -> None,
        BoxID      -> boxID,
        Enabled    -> TrueQ @ enabled,
        Method     -> "Preemptive"
    ],
    tooltip
];

acpMenu // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Recent Models*)

(* Recently chosen models per agent (persisted front end preference, cached for the session) *)
If[ ! AssociationQ @ $recentModels, $recentModels = <| |> ];

acpRecentModels // beginDefinition;

acpRecentModels[ agent_String ] := Lookup[
    $recentModels,
    agent,
    $recentModels[ agent ] = Replace[ acpPreference[ { "RecentModels", agent } ], Except[ { ___String } ] -> { } ]
];

acpRecentModels // endDefinition;


acpRememberRecentModel // beginDefinition;

acpRememberRecentModel[ agent_String, value_String ] := Module[ { recent },
    recent = Take[ DeleteDuplicates @ Prepend[ acpRecentModels @ agent, value ], UpTo[ $acpMaxRecentModels + 2 ] ];
    $recentModels[ agent ] = recent;
    acpSchedule @ acpSetPreference[ { "RecentModels", agent }, recent ];
    recent
];

acpRememberRecentModel // endDefinition;


(* Front end preferences under {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP", ...} *)
acpPreference // beginDefinition;
acpPreference[ key_String ] := acpPreference @ { key };
acpPreference[ keys_List ] := Replace[ Quiet @ CurrentValue[ $FrontEnd, Join[ $acpPreferencesPath, keys ] ], Inherited|$Failed -> Missing[ "NotSet" ] ];
acpPreference // endDefinition;

acpSetPreference // beginDefinition;
acpSetPreference[ keys_List, value_ ] := Quiet[ CurrentValue[ $FrontEnd, Join[ $acpPreferencesPath, keys ] ] = value ];
acpSetPreference // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpDirectoryRow*)

(* Folder icon + abbreviated project directory + "Review" (Review.wl; only while the project folder has uncommitted
   changes) + "Change..." (FE-native directory dialog; the setter runs the "SetProjectDirectory" action, disabled while a
   turn is running). *)
acpDirectoryRow // beginDefinition;

acpDirectoryRow[ nbo_NotebookObject ] :=
    acpWindowDerivedDynamic[ nbo, "DirectoryRow", acpDirectoryRowSignature, acpDirectoryRowView ];

acpDirectoryRow // endDefinition;


acpDirectoryRowSignature // beginDefinition;
acpDirectoryRowSignature[ window_Association ] := {
    Lookup[ window, "ProjectDirectory", None ],
    acpRunningQ @ window || acpRestoringQ @ window,
    acpReviewButtonSignature @ window
};
acpDirectoryRowSignature[ _ ] := None;
acpDirectoryRowSignature // endDefinition;


acpDirectoryRowView // beginDefinition;

acpDirectoryRowView[ nbo_NotebookObject ] := acpDirectoryRowView[ nbo, acpWindowGet @ nbo ];

acpDirectoryRowView[ nbo_NotebookObject, window_Association ] := Module[ { dir, running, warning, review, label },
    dir     = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> None ];
    running = acpRunningQ @ window || acpRestoringQ @ window;
    warning = acpDirectoryWarning @ dir;
    review  = acpReviewButton[ nbo, window ];
    (* the folder can come from the agent (a session restored from the Sessions window): neutralized *)
    label   = If[ StringQ @ dir,
        Tooltip[
            Style[
                acpNeutralizeLinearSyntax @ acpAbbreviatePath[ dir, If[ review === Nothing, $acpMaxPathLength, $acpMaxPathLengthReview ] ],
                "WorkspaceChatToolbarTitle",
                FontSize        -> 12,
                LineBreakWithin -> False
            ],
            acpLabel[ "ProjectDirectoryTooltip", <| "path" -> acpNeutralizeLinearSyntax @ dir |> ]
        ],
        Style[ acpLabel[ "ProjectDirectoryNone" ], "WorkspaceChatToolbarTitle", FontSize -> 12, FontSlant -> Italic ]
    ];
    Grid[
        { {
            Pane[ $acpFolderIcon, ImageMargins -> { { 6, 2 }, { 0, 0 } } ],
            label,
            If[ StringQ @ warning, Tooltip[ $acpWarningIcon, warning ], Nothing ],
            Item[ Spacer[ 0 ], ItemSize -> Fit ],
            review,
            acpDirectorySetter[ nbo, dir, running ]
        } },
        Alignment -> { Left, Center },
        Spacings  -> { 0.25, 0 }
    ]
];

acpDirectoryRowView[ _, _ ] := Spacer[ 0 ];

acpDirectoryRowView // endDefinition;


acpDirectorySetter // beginDefinition;

acpDirectorySetter[ nbo_NotebookObject, dir_, running_ ] := With[
    {
        setter = Function[
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "SetProjectDirectory", nbo, # ]
        ]
    },
    FileNameSetter[
        Dynamic[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "ProjectDirectory" } ], setter ],
        "Directory",
        Appearance -> blueHueButtonAppearance[
            Style[
                acpLabel @ If[ StringQ @ dir, "ProjectDirectoryChange", "ProjectDirectoryChoose" ],
                "NotebookAssistant`Sidebar`ToolbarButtonLabel",
                FontColor -> If[ TrueQ @ running, GrayLevel[ 0.6 ], Inherited ]
            ],
            { Automatic, 22 },
            { { 5, 5 }, { 0, 0 } }
        ],
        Enabled     -> ! TrueQ @ running,
        WindowTitle -> acpLabel[ "ProjectDirectoryDialogTitle" ]
    ]
];

acpDirectorySetter // endDefinition;


(* None | warning text *)
acpDirectoryWarning // beginDefinition;

acpDirectoryWarning[ dir_String ] := Which[
    ! TrueQ @ Quiet @ DirectoryQ @ dir,
        acpLabel[ "ProjectDirectoryWarningMissing" ],
    acpSamePathQ[ dir, $HomeDirectory ],
        acpLabel[ "ProjectDirectoryWarningHome" ],
    acpRootDirectoryQ @ dir,
        acpLabel[ "ProjectDirectoryWarningRoot" ],
    True,
        None
];

acpDirectoryWarning[ _ ] := None;

acpDirectoryWarning // endDefinition;


acpSamePathQ // beginDefinition;
acpSamePathQ[ a_String, b_String ] := StringTrim[ ExpandFileName @ a, $PathnameSeparator.. ] === StringTrim[ ExpandFileName @ b, $PathnameSeparator.. ];
acpSamePathQ // endDefinition;


acpRootDirectoryQ // beginDefinition;
acpRootDirectoryQ[ dir_String ] := StringMatchQ[ ExpandFileName @ dir, ("/" | (LetterCharacter ~~ ":")) ~~ ("/" | "\\")... ];
acpRootDirectoryQ // endDefinition;


(* "/home/user/projects/x" -> "~/projects/x"; long paths keep their end (no limit for max = None) *)
acpAbbreviatePath // beginDefinition;

acpAbbreviatePath[ dir_String ] := acpAbbreviatePath[ dir, $acpMaxPathLength ];

acpAbbreviatePath[ dir_String, max_ ] := Module[ { path },
    path = homeAbbreviation @ dir;
    If[ IntegerQ @ max && StringLength @ path > max,
        "\[Ellipsis]" <> StringTake[ path, -(max - 1) ],
        path
    ]
];

acpAbbreviatePath // endDefinition;


(* "~" for the home folder and "~/..." (or "~\...") for paths in it; not for /home/user2 when the home folder is
   /home/user *)
homeAbbreviation // beginDefinition;

homeAbbreviation[ dir_String ] := With[ { home = StringDelete[ $HomeDirectory, ("/" | "\\") ~~ EndOfString ] },
    Which[
        StringLength @ home < 2               , dir,
        dir === home                          , "~",
        StringStartsQ[ dir, home ~~ ("/" | "\\") ], "~" <> StringDrop[ dir, StringLength @ home ],
        True                                  , dir
    ]
];

homeAbbreviation // endDefinition;


$acpFolderIcon := $acpFolderIcon = Graphics[
    {
        color @ "NA_BlueHueButtonIcon",
        Polygon @ { { 0, 0 }, { 1, 0 }, { 1, 0.72 }, { 0.48, 0.72 }, { 0.38, 0.86 }, { 0, 0.86 } }
    },
    AspectRatio      -> 0.8,
    BaselinePosition -> Scaled[ 0.05 ],
    ImageSize        -> { 13, Automatic },
    PlotRangePadding -> None
];

$acpWarningIcon = Style[ "\:26a0", FontColor -> RGBColor[ 0.89, 0.6, 0.0 ], FontSize -> 13 ];

(* Text in the toolbar and input footer (docked/attached cells have no text style of their own) *)
$acpToolbarTextStyle = {
    FontColor          -> LightDarkSwitched[ RGBColor[ "#666666" ], RGBColor[ "#AAAAAA" ] ],
    FontFamily         -> "Source Sans Pro",
    FontSize           -> 12,
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
};

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStatusRow*)

(* Connection status / errors: Rendering.wl's acpToolbarStatusView is a self-contained view that tracks the window *)
acpStatusRow // beginDefinition;

acpStatusRow[ nbo_NotebookObject ] := Pane[
    acpToolbarStatusView @ nbo,
    BaseStyle    -> $acpToolbarTextStyle,
    ImageMargins -> { { 6, 2 }, { 0, 0 } }
];

acpStatusRow // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Input Cell*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpChatInputCell*)

(* The attached input cell of an ACP window. It keeps the conventions other code relies on: style "ChatInputField",
   CellTags "Top"|"Bottom", and an InputField with BoxID "AttachedChatInputField". The input text lives in the
   window's TaggingRules ({"ACP", "Input"}), so typing needs no kernel and the text survives re-attaching the cell and
   kernel restarts. Send/Return and Stop are preemptive. *)
acpChatInputCell // beginDefinition;

acpChatInputCell[ location_String ] := acpChatInputCell[ location, EvaluationNotebook[ ] ];

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::DynamicImageSize:: *)
acpChatInputCell[ location: "Top"|"Bottom", nbo_NotebookObject ] := Cell[
    BoxData @ ToBoxes @ EventHandler[
        Pane[
            Grid[
                {
                    { acpInputTopArea @ nbo },
                    {
                        Framed[
                            Grid[
                                { { acpInputField @ nbo, acpSendStopButton @ nbo } },
                                Alignment        -> { Left, Baseline },
                                BaselinePosition -> { 1, 1 },
                                Spacings         -> { 0, 0 }
                            ],
                            $inputFieldFrameOptions
                        ]
                    },
                    { Item[ acpInputFooter @ nbo, Alignment -> Left ] }
                },
                Alignment -> { Left, Baseline },
                BaseStyle -> { Magnification -> $inputFieldGridMagnification },
                Spacings  -> { 0.5, 0.0 }
            ],
            FrameMargins -> $inputFieldPaneMargins,
            ImageSize    ->
                If[ location === "Top",
                    Dynamic @ {
                        Automatic,
                        AbsoluteCurrentValue[ nbo, { WindowSize, 2 } ] / AbsoluteCurrentValue[ nbo, Magnification ]
                    },
                    Automatic
                ]
        ],
        {
            "ReturnKeyDown" :> (
                Needs[ "Wolfram`Chatbook`" -> None ];
                Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "Send", nbo ]
            )
        },
        Method -> "Preemptive"
    ],
    "ChatInputField",
    Background    -> $inputFieldOuterBackground,
    CellTags      -> location,
    Magnification :> AbsoluteCurrentValue[ FrontEnd`EvaluationNotebook[ ], Magnification ],
    Selectable    -> True
];
(* :!CodeAnalysis::EndBlock:: *)

acpChatInputCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpInputField*)
acpInputField // beginDefinition;

(* The field hint is an Overlay so it stays visible while the text caret is in the empty field. Both the field and
   the hint only use front end values (no kernel evaluation while typing). *)
acpInputField[ nbo_NotebookObject ] := Overlay[
    {
        InputField[
            Dynamic @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Input" } ],
            Boxes,
            Alignment        -> { Automatic, Baseline },
            Appearance       -> "Frameless",
            BaselinePosition -> Baseline,
            BaseStyle        -> {
                "Text",
                "TextStyleInputField",
                FontColor -> LightDarkSwitched @ RGBColor[ "#333333" ],
                FontSize  -> 15,
                FontSlant -> "Plain"
            },
            BoxID            -> "AttachedChatInputField",
            ContinuousAction -> True,
            ImageSize        -> { Scaled[ 1 ], Automatic }
        ],
        PaneSelector[
            { "" -> acpInputFieldHint @ nbo },
            Dynamic @ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Input" } ],
            "",
            ImageSize -> Automatic
        ]
    },
    { 1, 2 },
    1,
    Alignment -> { Left, Baseline }
];

acpInputField // endDefinition;


acpInputFieldHint // beginDefinition;

acpInputFieldHint[ nbo_NotebookObject ] := Row[
    {
        chatbookIcon[ "ChatIconGeneric", False, LightDarkSwitched @ RGBColor[ "#E0F2FC" ], LightDarkSwitched @ RGBColor[ "#128ED1" ], 13 ],
        Style[
            acpLabel[ "InputFieldHint", <| "agent" -> acpWindowAgent @ nbo |> ],
            "Text",
            "TextStyleInputField",
            FontColor       -> LightDarkSwitched @ RGBColor[ "#898989" ],
            FontSize        -> 15,
            FontSlant       -> "Plain",
            LineBreakWithin -> False
        ]
    },
    Spacer @ 0,
    StripOnInput -> True
];

acpInputFieldHint // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpSendStopButton*)

(* Send while idle, Stop while the FE flag {"ACP", "Busy"} is set (front end only, so it is right even if the kernel is
   busy or was quit). *)
acpSendStopButton // beginDefinition;

acpSendStopButton[ nbo_NotebookObject ] := PaneSelector[
    {
        True -> acpActionButton[
            blueHueButtonAppearance[ chatbookIcon[ "StopChatButton", False, 21 ], { 24.5, 24.5 } ],
            { "Stop", nbo },
            BoxID        -> "ACPStopChatButton",
            FrameMargins -> 0
        ]
    },
    (* The front end occasionally misses the reset of this flag right after the final output cell is written, and
       UpdateInterval does not make it redraw; another change of the flag does (see settleBusyFlag). *)
    Dynamic[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "Busy" } ], UpdateInterval -> 1 ],
    acpActionButton[
        blueHueButtonAppearance[ chatbookIcon[ "SendChatArrow", False, color @ "NA_BlueHueButtonIcon", 13 ], { 24.5, 24.5 } ],
        { "Send", nbo },
        BoxID        -> "ACPSendChatButton",
        FrameMargins -> 0
    ],
    Alignment -> { Automatic, Baseline }
];

acpSendStopButton // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpInputTopArea*)

(* Above the input field: the permission panel while permissions are pending (always visible, never re-rendered by
   the transcript), otherwise the queued prompt and notices. *)
acpInputTopArea // beginDefinition;

acpInputTopArea[ nbo_NotebookObject ] :=
    acpWindowDerivedDynamic[ nbo, "InputArea", acpInputAreaSignature, acpInputAreaView ];

acpInputTopArea // endDefinition;


acpInputAreaSignature // beginDefinition;

acpInputAreaSignature[ window_Association ] := {
    Keys @ Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ],
    Lookup[ window, "QueuedPrompt", None ],
    Lookup[ window, "Notice", None ],
    acpRestoringQ @ window
};

acpInputAreaSignature[ _ ] := None;

acpInputAreaSignature // endDefinition;


acpInputAreaView // beginDefinition;

acpInputAreaView[ nbo_NotebookObject ] := acpInputAreaView[ nbo, acpWindowGet @ nbo ];

acpInputAreaView[ nbo_NotebookObject, window_Association ] := Module[ { items },
    items = {
        If[ Length @ Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ] > 0,
            Pane[ acpPermissionPanel @ nbo, ImageMargins -> { { 0, 0 }, { 4, 0 } } ],
            Nothing
        ],
        acpQueuedPromptView[ nbo, Lookup[ window, "QueuedPrompt", None ], acpRestoringQ @ window ],
        acpNoticeView[ nbo, Lookup[ window, "Notice", None ] ]
    };
    If[ items === { }, Spacer[ { 0, 0 } ], Column[ items, Spacings -> 0.3 ] ]
];

acpInputAreaView[ _, _ ] := Spacer[ { 0, 0 } ];

acpInputAreaView // endDefinition;


acpQueuedPromptView // beginDefinition;

(* While a session is restored, a prompt waits for it (see evaluateACPChat) *)
acpQueuedPromptView[ nbo_, prompt_String, restoring_ ] := acpInputNote[
    If[ TrueQ @ restoring,
        acpLabel[ "QueuedPromptRestoring", <| "text" -> acpPreview @ prompt |> ],
        acpLabel[ "QueuedPrompt", <| "text" -> acpPreview @ prompt |> ]
    ],
    acpActionButton[ $acpCloseGlyph, { "CancelQueuedPrompt", nbo }, BoxID -> "ACPCancelQueuedPrompt" ],
    acpLabel[ "QueuedPromptCancel" ]
];

acpQueuedPromptView[ _, _, _ ] := Nothing;

acpQueuedPromptView // endDefinition;


acpNoticeView // beginDefinition;

acpNoticeView[ nbo_, notice_String ] := acpInputNote[
    notice,
    acpActionButton[ $acpCloseGlyph, { "DismissNotice", nbo }, BoxID -> "ACPDismissNotice" ],
    acpLabel[ "NoticeDismiss" ]
];

acpNoticeView[ _, _ ] := Nothing;

acpNoticeView // endDefinition;


acpInputNote // beginDefinition;

acpInputNote[ text_, button_, tooltip_ ] := Framed[
    Grid[
        { { Style[ text, "Text", FontSize -> 12, FontColor -> LightDarkSwitched @ RGBColor[ "#555555" ] ], Tooltip[ button, tooltip ] } },
        Alignment -> { { Left, Right }, Center },
        ItemSize  -> { { Fit, Automatic } },
        Spacings  -> { 0.5, 0 }
    ],
    Background     -> LightDarkSwitched[ RGBColor[ "#F5F5F5" ], RGBColor[ "#2C2C2C" ] ],
    FrameMargins   -> { { 6, 4 }, { 3, 3 } },
    FrameStyle     -> LightDarkSwitched[ RGBColor[ "#E5E5E5" ], RGBColor[ "#3C3C3C" ] ],
    ImageSize      -> Scaled[ 1 ],
    RoundingRadius -> 4
];

acpInputNote // endDefinition;


$acpCloseGlyph = Style[ "\[Times]", FontSize -> 14, FontColor -> GrayLevel[ 0.5 ] ];


acpPreview // beginDefinition;
acpPreview[ text_String ] := With[ { t = StringReplace[ StringTrim @ text, WhitespaceCharacter.. -> " " ] },
    If[ StringLength @ t > $acpQueuedPreviewSize, StringTake[ t, $acpQueuedPreviewSize - 1 ] <> "\[Ellipsis]", t ]
];
acpPreview // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpInputFooter*)

(* Context usage meter (Rendering.wl's acpUsageMeterView, a self-contained view), "Plan mode" badge and billing label *)
acpInputFooter // beginDefinition;

acpInputFooter[ nbo_NotebookObject ] := Pane[
    Row @ {
        acpUsageMeterView @ nbo,
        acpWindowDerivedDynamic[ nbo, "Footer", acpInputFooterSignature, acpInputFooterView ]
    },
    BaseStyle    -> { $acpToolbarTextStyle, FontSize -> 11 },
    ImageMargins -> { { 4, 0 }, { 0, 2 } }
];

acpInputFooter // endDefinition;


acpInputFooterSignature // beginDefinition;

acpInputFooterSignature[ window_Association ] := {
    Lookup[ window, "Usage", None ] =!= None,
    Replace[ acpConfigOption[ window, "mode"  ], o_Association :> acpConfigCurrentValue[ window, o ] ],
    Replace[ acpConfigOption[ window, "model" ], o_Association :> acpConfigCurrentValue[ window, o ] ]
};

acpInputFooterSignature[ _ ] := None;

acpInputFooterSignature // endDefinition;


acpInputFooterView // beginDefinition;

acpInputFooterView[ nbo_NotebookObject ] := acpInputFooterView[ nbo, acpWindowGet @ nbo ];

acpInputFooterView[ _NotebookObject, window_Association ] := Module[ { mode, model, items },
    mode  = acpConfigOption[ window, "mode" ];
    model = acpConfigOption[ window, "model" ];
    items = {
        If[ AssociationQ @ mode && acpConfigCurrentValue[ window, mode ] === "plan", acpPlanModeBadge[ ], Nothing ],
        If[ AssociationQ @ model,
            Replace[ acpBillingText @ acpConfigCurrentValue[ window, model ], { "" -> Nothing, s_String :> acpFooterStyle @ s } ],
            Nothing
        ]
    };
    Which[
        items === { },
            Spacer[ { 0, 0 } ],
        (* Separate from the usage meter if there is one: *)
        Lookup[ window, "Usage", None ] =!= None,
            Row[ Prepend[ items, "" ], acpFooterStyle[ " \[CenterDot] " ] ],
        True,
            Row[ items, acpFooterStyle[ " \[CenterDot] " ] ]
    ]
];

acpInputFooterView[ _, _ ] := Spacer[ { 0, 0 } ];

acpInputFooterView // endDefinition;


acpFooterStyle // beginDefinition;
acpFooterStyle[ expr_ ] := acpFooterStyle[ expr, LightDarkSwitched @ RGBColor[ "#898989" ] ];
acpFooterStyle[ expr_, fontColor_ ] := Style[ expr, FontColor -> fontColor, FontFamily -> "Source Sans Pro", FontSize -> 11 ];
acpFooterStyle // endDefinition;


acpPlanModeBadge // beginDefinition;

acpPlanModeBadge[ ] := Framed[
    acpFooterStyle[ acpLabel[ "PlanModeBadge" ], LightDarkSwitched @ RGBColor[ "#128ED1" ] ],
    Background     -> LightDarkSwitched[ RGBColor[ "#E0F2FC" ], RGBColor[ "#1E3A4C" ] ],
    FrameMargins   -> { { 4, 4 }, { 0, 0 } },
    FrameStyle     -> None,
    RoundingRadius -> 3
];

acpPlanModeBadge // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Dynamic Views*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRenderView*)

(* Dynamic render functions run isolated; a failure renders as nothing (and is logged by acpIsolated). *)
acpRenderView // beginDefinition;

acpRenderView[ f_, nbo_NotebookObject ] := Replace[
    acpIsolated @ f @ nbo,
    _Failure | $Failed | _Missing | Null :> Spacer[ { 0, 0 } ]
];

acpRenderView // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowDerivedDynamic*)

(* A view of part of the window state that re-renders only when that part changes: an invisible watcher Dynamic tracks
   the window symbol and compares a signature of the window record; when it changes, it bumps a separate change symbol
   that the view tracks. This keeps stateful widgets (menus, dialogs, permission buttons) stable while e.g. streaming
   updates bump the window symbol several times per second. (DynamicWrapper is not used because it does not hold its
   update expression.) *)
If[ ! AssociationQ @ $derivedSignatures, $derivedSignatures = <| |> ];

acpWindowDerivedDynamic // beginDefinition;

acpWindowDerivedDynamic[ nbo_NotebookObject, name_String, sigFunction_, viewFunction_ ] :=
    acpWindowDerivedDynamic[
        acpWindowSymbol @ nbo,
        acpEntitySymbol[ acpWindowKey @ nbo, name ],
        nbo,
        name,
        sigFunction,
        viewFunction
    ];

acpWindowDerivedDynamic[ HoldComplete[ w_Symbol ], HoldComplete[ d_Symbol ], nbo_, name_, sigFunction_, viewFunction_ ] :=
    Row @ {
        Dynamic[ w; acpSyncDerivedView[ nbo, name, sigFunction ]; Spacer[ { 0, 0 } ], TrackedSymbols :> { w } ],
        Dynamic[ d; acpRenderView[ viewFunction, nbo ], TrackedSymbols :> { d } ]
    };

acpWindowDerivedDynamic // endDefinition;


acpSyncDerivedView // beginDefinition;

acpSyncDerivedView[ nbo_NotebookObject, name_String, sigFunction_ ] := acpIsolated @ Module[ { sig },
    sig = sigFunction @ acpWindowGet @ nbo;
    If[ Lookup[ $derivedSignatures, Key @ { nbo, name }, $noSignature ] =!= sig,
        $derivedSignatures[ { nbo, name } ] = sig;
        acpBumpSymbol @ acpEntitySymbol[ acpWindowKey @ nbo, name ]
    ];
    Null
];

acpSyncDerivedView // endDefinition;


acpBumpSymbol // beginDefinition;
acpBumpSymbol[ HoldComplete[ s_Symbol ] ] := (s = If[ IntegerQ @ s, s + 1, 1 ]);
acpBumpSymbol // endDefinition;


(* An ID for per-window (non-turn) change symbols *)
acpWindowKey // beginDefinition;
acpWindowKey[ nbo_NotebookObject ] := "ACPWindow-" <> IntegerString[ Hash @ nbo, 36 ];
acpWindowKey // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Sending*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*evaluateACPChat*)

(* Send button / Return key (preemptive, fast): writes the user and active output cells and sends the prompt. While a
   turn is running the prompt is queued; while connecting, the turn starts and is sent when the connection is ready.
   While a session is restored (Sessions.wl), the prompt is queued too: its user cell must come after the restored
   transcript, which is written when the session has loaded. *)
evaluateACPChat // beginDefinition;

evaluateACPChat[ nbo_NotebookObject ] := Enclose[
    Catch @ Module[ { window, input, prompt, status },

        acpCheckSession @ nbo;
        window = ConfirmBy[ acpEnsureWindowRecord @ nbo, AssociationQ, "Window" ];
        input  = acpFE[ nbo, "Input", "" ];
        If[ ! validInputStringQ @ input, Throw @ Null ];

        prompt = ConfirmBy[ acpInputString @ input, StringQ, "Prompt" ];
        status = Lookup[ window, "Status", "Disconnected" ];

        Which[
            status === "NoDirectory",
                acpSetNotice[ nbo, acpLabel[ "NoticeNoDirectory" ] ];
                Throw @ Null,

            status === "Error",
                acpSetNotice[ nbo, acpLabel[ "NoticeCannotSend", <| "reason" -> acpErrorMessage @ window |> ] ];
                Throw @ Null,

            acpRunningQ @ window || acpRestoringQ @ window,
                acpQueuePrompt[ nbo, prompt ];
                Throw @ Null
        ];

        acpStartTurn[ nbo, Dynamic @ CurrentValue[ nbo, { TaggingRules, "ACP", "Input" } ], prompt, status ]
    ],
    throwInternalFailure
];

evaluateACPChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStartTurn*)

(* Writes the user cell (shared with the notebook assistance window), the active output cell with the live view, and
   creates the turn. The prompt is sent now if the agent is ready, otherwise the turn is queued until it is.
   With anchor None (Send button) the user cell is written at the selection like in the notebook assistance window;
   otherwise (queued prompts, sent from scheduled tasks while the user may be typing or selecting) it is written after
   anchor (a cell, or Automatic for the last cell) without touching the selection. *)
acpStartTurn // beginDefinition;

acpStartTurn[ nbo_NotebookObject, inputSpec_Dynamic, prompt_String, status_ ] :=
    acpStartTurn[ nbo, inputSpec, prompt, status, None ];

acpStartTurn[ nbo_NotebookObject, inputSpec_Dynamic, prompt_String, status_, anchor_ ] := Enclose[
    Module[ { window, turnID, userCell, turn, outCell, sendNow },

        window  = ConfirmBy[ acpWindowGet @ nbo, AssociationQ, "Window" ];
        turnID  = ConfirmBy[ "acp-turn-" <> createUUID[ ], StringQ, "TurnID" ];
        sendNow = status === "Ready";

        (* Clears the input and moves the input field to the bottom: *)
        userCell = ConfirmMatch[ acpWriteUserCell[ nbo, inputSpec, prompt, anchor ], _CellObject, "UserCell" ];

        turn = ConfirmBy[
            acpNewTurn @ <|
                "ID"         -> turnID,
                "Notebook"   -> nbo,
                "SessionID"  -> Lookup[ window, "SessionID", None ],
                "Prompt"     -> prompt,
                "InputCell"  -> userCell,
                "OutputCell" -> None,
                "StartTime"  -> AbsoluteTime[ ]
            |>,
            AssociationQ,
            "Turn"
        ];

        (* The turn must exist before the live view is displayed: *)
        ConfirmBy[ acpTurnCreate @ turn, StringQ, "TurnCreate" ];
        outCell = ConfirmMatch[ acpWriteActiveCell[ nbo, userCell, turnID ], _CellObject, "OutputCell" ];
        acpTurnUpdate[ turnID, <| "Turn" -> <| #, "OutputCell" -> outCell |>, "Changed" -> { }, "Layout" -> False |> & ];

        acpFESet[ nbo, "Busy", True ];
        acpWindowUpdate[
            nbo,
            <|
                #,
                "Status"       -> If[ sendNow, "Running", Lookup[ #, "Status", "Disconnected" ] ],
                "CurrentTurn"  -> turnID,
                "Turns"        -> Append[ Replace[ Lookup[ #, "Turns", { } ], Except[ _List ] -> { } ], turnID ],
                "QueuedTurn"   -> If[ sendNow, None, turnID ],
                "Notice"       -> None,
                "LastActivity" -> AbsoluteTime[ ]
            |> &
        ];

        If[ sendNow,
            acpSendPrompt[ nbo, turnID ],
            If[ status =!= "Connecting", acpEnsureConnected @ nbo ]
        ];

        acpPublish[ ];
        turnID
    ],
    throwInternalFailure
];

acpStartTurn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWriteUserCell*)
acpWriteUserCell // beginDefinition;

acpWriteUserCell[ nbo_NotebookObject, inputSpec_Dynamic, _, None ] :=
    writeWorkspaceChatInputCell[ nbo, inputSpec ];

acpWriteUserCell[ nbo_NotebookObject, _, prompt_String, anchor_ ] :=
    acpWriteUserCellAddressed[ nbo, prompt, anchor ];

acpWriteUserCell // endDefinition;


(* The user cell is written after anchor (or after the last cell) with an addressed write: no SelectionMove, no
   selection-based NotebookWrite, no scrolling, so it never lands inside a cell the user clicked into. The input field is
   not touched (a queued prompt was already taken from it). *)
acpWriteUserCellAddressed // beginDefinition;

acpWriteUserCellAddressed[ nbo_NotebookObject, prompt_String, anchor_ ] := Enclose[
    Module[ { location, uuid, cell, cellObject },
        location = If[ MatchQ[ anchor, _CellObject ] && acpCellExistsQ @ anchor, anchor, Last[ Cells @ nbo, None ] ];

        (* An empty window has no cell to write after (and nothing the selection could be inside of): *)
        If[ ! MatchQ[ location, _CellObject ],
            Return[ Module[ { text = prompt }, writeWorkspaceChatInputCell[ nbo, Dynamic @ text ] ], Module ]
        ];

        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        cell = ConfirmMatch[ workspaceChatInputCellExpr[ prompt, uuid ], _Cell, "Cell" ];
        contextBlock @ NotebookWrite[ System`NotebookLocationSpecifier[ location, "After" ], cell, None, AutoScroll -> False ];
        moveChatInputToBottom @ nbo;
        cellObject = ConfirmMatch[ First[ Cells[ nbo, CellTags -> uuid ], $Failed ], _CellObject, "CellObject" ];
        setCurrentValue[ cellObject, CellTags, { } ];
        cellObject
    ],
    throwInternalFailure
];

acpWriteUserCellAddressed // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWriteActiveCell*)

(* The active output cell is written directly after the user cell (addressed write, no selection involved). *)
acpWriteActiveCell // beginDefinition;

acpWriteActiveCell[ nbo_NotebookObject, userCell_CellObject, turnID_String ] := Enclose[
    Module[ { cell },
        cell = ConfirmMatch[ acpActiveCell @ turnID, _Cell, "Cell" ];
        contextBlock @ NotebookWrite[ System`NotebookLocationSpecifier[ userCell, "After" ], cell, None, AutoScroll -> False ];
        ConfirmMatch[ First[ Cells[ nbo, CellTags -> turnID ], $Failed ], _CellObject, "CellObject" ]
    ],
    throwInternalFailure
];

acpWriteActiveCell // endDefinition;


acpActiveCell // beginDefinition;

acpActiveCell[ turnID_String ] := Cell[
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
    CellTags           -> { "ACPActiveTurn", turnID },
    Editable           -> False,
    PrivateCellOptions -> { "TrackScrollingWhenPlaced" -> True },
    Selectable         -> False,
    TaggingRules       -> <|
        "ACPTurnID"            -> turnID,
        "ACPKernelSessionID"   -> $SessionID,
        "ChatNotebookSettings" -> <| "ACPWindow" -> True |>
    |>
];

acpActiveCell // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Queued Prompts*)

(* A prompt sent while a turn is running is queued and sent after the turn is finalized. *)
acpQueuePrompt // beginDefinition;

acpQueuePrompt[ nbo_NotebookObject, prompt_String ] := (
    acpWindowUpdate[
        nbo,
        <| #, "QueuedPrompt" -> If[ StringQ @ #[ "QueuedPrompt" ], #[ "QueuedPrompt" ] <> "\n\n" <> prompt, prompt ] |> &
    ];
    acpFESet[ nbo, "Input", "" ];
    acpPublish[ ]
);

acpQueuePrompt // endDefinition;


acpCancelQueuedPrompt // beginDefinition;

acpCancelQueuedPrompt[ nbo_NotebookObject ] := Module[ { prompt },
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    prompt = acpWindowGet[ nbo, "QueuedPrompt", None ];
    acpWindowSet[ nbo, "QueuedPrompt", None ];
    (* Give the text back if the input field is empty: *)
    If[ StringQ @ prompt && ! validInputStringQ @ acpFE[ nbo, "Input", "" ], acpFESet[ nbo, "Input", prompt ] ];
    acpPublish[ ]
];

acpCancelQueuedPrompt // endDefinition;


(* Sends the queued prompt as a new turn (runs in a scheduled task after finalization, or from housekeeping). The user
   cell is written after anchor (the output cell of the turn that was just finalized) or after the last cell. *)
acpSendQueuedPrompt // beginDefinition;

acpSendQueuedPrompt[ nbo_NotebookObject ] := acpSendQueuedPrompt[ nbo, Automatic ];

acpSendQueuedPrompt[ nbo_NotebookObject, anchor_ ] := Catch @ Module[ { window, prompt, claimed, result },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Null ];
    prompt = Lookup[ window, "QueuedPrompt", None ];
    If[ ! StringQ @ prompt || acpRunningQ @ window || acpRestoringQ @ window || Lookup[ window, "Status" ] =!= "Ready", Throw @ Null ];
    If[ ! acpNotebookExistsQ @ nbo, Throw @ Null ];

    (* Claim the prompt so it is sent only once: *)
    claimed = False;
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "QueuedPrompt" ] === prompt && ! acpRunningQ @ w && ! acpRestoringQ @ w,
                claimed = True; <| w, "QueuedPrompt" -> None |>,
                w
            ]
        ]
    ];
    If[ ! claimed, Throw @ Null ];

    result = acpCatchAll[
        Module[ { text = prompt }, acpStartTurn[ nbo, Dynamic @ text, prompt, "Ready", Replace[ anchor, None -> Automatic ] ] ],
        (acpLog[ "QueuedPromptFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; $Failed) &
    ];

    (* The prompt was claimed but no turn was started: give it back in the input field, so it is not lost (putting it
       back into the queue would make housekeeping retry it every tick). *)
    If[ ! StringQ @ result && ! acpRunningQ @ acpWindowGet @ nbo, acpRestoreInput[ nbo, prompt ] ];
    result
];

acpSendQueuedPrompt // endDefinition;


(* Puts text back into the window's input field (before anything typed since) *)
acpRestoreInput // beginDefinition;

acpRestoreInput[ nbo_NotebookObject, text_String ] := With[ { input = acpFE[ nbo, "Input", "" ] },
    Which[
        ! validInputStringQ @ input, acpFESet[ nbo, "Input", text ],
        StringQ @ input           , acpFESet[ nbo, "Input", text <> "\n\n" <> input ],
        True                      , acpLog[ "QueuedPromptNotRestored", text ] (* never overwrite typed boxes *)
    ];
    acpPublish[ ]
];

acpRestoreInput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Queued Turns*)

(* A turn started while the agent was connecting is sent when the window becomes "Ready", and ends with an error if
   the connection fails (checked by housekeeping). *)
acpSendQueuedTurn // beginDefinition;

acpSendQueuedTurn[ nbo_NotebookObject, turnID_String ] := Module[ { claimed = False, sessionID },
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ w[ "QueuedTurn" ] === turnID && w[ "Status" ] === "Ready",
                claimed = True; <| w, "QueuedTurn" -> None, "Status" -> "Running" |>,
                w
            ]
        ]
    ];
    If[ claimed,
        sessionID = acpWindowGet[ nbo, "SessionID", None ];
        acpTurnUpdate[ turnID, <| "Turn" -> <| #, "SessionID" -> sessionID |>, "Changed" -> { }, "Layout" -> False |> & ];
        acpSendPrompt[ nbo, turnID ]
    ];
    claimed
];

acpSendQueuedTurn // endDefinition;


acpFailQueuedTurn // beginDefinition;

acpFailQueuedTurn[ nbo_NotebookObject, turnID_String ] := Module[ { claimed = False, agent },
    acpWindowUpdate[
        nbo,
        Function[ w, If[ w[ "QueuedTurn" ] === turnID, claimed = True; <| w, "QueuedTurn" -> None |>, w ] ]
    ];
    If[ claimed,
        agent = acpWindowGet[ nbo, "Agent", $acpDefaultAgent ];
        acpEndTurnLocally[
            turnID,
            <| "Error" -> <|
                "Code"    -> "NotConnected",
                "Message" -> acpLabel[ "QueuedTurnFailed", <| "agent" -> agent |> ],
                "Data"    -> acpWindowGet[ nbo, "Error", None ]
            |> |>
        ]
    ];
    claimed
];

acpFailQueuedTurn // endDefinition;


(* Ends a turn without an agent response (queued turns, local Stop) and schedules its finalization. *)
acpEndTurnLocally // beginDefinition;

acpEndTurnLocally[ turnID_String, end_Association ] := (
    acpTurnUpdate[ turnID, acpApplyTurnEnd[ #, end, AbsoluteTime[ ] ] & ];
    acpSchedule @ acpFinalizeTurn @ turnID
);

acpEndTurnLocally // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Finalization*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFinalizeTurn*)

(* Replaces the active output cell of a turn that has ended with the static final cell, resets the busy state, drops
   the live view state, and sends a queued prompt. Scheduled by Connection.wl when the prompt response arrives, with a
   housekeeping fallback (below). Idempotent: the first call claims the turn ("FinalizeClaimed") under PreemptProtect.
   Waits until $acpFinalizeDebounce seconds after the end of the turn, to absorb trailing updates. *)
acpFinalizeTurn // beginDefinition;

acpFinalizeTurn[ turnID_String ] := Catch @ Module[ { turn, delay, claimed, nbo, cell, final },

    turn = acpTurnGet @ turnID;
    If[ ! AssociationQ @ turn || TrueQ @ turn[ "FinalizeClaimed" ], Throw @ Null ];

    delay = acpFinalizeDelay @ turn;
    If[ delay > 0,
        acpSchedule[ acpFinalizeTurn @ turnID, Quantity[ Ceiling[ 1000 * delay ], "Milliseconds" ] ];
        Throw @ Null
    ];

    claimed = AssociationQ @ acpTurnUpdate[ turnID, acpClaimFinalize ];
    If[ ! claimed, Throw @ Null ];

    (* Once the turn is claimed nothing else finalizes it, so everything below must always end in acpFinishTurnState:
       rendering and writing are guarded against any Throw (an untagged Throw would otherwise only be caught by the outer
       Catch and wedge the window in "Running"). *)
    turn = acpTurnGet @ turnID;
    nbo  = Lookup[ turn, "Notebook" ];
    cell = Lookup[ turn, "OutputCell" ];

    (* The cell or window is gone (window closed, New chat, ...): just drop the state *)
    If[ ! acpCellExistsQ @ cell,
        acpFinishTurnState[ turnID, nbo ];
        Throw @ Null
    ];

    final = Replace[ acpCatchAll @ acpRenderFinalCell @ turnID, Except[ _Cell ] :> acpStaticFinalCell[ ] ];

    AbortProtect @ WithCleanup[
        acpCatchAll[ contextBlock @ NotebookWrite[ cell, final, None, AutoScroll -> False ], (acpLog[ "FinalCellWriteFailed", { turnID, ## } ]; $Failed) & ],
        acpFinishTurnState[ turnID, nbo ]
    ];

    (* The user cell of a queued prompt is written after this turn's output cell (addressed write, no selection): *)
    If[ MatchQ[ nbo, _NotebookObject ], acpSendQueuedPrompt[ nbo, cell ] ]
];

acpFinalizeTurn // endDefinition;


acpClaimFinalize // beginDefinition;

acpClaimFinalize[ turn_Association ] :=
    If[ TrueQ @ turn[ "FinalizeClaimed" ],
        Null,
        <|
            "Turn"    -> <| turn, "FinalizeClaimed" -> True, "FinalizeClaimedAt" -> AbsoluteTime[ ], "Status" -> "Finalizing" |>,
            "Changed" -> { },
            "Layout"  -> False
        |>
    ];

acpClaimFinalize // endDefinition;


(* Seconds to wait before finalizing (debounce after the end of the turn) *)
acpFinalizeDelay // beginDefinition;

acpFinalizeDelay[ turn_Association ] := With[ { end = acpAbsoluteTime @ Lookup[ turn, "EndTime", None ] },
    If[ NumberQ @ end, Max[ 0, $acpFinalizeDebounce - (AbsoluteTime[ ] - end) ], 0 ]
];

acpFinalizeDelay // endDefinition;


acpAbsoluteTime // beginDefinition;
acpAbsoluteTime[ t_? NumberQ ] := t;
acpAbsoluteTime[ d_DateObject ] := AbsoluteTime @ d;
acpAbsoluteTime[ _ ] := None;
acpAbsoluteTime // endDefinition;


(* The final cell from Rendering.wl; if rendering fails, retry without front end formatting, then fall back to plain
   text so the active cell is never left behind. *)
acpRenderFinalCell // beginDefinition;

acpRenderFinalCell[ turnID_String ] := Module[ { final },
    final = acpTryFinalCell @ turnID;
    If[ ! MatchQ[ final, _Cell ], final = Block[ { $dynamicText = True }, acpTryFinalCell @ turnID ] ];
    If[ ! MatchQ[ final, _Cell ], final = acpFallbackFinalCell @ turnID ];
    final
];

acpRenderFinalCell // endDefinition;


acpTryFinalCell // beginDefinition;

(* Catches tagged and untagged throws (a Cell thrown untagged is not accepted as the result). *)
acpTryFinalCell[ turnID_String ] := Quiet @ acpCatchAll[
    CheckAbort[ acpFinalCell @ turnID, $Aborted ],
    (acpLog[ "FinalCellFailed", { turnID, ## } ]; $Failed) &
];

acpTryFinalCell // endDefinition;


acpFallbackFinalCell // beginDefinition;

acpFallbackFinalCell[ turnID_String ] := Module[ { turn, text },
    turn = acpTurnGet @ turnID;
    text = Replace[
        Quiet @ acpCatchAll @ acpTurnToMarkdown @ turn,
        Except[ _String ] :> StringRiffle[
            Cases[
                Values @ Replace[ Lookup[ Replace[ turn, Except[ _Association ] -> <| |> ], "Entities", <| |> ], Except[ _Association ] -> <| |> ],
                KeyValuePattern @ { "Type" -> "Message", "Text" -> t_String } :> t
            ],
            "\n\n"
        ]
    ];
    Cell[
        BoxData @ TemplateBox[
            { Cell[ TextData @ { text }, Background -> None, Editable -> True, Selectable -> True ] },
            "AssistantMessageBox"
        ],
        "ChatOutput",
        CellAutoOverwrite -> True,
        GeneratedCell     -> True,
        TaggingRules      -> <| "CellToStringData" -> text, "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>
    ]
];

acpFallbackFinalCell // endDefinition;


(* Last resort if even the fallback cell could not be made: a static note *)
acpStaticFinalCell // beginDefinition;

acpStaticFinalCell[ ] := With[ { text = Replace[ Quiet @ acpCatchAll @ acpLabel[ "FinalCellUnavailable" ], Except[ _String ] -> "" ] },
    Cell[
        BoxData @ TemplateBox[
            { Cell[ TextData @ { text }, Background -> None, Editable -> True, Selectable -> True ] },
            "AssistantMessageBox"
        ],
        "ChatOutput",
        CellAutoOverwrite -> True,
        GeneratedCell     -> True,
        TaggingRules      -> <| "CellToStringData" -> text, "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>
    ]
];

acpStaticFinalCell // endDefinition;


(* Marks the turn done, resets the window's running state and busy flag, and drops the live view state *)
acpFinishTurnState // beginDefinition;

acpFinishTurnState[ turnID_String, nbo_NotebookObject ] := Module[ { pending, window },
    acpTurnUpdate[ turnID, <| "Turn" -> <| #, "Status" -> "Done" |>, "Changed" -> { }, "Layout" -> False |> & ];
    If[ AssociationQ @ acpWindowGet @ nbo,
        (* Permission requests of this turn that are still pending (e.g. one that arrived after Stop, before the prompt
           response) are answered "cancelled": the turn record already shows them cancelled, and neither the agent nor
           the approval panel may wait for them. New ones are refused once the turn is claimed for finalization. *)
        pending = Keys @ Select[ acpPendingPermissions @ acpWindowGet @ nbo, Lookup[ #, "TurnID", None ] === turnID & ];
        Scan[ acpCatchAll[ acpAnswerPermission[ nbo, #, None ] ] &, pending ];
        window = acpWindowUpdate[
            nbo,
            Function[ w,
                <|
                    w,
                    "PendingPermissions" -> Select[ acpPendingPermissions @ w, Lookup[ #, "TurnID", None ] =!= turnID & ],
                    If[ Lookup[ w, "CurrentTurn" ] === turnID,
                        Sequence @@ {
                            "CurrentTurn" -> None,
                            "QueuedTurn"  -> If[ Lookup[ w, "QueuedTurn" ] === turnID, None, Lookup[ w, "QueuedTurn", None ] ],
                            "Status"      -> If[ Lookup[ w, "Status" ] === "Running", "Ready", Lookup[ w, "Status" ] ]
                        },
                        Nothing
                    ]
                |>
            ]
        ];
        If[ Lookup[ window, "CurrentTurn", None ] === None,
            acpFESet[ nbo, "Busy", False ];
            acpSchedule[ settleBusyFlag @ nbo, Quantity[ 500, "Milliseconds" ] ]
        ];
        If[ pending =!= { }, acpUpdateWindowTitle @ nbo ];
        (* The turn may have changed files: check the project's uncommitted changes (Git.wl) *)
        acpGitMarkStale @ nbo;
        (* The session moved to the top of the agent's list and may have a (new) title (Sessions.wl) *)
        acpSessionsNoteTurnEnd @ nbo
    ];
    acpTurnDrop @ turnID;
    acpPublish[ ];
    Null
];

acpFinishTurnState[ turnID_String, _ ] := (acpTurnDrop @ turnID; Null);

acpFinishTurnState // endDefinition;


(* The front end occasionally misses the reset of the busy flag at the end of a turn and keeps showing the Stop button,
   UpdateInterval notwithstanding; another change of the flag makes it redraw. So once the window has settled, an idle
   flag is changed from False to None (both mean idle). *)
settleBusyFlag // beginDefinition;

settleBusyFlag[ nbo_NotebookObject ] := If[
    acpWindowAliveQ @ nbo && acpWindowGet[ nbo, "CurrentTurn", None ] === None && acpFE[ nbo, "Busy", None ] === False,
    acpFESet[ nbo, "Busy", None ]
];

settleBusyFlag // endDefinition;


acpPendingPermissions // beginDefinition;
acpPendingPermissions[ window_Association ] := Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ];
acpPendingPermissions[ _ ] := <| |>;
acpPendingPermissions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Other Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStopAction*)

(* Stop button (preemptive). A turn that was never sent (still waiting for the connection) is ended locally;
   otherwise Connection.wl cancels the prompt. *)
acpStopAction // beginDefinition;

acpStopAction[ nbo_NotebookObject ] := Catch @ Module[ { window, turnID },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    turnID = Lookup[ window, "CurrentTurn", None ];

    (* Nothing is running (e.g. the kernel was restarted): reset the flag *)
    If[ ! StringQ @ turnID || ! AssociationQ @ acpTurnGet @ turnID,
        acpFESet[ nbo, "Busy", False ];
        Throw @ Null
    ];

    If[ Lookup[ window, "QueuedTurn" ] === turnID,
        acpWindowSet[ nbo, "QueuedTurn", None ];
        acpTurnUpdate[ turnID, <| #, "ClientCancel" -> "Stop" |> & ];
        acpEndTurnLocally[ turnID, <| "StopReason" -> "cancelled" |> ],
        acpStop @ nbo
    ];
    acpPublish[ ]
];

acpStopAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNewChat*)

(* New chat (preemptive): stop a running turn, clear the cells, move the input to the top, start a new session. Ignored
   while a session is restored (the button is disabled then). *)
acpNewChat // beginDefinition;

acpNewChat[ nbo_NotebookObject ] := Catch[
    acpCheckSession @ nbo;
    If[ acpRestoringQ @ acpEnsureWindowRecord @ nbo, Throw @ Null ];
    If[ acpRunningQ @ acpWindowGet @ nbo, acpStopAction @ nbo ];
    acpWindowUpdate[ nbo, <| #, "QueuedPrompt" -> None, "Notice" -> None, "Turns" -> { } |> & ];
    NotebookDelete @ Cells @ nbo;
    CurrentValue[ nbo, { TaggingRules, "ChatNotebookSettings", "ConversationUUID" } ] = createUUID[ ];
    moveChatInputToTop @ nbo;
    acpNewSession @ nbo;
    acpPublish[ ];
    Null
];

acpNewChat // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPermissionResponseAction*)
acpPermissionResponseAction // beginDefinition;

acpPermissionResponseAction[ nbo_NotebookObject, reqID_, optionID_ ] := (
    acpCheckSession @ nbo;
    acpAnswerPermission[ nbo, reqID, optionID ];
    acpUpdateWindowTitle @ nbo;
    acpPublish[ ]
);

acpPermissionResponseAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetConfigOptionAction*)
acpSetConfigOptionAction // beginDefinition;

acpSetConfigOptionAction[ nbo_NotebookObject, id_String, value_ ] := Catch @ Module[ { window },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    If[ acpRunningQ @ window || acpRestoringQ @ window, Throw @ Null ];
    acpSetConfigOption[ nbo, id, value ];
    If[ StringQ @ value && Replace[ acpConfigOption[ window, "model" ], { o_Association :> Lookup[ o, "id" ], _ -> None } ] === id,
        acpRememberRecentModel[ Lookup[ window, "Agent", $acpDefaultAgent ], value ]
    ];
    acpPublish[ ]
];

acpSetConfigOptionAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetProjectDirectoryAction*)
acpSetProjectDirectoryAction // beginDefinition;

acpSetProjectDirectoryAction[ nbo_NotebookObject, dir0_ ] := Catch @ Module[ { window, dir },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    dir = acpNormalizeDirectory @ dir0;
    If[ ! acpValidProjectDirectoryQ @ dir || dir === Lookup[ window, "ProjectDirectory" ], Throw @ Null ];
    If[ acpRestoringQ @ window,
        acpSetNotice[ nbo, acpLabel[ "NoticeDirectoryWhileRestoring" ] ];
        Throw @ Null
    ];
    If[ acpRunningQ @ window,
        acpSetNotice[ nbo, acpLabel[ "NoticeDirectoryWhileRunning" ] ];
        Throw @ Null
    ];
    acpChangeProjectDirectory[ nbo, dir ]
];

acpSetProjectDirectoryAction // endDefinition;


(* Connection.wl does the work (disconnect, clear the chat, persist, reconnect). The window title and the input field
   location follow. extra: see acpSetProjectDirectory (Sessions.wl restores a session of another folder this way). *)
acpChangeProjectDirectory // beginDefinition;

acpChangeProjectDirectory[ nbo_NotebookObject, dir_String ] := acpChangeProjectDirectory[ nbo, dir, <| |> ];

acpChangeProjectDirectory[ nbo_NotebookObject, dir_String, extra_Association ] := (
    If[ extra === <| |>, acpSetProjectDirectory[ nbo, dir ], acpSetProjectDirectory[ nbo, dir, extra ] ];
    acpSetNotice[ nbo, None ];
    If[ $FrontEnd =!= Null && Quiet @ Cells @ nbo === { }, moveChatInputToTop @ nbo ];
    acpUpdateWindowTitle @ nbo;
    acpPublish[ ];
    Null
);

acpChangeProjectDirectory // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReconnectAction*)
acpReconnectAction // beginDefinition;

acpReconnectAction[ nbo_NotebookObject ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    acpSetNotice[ nbo, None ];
    acpReconnect @ nbo;
    acpPublish[ ]
);

acpReconnectAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorAction*)

(* Actions offered by error views (Rendering.wl's acpErrorView), see the "Actions" of window/turn errors *)
acpErrorAction // beginDefinition;

acpErrorAction[ nbo_NotebookObject, "Reconnect"       ] := acpReconnectAction @ nbo;
acpErrorAction[ nbo_NotebookObject, "ChooseModel"     ] := acpSetNotice[ nbo, acpLabel[ "NoticeChooseModel" ] ];
acpErrorAction[ nbo_NotebookObject, "SignIn"          ] := acpSetNotice[ nbo, acpLabel[ "NoticeSignIn" ] ];
acpErrorAction[ nbo_NotebookObject, "LocateAgent"     ] := acpSetNotice[ nbo, acpLabel[ "NoticeLocateAgent" ] ];
acpErrorAction[ nbo_NotebookObject, "ChooseDirectory" ] := acpSetNotice[ nbo, acpLabel[ "NoticeNoDirectory" ] ];
acpErrorAction[ nbo_NotebookObject, "Dismiss"         ] := acpSetNotice[ nbo, None ];
acpErrorAction[ _NotebookObject  , action_           ] := (acpLog[ "UnknownErrorAction", action ]; Null);

acpErrorAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetNotice*)
acpSetNotice // beginDefinition;

acpSetNotice[ nbo_NotebookObject, notice: _String | None ] := (
    If[ AssociationQ @ acpWindowGet @ nbo, acpWindowSet[ nbo, "Notice", notice ] ];
    acpPublish[ ];
    Null
);

acpSetNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Kernel Restarts*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpMarkOrphanCells*)

(* Called by acpCheckSession when a window was owned by another kernel session: active output cells of that session
   are replaced by a static note, and the toolbar and input field are rebuilt so their views track this kernel's
   state. *)
acpMarkOrphanCells // beginDefinition;

acpMarkOrphanCells[ nbo_NotebookObject ] := (
    Scan[
        contextBlock @ NotebookWrite[ #, acpInterruptedCell[ ], None, AutoScroll -> False ] &,
        Cells[ nbo, CellTags -> "ACPActiveTurn" ]
    ];
    acpRefreshWindowUI @ nbo;
    Null
);

acpMarkOrphanCells // endDefinition;


acpInterruptedCell // beginDefinition;

acpInterruptedCell[ ] := With[ { text = acpLabel[ "InterruptedKernelRestart" ] },
    Cell[
        BoxData @ TemplateBox[
            { Cell[ TextData @ { StyleBox[ text, FontSlant -> Italic ] }, Background -> None, Editable -> True, Selectable -> True ] },
            "AssistantMessageBox"
        ],
        "ChatOutput",
        CellAutoOverwrite -> True,
        GeneratedCell     -> True,
        TaggingRules      -> <| "CellToStringData" -> text, "ChatNotebookSettings" -> <| "ACPWindow" -> True |> |>
    ]
];

acpInterruptedCell // endDefinition;


acpRefreshWindowUI // beginDefinition;

acpRefreshWindowUI[ nbo_NotebookObject ] := Module[ { location },
    location = If[ Cells @ nbo === { }, Top, Bottom ];
    NotebookDelete @ Cells[ nbo, AttachedCell -> True, CellStyle -> "ChatInputField" ];
    attachWorkspaceChatInput[ nbo, location ];
    acpRefreshToolbar @ nbo;
    (* An open Sessions window is rebuilt too (Sessions.wl); scheduled, so the window record exists by then *)
    acpSchedule @ acpSessionsRecover @ nbo;
    Null
];

acpRefreshWindowUI // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Housekeeping*)

(* Runs with the publisher task (every tick while connections exist or turns run):
     * sends turns that were waiting for the connection, or ends them if the connection failed
     * finalizes turns that ended but were not finalized (fallback for a lost finalization task)
     * sends queued prompts that were not sent after finalization
     * keeps window titles up to date ("Approval needed" while a permission is pending) *)
acpUIHousekeeping // beginDefinition;

acpUIHousekeeping[ ] := (
    KeyValueMap[ acpWindowHousekeeping, $acpWindows ];
    KeyValueMap[ acpTurnHousekeeping, $acpTurns ];
    Null
);

acpUIHousekeeping // endDefinition;


acpWindowHousekeeping // beginDefinition;

acpWindowHousekeeping[ nbo_NotebookObject, window_Association ] := acpIsolated[
    Replace[
        { Lookup[ window, "QueuedTurn", None ], Lookup[ window, "Status", None ] },
        {
            { id_String, "Ready" } :> acpSendQueuedTurn[ nbo, id ],
            { id_String, "Error"|"NoDirectory" } :> acpFailQueuedTurn[ nbo, id ]
        }
    ];
    If[ StringQ @ Lookup[ window, "QueuedPrompt", None ] && Lookup[ window, "Status" ] === "Ready" && ! acpRunningQ @ window,
        acpSchedule @ acpSendQueuedPrompt @ nbo
    ];
    (* New agent settings given while a turn was running (acpApplyWindowSettings): *)
    If[ TrueQ @ Lookup[ window, "ReconnectRequested", False ] && ! acpRunningQ @ window && ! acpRestoringQ @ window,
        acpWindowSet[ nbo, "ReconnectRequested", False ];
        acpReconnect @ nbo
    ];
    acpUpdateWindowTitle[ nbo, window ]
];

acpWindowHousekeeping[ _, _ ] := Null;

acpWindowHousekeeping // endDefinition;


acpTurnHousekeeping // beginDefinition;

acpTurnHousekeeping[ turnID_String, turn_Association ] := With[
    {
        end     = acpAbsoluteTime @ Lookup[ turn, "EndTime", None ],
        claimed = acpAbsoluteTime @ Lookup[ turn, "FinalizeClaimedAt", None ]
    },
    Which[
        NumberQ @ end && ! TrueQ @ turn[ "FinalizeClaimed" ] && AbsoluteTime[ ] - end > $acpFinalizeFallback,
            acpIsolated @ acpFinalizeTurn @ turnID,
        (* Fallback (R5) for a finalization that never finished (e.g. its task was lost after the claim): *)
        TrueQ @ turn[ "FinalizeClaimed" ] && NumberQ @ claimed && AbsoluteTime[ ] - claimed > $acpFinalizeTimeout,
            acpIsolated @ acpForceFinishTurn @ turnID
    ]
];

acpTurnHousekeeping[ _, _ ] := Null;

acpTurnHousekeeping // endDefinition;


(* Ends a turn whose finalization was claimed but never completed: a static final cell replaces the live view (if it is
   still there) and the turn state is finished. *)
acpForceFinishTurn // beginDefinition;

acpForceFinishTurn[ turnID_String ] := Module[ { turn, nbo, cell },
    turn = acpTurnGet @ turnID;
    If[ ! AssociationQ @ turn, Return[ Null, Module ] ];
    acpLog[ "FinalizeTimeout", turnID ];
    nbo  = Lookup[ turn, "Notebook", None ];
    cell = Lookup[ turn, "OutputCell", None ];
    AbortProtect @ WithCleanup[
        If[ acpCellExistsQ @ cell,
            acpCatchAll @ contextBlock @ NotebookWrite[ cell, Replace[ acpCatchAll @ acpFallbackFinalCell @ turnID, Except[ _Cell ] :> acpStaticFinalCell[ ] ], None, AutoScroll -> False ]
        ],
        acpFinishTurnState[ turnID, nbo ]
    ]
];

acpForceFinishTurn // endDefinition;


acpRegisterHousekeeping[ "ACPUI", acpUIHousekeeping, 1 ];

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Utilities*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpRunningQ*)
acpRunningQ // beginDefinition;
acpRunningQ[ window_Association ] := StringQ @ Lookup[ window, "CurrentTurn", None ];
acpRunningQ[ _ ] := False;
acpRunningQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWindowAgent*)
acpWindowAgent // beginDefinition;
acpWindowAgent[ nbo_NotebookObject ] := Replace[ acpWindowGet[ nbo, "Agent", $acpDefaultAgent ], Except[ _String ] -> $acpDefaultAgent ];
acpWindowAgent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpErrorMessage*)
acpErrorMessage // beginDefinition;

acpErrorMessage[ window_Association ] := Replace[
    Lookup[ window, "Error", None ],
    {
        KeyValuePattern[ "Message" -> msg_String ] :> msg,
        _ :> acpLabel[ "NoticeNotConnected" ]
    }
];

acpErrorMessage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpInputString*)

(* The prompt text for the agent *)
(* The prompt text for the agent. Box input from the input field is first made text-like (the same way as the user
   message cell), so e.g. "x+y" is not reformatted as an expression. *)
acpInputString // beginDefinition;

acpInputString[ input_String ] := input;

acpInputString[ boxes_ ] := Replace[
    Replace[
        makeBoxesInputMoreTextLike @ boxes,
        {
            text_String     :> text,
            text_TextData   :> CellToString @ Cell[ text, "Text" ],
            Cell[ b_, ___ ] :> CellToString @ Cell[ BoxData @ b, "Text" ]
        }
    ],
    Except[ _String ] :> ToString @ DisplayForm @ boxes
];

acpInputString // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Front End Objects*)
acpNotebookExistsQ // beginDefinition;
acpNotebookExistsQ[ nbo_NotebookObject ] := MemberQ[ Notebooks[ ], nbo ];
acpNotebookExistsQ[ _ ] := False;
acpNotebookExistsQ // endDefinition;

acpCellExistsQ // beginDefinition;
acpCellExistsQ[ cell_CellObject ] := MatchQ[ Quiet @ ParentNotebook @ cell, _NotebookObject ];
acpCellExistsQ[ _ ] := False;
acpCellExistsQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
