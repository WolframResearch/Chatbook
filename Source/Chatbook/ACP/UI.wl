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
(* The window's width at magnification 1: wider than the Notebook Assistant's ($workspaceChatWidth). attachToLeft scales it
   with the source notebook's magnification and caps it to the display (attachedWindowWidth), each time the window is
   shown from a notebook (the width and zoom are reset then, as in the Notebook Assistant). *)
$acpWindowWidth      := $acpWindowWidth = Switch[ $OperatingSystem, "MacOSX", 600, _, 480 ];
$acpStyleSheet        = FrontEnd`FileName[ { "Wolfram" }, "ACPChat.nb", CharacterEncoding -> "UTF-8" ];
$acpDefaultAgent      = "OpenCode";
$acpFinalizeDebounce  = 0.2;  (* seconds to wait after the end of a turn for trailing updates *)
(* Finalization waits for the front end to show the frozen live view (acpFrozenViewPendingQ): *)
$acpFreezeSettle      = 0.15; (* seconds after the frozen view was rendered *)
$acpFreezeTimeout     = 5;    (* seconds after which the final cell is written without that *)
$acpFreezePoll        = Quantity[ 50, "Milliseconds" ];
$acpFinalizeFallback  = 1.0;  (* seconds after which housekeeping finalizes a turn that ended but was not finalized *)
$acpFinalizeTimeout   = 30;   (* seconds after which housekeeping finishes a turn whose finalization never completed *)
$acpMaxRecentModels   = 3;
$acpPreferencesPath   = { PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP" };
$acpMaxPathLength     = 42;  (* acpAbbreviatePath's default *)
$acpFolderLabelMaxLength = 200; (* the folder row's label in the kernel (the front end cuts it to the room) *)
$acpQueuedPreviewSize = 80;
$acpPrepareTimeout    = 180;  (* seconds after which housekeeping cancels a preparation of attachments (Attachments.wl),
                                 also of a prompt notebook's message (PromptNotebook.wl) *)

(* UI-owned keys in window records (in addition to the ones described in docs/acp-window.md, "State model"):
     "Settings"     -> explicit ShowNotebookAssistance settings ("ACPAgent", "ACPAgentCommandLine", "ACPModel", ...)
     "Notice"       -> None | String: a transient message shown above the input field; or <| "Text", "Command" |>: a
                       message with a terminal command below it (shown as typed, with "Copy command"; see acpNoticeView)
     "QueuedPrompt" -> None | { <| "Text" -> String, "Attachments" -> { prepared attachments }, "At" -> time |>... }:
                       the messages sent while a turn was running, in the order of their Send clicks ("At"); sent after
                       the turn is finalized, merged into as few turns as the caps of one message allow (see
                       acpQueuePrompt). A String or one <| "Text", "Attachments" |> is read as one message. Their text and
                       the references of their attachments are also in the TaggingRules ({"ACP", "QueuedPrompt"}), so a
                       kernel restart puts them back into the draft.
     "QueuedTurn"   -> None | turnID: a turn that was started before the connection was ready
     "Attachments"  -> the draft's attachments: references (Attachments.wl), also in the TaggingRules
     "Preparing"    -> None | <| "Token", "StartedAt", "Input", "Text", "Attachments" (references) |>: a message whose
                       attachments a main link job prepares (Attachments.wl); also in the TaggingRules
                       ({"ACP", "PreparingPrompt"}, without the token)
   UI-owned keys in turn records:
     "Attachments"       -> the prepared attachments of the message (Attachments.wl's acpPromptBlocks sends them)
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
    "WindowTitleProjectRemote"       -> "`project` on `host` \[LongDash] `agent`",
    "WindowTitleApprovalRemote"      -> "Approval needed \[LongDash] `project` on `host`",
    "NewChat"                        -> "New",
    "NewChatTooltip"                 -> "Start a new chat",
    "SessionsButtonLabel"            -> "Sessions", (* Sessions.wl's toolbar button; the main row measures it *)
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
    "ProjectDirectoryChoose"         -> "Choose folder\[Ellipsis]",
    "ProjectDirectoryTooltip"        -> "Project folder: `path`",
    "ProjectDirectoryClickToChange"  -> "Click to choose another folder",
    "ProjectDirectoryDialogTitle"    -> "Choose a project folder",
    "ProjectDirectoryWarningHome"    -> "This is your home folder: the agent can read and change everything in it.",
    "ProjectDirectoryWarningRoot"    -> "This is a filesystem root: the agent can read and change everything in it.",
    "ProjectDirectoryWarningMissing" -> "This folder does not exist.",
    "ProjectDirectoryTooltipRemote"  -> "Project folder on `host`: `path`",
    "ProjectDirectoryNoneRemote"     -> "No project folder on `host`",
    "ProjectDirectoryWarningHomeRemote"    -> "This is your home folder on `host`: the agent can read and change everything in it.",
    "ProjectDirectoryWarningRootRemote"    -> "This is the root folder of `host`: the agent can read and change everything on it.",
    "ProjectDirectoryWarningMissingRemote" -> "This folder doesn't exist on `host`.",
    "InputFieldHint"                 -> "Ask `agent` to do something\[Ellipsis]",
    "AttachButtonTooltip"            -> "Attach notebooks or files",
    "AttachMenuNotebooks"            -> "Open notebooks",
    "AttachMenuNoNotebooks"          -> "No notebooks are open.",
    "AttachMenuMoreNotebooks"        -> "and `n` more",
    "AttachMenuFile"                 -> "File\[Ellipsis]",
    "AttachMenuFileLocal"            -> "File on this computer\[Ellipsis]",
    "AttachFileDialogTitle"          -> "Attach files",
    "AttachmentRemove"               -> "Remove",
    "AttachmentNotebook"             -> "Notebook",
    "AttachmentFile"                 -> "File",
    "AttachmentImage"                -> "Image",
    "AttachmentCells"                -> "`n` cells",
    "AttachmentCellsOne"             -> "1 cell",
    "AttachmentImages"               -> "`n` images",
    "AttachmentImagesOne"            -> "1 image",
    "AttachmentBytes"                -> "`n` bytes",
    "AttachmentKilobytes"            -> "`n` kB",
    "AttachmentMegabytes"            -> "`n` MB",
    "AttachmentsPreparing"           -> "Preparing `n` attachments\[Ellipsis]",
    "AttachmentsPreparingOne"        -> "Preparing the attachment\[Ellipsis]",
    "UserCellAttachmentNotebook"     -> "[Attached notebook: `name`]",
    "UserCellAttachmentFile"         -> "[Attached file: `name`]",
    "UserCellAttachmentImage"        -> "[Attached image: `name`]",
    "PromptNotebookButtonTooltip"    -> "Write the message in a notebook",
    "PromptNotebookTitle"            -> "Prompt notebook",
    "PromptNotebookTarget"           -> "`agent` \[CenterDot] `folder`",
    "PromptNotebookNoFolder"         -> "no project folder",
    "PromptNotebookNotLinked"        -> "Not linked to an agent window",
    "PromptNotebookOpenWindow"       -> "Open agent window",
    "PromptNotebookOpenWindowTooltip" -> "Show the agent window and link this notebook to it",
    "PromptNotebookSend"             -> "Send",
    "PromptNotebookSendTooltip"      -> "Send the whole notebook as one message",
    "PromptNotebookCancel"           -> "Cancel",
    "PromptNotebookHint"             -> "Send sends the whole notebook as one message. The notebook stays open, so you can change it and send it again.",
    "PromptNotebookWorking"          -> "`agent` is working: Send queues the message.",
    "PromptNotebookPreparing"        -> "Preparing the message\[Ellipsis]",
    "PromptNotebookQueued"           -> "Queued: sent when `agent` is done.",
    "PromptNotebookSent"             -> "Sent at `time`.",
    "PromptNotebookNotSent"          -> "Not sent.",
    "PromptNotebookNotSentReason"    -> "Not sent. `reason`",
    "PromptNotebookRetargeted"       -> "This notebook now goes to `target`. Click Send again to send it there.",
    "PromptNotebookNoWindow"         -> "No agent window is open.",
    "PromptNotebookEmpty"            -> "The notebook is empty.",
    "PromptNotebookFailed"           -> "The notebook could not be converted.",
    "PromptNotebookRemoved"          -> "The queued message was removed.",
    "PromptNotebookNewChat"          -> "The agent window switched to another chat.",
    "PromptNotebookTimeout"          -> "Preparing the message took too long.",
    "PromptNotebookInterrupted"      -> "The kernel was restarted.",
    "PromptNotebookWindowClosed"     -> "The agent window was closed.",
    "QueuedPrompt"                   -> "Queued, sent when the agent is done: `text`",
    "QueuedPromptRestoring"          -> "Queued, sent when the session is loaded: `text`",
    "QueuedPromptCancel"             -> "Remove the queued message",
    "QueuedPromptAttachments"        -> "+`n` attachments",
    "QueuedPromptAttachmentsOne"     -> "+1 attachment",
    "NoticeDismiss"                  -> "Dismiss",
    "PlanModeBadge"                  -> "Plan mode",
    "NoticeNoDirectory"              -> "Choose a project folder first.",
    "NoticeCannotSend"               -> "Can't send the message: `reason`",
    "NoticeNotConnected"             -> "the agent is not connected.",
    "NoticePreparing"                -> "The attachments of the last message are still being prepared.",
    "NoticeAttachmentClosed"         -> "The notebook `name` is no longer open: remove it from the attachments or open it again.",
    "NoticeAttachmentMissing"        -> "The file `name` can't be read.",
    "NoticeAttachmentUnreadable"     -> "The notebook file `name` can't be read.",
    "NoticeAttachmentNotebookUnreadable" -> "The notebook `name` can't be read.",
    "NoticeAttachmentBinary"         -> "`name` can't be attached: only text files, notebooks and images can.",
    "NoticeAttachmentTooLarge"       -> "`name` is too large to attach (`size`; at most `max`).",
    "NoticeAttachmentsTooLarge"      -> "The attachments are too large to send in one message (`size`; at most `max`).",
    "NoticeAttachmentImage"          -> "The image `name` can't be read.",
    "NoticeAttachmentNoImages"       -> "`agent` does not accept images, so `name` can't be attached.",
    "NoticeAttachmentTooManyImages"  -> "A message can have at most `max` images.",
    "NoticeAttachmentsFailed"        -> "The attachments could not be prepared, so the message was not sent.",
    "NoticeAttachmentsTimeout"       -> "Preparing the attachments took too long, so the message was not sent.",
    "NoticePendingPromptRestored"    -> "The kernel was restarted: the message that was waiting to be sent is back in the input field.",
    "NoticeMessageReturned"          -> "The chat changed, so the message that was waiting to be sent is back in the input field.",
    "NoticeDirectoryWhileRunning"    -> "The project folder can't be changed while the agent is working.",
    "NoticeDirectoryWhileRestoring"  -> "The project folder can't be changed while a session is loading.",
    "NoticeChooseModel"              -> "Choose another model from the model menu above.",
    "NoticeSignIn"                   -> "Run \"opencode auth login\" in a terminal to sign in, then reconnect.",
    "NoticeSignInRemote"             -> "The sign-in runs on `host`: connect with this command in a terminal, run \"opencode auth login\" there, then reconnect.",
    "NoticeCopyCommand"              -> "Copy command",
    "NoticeCopyCommandTooltip"       -> "Copy the command to run in a terminal",
    "NoticeLocateAgent"              -> "Install OpenCode (https://opencode.ai) or give its command line with the \"ACPAgentCommandLine\" setting, then reconnect.",
    "NoticeAgentExecutableMissing"   -> "The file `path` does not exist.",
    "NoticeReconnectAfterTurn"       -> "The new agent settings are applied when the agent is done.",
    "NoticeHostWhileRunning"         -> "The SSH settings can't be changed while the agent is working.",
    "NoticeHostWhileRestoring"       -> "The SSH settings can't be changed while a session is loading.",
    "NoticeInvalidRemoteDirectory"   -> "`path` is not a folder path on `host`: it must start with / or ~/.",
    "NoticeDirectoryMissing"         -> "The folder `path` doesn't exist.",
    "NoticeLocateAgentRemote"        -> "Install OpenCode on `host` (https://opencode.ai), or give its command line on `host` with the \"ACPAgentCommandLine\" setting, then reconnect.",
    "NoticeCommandLineReset"         -> "The \"ACPAgentCommandLine\" setting was for another computer, so it is no longer used.",
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

(* The "+" button, its menu and the chips of the draft's attachments (Attachments.wl) *)
$$attachmentsAction = Alternatives[
    "AttachFiles",
    "AttachMenu",
    "AttachNotebook",
    "RemoveAttachment",
    "ShowAttachment"
];

(* The button that opens the prompt notebook, and the buttons of its docked cell (PromptNotebook.wl), whose notebook
   argument is the prompt notebook *)
$$promptNotebookAction = Alternatives[
    "OpenPromptNotebook",
    "PromptNotebookCancel",
    "PromptNotebookOpenWindow",
    "PromptNotebookSend"
];

(* Buttons and keys of the remote folder picker (FolderPicker.wl) *)
$$folderPickerAction = Alternatives[
    "FolderPickerCancel",
    "FolderPickerChoose",
    "FolderPickerClosed",
    "FolderPickerCopyCommand",
    "FolderPickerCopyError",
    "FolderPickerEnter",
    "FolderPickerGo",
    "FolderPickerHome",
    "FolderPickerRefresh",
    "FolderPickerShowMore",
    "FolderPickerToggleHidden",
    "FolderPickerUp"
];

acpAction0 // beginDefinition;
acpAction0[ "Send"               , nbo_NotebookObject                  ] := evaluateACPChat @ nbo;
acpAction0[ "Stop"               , nbo_NotebookObject                  ] := acpStopAction @ nbo;
acpAction0[ "NewChat"            , nbo_NotebookObject                  ] := acpNewChat @ nbo;
acpAction0[ "ToggleOpen"         , args___                             ] := acpToggleOpen @ args;
acpAction0[ "PermissionResponse" , nbo_NotebookObject, args__          ] := acpPermissionResponseAction[ nbo, args ];
acpAction0[ "PermissionDetails"  , nbo_NotebookObject, key_String      ] := acpPermissionDetails[ nbo, key ];
acpAction0[ "SetConfigOption"    , nbo_NotebookObject, id_String, val_ ] := acpSetConfigOptionAction[ nbo, id, val ];
acpAction0[ "SetProjectDirectory", nbo_NotebookObject, dir_            ] := acpSetProjectDirectoryAction[ nbo, dir ];
acpAction0[ "Reconnect"          , nbo_NotebookObject                  ] := acpReconnectAction @ nbo;
acpAction0[ "ErrorAction"        , nbo_NotebookObject, action_         ] := acpErrorAction[ nbo, action ];
acpAction0[ action: $$errorAction  , nbo_NotebookObject                  ] := acpErrorAction[ nbo, action ];
acpAction0[ "ToggleErrorDetail"  , nbo_NotebookObject                  ] := acpToggleErrorDetail @ nbo;
acpAction0[ "CopyErrorDetail"    , nbo_NotebookObject                  ] := acpCopyErrorDetail @ nbo;
acpAction0[ "CopyNoticeCommand"  , nbo_NotebookObject                  ] := acpCopyNoticeCommand @ nbo;
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
acpAction0[ name: $$folderPickerAction, nbo_NotebookObject, args___ ] := acpFolderPickerAction[ name, nbo, args ];
acpAction0[ name: $$attachmentsAction, nbo_NotebookObject, args___ ] := acpAttachmentsAction[ name, nbo, args ];
acpAction0[ name: $$promptNotebookAction, nbo_NotebookObject ] := acpPromptNotebookAction[ name, nbo ];
acpAction0[ name_, args___ ] := (acpLog[ "UnknownAction", { name, args } ]; Missing[ "UnknownAction", name ]);
acpAction0 // endDefinition;

(* The action names handled by acpAction (used by tests) *)
$acpActionNames = {
    "AttachFiles",
    "AttachMenu",
    "AttachNotebook",
    "CancelQueuedPrompt",
    "ChooseDirectory",
    "ChooseModel",
    "CopyErrorDetail",
    "CopyNoticeCommand",
    "DeleteSession",
    "DismissNotice",
    "ErrorAction",
    "FolderPickerCancel",
    "FolderPickerChoose",
    "FolderPickerClosed",
    "FolderPickerCopyCommand",
    "FolderPickerCopyError",
    "FolderPickerEnter",
    "FolderPickerGo",
    "FolderPickerHome",
    "FolderPickerRefresh",
    "FolderPickerShowMore",
    "FolderPickerToggleHidden",
    "FolderPickerUp",
    "InitializeWindow",
    "LocateAgent",
    "NewChat",
    "NewSessionIn",
    "OpenPromptNotebook",
    "PermissionDetails",
    "PermissionResponse",
    "PromptNotebookCancel",
    "PromptNotebookOpenWindow",
    "PromptNotebookSend",
    "Reconnect",
    "RemoveAttachment",
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
    "ShowAttachment",
    "SignIn",
    "Stop",
    "ToggleErrorDetail",
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
            ConfirmMatch[ attachToLeft[ source, nbo, $acpWindowWidth ], _NotebookObject, "Attached" ],
            SetOptions[
                nbo,
                WindowMargins -> { { 0, Automatic }, { Automatic, 0 } },
                WindowSize    -> { attachedWindowWidth[ $acpWindowWidth, 1, notebookDisplayRange @ nbo ], Automatic }
            ];
            SetSelectedNotebook @ nbo
        ];

        acpUpdateWindowTitle @ nbo;
        acpEnsureConnected @ nbo;
        (* A remote window without a folder opens its folder picker (FolderPicker.wl), once *)
        acpFolderPickerAutoOpen @ nbo;
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
    WindowTitle -> acpWindowTitleString[ dir, agent, False, acpSettingsSSH @ settings ]
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

(* Explicit setting -> last used directory -> directory of the (saved) source notebook -> None.
   With "SSHSettings" (remote): the explicit folder (a ~ folder as given: the launch resolves it with the remote $HOME,
   while the home persisted for the host name may be another machine's), or the host's persisted last folder, else
   None; never the source notebook's folder and never a check on this computer. *)
acpDefaultProjectDirectory // beginDefinition;

acpDefaultProjectDirectory[ source_, settings_Association ] := With[ { ssh = acpSettingsSSH @ settings },
    If[ ssh === None,
        acpDefaultProjectDirectory[ source, Lookup[ settings, "ProjectDirectory", Automatic ] ],
        acpRemoteDefaultProjectDirectory[ ssh, Lookup[ settings, "ProjectDirectory", Automatic ] ]
    ]
];

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


acpRemoteDefaultProjectDirectory // beginDefinition;

acpRemoteDefaultProjectDirectory[ _, None ] := None;

acpRemoteDefaultProjectDirectory[ _, dir: _String | File[ _String ] ] :=
    acpRemoteNormalizeDirectory[ dir, None ];

acpRemoteDefaultProjectDirectory[ ssh_, Automatic ] := With[ { key = acpLastProjectDirectoryKey @ ssh },
    If[ ListQ @ key, Replace[ acpPersistedSetting[ key, None ], Except[ _String? acpRemoteProjectDirectoryQ ] -> None ], None ]
];

acpRemoteDefaultProjectDirectory[ _, _ ] := None;

acpRemoteDefaultProjectDirectory // endDefinition;


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

(* A remote window's record also gets the host's persisted home folder ("RemoteHome") and "RemoteVerified" -> False
   (True once a launch reached the host, Connection.wl) *)
acpInitialWindowRecord[ nbo_NotebookObject, dir_, agent_String, settings_Association ] := <|
    "Notebook"           -> nbo,
    "Agent"              -> agent,
    "ProjectDirectory"   -> dir,
    "Status"             -> If[ acpValidProjectDirectoryQ[ dir, acpSettingsSSH @ settings ], "Connecting", "NoDirectory" ],
    "RemoteHome"         -> acpPersistedRemoteHome @ acpSettingsSSH @ settings,
    "RemoteVerified"     -> False,
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
    "Attachments"        -> { },
    "Preparing"          -> None,
    "Restore"            -> None,
    "PendingRestore"     -> None
|>;

acpInitialWindowRecord // endDefinition;


(* ssh: the window's SSH settings (acpSettingsSSH): a local folder must exist, a remote one is a path (SSH.wl) *)
acpValidProjectDirectoryQ // beginDefinition;
acpValidProjectDirectoryQ[ dir_, ssh_ ] := acpProjectDirectoryQ[ dir, ssh ];
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

(* The settings come first: a remote window's folder is a remote path, stored already normalized, so it is taken as it
   is ("Raw": a folder name may end in a space), and a ~ folder (the launch never reached it) stays one (see
   acpDefaultProjectDirectory) *)
acpRebuildWindowRecord[ nbo_NotebookObject ] := Module[ { settings, ssh, dir, agent, record, rebuilt = False, window },
    settings = acpPersistedWindowSettings @ acpFE[ nbo, "Settings", <| |> ];
    ssh      = acpSettingsSSH @ settings;
    dir      = If[ ssh === None,
        acpNormalizeProjectDirectory[ acpFE[ nbo, "ProjectDirectory", None ], None, None ],
        acpRemoteNormalizeDirectory[ acpFE[ nbo, "ProjectDirectory", None ], None, "Raw" -> True ]
    ];
    agent    = Replace[ acpFE[ nbo, "Agent", $acpDefaultAgent ], Except[ _String ] -> $acpDefaultAgent ];
    record   = acpInitialWindowRecord[ nbo, dir, agent, settings ];
    record[ "Status" ] = If[ acpValidProjectDirectoryQ[ dir, ssh ], "Disconnected", "NoDirectory" ];
    record[ "ResumableSessionID" ] = Replace[ acpFE[ nbo, "ResumableSessionID", None ], Except[ _String ] -> None ];
    (* the draft's attachments (Attachments.wl) *)
    record[ "Attachments" ] = acpAttachmentRefs @ acpFE[ nbo, "Attachments", { } ];
    acpEnsureWindowSymbols @ nbo;
    window = acpWindowUpdate[ nbo, Function[ old, If[ KeyExistsQ[ old, "Status" ], old, rebuilt = True; Join[ old, record ] ] ] ];
    (* a message that was queued or prepared when the kernel quit goes back into the draft *)
    If[ rebuilt && restorePendingPrompts @ nbo, acpWindowGet @ nbo, window ]
];

acpRebuildWindowRecord // endDefinition;


(* The messages of the TaggingRules ({"ACP", "PreparingPrompt"}, then {"ACP", "QueuedPrompt"}, which was sent before it)
   that a quit kernel did not send: their text goes back into the input field (before what was typed since) and their
   attachments into the draft, with a notice. True if there was one. *)
restorePendingPrompts // beginDefinition;

restorePendingPrompts[ nbo_NotebookObject ] := Module[ { pending, given },
    pending = Select[ persistedPrompt /@ { acpFE[ nbo, "PreparingPrompt", None ], acpFE[ nbo, "QueuedPrompt", None ] }, AssociationQ ];
    If[ pending === { }, Return[ False, Module ] ];
    (* a prompt notebook's message stays in its notebook (PromptNotebook.wl), whose status says why it was not sent *)
    given = acpGiveBackDraft[ nbo, #, acpLabel[ "PromptNotebookInterrupted" ] ] & /@ pending;
    acpFESet[ nbo, "PreparingPrompt", None ];
    acpFESet[ nbo, "QueuedPrompt", None ];
    If[ MemberQ[ given, True ], acpSetNotice[ nbo, acpLabel[ "NoticePendingPromptRestored" ] ] ];
    True
];

restorePendingPrompts // endDefinition;


(* A message of the TaggingRules: <| "Input" (what was typed; boxes or a string), "Text", "Attachments" (references) |>;
   the front end may give an association back as rules *)
persistedPrompt // beginDefinition;
persistedPrompt[ rules: { ___Rule } ] := persistedPrompt @ Association @ rules;
persistedPrompt[ prompt_Association ] /; StringQ @ Lookup[ prompt, "Text", None ] || Lookup[ prompt, "Attachments", { } ] =!= { } := prompt;
persistedPrompt[ _ ] := None;
persistedPrompt // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpPersistedWindowSettings*)

(* The explicit agent settings of a window. They are also stored in the notebook's TaggingRules ({"ACP", "Settings"}),
   so a window rebuilt after a kernel restart connects with the same command line, model, MCP server setting and host
   ("SSHSettings", in its canonical form: it holds no secrets, at most the path of a key file). *)
$acpPersistedSettingNames = { "ACPAgent", "ACPAgentCommandLine", "ACPMCPServer", "ACPModel", "SSHSettings" };

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

$acpDerivedViewNames = { "Attachments", "ConfigMenus", "DirectoryRow", "Footer", "InputArea", "NewChat" };

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpReuseWindow*)
acpReuseWindow // beginDefinition;

acpReuseWindow[ source_, nbo_NotebookObject, settings_Association ] := Enclose[
    Module[ { window, plan, dir, notices, dirChanged, changed, result, queued },
        acpCheckSession @ nbo;
        window  = ConfirmBy[ acpEnsureWindowRecord @ nbo, AssociationQ, "Window" ];
        plan    = ConfirmBy[ acpReusePlan[ source, window, settings ], AssociationQ, "Plan" ];
        dir     = plan[ "Directory" ];
        notices = plan[ "Notices" ];

        (* Explicit agent settings (executable, model, host) are stored first, so a reconnect below (or the one done by a
           directory change) uses them: *)
        changed = acpMergeWindowSettings[ nbo, plan[ "Settings" ] ];

        (* Another host is a new chat in the new host's folder (or without a folder); an explicit project directory for
           an existing window is applied (unless the agent is busy) *)
        dirChanged = False;
        Which[
            TrueQ @ plan[ "Switch" ],
                queued = acpQueuedPromptOf @ acpWindowGet[ nbo, "QueuedPrompt", None ];
                acpResetProjectDirectory[ nbo, dir ];
                acpReturnPendingMessages[ nbo, queued ];
                acpDirectoryChanged @ nbo;
                (* a remote host without a folder: its folder picker opens (FolderPicker.wl) *)
                acpFolderPickerAutoOpen @ nbo;
                dirChanged = True,
            StringQ @ dir && dir =!= Lookup[ window, "ProjectDirectory" ],
                Which[
                    acpRestoringQ @ window,
                        AppendTo[ notices, acpLabel[ "NoticeDirectoryWhileRestoring" ] ],
                    acpRunningQ @ window,
                        AppendTo[ notices, acpLabel[ "NoticeDirectoryWhileRunning" ] ],
                    True,
                        result     = acpChangeProjectDirectory[ nbo, dir ];
                        dirChanged = StringQ @ result
                ]
        ];
        If[ notices =!= { }, acpSetNotice[ nbo, StringRiffle[ notices, " " ] ] ];

        If[ MatchQ[ source, _NotebookObject ],
            ConfirmMatch[ attachToLeft[ source, nbo, $acpWindowWidth ], _NotebookObject, "Attached" ],
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
(* ::Subsubsection::Closed:: *)
(*acpReusePlan*)

(* What reusing the window with the settings of a ShowNotebookAssistance call does (acpReuseWindow), decided without
   changing anything (it reads preferences: the new host's last folder):
     "Settings"  -> the settings to merge;
     "Switch"    -> True if the window moves to another host ("SSHSettings" with another host key; local is a host
                    too). Refused while the agent works or a session loads: then "SSHSettings", "ProjectDirectory" and
                    "ACPAgentCommandLine" are dropped, with a notice. A switch resets "ACPAgentCommandLine" (a path on
                    the machine that runs the agent) to Automatic unless the call gives one, with a notice if a value
                    was dropped;
     "Directory" -> the call's folder normalized for the window's (new) host (a remote ~ folder: expanded with the
                    window's home on the same host, kept for another host), or None. With a switch: the call's
                    folder, else the window's folder if the old host was never reached (a typo in the user name or port
                    must not lose it), else the new host's default (acpDefaultProjectDirectory), which may be None;
     "Notices"   -> notices to show, e.g. for a folder that can't be used (it is ignored). *)
acpReusePlan // beginDefinition;

acpReusePlan[ source_, window_Association, settings0_Association ] := Module[
    { settings, oldSSH, newSSH, switchQ, busy, notices, home, dir },

    settings = settings0;
    oldSSH   = acpWindowSSH @ window;
    newSSH   = If[ KeyExistsQ[ settings, "SSHSettings" ], acpSSHSettings @ settings[ "SSHSettings" ], oldSSH ];
    switchQ  = reuseHostKey @ oldSSH =!= reuseHostKey @ newSSH;
    notices  = { };

    busy = Which[ acpRestoringQ @ window, "NoticeHostWhileRestoring", acpRunningQ @ window, "NoticeHostWhileRunning", True, None ];
    If[ switchQ && StringQ @ busy,
        AppendTo[ notices, acpLabel @ busy ];
        settings = KeyDrop[ settings, { "SSHSettings", "ProjectDirectory", "ACPAgentCommandLine" } ];
        newSSH   = oldSSH;
        switchQ  = False
    ];

    If[ switchQ && ! KeyExistsQ[ settings, "ACPAgentCommandLine" ],
        If[ Lookup[ Replace[ Lookup[ window, "Settings", <| |> ], Except[ _Association ] -> <| |> ], "ACPAgentCommandLine", Automatic ] =!= Automatic,
            AppendTo[ notices, acpLabel[ "NoticeCommandLineReset" ] ]
        ];
        settings = <| settings, "ACPAgentCommandLine" -> Automatic |>
    ];

    (* A remote ~ folder is expanded only with the window's own home (for the same host), so that ~/x and the window's
       /home/u/x are the same folder; for another host it is kept: the launch resolves it (acpDefaultProjectDirectory) *)
    home = If[ switchQ, None, acpWindowRemoteHome @ window ];
    dir  = Replace[
        Lookup[ settings, "ProjectDirectory", None ],
        { d: _String | File[ _String ] :> acpNormalizeProjectDirectory[ d, newSSH, home ], _ -> None }
    ];
    If[ StringQ @ dir && ! acpProjectDirectoryQ[ dir, newSSH ],
        AppendTo[ notices, unusableDirectoryNotice[ dir, newSSH ] ];
        dir = None
    ];
    (* the window's own ~ folder (not resolved yet) given again is no change either *)
    If[ ! switchQ && newSSH =!= None && StringQ @ dir && sameRemoteFolderQ[ dir, Lookup[ window, "ProjectDirectory", None ], home ],
        dir = window[ "ProjectDirectory" ]
    ];

    If[ switchQ,
        dir = Which[
            StringQ @ dir,
                dir,
            keepFolderQ[ window, oldSSH, newSSH ],
                window[ "ProjectDirectory" ],
            True,
                acpDefaultProjectDirectory[ source, <| "SSHSettings" -> newSSH, "ProjectDirectory" -> Automatic |> ]
        ]
    ];

    <| "Settings" -> settings, "Switch" -> switchQ, "Directory" -> dir, "Notices" -> notices |>
];

acpReusePlan // endDefinition;


(* Whether a remote folder (normalized, ~ expanded with home if known) is the window's folder, which may still be a ~
   folder *)
sameRemoteFolderQ // beginDefinition;
sameRemoteFolderQ[ dir_String, current_String, home_ ] := acpRemoteNormalizeDirectory[ current, home, "Raw" -> True ] === dir;
sameRemoteFolderQ[ _, _, _ ] := False;
sameRemoteFolderQ // endDefinition;


(* The host of SSH settings for host switches: None (local), "?" (invalid settings) or the host key *)
reuseHostKey // beginDefinition;
reuseHostKey[ None ] := None;
reuseHostKey[ _Failure ] := "?";
reuseHostKey[ ssh_ ] := acpSSHHostKey @ ssh;
reuseHostKey // endDefinition;


(* A remote window's folder is kept for another host when the old host was never reached (RemoteVerified) *)
keepFolderQ // beginDefinition;

keepFolderQ[ window_Association, oldSSH_, newSSH_ ] := And[
    oldSSH =!= None,
    newSSH =!= None,
    ! TrueQ @ Lookup[ window, "RemoteVerified", False ],
    acpRemoteProjectDirectoryQ @ Lookup[ window, "ProjectDirectory", None ]
];

keepFolderQ // endDefinition;


(* The notice for an explicit folder that can't be used: a local folder that doesn't exist, or a remote one that is not
   an absolute or ~/ path *)
unusableDirectoryNotice // beginDefinition;

unusableDirectoryNotice[ dir_String, None ] :=
    acpLabel[ "NoticeDirectoryMissing", <| "path" -> acpRemoteDisplayName @ acpAbbreviatePath[ dir, None ] |> ];

unusableDirectoryNotice[ dir_String, ssh_ ] := acpLabel[
    "NoticeInvalidRemoteDirectory",
    <| "path" -> acpRemoteDisplayName @ dir, "host" -> Replace[ acpSSHHostLabel @ ssh, Except[ _String ] -> "?" ] |>
];

unusableDirectoryNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Window Settings*)

(* Merges explicit agent settings into the window record and its TaggingRules. Gives the names of the settings that
   changed: values are compared in their normal form (settingNormal), so that e.g. "u@h" and the canonical
   <| "MachineName" -> "h", "Username" -> "u", ... |>, or None and a missing "SSHSettings", are the same. "SSHSettings"
   is stored in its canonical form. A new "ACPModel" replaces a model chosen in the menu for the next connection. *)
acpMergeWindowSettings // beginDefinition;

acpMergeWindowSettings[ nbo_NotebookObject, settings_Association ] := Module[ { new, old, changed, merged },
    new     = acpPersistedWindowSettings @ settings;
    If[ KeyExistsQ[ new, "SSHSettings" ], new[ "SSHSettings" ] = settingNormal[ "SSHSettings", new[ "SSHSettings" ] ] ];
    old     = Replace[ acpWindowGet[ nbo, "Settings", <| |> ], Except[ _Association ] -> <| |> ];
    changed = Select[ Keys @ new, settingNormal[ #, Lookup[ old, #, Automatic ] ] =!= settingNormal[ #, new[ # ] ] & ];
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


(* A setting's value for comparisons: SSH settings in their canonical form (an invalid value stays as it is);
   "ACPMCPServer" True, False or Automatic: Automatic and True are not the same, since Automatic offers the MCP server
   only to the agent's own program (MCP.wl's acpMCPEnabledQ) *)
settingNormal // beginDefinition;
settingNormal[ "SSHSettings", value_ ] := Replace[ acpSSHSettings @ value, _Failure -> value ];
settingNormal[ "ACPMCPServer", value_ ] := Replace[ value, Except[ True | False ] -> Automatic ];
settingNormal[ _, value_ ] := value;
settingNormal // endDefinition;


(* Applies changed settings (see acpMergeWindowSettings): a new agent, executable or SSH setting of the same host (or a
   window in "Error", e.g. after AgentNotFound) reconnects, after the running turn if there is one (the folder, the
   transcript and the resumable session stay); so does a new MCP server setting of a local window (the MCP servers are
   only offered when a session starts; turning the setting off revokes the connection's token at once, MCP.wl), while a
   remote window, which never offers the server, only keeps the value for a later switch to this computer. A new model
   is selected in the current session. Otherwise the window just makes sure it is connected. dirChanged: the window is
   already reconnecting for a new project directory (or a new host). New SSH settings are a user action: they clear the
   host's failure latch (Remote.wl), typically the fix of the failure that latched it. *)
acpApplyWindowSettings // beginDefinition;

acpApplyWindowSettings[ nbo_NotebookObject, changed_List, dirChanged_ ] := Module[ { window, modelID, model },
    window = acpWindowGet @ nbo;
    If[ MemberQ[ changed, "SSHSettings" ] && StringQ @ acpWindowHostKey @ window,
        acpRemoteClearHostError @ acpWindowHostKey @ window
    ];
    Which[
        ! AssociationQ @ window,
            Null,
        TrueQ @ dirChanged,
            acpEnsureConnected @ nbo,
        Or[
            MemberQ[ changed, "ACPAgentCommandLine" | "ACPAgent" | "SSHSettings" ],
            MemberQ[ changed, "ACPMCPServer" ] && ! acpRemoteQ @ window,
            Lookup[ window, "Status" ] === "Error"
        ],
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
   "ACPAgentCommandLine" setting (with the agent's arguments; kept across kernel restarts) and the window reconnects.
   Refused for a remote window: a local file is no program on the remote machine. *)
acpSetAgentExecutableAction // beginDefinition;

acpSetAgentExecutableAction[ nbo_NotebookObject, path0_ ] := Catch @ Module[ { window, path },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    If[ acpRemoteQ @ window, acpSetNotice[ nbo, locateAgentRemoteNotice @ window ]; Throw @ Null ];
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
    acpIsolated @ acpFolderPickerCloseWindow @ nbo;
    acpIsolated @ acpPermissionDetailsCloseWindow @ nbo;
    Quiet @ NotebookClose @ nbo;
    acpIsolated @ acpPromptNotebooksOwnerClosed @ nbo;
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
    (* A placeholder toolbar that acpCheckSession did not replace (no kernel restart, e.g. a window whose record was
       forgotten) is replaced now that the record and its symbols exist *)
    If[ KeyExistsQ[ $placeholderToolbars, nbo ], acpRefreshToolbar @ nbo ];
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
   window, folder picker and permission details window; its prompt notebooks stay open, see PromptNotebook.wl). *)
acpWindowClosed // beginDefinition;

acpWindowClosed[ nbo_NotebookObject ] := (
    acpSchedule[
        acpDisconnect[ nbo, "WindowClosed" ];
        acpForgetWindow @ nbo;
        acpSessionsCloseWindow @ nbo;
        acpFolderPickerCloseWindow @ nbo;
        acpPermissionDetailsCloseWindow @ nbo;
        acpPromptNotebooksOwnerClosed @ nbo
    ];
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
    KeyDropFrom[ $placeholderToolbars, Key @ nbo ];
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
    title = acpWindowTitleString @ window;
    If[ Lookup[ $windowTitles, Key @ nbo ] =!= title,
        $windowTitles[ nbo ] = title;
        Quiet @ SetOptions[ nbo, WindowTitle -> title ]
    ];
    (* the target that the docked cells of the window's prompt notebooks show (PromptNotebook.wl) follows too *)
    acpSyncPromptTarget[ nbo, window ];
    title
];

acpUpdateWindowTitle[ _, _Missing ] := Null;

acpUpdateWindowTitle // endDefinition;


(* The project folder can come from the agent (a session restored from the Sessions window): its name is display-safe
   (acpRemoteDisplayName, as the folder label shows it).
   A remote window's title names the host (short form); its folder is a POSIX path on that host, whose name is taken
   with string operations (FileNameTake would read it as a path of this computer). *)
acpWindowTitleString // beginDefinition;

acpWindowTitleString[ window_Association ] := acpWindowTitleString[
    Lookup[ window, "ProjectDirectory", None ],
    Lookup[ window, "Agent", $acpDefaultAgent ],
    Length @ Replace[ Lookup[ window, "PendingPermissions", <| |> ], Except[ _Association ] -> <| |> ] > 0,
    acpWindowSSH @ window
];

acpWindowTitleString[ dir_, agent_, approval_ ] := acpWindowTitleString[ dir, agent, approval, None ];

acpWindowTitleString[ dir_String, agent_, approval_, ssh: Except[ None ] ] := acpLabel[
    If[ TrueQ @ approval, "WindowTitleApprovalRemote", "WindowTitleProjectRemote" ],
    <|
        "project" -> acpRemoteDisplayName @ acpRemotePathName @ dir,
        "host"    -> acpRemoteDisplayName @ Replace[ acpSSHShortHost @ ssh, Except[ _String ] -> "?" ],
        "agent"   -> agent
    |>
];

acpWindowTitleString[ dir_String, agent_, True, None ] :=
    acpLabel[ "WindowTitleApproval", <| "project" -> acpRemoteDisplayName @ FileNameTake @ dir, "agent" -> agent |> ];

acpWindowTitleString[ dir_String, agent_, _, None ] :=
    acpLabel[ "WindowTitleProject", <| "project" -> acpRemoteDisplayName @ FileNameTake @ dir, "agent" -> agent |> ];

acpWindowTitleString[ _, agent_, _, _ ] :=
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
   R3). If building the toolbar fails, a minimal toolbar still initializes the window (input field and connection).
   The front end does not track symbols created while it evaluates this DynamicBox, so the toolbar is built here only
   for a window that has a record in this kernel (and so its change symbols, see acpEnsureWindowSymbols). After a
   kernel restart the box is evaluated again in the new kernel, which knows nothing of the window yet: then a
   placeholder is shown, and its Initialization runs acpInitializeWindow in the pump, which rebuilds the record (with
   the symbols) before the toolbar (acpCheckSession, or acpRefreshToolbar for a placeholder it did not replace).
   Nothing else happens in this Dynamic: no front end reads, no loading of ACPLink, no connecting (rule R1). *)
makeACPChatDockedCell[ ] := With[ { nbo = EvaluationNotebook[ ] },
    Replace[
        acpIsolated @ If[ knownWindowQ @ nbo, makeACPChatDockedCell @ nbo, acpPlaceholderDockedCell @ nbo ],
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


(* Whether this kernel has the window's state: a record made by acpRegisterWindow or acpRebuildWindowRecord, which
   create the change symbols too (a record without "Status" is a partial one, see acpEnsureWindowRecord) *)
knownWindowQ // beginDefinition;
knownWindowQ[ nbo_NotebookObject ] := KeyExistsQ[ Replace[ acpWindowGet @ nbo, Except[ _Association ] -> <| |> ], "Status" ];
knownWindowQ // endDefinition;


(* The toolbar of a window this kernel does not know yet (makeACPChatDockedCell): the toolbar's frame without views,
   whose Initialization starts acpInitializeWindow. The window is noted, so acpInitializeWindow replaces it with the
   toolbar once the record exists. *)
If[ ! AssociationQ @ $placeholderToolbars, $placeholderToolbars = <| |> ];

acpPlaceholderDockedCell // beginDefinition;

(* :!CodeAnalysis::BeginBlock:: *)
(* :!CodeAnalysis::Disable::NoVariables::DynamicModule:: *)
acpPlaceholderDockedCell[ nbo_NotebookObject ] := (
    $placeholderToolbars[ nbo ] = True;
    Framed[
        DynamicModule[ { },
            Spacer[ { 0, 24 } ],
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
    ]
);
(* :!CodeAnalysis::EndBlock:: *)

acpPlaceholderDockedCell // endDefinition;

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
   its Dynamics are evaluated (and track symbols) in this kernel and its DynamicModule state is reset. A window whose
   toolbar is not found (e.g. a notebook given the ACPChat stylesheet and other docked cells by hand) keeps its docked
   cells; this is logged, since after a kernel restart that toolbar stays as the old kernel left it. *)
acpRefreshToolbar[ nbo_NotebookObject ] := Catch @ Module[ { docked, new },
    docked = Replace[ AbsoluteCurrentValue[ nbo, DockedCells ], cell_Cell :> { cell } ];
    If[ ! MatchQ[ docked, { ___Cell } ] || ! MemberQ[ docked, $$acpToolbarCell ],
        acpLog[ "ToolbarNotFound", <| "Notebook" -> nbo, "DockedCells" -> dockedCellsSummary @ docked |> ];
        Throw @ Null
    ];
    new = Replace[ docked, $$acpToolbarCell :> acpToolbarDockedCell @ nbo, { 1 } ];
    KeyDropFrom[ $placeholderToolbars, Key @ nbo ];
    contextBlock @ SetOptions[ nbo, DockedCells -> new ]
];

acpRefreshToolbar // endDefinition;

(* The toolbar cell (ACPStyles.wl, acpToolbarDockedCell); the front end may give its tag in a list *)
$$acpToolbarCell = Cell[ ___, CellTags -> ("ACPToolbar" | { ___, "ACPToolbar", ___ }), ___ ];

(* What a window's docked cells are, for the debug log: the number of cells and their tags, or the head *)
dockedCellsSummary // beginDefinition;
dockedCellsSummary[ cells: { ___Cell } ] := { Length @ cells, Cases[ cells, Cell[ ___, CellTags -> tags_, ___ ] :> tags ] };
dockedCellsSummary[ other_ ] := Head @ other;
dockedCellsSummary // endDefinition;

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
        acpToolbarButtonLabel[ "WorkspaceToolbarIconNew", acpLabel[ "NewChat" ], acpLabel[ "NewChatTooltip" ], True ],
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

acpToolbarButtonLabel[ iconName_String, label_, tooltip_ ] := acpToolbarButtonLabel[ iconName, label, tooltip, False ];

(* collapsible: True for New and Sessions in the main row, which show only their icons (the tooltip says what they do)
   while the row is too narrow for their labels (toolbarNarrowWidth), so the menus stay in the window *)
acpToolbarButtonLabel[ iconName_String, label_, tooltip_, collapsible_ ] := Tooltip[
    If[ TrueQ @ collapsible,
        Style[
            acpFitSwitch[ toolbarNarrowWidth[ ], $minModelLabelWidth, toolbarButtonGrid[ iconName, None ], toolbarButtonGrid[ iconName, label ] ],
            "NotebookAssistant`Sidebar`ToolbarButtonLabel"
        ],
        toolbarButtonGrid[ iconName, label ]
    ],
    tooltip
];

acpToolbarButtonLabel // endDefinition;


toolbarButtonGrid // beginDefinition;

toolbarButtonGrid[ iconName_String, label_ ] := Grid[
    { { chatbookIcon[ iconName, False, color @ "NA_BlueHueButtonIcon" ], If[ label === None, Nothing, label ] } },
    Alignment        -> { Left, Baseline },
    BaselinePosition -> { 1, If[ label === None, 1, 2 ] },
    BaseStyle        -> "NotebookAssistant`Sidebar`ToolbarButtonLabel",
    Spacings         -> { 0.3, 0 }
];

toolbarButtonGrid // endDefinition;

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

(* The main row can't shrink: the model's name takes one line, cut at its end to the room that New, Sessions and the
   other menus leave (modelLabelWidth), and in a narrow or magnified window New and Sessions show only their icons
   (toolbarNarrowWidth), so a long name or a narrow window doesn't push the effort menu out of the window (unless the
   window is very narrow, e.g. 360 points at magnification 2). *)
acpConfigMenusView[ nbo_NotebookObject, window_Association ] := Module[ { enabled, others, menus },
    enabled = ! acpRunningQ @ window && ! acpRestoringQ @ window;
    others  = DeleteCases[ acpConfigMenuLabel[ window, # ] & /@ { "mode", "thought_level" }, None ];
    menus = {
        acpModelMenu[ nbo, window, enabled, modelLabelWidth @ others ],
        acpModeMenu[ nbo, window, enabled ],
        acpEffortMenu[ nbo, window, enabled ]
    };
    If[ menus === { }, Spacer[ 0 ], Row[ menus, Spacer[ 2 ] ] ]
];

acpConfigMenusView[ _, _ ] := Spacer[ 0 ];

acpConfigMenusView // endDefinition;


(* The label of the mode or effort menu ("mode", "thought_level"), None if the menu is not shown (as acpModeMenu and
   acpEffortMenu decide) *)
acpConfigMenuLabel // beginDefinition;

acpConfigMenuLabel[ window_Association, category_String ] := Replace[
    acpConfigOption[ window, category ],
    {
        opt_Association :> With[ { options = acpConfigOptionValues @ opt },
            If[ Length @ options < 2, None, acpOptionName[ acpConfigCurrentValue[ window, opt ], options ] ]
        ],
        _ -> None
    }
];

acpConfigMenuLabel // endDefinition;


(* The width available to the model's name (acpFitWidth): what the main row leaves after New and Sessions (with their
   labels, unless the row is narrow: see toolbarNarrowWidth), the other menus (their labels measured in the menus' font,
   which is the model label's and the buttons' labels'), the menus' frames and chevrons, and the spacings. The reserves
   were measured in a real front end (see acpFitWidth and docs/acp-window.md, "The toolbar"). *)
modelLabelWidth // beginDefinition;

modelLabelWidth[ others: { ___String } ] := acpFitWidthSwitch[
    toolbarNarrowWidth[ ],
    $minModelLabelWidth,
    mainRowRoom[ others, { } ],
    mainRowRoom[ others, { acpLabel[ "NewChat" ], acpLabel[ "SessionsButtonLabel" ] } ]
];

modelLabelWidth // endDefinition;


mainRowRoom // beginDefinition;
mainRowRoom[ others_List, labels_List ] := acpFitWidth[
    { $toolbarScreenReserve, $mainRowReserve + (Length @ others + 1) * $menuReserve + Length @ labels * $buttonLabelReserve },
    { #, { } } & /@ Join[ labels, others ]
];
mainRowRoom // endDefinition;


(* What the main row leaves for the model's name with New's and Sessions' labels and two other menus whose labels are
   $menuLabelsAllowance points wide in all: while that is less than $minModelLabelWidth points (a narrow or magnified
   window), New and Sessions show only their icons. The buttons are in other views than the menus and don't know the
   menus' labels, hence the typical width; the model menu uses the same test for its width, so it always knows whether
   the labels are shown. *)
toolbarNarrowWidth // beginDefinition;

toolbarNarrowWidth[ ] := acpFitWidth[
    { $toolbarScreenReserve, $mainRowReserve + 3 * $menuReserve + 2 * $buttonLabelReserve + $menuLabelsAllowance },
    { { acpLabel[ "NewChat" ], { } }, { acpLabel[ "SessionsButtonLabel" ], { } } }
];

toolbarNarrowWidth // endDefinition;

(* The layout of the main row, measured in a real front end at window widths of 360 to 600 points and magnifications
   from 0.85 to 2 (see acpFitWidth: the toolbar is a docked cell, whose "ViewSize" is the window's whole width): the
   row takes $toolbarScreenReserve screen points, which magnification does not scale, and in points at magnification 1
   $mainRowReserve besides the texts of its buttons and menus (the toolbar's margins, the icons and frames of New and
   Sessions, the spacings), $menuReserve for a menu besides its label (its frame, the chevron, the space before the
   next menu), and $buttonLabelReserve for each of New's and Sessions' labels that is shown (the space before it) *)
$toolbarScreenReserve = 3;
(* The largest width (points) of the model menu's label: never reached (the name is cut to the room in the row), but a
   number rather than Full (see acpModelMenu) *)
$menuLabelMaxWidth    = 4000;
$mainRowReserve       = 41;
$menuReserve          = 27;
$buttonLabelReserve   = 5.2;

(* The least room for the model's name (points) with New's and Sessions' labels shown, and the typical width of the mode
   and effort menus' labels together (e.g. "Build" and "Medium") *)
$minModelLabelWidth  = 40;
$menuLabelsAllowance = 80;

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

(* width: the width available to the model's name (modelLabelWidth), or None: the name is not cut *)
acpModelMenu[ nbo_, window_Association, enabled_ ] := acpModelMenu[ nbo, window, enabled, None ];

acpModelMenu[ nbo_, window_Association, enabled_, width_ ] :=
    acpModelMenu[ nbo, window, enabled, width, acpConfigOption[ window, "model" ] ];

acpModelMenu[ nbo_, window_, enabled_, width_, opt_Association ] := Module[
    { id, current, options, values, failed, recent, groups, items, billing, name, tooltip },

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

    name    = acpModelShortName[ current, options ];
    tooltip = If[ TrueQ @ enabled, acpLabel[ "ModelMenuTooltip", <| "billing" -> billing |> ], acpMenusDisabledTooltip @ window ];

    acpMenu[
        (* one line, cut at its end to the room in the row; a name that was cut is in the tooltip. The clipping panes
           get a numeric largest width: inside the ActionMenu, Full is about 376 points whatever the room in the row,
           so a name cut to a wider room lost its ellipsis there (acpFitText's "MaxWidth") *)
        If[ width === None,
            name,
            acpFitText @ <|
                "Object"   -> name,
                "Side"     -> Right,
                "Width"    -> width,
                "Tooltip"  -> Column @ { name, tooltip },
                "MaxWidth" -> $menuLabelMaxWidth
            |>
        ],
        items,
        tooltip,
        enabled,
        "ACPModelMenu"
    ]
];

acpModelMenu[ _, _, _, _, _Missing ] := Nothing;

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
    (* the name comes from the agent (an option's "name", or the model value): neutralize its linear syntax *)
    acpSafeText @ If[ StringContainsQ[ name, "/" ], Last @ StringSplit[ name, "/", 2 ], name ]
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
        (* an unknown provider is the agent's own string (the model value's prefix): neutralize its linear syntax *)
        True, Lookup[ $acpProviderNames, ToLowerCase @ provider, acpSafeText @ provider ]
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
                FirstCase[ options, KeyValuePattern @ { "value" -> current, "description" -> d_String } :> acpSafeText @ d, None ],
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
            Replace[ acpSafeText @ Lookup[ opt, "description", None ], Except[ _String ] :> acpLabel[ "EffortMenuTooltip" ] ],
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
(* The menu button's label: an agent-provided option name (or the value), so its linear syntax is neutralized *)
acpOptionName // beginDefinition;
acpOptionName[ value_, options_List ] := acpSafeText @ FirstCase[ options, KeyValuePattern @ { "value" -> value, "name" -> n_String } :> n, ToString @ value ];
acpOptionName // endDefinition;


acpCheckedLabel // beginDefinition;

(* The label and description can be an agent-provided option name or description (mode, effort), so their linear syntax
   is neutralized (a no-op on a non-string label, such as the model menu's unavailable note, whose agent text is
   already neutralized by acpModelShortName) *)
acpCheckedLabel[ label_, checked_ ] := Row @ {
    Style[ "\[Checkmark]", ShowContents -> TrueQ @ checked ],
    " ",
    Style[ acpSafeText @ label, PrivateFontOptions -> { "OperatorSubstitution" -> False } ]
};

acpCheckedLabel[ label_, checked_, description_String ] := Tooltip[ acpCheckedLabel[ label, checked ], acpSafeText @ description ];

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

(* Folder icon + the project folder, which is the control that changes it + "Review" (Review.wl; only while the project
   folder has uncommitted changes). The folder is a button (acpFolderControl): a local window's opens the front end's
   directory dialog (its setter runs the "SetProjectDirectory" action), a remote window's the remote folder picker
   (the "ChooseDirectory" action, FolderPicker.wl); disabled while a turn runs or a session loads. Without a folder it
   reads "Choose folder...". The path takes one line: as much of it as fits in the room that the row leaves, cut at its
   start by the front end (acpFitText, folderLabelWidth), so the folder's own name stays visible; a remote window's
   host stays whole. The control is in a Fit column whose pane draws a label that is still too wide smaller (the
   safety net, if a width is off), so "Review" always stays in the window. A warning about the folder sits in its own
   column before it, so it is never shrunk or cut. *)
acpDirectoryRow // beginDefinition;

acpDirectoryRow[ nbo_NotebookObject ] :=
    acpWindowDerivedDynamic[ nbo, "DirectoryRow", acpDirectoryRowSignature, acpDirectoryRowView ];

acpDirectoryRow // endDefinition;


acpDirectoryRowSignature // beginDefinition;
(* A remote window's row also shows its host and its home folder (paths are abbreviated with it), and warns about a
   missing folder from the window's error *)
acpDirectoryRowSignature[ window_Association ] := {
    Lookup[ window, "ProjectDirectory", None ],
    directoryBusyReason @ window,
    acpReviewButtonSignature @ window,
    acpWindowHostKey @ window,
    acpWindowRemoteHome @ window,
    windowErrorCode @ window
};
acpDirectoryRowSignature[ _ ] := None;
acpDirectoryRowSignature // endDefinition;


acpDirectoryRowView // beginDefinition;

acpDirectoryRowView[ nbo_NotebookObject ] := acpDirectoryRowView[ nbo, acpWindowGet @ nbo ];

acpDirectoryRowView[ nbo_NotebookObject, window_Association ] := Module[ { dir, warning, review, width },
    dir     = Replace[ Lookup[ window, "ProjectDirectory", None ], Except[ _String ] -> None ];
    warning = acpDirectoryWarning[ dir, window ];
    review  = acpReviewButton[ nbo, window ];
    width   = folderLabelWidth[ StringQ @ warning, If[ review === Nothing, None, acpGitSummary @ window ] ];
    Grid[
        { {
            Pane[ $acpFolderIcon, ImageMargins -> { { 6, 2 }, { 0, 0 } } ],
            If[ StringQ @ warning, Tooltip[ $acpWarningIcon, warning ], Nothing ],
            (* the pane takes at most the room that the Fit column gets (a pane of Full width made the column wider than
               that in a narrow, magnified window, and pushed "Review" out of it) *)
            Item[
                Pane[ acpFolderControl[ nbo, window, dir, width ], ImageSize -> { { 0, Full }, Automatic }, ImageSizeAction -> "ShrinkToFit" ],
                ItemSize -> Fit
            ],
            review
        } },
        Alignment -> { Left, Center },
        Spacings  -> { 0.25, 0 }
    ]
];

acpDirectoryRowView[ _, _ ] := Spacer[ 0 ];

acpDirectoryRowView // endDefinition;


(* None, or the key of the reason why the folder can't be changed now *)
directoryBusyReason // beginDefinition;
directoryBusyReason[ window_Association ] := Which[
    acpRestoringQ @ window, "NoticeDirectoryWhileRestoring",
    acpRunningQ @ window  , "NoticeDirectoryWhileRunning",
    True                  , None
];
directoryBusyReason // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpFolderControl*)

(* The folder's control with its tooltip, which is outside the control, so it also shows while the control is disabled:
   the folder's path (or that there is none), and a muted line: "Click to choose another folder", or why the folder
   can't be changed now. Invalid stored SSH settings: the folder's label only, since no folder can be chosen until the
   settings are fixed. *)
acpFolderControl // beginDefinition;

acpFolderControl[ nbo_NotebookObject, window_Association, dir_, width_ ] := Module[ { ssh, busy, appearance },
    ssh  = acpWindowSSH @ window;
    busy = directoryBusyReason @ window;
    If[ FailureQ @ ssh,
        Return[ Tooltip[ plainFolderFrame @ folderLabel[ dir, window, width, Inherited ], folderTooltipLine[ dir, ssh ] ], Module ]
    ];
    appearance = folderControlAppearance[ dir, window, width, busy === None ];
    Tooltip[
        If[ ssh === None,
            localFolderSetter[ nbo, appearance, busy === None ],
            (* ImageSize -> Automatic: a button in the row's full-width pane would take its whole width (and center the
               label in it) *)
            acpActionButton[
                appearance,
                { "ChooseDirectory", nbo },
                BoxID     -> "ACPChooseDirectory",
                Enabled   -> busy === None,
                ImageSize -> Automatic
            ]
        ],
        folderTooltip[ dir, ssh, busy ]
    ]
];

acpFolderControl // endDefinition;


(* A local window's folder is chosen with the front end's directory dialog (rule R1: the front end runs the dialog, so
   nothing in the kernel waits for it); the setter runs the "SetProjectDirectory" action *)
localFolderSetter // beginDefinition;

localFolderSetter[ nbo_NotebookObject, appearance_, enabled_ ] := With[
    {
        setter = Function[
            Needs[ "Wolfram`Chatbook`" -> None ];
            Symbol[ "Wolfram`Chatbook`ChatbookAction" ][ "ACP", "SetProjectDirectory", nbo, # ]
        ]
    },
    FileNameSetter[
        Dynamic[ CurrentValue[ FrontEnd`EvaluationNotebook[ ], { TaggingRules, "ACP", "ProjectDirectory" } ], setter ],
        "Directory",
        Appearance  -> appearance,
        Enabled     -> TrueQ @ enabled,
        ImageSize   -> Automatic,
        WindowTitle -> acpLabel[ "ProjectDirectoryDialogTitle" ]
    ]
];

localFolderSetter // endDefinition;


(* The look of the control: the folder's label with the toolbar buttons' hover frame and background, and the path in
   the buttons' blue under the mouse (the color is given inside the label's own style: the color of the
   "WorkspaceChatToolbarTitle" style would win over an outer one). Disabled: the label in the same frame without a
   hover look. Without a folder: "Choose folder...", in the buttons' style. *)
folderControlAppearance // beginDefinition;

folderControlAppearance[ dir_String, window_, width_, True ] := blueHueButtonAppearance[
    {
        folderLabel[ dir, window, width, Inherited ],
        folderLabel[ dir, window, width, color @ "NA_BlueHueButtonIcon" ],
        folderLabel[ dir, window, width, color @ "NA_BlueHueButtonIcon" ]
    },
    { Automatic, 22 },
    { { 5, 5 }, { 0, 0 } }
];

folderControlAppearance[ dir_String, window_, width_, False ] := plainFolderFrame @ folderLabel[ dir, window, width, Inherited ];

folderControlAppearance[ None, _, _, enabled_ ] := With[
    {
        label = Style[
            acpLabel[ "ProjectDirectoryChoose" ],
            "NotebookAssistant`Sidebar`ToolbarButtonLabel",
            FontColor -> If[ TrueQ @ enabled, Inherited, GrayLevel[ 0.6 ] ]
        ]
    },
    If[ TrueQ @ enabled, blueHueButtonAppearance[ label, { Automatic, 22 }, { { 5, 5 }, { 0, 0 } } ], plainFolderFrame @ label ]
];

folderControlAppearance // endDefinition;


(* The frame of blueHueButtonAppearance's default look (the same size), without the hover look *)
plainFolderFrame // beginDefinition;

plainFolderFrame[ label_ ] := Framed[
    label,
    Alignment      -> { Center, Center },
    Background     -> None,
    FrameMargins   -> { { 5, 5 }, { 0, 0 } },
    FrameStyle     -> None,
    ImageSize      -> { Automatic, 22 },
    RoundingRadius -> 4
];

plainFolderFrame // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*folderLabel*)

(* The folder's label: the path, or host:path for a remote window (e.g. "ec2-203-0-113-100:~/projects/app": the host in
   its short form, muted and whole; the path abbreviated with the remote home folder). The folder can come from the
   agent (a session restored from the Sessions window), and remote text only reaches boxes through
   acpRemoteDisplayName: the path is display-safe, as the review window shows it (a bidi control or another invisible
   character as a visible marker), before anything is cut, and a marker is a piece that the front end cuts whole
   (folderLabelPieces). The front end cuts the path at its start to the room that the row leaves (acpFitText with the
   width of folderLabelWidth); the kernel only keeps a pathological path to $acpFolderLabelMaxLength pieces. Paths are
   drawn as they are typed (no operator substitution, which draws "-" as a long minus sign). pathColor: the path's
   color (Inherited: the title color of the toolbar). *)
folderLabel // beginDefinition;

folderLabel[ dir_String, window_Association, width_, pathColor_ ] := Module[ { ssh, host, path },
    ssh = acpWindowSSH @ window;
    { host, path } = If[ ssh === None,
        { None, acpRemoteDisplayName @ acpAbbreviatePath[ dir, None ] },
        MapAt[
            acpRemoteDisplayName,
            acpRemoteFolderLabel[ remoteShortHost @ ssh, dir, acpWindowRemoteHome @ window, $acpFolderLabelMaxLength ],
            1
        ]
    ];
    Style[
        acpFitText @ <|
            "Prefix"      -> If[ StringQ @ host, { { host <> ":", { FontColor -> acpColor[ "Muted" ] } } }, { } ],
            "Object"      -> folderLabelPieces @ path,
            "ObjectStyle" -> If[ pathColor === Inherited, { }, { FontColor -> pathColor } ],
            "Side"        -> Left,
            "Width"       -> width,
            "Tooltip"     -> None,
            "DropPrefix"  -> False
        |>,
        "WorkspaceChatToolbarTitle",
        FontSize -> 12,
        $pathTextOptions
    ]
];

(* Invalid stored settings without a folder *)
folderLabel[ None, window_Association, _, _ ] := Style[
    acpLabel[ "ProjectDirectoryNoneRemote", <| "host" -> acpRemoteDisplayName @ remoteShortHost @ acpWindowSSH @ window |> ],
    "WorkspaceChatToolbarTitle",
    FontSize  -> 12,
    FontSlant -> Italic
];

folderLabel // endDefinition;


(* The pieces of a display-safe path that are cut whole: its characters, and acpRemoteDisplayName's markers; at most
   $acpFolderLabelMaxLength of them, the end kept *)
folderLabelPieces // beginDefinition;

folderLabelPieces[ path_String ] := Module[ { pieces },
    pieces = Flatten @ Replace[
        StringSplit[ path, m: ("\:27e6U+" ~~ Repeated[ HexadecimalCharacter, { 4, 6 } ] ~~ "\:27e7") :> Hold[ m ] ],
        { Hold[ m_String ] :> m, s_String :> Characters @ s },
        { 1 }
    ];
    If[ Length @ pieces > $acpFolderLabelMaxLength, Prepend[ Take[ pieces, 1 - $acpFolderLabelMaxLength ], "\[Ellipsis]" ], pieces ]
];

folderLabelPieces // endDefinition;


(* The width available to the folder's label (acpFitWidth): what the row leaves after the folder icon, a warning, the
   Review button (with its text and counts, measured in their fonts) and the control's frame. The reserves were
   measured in a real front end (see docs/acp-window.md, "The toolbar"). *)
folderLabelWidth // beginDefinition;

folderLabelWidth[ warning_, git_ ] := acpFitWidth[
    $folderRowReserve + { 0, If[ TrueQ @ warning, $folderWarningReserve, 0 ] + If[ AssociationQ @ git, $reviewButtonReserve, 0 ] },
    If[ AssociationQ @ git, acpReviewButtonTexts @ git, { } ]
];

folderLabelWidth // endDefinition;


(* The tooltip of the control (see acpFolderControl). Paths are drawn as typed (no operator substitution). *)
folderTooltip // beginDefinition;

folderTooltip[ dir_, ssh_, busy_ ] := Style[
    Column[
        {
            folderTooltipLine[ dir, ssh ],
            Which[
                StringQ @ busy, Style[ acpLabel @ busy, FontColor -> acpColor[ "Muted" ] ],
                StringQ @ dir , Style[ acpLabel[ "ProjectDirectoryClickToChange" ], FontColor -> acpColor[ "Muted" ] ],
                True          , Nothing
            ]
        },
        Spacings -> 0.2
    ],
    PrivateFontOptions -> { "OperatorSubstitution" -> False }
];

folderTooltip // endDefinition;


(* "Project folder: path", "Project folder on user@host: path", or that there is none *)
folderTooltipLine // beginDefinition;

folderTooltipLine[ dir_String, None ] :=
    acpLabel[ "ProjectDirectoryTooltip", <| "path" -> acpRemoteDisplayName @ dir |> ];

folderTooltipLine[ dir_String, ssh_ ] :=
    acpLabel[ "ProjectDirectoryTooltipRemote", <| "host" -> acpRemoteDisplayName @ remoteHostLabel @ ssh, "path" -> acpRemoteDisplayName @ dir |> ];

folderTooltipLine[ _, None ] := acpLabel[ "ProjectDirectoryNone" ];

folderTooltipLine[ _, ssh_ ] := acpLabel[ "ProjectDirectoryNoneRemote", <| "host" -> acpRemoteDisplayName @ remoteShortHost @ ssh |> ];

folderTooltipLine // endDefinition;


$pathTextOptions := Sequence[ LineBreakWithin -> False, PrivateFontOptions -> { "OperatorSubstitution" -> False } ];

(* The layout of the folder row, measured like the main row's (see $mainRowReserve): $folderRowReserve is what the row
   takes besides the label's text, as { screen points, points at magnification 1 } (the folder icon, the spacings, the
   control's frame, and a right margin like the menus' above it, so the label ends where the main row does),
   $folderWarningReserve a warning, $reviewButtonReserve the Review button besides its texts (its frame, the spacings
   between its parts), both in points at magnification 1 *)
$folderRowReserve     = { 2.25, 35 };
$folderWarningReserve = 12;
$reviewButtonReserve  = 24;


remoteShortHost // beginDefinition;
remoteShortHost[ ssh_Association ] := Replace[ acpSSHShortHost @ ssh, Except[ _String ] -> "?" ];
remoteShortHost[ _ ] := "?";
remoteShortHost // endDefinition;

remoteHostLabel // beginDefinition;
remoteHostLabel[ ssh_Association ] := Replace[ acpSSHHostLabel @ ssh, Except[ _String ] -> "?" ];
remoteHostLabel[ _ ] := "?";
remoteHostLabel // endDefinition;


(* The code of the window's error, or None *)
windowErrorCode // beginDefinition;
windowErrorCode[ window_Association ] := Lookup[ Replace[ Lookup[ window, "Error", None ], Except[ _Association ] -> <| |> ], "Code", None ];
windowErrorCode[ _ ] := None;
windowErrorCode // endDefinition;


(* None | warning text. A remote window's folder is never looked at on this computer: it is the remote home folder (or
   ~), the root, or missing (the launch said so: the window's error is RemoteFolderMissing). *)
acpDirectoryWarning // beginDefinition;

acpDirectoryWarning[ dir_String, window_Association ] /; acpRemoteQ @ window := With[
    {
        home = acpWindowRemoteHome @ window,
        host = acpRemoteDisplayName @ Replace[ acpWindowShortHost @ window, Except[ _String ] -> "?" ],
        path = acpRemoteLexicalPath @ dir
    },
    Which[
        windowErrorCode @ window === "RemoteFolderMissing",
            acpLabel[ "ProjectDirectoryWarningMissingRemote", <| "host" -> host |> ],
        dir === "~" || StringQ @ home && path === acpRemoteLexicalPath @ home,
            acpLabel[ "ProjectDirectoryWarningHomeRemote", <| "host" -> host |> ],
        path === "/",
            acpLabel[ "ProjectDirectoryWarningRootRemote", <| "host" -> host |> ],
        True,
            None
    ]
];

acpDirectoryWarning[ dir_, _ ] := acpDirectoryWarning @ dir;

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

(* Connection status / errors: Rendering.wl's acpToolbarStatusView is a self-contained view that tracks the window. The
   pane has the toolbar's width, so a long error wraps instead of widening the toolbar column (which would push the
   model/mode/effort menus of the main row past the window's edge); its margins are inside (FrameMargins), since margins
   outside a full-width pane overflow. The toolbar is a docked cell, whose "DockedCell" style turns line breaking off, so
   the pane turns it on again (wrapped lines start at the left edge: LineIndent -> 0). *)
acpStatusRow // beginDefinition;

acpStatusRow[ nbo_NotebookObject ] := Pane[
    acpToolbarStatusView @ nbo,
    BaseStyle    -> { $acpToolbarTextStyle, LineBreakWithin -> Automatic, LineIndent -> 0 },
    FrameMargins -> { { 6, 2 }, { 0, 0 } },
    ImageSize    -> { Full, Automatic }
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
                    { acpAttachmentsArea @ nbo }, (* Attachments.wl: the chips of the draft *)
                    {
                        Framed[
                            Grid[
                                (* the prompt notebook's button (PromptNotebook.wl) next to Send *)
                                { { acpAttachButton @ nbo, acpInputField @ nbo, acpPromptNotebookButton @ nbo, acpSendStopButton @ nbo } },
                                Alignment        -> { Left, Baseline },
                                BaselinePosition -> { 1, 2 },
                                ItemSize         -> { { Automatic, Fit, Automatic, Automatic } },
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

(* a message without attachments, or the messages of the queue as one *)
acpQueuedPromptView[ nbo_, prompt: _String | { __ }, restoring_ ] := acpQueuedPromptView[ nbo, acpQueuedPromptOf @ prompt, restoring ];

(* While a session is restored, a prompt waits for it (see evaluateACPChat). A message with attachments says how many
   ("+2 attachments") *)
acpQueuedPromptView[ nbo_, KeyValuePattern @ { "Text" -> text_String, "Attachments" -> attachments_List }, restoring_ ] := acpInputNote[
    StringRiffle[
        {
            StringTrim @ If[ TrueQ @ restoring,
                acpLabel[ "QueuedPromptRestoring", <| "text" -> acpPreview @ text |> ],
                acpLabel[ "QueuedPrompt", <| "text" -> acpPreview @ text |> ]
            ],
            Switch[ Length @ attachments,
                0, Nothing,
                1, acpLabel[ "QueuedPromptAttachmentsOne" ],
                _, acpLabel[ "QueuedPromptAttachments", <| "n" -> Length @ attachments |> ]
            ]
        },
        " "
    ],
    acpActionButton[ $acpCloseGlyph, { "CancelQueuedPrompt", nbo }, BoxID -> "ACPCancelQueuedPrompt" ],
    acpLabel[ "QueuedPromptCancel" ]
];

acpQueuedPromptView[ _, _, _ ] := Nothing;

acpQueuedPromptView // endDefinition;


acpNoticeView // beginDefinition;

acpNoticeView[ nbo_, notice_String ] := acpInputNote[
    acpSafeText @ notice,
    acpActionButton[ $acpCloseGlyph, { "DismissNotice", nbo }, BoxID -> "ACPDismissNotice" ],
    acpLabel[ "NoticeDismiss" ]
];

(* A notice with a terminal command (e.g. the sign-in of a remote agent): the text, the command as it must be typed (code
   font, wrapped anywhere) and "Copy command", whose button carries no text: the action copies the command of the
   window's notice *)
acpNoticeView[ nbo_, KeyValuePattern @ { "Text" -> text_String, "Command" -> command_String } ] := acpInputNote[
    Column[
        {
            acpSafeText @ text,
            Style[ acpSafeText @ command, FontFamily -> "Source Code Pro", FontSize -> 11 ],
            Tooltip[
                acpActionButton[
                    sessionsButtonLabel[ acpLabel[ "NoticeCopyCommand" ], "Secondary" ],
                    { "CopyNoticeCommand", nbo },
                    BoxID -> "ACPCopyNoticeCommand"
                ],
                acpLabel[ "NoticeCopyCommandTooltip" ]
            ]
        },
        Alignment -> Left,
        Spacings  -> 0.4
    ],
    acpActionButton[ $acpCloseGlyph, { "DismissNotice", nbo }, BoxID -> "ACPDismissNotice" ],
    acpLabel[ "NoticeDismiss" ]
];

acpNoticeView[ _, _ ] := Nothing;

acpNoticeView // endDefinition;


(* Notices show commands and paths as typed: without operator substitution, which draws "-" as a long minus sign *)
acpInputNote // beginDefinition;

acpInputNote[ text_, button_, tooltip_ ] := Framed[
    Grid[
        {
            {
                Style[
                    text,
                    "Text",
                    FontSize           -> 12,
                    FontColor          -> LightDarkSwitched @ RGBColor[ "#555555" ],
                    PrivateFontOptions -> { "OperatorSubstitution" -> False }
                ],
                Tooltip[ button, tooltip ]
            }
        },
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
   transcript, which is written when the session has loaded. A message with attachments (the draft, Attachments.wl) is
   prepared first, on the main link (acpPrepareMessage); it may have no typed text. *)
evaluateACPChat // beginDefinition;

evaluateACPChat[ nbo_NotebookObject ] := Enclose[
    Catch @ Module[ { window, input, draft, prompt, status },

        acpCheckSession @ nbo;
        window = ConfirmBy[ acpEnsureWindowRecord @ nbo, AssociationQ, "Window" ];
        input  = acpFE[ nbo, "Input", "" ];
        draft  = acpDraftAttachments @ window;
        If[ ! validInputStringQ @ input && draft === { }, Throw @ Null ];

        prompt = If[ validInputStringQ @ input, ConfirmBy[ acpInputString @ input, StringQ, "Prompt" ], "" ];
        status = Lookup[ window, "Status", "Disconnected" ];

        Which[
            status === "NoDirectory",
                acpSetNotice[ nbo, acpLabel[ "NoticeNoDirectory" ] ];
                Throw @ Null,

            status === "Error",
                acpSetNotice[ nbo, acpLabel[ "NoticeCannotSend", <| "reason" -> acpErrorMessage @ window |> ] ];
                Throw @ Null,

            (* one message is prepared at a time; the typed text stays in the input field *)
            acpPreparingQ @ window,
                acpSetNotice[ nbo, acpLabel[ "NoticePreparing" ] ];
                Throw @ Null,

            draft =!= { },
                acpPrepareMessage[ nbo, If[ validInputStringQ @ input, input, "" ], prompt, draft ];
                Throw @ Null,

            (* also behind messages that wait in the queue (e.g. for the connection): they were sent before *)
            acpRunningQ @ window || acpRestoringQ @ window || acpQueuedPromptQ @ Lookup[ window, "QueuedPrompt", None ],
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
(*Messages with Attachments*)

(* Send with attachments (preemptive, fast): the input and the draft are taken (and given back if the message is not
   sent, see acpGiveBackDraft), the window is busy at once (Stop instead of Send: no second send), and a main link job
   prepares the attachments (Attachments.wl's acpPrepareAttachmentsJob, queued with MCP.wl's acpMainLinkRun): converting
   notebooks and rasterizing graphics make front end calls and take time, which no preemptive evaluation may do. The
   message is kept in the TaggingRules ({"ACP", "PreparingPrompt"}) until the job is done, so a kernel restart gives it
   back (R8). *)
acpPrepareMessage // beginDefinition;

acpPrepareMessage[ nbo_NotebookObject, input_, prompt_String, refs_List ] := With[ { token = createUUID[ ] },
    acpWindowUpdate[
        nbo,
        <|
            #,
            "Preparing"   -> <| "Token" -> token, "StartedAt" -> AbsoluteTime[ ], "Input" -> input, "Text" -> prompt, "Attachments" -> refs |>,
            "Attachments" -> { },
            "Notice"      -> None
        |> &
    ];
    acpFESet[ nbo, "PreparingPrompt", <| "Input" -> input, "Text" -> prompt, "Attachments" -> refs |> ];
    acpFESet[ nbo, "Attachments", { } ];
    acpFESet[ nbo, "Input", "" ];
    acpFESet[ nbo, "Busy", True ];
    acpMainLinkRun[ nbo, acpPrepareAttachmentsJob[ nbo, token ], "Attachments" ];
    acpPublish[ ];
    token
];

acpPrepareMessage // endDefinition;


acpPreparingQ // beginDefinition;
acpPreparingQ[ window_Association ] := AssociationQ @ Lookup[ window, "Preparing", None ];
acpPreparingQ[ _ ] := False;
acpPreparingQ // endDefinition;


(* The result of the main link job (in the pump): <| "Attachments" -> prepared |> or a Failure with a "Notice". The
   preparation is claimed first (Stop, New and the timeout cancel it, and its result is then dropped). A failure gives
   the draft back with the failure's notice; otherwise the turn starts, or is queued while one runs (or a session loads),
   like a message without attachments, and also behind a queued message that was sent before it. A message queued
   meanwhile that was sent after it (a prompt notebook's, see acpSendPreparedMessage) follows its turn. *)
acpPreparedPrompt // beginDefinition;

acpPreparedPrompt[ nbo_NotebookObject, token_String, result_ ] := Catch @ Module[ { prep = None, window, status, turnID },
    (* a window that was closed meanwhile has no record: none is created for it (housekeeping would make front end
       calls for it for good) *)
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ] && MatchQ[ Lookup[ w, "Preparing", None ], KeyValuePattern[ "Token" -> token ] ],
                prep = w[ "Preparing" ]; <| w, "Preparing" -> None |>,
                Missing[ "NotClaimed" ]
            ]
        ]
    ];
    If[ ! AssociationQ @ prep, Throw @ Null ];
    acpFESet[ nbo, "PreparingPrompt", None ];
    window = acpWindowGet @ nbo;
    status = Lookup[ window, "Status", "Disconnected" ];

    Which[
        ! MatchQ[ result, KeyValuePattern[ "Attachments" -> _List ] ],
            preparationFailed[ nbo, prep, preparationNotice @ result ],

        status === "NoDirectory",
            preparationFailed[ nbo, prep, acpLabel[ "NoticeNoDirectory" ] ],

        status === "Error",
            preparationFailed[ nbo, prep, acpLabel[ "NoticeCannotSend", <| "reason" -> acpErrorMessage @ window |> ] ],

        acpRunningQ @ window || acpRestoringQ @ window || acpQueuedBeforeQ[ window, sentAt @ prep ],
            acpQueuePrompt[ nbo, prep[ "Text" ], result[ "Attachments" ], sentAt @ prep ],

        True,
            turnID = acpCatchAll[
                Module[ { input = prep[ "Input" ] },
                    acpStartTurn[ nbo, Dynamic @ input, prep[ "Text" ], status, Automatic, result[ "Attachments" ] ]
                ],
                (acpLog[ "PreparedPromptFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; $Failed) &
            ];
            If[ ! StringQ @ turnID && ! acpRunningQ @ acpWindowGet @ nbo, preparationFailed[ nbo, prep, None ] ];
            turnID
    ]
];

acpPreparedPrompt // endDefinition;


preparationNotice // beginDefinition;
preparationNotice[ failure_Failure ] := Replace[ failure[ "Notice" ], Except[ _String ] :> acpLabel[ "NoticeAttachmentsFailed" ] ];
preparationNotice[ _ ] := acpLabel[ "NoticeAttachmentsFailed" ];
preparationNotice // endDefinition;


(* The time of a prepared message's Send click *)
sentAt // beginDefinition;
sentAt[ prep_Association ] := Replace[ Lookup[ prep, "StartedAt", None ], Except[ _? NumberQ ] :> AbsoluteTime[ ] ];
sentAt // endDefinition;


(* The message was not sent: its text and attachments go back to the input field, the window is idle again (unless a
   turn runs) *)
preparationFailed // beginDefinition;

preparationFailed[ nbo_NotebookObject, prep_Association, notice_ ] := (
    acpGiveBackDraft[ nbo, prep ];
    If[ StringQ @ notice, acpSetNotice[ nbo, notice ] ];
    If[ ! acpRunningQ @ acpWindowGet @ nbo,
        acpFESet[ nbo, "Busy", False ];
        acpSchedule[ settleBusyFlag @ nbo, Quantity[ 500, "Milliseconds" ] ]
    ];
    (* a message queued behind this one (sent after it, see acpSendPreparedMessage) no longer waits for it *)
    acpSchedule @ acpKickQueue @ nbo;
    acpPublish[ ];
    Null
);

preparationFailed // endDefinition;


(* Stop, New, a folder or host change, a restored session and housekeeping's timeout: the preparation is dropped (the
   job's result will be ignored) and the message goes back to the input field. True if there was one. A window without a
   record (closed) gets none. *)
acpCancelPreparation // beginDefinition;

acpCancelPreparation[ nbo_NotebookObject, notice_ ] := Module[ { prep = None },
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ] && AssociationQ @ Lookup[ w, "Preparing", None ],
                prep = w[ "Preparing" ]; <| w, "Preparing" -> None |>,
                Missing[ "NotClaimed" ] (* never a partial record for a window without one *)
            ]
        ]
    ];
    If[ ! AssociationQ @ prep, Return[ False, Module ] ];
    acpFESet[ nbo, "PreparingPrompt", None ];
    preparationFailed[ nbo, prep, notice ];
    True
];

acpCancelPreparation // endDefinition;


(* A message that was not sent goes back: its text (or what was typed, boxes too) before the input field's text, and its
   attachments into the draft (references, or the references of prepared attachments). A prompt notebook's message
   (PromptNotebook.wl) stays in its notebook, which is still open: the notebook's status says that it was not sent, and
   why (reason: a text, or None). True if anything went back to the input field or the draft. *)
acpGiveBackDraft // beginDefinition;

acpGiveBackDraft[ nbo_NotebookObject, prompt_Association ] := acpGiveBackDraft[ nbo, prompt, None ];

acpGiveBackDraft[ nbo_NotebookObject, prompt_Association, reason_ ] := Module[ { input, attachments, refs },
    input       = Lookup[ prompt, "Input", Lookup[ prompt, "Text", "" ] ];
    attachments = Replace[ Lookup[ prompt, "Attachments", { } ], Except[ _List ] -> { } ];
    refs        = Join[ acpAttachmentRefs @ attachments, acpAttachmentRefsOf @ attachments ];
    acpNotePromptNotebooks[ nbo, refs, "NotSent", reason ];
    refs = DeleteCases[ refs, KeyValuePattern[ "Prompt" -> True ] ];
    If[ validInputStringQ @ input, acpRestoreInput[ nbo, input ] ];
    acpAddDraftAttachments[ nbo, refs ];
    validInputStringQ @ input || refs =!= { }
];

acpGiveBackDraft // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSendPreparedMessage*)

(* A prompt notebook's message (PromptNotebook.wl), whose attachments a main link job prepared (in the pump): sent like
   a prepared message of the input field (acpPreparedPrompt), or queued while a turn runs or a session loads, without
   touching the input field: the user cell is an addressed write after the last cell. The messages of a window go in the
   order of their Send clicks (at: this one's): it is also queued while a message of the input field that was sent
   before it is being prepared (that one's turn starts first) or a message sent before it is queued. Gives "Sent" (the
   turn started, or waits for the connection), "Queued", or a Failure with a "Notice". *)
acpSendPreparedMessage // beginDefinition;

acpSendPreparedMessage[ nbo_NotebookObject, attachments: { __Association } ] := acpSendPreparedMessage[ nbo, attachments, AbsoluteTime[ ] ];

acpSendPreparedMessage[ nbo_NotebookObject, attachments: { __Association }, at_? NumberQ ] := Catch @ Module[
    { window, notice, status, turnID },
    window = acpEnsureWindowRecord @ nbo;
    notice = acpCannotSendNotice @ window;
    If[ StringQ @ notice, Throw @ Failure[ "NotSent", <| "MessageTemplate" -> "The message was not sent.", "Notice" -> notice |> ] ];
    status = Lookup[ window, "Status", "Disconnected" ];
    If[ Or[ acpRunningQ @ window, acpRestoringQ @ window, preparingSince @ window < at, acpQueuedBeforeQ[ window, at ] ],
        acpQueuePrompt[ nbo, "", attachments, at ];
        Throw @ "Queued"
    ];
    turnID = acpCatchAll[
        Module[ { text = "" }, acpStartTurn[ nbo, Dynamic @ text, "", status, Automatic, attachments ] ],
        (acpLog[ "PreparedPromptFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; $Failed) &
    ];
    If[ StringQ @ turnID,
        "Sent",
        Failure[ "NotSent", <| "MessageTemplate" -> "The message was not sent.", "Notice" -> None |> ]
    ]
];

acpSendPreparedMessage // endDefinition;


(* Why the window can't send a message now (no project folder, an error), or None *)
acpCannotSendNotice // beginDefinition;

acpCannotSendNotice[ window_Association ] := Switch[ Lookup[ window, "Status", "Disconnected" ],
    "NoDirectory", acpLabel[ "NoticeNoDirectory" ],
    "Error"      , acpLabel[ "NoticeCannotSend", <| "reason" -> acpErrorMessage @ window |> ],
    _            , None
];

acpCannotSendNotice[ _ ] := None;

acpCannotSendNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStartTurn*)

(* Writes the user cell (shared with the notebook assistance window), the active output cell with the live view, and
   creates the turn. The prompt is sent now if the agent is ready, otherwise the turn is queued until it is.
   With anchor None (Send button) the user cell is written at the selection like in the notebook assistance window;
   otherwise (queued prompts and prepared messages, sent from scheduled tasks while the user may be typing or selecting)
   it is written after anchor (a cell, or Automatic for the last cell) without touching the selection, and shows the
   value of inputSpec. attachments: the message's prepared attachments (Attachments.wl), sent with the prompt and shown
   as chips in the user cell. *)
acpStartTurn // beginDefinition;

acpStartTurn[ nbo_NotebookObject, inputSpec_Dynamic, prompt_String, status_ ] :=
    acpStartTurn[ nbo, inputSpec, prompt, status, None ];

acpStartTurn[ nbo_NotebookObject, inputSpec_Dynamic, prompt_String, status_, anchor_ ] :=
    acpStartTurn[ nbo, inputSpec, prompt, status, anchor, { } ];

acpStartTurn[ nbo_NotebookObject, inputSpec_Dynamic, prompt_String, status_, anchor_, attachments_List ] := Enclose[
    Module[ { window, turnID, userCell, turn, outCell, sendNow },

        window  = ConfirmBy[ acpWindowGet @ nbo, AssociationQ, "Window" ];
        turnID  = ConfirmBy[ "acp-turn-" <> createUUID[ ], StringQ, "TurnID" ];
        sendNow = status === "Ready";

        (* Clears the input and moves the input field to the bottom: *)
        userCell = ConfirmMatch[ acpWriteUserCell[ nbo, inputSpec, prompt, anchor, attachments ], _CellObject, "UserCell" ];

        turn = ConfirmBy[
            acpNewTurn @ <|
                "ID"          -> turnID,
                "Notebook"    -> nbo,
                "SessionID"   -> Lookup[ window, "SessionID", None ],
                "Prompt"      -> prompt,
                "Attachments" -> attachments,
                "InputCell"   -> userCell,
                "OutputCell"  -> None,
                "Remote"      -> acpTurnRemote @ window,
                "StartTime"   -> AbsoluteTime[ ]
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

        (* the status of a prompt notebook whose message this is (PromptNotebook.wl) *)
        acpNotePromptNotebooks[ nbo, attachments, "Sent" ];
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

acpWriteUserCell[ nbo_NotebookObject, inputSpec_Dynamic, prompt_, anchor_ ] :=
    acpWriteUserCell[ nbo, inputSpec, prompt, anchor, { } ];

acpWriteUserCell[ nbo_NotebookObject, inputSpec_Dynamic, _, None, { } ] :=
    writeWorkspaceChatInputCell[ nbo, inputSpec ];

(* The addressed write shows the value of inputSpec (what was typed: boxes, or the queued prompt's text) *)
acpWriteUserCell[ nbo_NotebookObject, Dynamic[ input_ ], prompt_String, anchor_, attachments_List ] :=
    acpWriteUserCellAddressed[ nbo, Replace[ input, Except[ _String? StringQ | _? (validInputStringQ) ] -> prompt ], anchor, attachments ];

acpWriteUserCell // endDefinition;


(* The user cell is written after anchor (or after the last cell) with an addressed write: no SelectionMove, no
   selection-based NotebookWrite, no scrolling, so it never lands inside a cell the user clicked into. The input field is
   not touched (a queued prompt was already taken from it). input: what the cell shows (a string, or the boxes of the
   input field); attachments: the message's (chips after the text, Attachments.wl's acpUserCellExpr). *)
acpWriteUserCellAddressed // beginDefinition;

acpWriteUserCellAddressed[ nbo_NotebookObject, input_, anchor_ ] := acpWriteUserCellAddressed[ nbo, input, anchor, { } ];

acpWriteUserCellAddressed[ nbo_NotebookObject, input_, anchor_, attachments_List ] := Enclose[
    Module[ { location, uuid, cell, cellObject },
        location = If[ MatchQ[ anchor, _CellObject ] && acpCellExistsQ @ anchor, anchor, Last[ Cells @ nbo, None ] ];

        (* An empty window has no cell to write after (and nothing the selection could be inside of): *)
        If[ ! MatchQ[ location, _CellObject ] && attachments === { },
            Return[ Module[ { text = input }, writeWorkspaceChatInputCell[ nbo, Dynamic @ text ] ], Module ]
        ];

        uuid = ConfirmBy[ createUUID[ ], StringQ, "UUID" ];
        cell = ConfirmMatch[ acpUserCellExpr[ input, attachments, uuid ], _Cell, "Cell" ];
        If[ MatchQ[ location, _CellObject ],
            contextBlock @ NotebookWrite[ System`NotebookLocationSpecifier[ location, "After" ], cell, None, AutoScroll -> False ],
            (* an empty window, as writeWorkspaceChatInputCell writes there *)
            SelectionMove[ nbo, After, Notebook, AutoScroll -> True ];
            contextBlock @ NotebookWrite[ nbo, cell ]
        ];
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

(* A message sent while a turn is running (or a session loads) is queued and sent after the turn is finalized. The queue
   is a list of messages in the order of their Send clicks ("At"; a message whose attachments were prepared first goes
   where its click was, see acpQueuedBeforeQ): <| "Text", "Attachments" (prepared, Attachments.wl), "At" |>. When the
   queue is sent (acpSendQueuedPrompt), its messages are merged into one: the texts are joined with a blank line, the
   attachments appended, their images numbered again (each message numbers its own from 1). As many messages are merged
   as stay within the caps of one message (Attachments.wl's acpMessageFitsQ: the bytes and images that one ACP message
   of the window may have, as for the attachments of one message), at least one; the others are sent after that turn, in
   order. A prompt notebook's new message replaces its queued one. The queued messages are also kept in the TaggingRules
   (their text and the references of their attachments, as one message; acpPersistQueuedPrompt), so that a kernel
   restart gives them back. Typed text (evaluateACPChat) leaves the input field; a prepared message (with attachments,
   or a prompt notebook's) was taken from it before, or never was in it, so the input field, where the next message may
   be typed meanwhile, is not touched. at: the time of the message's Send click. *)
acpQueuePrompt // beginDefinition;

acpQueuePrompt[ nbo_NotebookObject, prompt_String ] := (
    acpQueuePrompt[ nbo, prompt, { } ];
    acpFESet[ nbo, "Input", "" ];
    acpPublish[ ]
);

acpQueuePrompt[ nbo_NotebookObject, prompt_String, attachments_List ] := acpQueuePrompt[ nbo, prompt, attachments, AbsoluteTime[ ] ];

acpQueuePrompt[ nbo_NotebookObject, prompt_String, attachments_List, at_? NumberQ ] := Module[ { window },
    window = acpWindowUpdate[ nbo, <| #, "QueuedPrompt" -> queueMessage[ #[ "QueuedPrompt" ], prompt, attachments, at ] |> & ];
    acpPersistQueuedPrompt[ nbo, Lookup[ window, "QueuedPrompt", None ] ];
    (* the status of a prompt notebook whose message this is (PromptNotebook.wl) *)
    acpNotePromptNotebooks[ nbo, attachments, "Queued" ];
    acpKickQueue @ nbo;
    acpPublish[ ]
];

acpQueuePrompt // endDefinition;


(* The queue with a new message, after those sent before it. A prompt notebook's new message replaces its queued one
   (Send again while it is queued, PromptNotebook.wl): the agent never gets the notebook twice. *)
queueMessage // beginDefinition;

queueMessage[ old_, prompt_String, attachments_List, at_ ] := Module[ { messages },
    messages = DeleteCases[
        <| #, "Attachments" -> acpReplacedPromptAttachments[ #[ "Attachments" ], attachments ] |> & /@ acpQueuedMessages @ old,
        KeyValuePattern @ { "Text" -> "", "Attachments" -> { } }
    ];
    Insert[
        messages,
        <| "Text" -> prompt, "Attachments" -> attachments, "At" -> at |>,
        LengthWhile[ messages, #[ "At" ] <= at & ] + 1
    ]
];

queueMessage // endDefinition;


(* The messages of the queue (see acpQueuePrompt), in order; a String or one <| "Text", "Attachments" |> is one message
   (sent before any other) *)
acpQueuedMessages // beginDefinition;

acpQueuedMessages[ prompt_String ] := { <| "Text" -> prompt, "Attachments" -> { }, "At" -> 0 |> };

acpQueuedMessages[ prompt: KeyValuePattern @ { "Text" -> _String, "Attachments" -> _List } ] := { <| "At" -> 0, Association @ prompt |> };

acpQueuedMessages[ messages_List ] := Cases[
    messages,
    message: KeyValuePattern @ { "Text" -> _String, "Attachments" -> _List } :> <| "At" -> 0, Association @ message |>
];

acpQueuedMessages[ _ ] := { };

acpQueuedMessages // endDefinition;


(* The queued messages as one <| "Text", "Attachments" |> (what the note above the input field shows, what Cancel and a
   new chat give back, what the TaggingRules keep), or None *)
acpQueuedPromptOf // beginDefinition;
acpQueuedPromptOf[ prompt_ ] := Replace[ acpQueuedMessages @ prompt, { { } -> None, messages_ :> mergeMessages @ messages } ];
acpQueuedPromptOf // endDefinition;


mergeMessages // beginDefinition;

mergeMessages[ messages_List ] := <|
    "Text"        -> StringRiffle[ Select[ Lookup[ messages, "Text", "" ], StringLength[ # ] > 0 & ], "\n\n" ],
    "Attachments" -> Catenate @ Lookup[ messages, "Attachments", { } ]
|>;

mergeMessages // endDefinition;


(* Whether a message of the queue was sent before time t (the Send click of a message whose attachments were prepared
   meanwhile, which then goes after it) *)
acpQueuedBeforeQ // beginDefinition;
acpQueuedBeforeQ[ window_Association, t_ ] := AnyTrue[ acpQueuedMessages @ Lookup[ window, "QueuedPrompt", None ], #[ "At" ] < t & ];
acpQueuedBeforeQ[ _, _ ] := False;
acpQueuedBeforeQ // endDefinition;


(* The time of the Send click of the message whose attachments are being prepared (Infinity if there is none): a
   message sent after it waits for it *)
preparingSince // beginDefinition;

preparingSince[ window_Association ] := Replace[
    Lookup[ window, "Preparing", None ],
    { KeyValuePattern[ "StartedAt" -> t_? NumberQ ] :> t, _ :> Infinity }
];

preparingSince[ _ ] := Infinity;

preparingSince // endDefinition;


(* The next turn of the queue: { the message (the first messages, merged as far as they stay within the caps of one
   message of the window; their images numbered again), the messages that stay queued }, or None if the first message
   was sent after the Send click of a message that is being prepared (it waits for that one) *)
queuedBatch // beginDefinition;

queuedBatch[ window_Association, messages: { __Association } ] := Module[ { ready, sizes, n },
    ready = LengthWhile[ messages, #[ "At" ] < preparingSince @ window & ];
    If[ ready === 0, Return[ None, Module ] ];
    sizes = acpMessageSize[ #[ "Text" ], #[ "Attachments" ] ] & /@ Take[ messages, ready ];
    n     = Max[ 1, LengthWhile[ Accumulate @ sizes, acpMessageFitsQ[ window, # ] & ] ];
    {
        <| #, "Attachments" -> acpRenumberImages @ #[ "Attachments" ] |> & @ mergeMessages @ Take[ messages, n ],
        Drop[ messages, n ]
    }
];

queuedBatch[ _, _ ] := None;

queuedBatch // endDefinition;


(* After a message was queued while no turn runs (it waits for one that was sent before it, see acpQueuedBeforeQ): the
   queue is sent when the window is ready, and a window that lost its connection connects again, as Send does *)
acpKickQueue // beginDefinition;

acpKickQueue[ nbo_NotebookObject ] := With[ { window = acpWindowGet @ nbo },
    If[ AssociationQ @ window && acpQueuedPromptQ @ Lookup[ window, "QueuedPrompt", None ] && ! acpRunningQ @ window && ! acpRestoringQ @ window,
        Switch[ Lookup[ window, "Status", None ],
            "Ready"       , acpSchedule @ acpSendQueuedPrompt @ nbo,
            "Disconnected", acpEnsureConnected @ nbo,
            _             , Null
        ]
    ];
    Null
];

acpKickQueue // endDefinition;


(* The queued messages in the TaggingRules (R8), as one: their text and the references of their attachments, never
   their content *)
acpPersistQueuedPrompt // beginDefinition;

acpPersistQueuedPrompt[ nbo_NotebookObject, prompt_ ] := acpFESet[
    nbo,
    "QueuedPrompt",
    Replace[
        acpQueuedPromptOf @ prompt,
        q_Association :> <| "Text" -> q[ "Text" ], "Attachments" -> acpAttachmentRefsOf @ q[ "Attachments" ] |>
    ]
];

acpPersistQueuedPrompt // endDefinition;


acpQueuedPromptQ // beginDefinition;
acpQueuedPromptQ[ prompt_ ] := acpQueuedMessages @ prompt =!= { };
acpQueuedPromptQ // endDefinition;


acpCancelQueuedPrompt // beginDefinition;

acpCancelQueuedPrompt[ nbo_NotebookObject ] := Module[ { prompt },
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    prompt = acpQueuedPromptOf @ acpWindowGet[ nbo, "QueuedPrompt", None ];
    acpWindowSet[ nbo, "QueuedPrompt", None ];
    acpPersistQueuedPrompt[ nbo, None ];
    (* Give the text back (before anything typed since) and the attachments into the draft (a prompt notebook's message
       stays in its notebook): *)
    If[ AssociationQ @ prompt, acpGiveBackDraft[ nbo, prompt, acpLabel[ "PromptNotebookRemoved" ] ] ];
    acpPublish[ ]
];

acpCancelQueuedPrompt // endDefinition;


(* Sends the next turn of the queue (runs in a scheduled task after finalization, or from housekeeping): its first
   messages, as many as fit into one message (queuedBatch); the others stay queued for the turn after it. The user cell
   is written after anchor (the output cell of the turn that was just finalized) or after the last cell. *)
acpSendQueuedPrompt // beginDefinition;

acpSendQueuedPrompt[ nbo_NotebookObject ] := acpSendQueuedPrompt[ nbo, Automatic ];

acpSendQueuedPrompt[ nbo_NotebookObject, anchor_ ] := Catch @ Module[ { window, raw, batch, prompt, rest, claimed, result },
    window = acpWindowGet @ nbo;
    If[ ! AssociationQ @ window, Throw @ Null ];
    raw = Lookup[ window, "QueuedPrompt", None ];
    If[ ! acpQueuedPromptQ @ raw || acpRunningQ @ window || acpRestoringQ @ window || Lookup[ window, "Status" ] =!= "Ready", Throw @ Null ];
    If[ ! acpNotebookExistsQ @ nbo, Throw @ Null ];
    batch = queuedBatch[ window, acpQueuedMessages @ raw ];
    If[ batch === None, Throw @ Null ];
    { prompt, rest } = batch;
    rest = If[ rest === { }, None, rest ];

    (* Claim the turn's messages so they are sent only once: *)
    claimed = False;
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ Lookup[ w, "QueuedPrompt" ] === raw && ! acpRunningQ @ w && ! acpRestoringQ @ w,
                claimed = True; <| w, "QueuedPrompt" -> rest |>,
                w
            ]
        ]
    ];
    If[ ! claimed, Throw @ Null ];
    acpPersistQueuedPrompt[ nbo, rest ];

    result = acpCatchAll[
        Module[ { text = prompt[ "Text" ] },
            acpStartTurn[ nbo, Dynamic @ text, prompt[ "Text" ], "Ready", Replace[ anchor, None -> Automatic ], prompt[ "Attachments" ] ]
        ],
        (acpLog[ "QueuedPromptFailed", <| "Value" -> #1, "Tag" -> #2 |> ]; $Failed) &
    ];

    (* The messages were claimed but no turn was started: they go back to the input field (and their attachments to the
       draft), with those still queued after them, so that none is lost or sent before them (putting them back into the
       queue would make housekeeping retry them every tick). *)
    If[ ! StringQ @ result && ! acpRunningQ @ acpWindowGet @ nbo,
        acpGiveBackDraft[ nbo, mergeMessages @ Prepend[ takeQueue @ nbo, prompt ] ]
    ];
    result
];

acpSendQueuedPrompt // endDefinition;


(* Takes the window's queue (its messages) *)
takeQueue // beginDefinition;

takeQueue[ nbo_NotebookObject ] := Module[ { taken = { } },
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ],
                taken = acpQueuedMessages @ Lookup[ w, "QueuedPrompt", None ]; <| w, "QueuedPrompt" -> None |>,
                Missing[ "NotFound" ]
            ]
        ]
    ];
    If[ taken =!= { }, acpPersistQueuedPrompt[ nbo, None ] ];
    taken
];

takeQueue // endDefinition;


(* Puts text back into the window's input field (before anything typed since); typed boxes (e.g. of a message whose
   attachments could not be prepared) go back into an empty field, or as text before typed text *)
acpRestoreInput // beginDefinition;

acpRestoreInput[ nbo_NotebookObject, text_String ] := With[ { input = acpFE[ nbo, "Input", "" ] },
    Which[
        ! validInputStringQ @ input, acpFESet[ nbo, "Input", text ],
        StringQ @ input           , acpFESet[ nbo, "Input", text <> "\n\n" <> input ],
        True                      , acpLog[ "QueuedPromptNotRestored", text ] (* never overwrite typed boxes *)
    ];
    acpPublish[ ]
];

acpRestoreInput[ nbo_NotebookObject, boxes_ ] := With[ { input = acpFE[ nbo, "Input", "" ] },
    If[ ! validInputStringQ @ input,
        acpFESet[ nbo, "Input", boxes ];
        acpPublish[ ],
        Replace[ acpCatchAll @ acpInputString @ boxes, { text_String :> acpRestoreInput[ nbo, text ], _ :> acpLog[ "QueuedPromptNotRestored", boxes ] } ]
    ]
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
   Waits until $acpFinalizeDebounce seconds after the end of the turn, to absorb trailing updates.

   The cell is not replaced at once: the front end may be evaluating the live view's Dynamics (with "Working" open, one
   per entity, which it evaluates one by one as it formats new ones), and a NotebookWrite that replaces a cell while
   the front end waits for one of its Dynamics in the middle of formatting it makes the front end fail an assertion
   ("overcounted formatting", CellControl.cpp) and crash. The scheduled task that finalizes holds the kernel, so a
   Dynamic the front end asks for meanwhile always waits for it. So the live view is frozen first (Rendering.wl's
   acpFreezeLiveView: no more change publication for the turn, and its layout shows the same boxes without Dynamics),
   and acpWriteFinalCell writes the final cell once the front end has shown the frozen view. *)
acpFinalizeTurn // beginDefinition;

acpFinalizeTurn[ turnID_String ] := Catch @ Module[ { turn, delay, claimed, cell },

    turn = acpTurnGet @ turnID;
    If[ ! AssociationQ @ turn || TrueQ @ turn[ "FinalizeClaimed" ], Throw @ Null ];

    delay = acpFinalizeDelay @ turn;
    If[ delay > 0,
        acpSchedule[ acpFinalizeTurn @ turnID, Quantity[ Ceiling[ 1000 * delay ], "Milliseconds" ] ];
        Throw @ Null
    ];

    claimed = AssociationQ @ acpTurnUpdate[ turnID, acpClaimFinalize ];
    If[ ! claimed, Throw @ Null ];

    (* Once the turn is claimed nothing else finalizes it, so everything below must always end in acpFinishTurnState
       (acpWriteFinalCell, or the housekeeping fallback, acpForceFinishTurn) *)
    cell = acpTurnGet[ turnID, "OutputCell", None ];
    If[ acpCellExistsQ @ cell && ! FailureQ @ acpCatchAll @ acpFreezeLiveView @ turnID,
        acpTurnUpdate[ turnID, <| "Turn" -> <| #, "FrozenAt" -> AbsoluteTime[ ] |>, "Changed" -> { }, "Layout" -> False |> & ]
    ];
    acpWriteFinalCell @ turnID
];

acpFinalizeTurn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWriteFinalCell*)

(* The second step of acpFinalizeTurn: once the front end has shown the frozen live view (or after $acpFreezeTimeout
   seconds), renders the final cell and writes it over the active output cell, then finishes the turn's state. Until
   then it schedules itself again. Writes once ("FinalWriteClaimed").
   The front end does not evaluate the Dynamics of a cell that is scrolled out of view, so it never shows the frozen view
   of such a cell. Then the final cell is rendered in one evaluation and written in a later one: the pump task holds the
   kernel while it renders (seconds for a large turn), and if the user scrolls the cell into view meanwhile, the front
   end's evaluation of the frozen view waits for the kernel and must be done (and settled) before the cell is replaced.
   A frozen view that was shown has no Dynamic the front end could ask for, so it is replaced in the same evaluation. *)
acpWriteFinalCell // beginDefinition;

acpWriteFinalCell[ turnID_String ] := Catch @ Module[ { turn, nbo, cell, final },

    turn = acpTurnGet @ turnID;
    If[ ! AssociationQ @ turn || ! TrueQ @ turn[ "FinalizeClaimed" ] || TrueQ @ turn[ "FinalWriteClaimed" ], Throw @ Null ];

    If[ acpFrozenViewPendingQ[ turn, AbsoluteTime[ ] ],
        acpSchedule[ acpWriteFinalCell @ turnID, $acpFreezePoll ];
        Throw @ Null
    ];

    (* Rendering and writing are guarded against any Throw (an untagged Throw would otherwise only be caught by the
       outer Catch and wedge the window in "Running"). *)
    nbo   = Lookup[ turn, "Notebook" ];
    cell  = Lookup[ turn, "OutputCell" ];
    final = Lookup[ turn, "FinalCell", None ];

    If[ final === None && acpFrozenViewUnshownQ @ turn && acpCellExistsQ @ cell,
        final = Replace[ acpCatchAll @ acpRenderFinalCell @ turnID, Except[ _Cell ] :> acpStaticFinalCell[ ] ];
        acpTurnUpdate[ turnID, <| "Turn" -> <| #, "FinalCell" -> final |>, "Changed" -> { }, "Layout" -> False |> & ];
        acpSchedule[ acpWriteFinalCell @ turnID, $acpFreezePoll ];
        Throw @ Null
    ];

    If[ ! AssociationQ @ acpTurnUpdate[ turnID, acpClaimFinalWrite ], Throw @ Null ];

    (* The cell or window is gone (window closed, New chat, ...): just drop the state *)
    If[ ! acpCellExistsQ @ cell,
        acpFinishTurnState[ turnID, nbo ];
        Throw @ Null
    ];

    If[ final === None, final = Replace[ acpCatchAll @ acpRenderFinalCell @ turnID, Except[ _Cell ] :> acpStaticFinalCell[ ] ] ];

    AbortProtect @ WithCleanup[
        acpCatchAll[ contextBlock @ NotebookWrite[ cell, final, None, AutoScroll -> False ], (acpLog[ "FinalCellWriteFailed", { turnID, ## } ]; $Failed) & ],
        acpFinishTurnState[ turnID, nbo ]
    ];

    (* The user cell of a queued prompt is written after this turn's output cell (addressed write, no selection): *)
    If[ MatchQ[ nbo, _NotebookObject ], acpSendQueuedPrompt[ nbo, cell ] ]
];

acpWriteFinalCell // endDefinition;


(* Whether acpWriteFinalCell waits for the front end. The live view was frozen ("FrozenAt"), and
     * the front end has rendered the frozen view ("FrozenViewShownAt", Rendering.wl) less than $acpFreezeSettle seconds
       ago (at most until twice $acpFreezeTimeout after the freeze), or
     * it has not rendered it yet, and the freeze was less than $acpFreezeTimeout seconds ago.
   A rendering of the frozen view is followed by the front end formatting static boxes only, which needs no kernel, and
   no symbol of the turn changes any more, so nothing makes the front end evaluate one of the cell's Dynamics while it is
   replaced. *)
acpFrozenViewPendingQ // beginDefinition;

acpFrozenViewPendingQ[ turn_Association, now_? NumberQ ] := With[
    {
        frozen = acpAbsoluteTime @ Lookup[ turn, "FrozenAt", None ],
        shown  = acpAbsoluteTime @ Lookup[ turn, "FrozenViewShownAt", None ]
    },
    NumberQ @ frozen && If[ NumberQ @ shown,
        now - shown < $acpFreezeSettle && now - frozen < 2 * $acpFreezeTimeout,
        now - frozen < $acpFreezeTimeout
    ]
];

acpFrozenViewPendingQ // endDefinition;


acpFrozenViewUnshownQ // beginDefinition;
acpFrozenViewUnshownQ[ turn_Association ] := NumberQ @ acpAbsoluteTime @ Lookup[ turn, "FrozenAt", None ] && ! NumberQ @ acpAbsoluteTime @ Lookup[ turn, "FrozenViewShownAt", None ];
acpFrozenViewUnshownQ // endDefinition;


acpClaimFinalWrite // beginDefinition;

acpClaimFinalWrite[ turn_Association ] :=
    If[ TrueQ @ turn[ "FinalWriteClaimed" ],
        Null,
        <| "Turn" -> <| turn, "FinalWriteClaimed" -> True |>, "Changed" -> { }, "Layout" -> False |>
    ];

acpClaimFinalWrite // endDefinition;


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
        (* not while the attachments of a message are prepared: Stop, which cancels that, stays (acpPrepareMessage) *)
        If[ Lookup[ window, "CurrentTurn", None ] === None && ! acpPreparingQ @ window,
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
   otherwise Connection.wl cancels the prompt. Without a turn, Stop cancels the preparation of a message with attachments
   (its text and attachments go back to the input field). *)
acpStopAction // beginDefinition;

acpStopAction[ nbo_NotebookObject ] := Catch @ Module[ { window, turnID },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    turnID = Lookup[ window, "CurrentTurn", None ];

    (* Nothing is running (e.g. the kernel was restarted, or attachments are prepared): reset the flag *)
    If[ ! StringQ @ turnID || ! AssociationQ @ acpTurnGet @ turnID,
        acpCancelPreparation[ nbo, None ];
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
    (* a message whose attachments are being prepared goes back to the input field, like typed text it stays *)
    acpCancelPreparation[ nbo, None ];
    (* a queued message is dropped; a prompt notebook's says so in its notebook, as one that is being prepared does
       (PromptNotebook.wl) *)
    acpNotePromptNotebooks[
        nbo,
        Lookup[ Replace[ acpQueuedPromptOf @ acpWindowGet[ nbo, "QueuedPrompt", None ], None -> <| |> ], "Attachments", { } ],
        "NotSent",
        acpLabel[ "PromptNotebookNewChat" ]
    ];
    acpCancelPromptNotebookJobs[ nbo, acpLabel[ "PromptNotebookNewChat" ] ];
    acpWindowUpdate[ nbo, <| #, "QueuedPrompt" -> None, "Notice" -> None, "Turns" -> { } |> & ];
    acpPersistQueuedPrompt[ nbo, None ];
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

(* The local folder chooser (FileNameSetter); a remote window's folder is only set by the remote folder picker *)
acpSetProjectDirectoryAction[ nbo_NotebookObject, dir0_ ] := Catch @ Module[ { window, dir },
    acpCheckSession @ nbo;
    window = acpEnsureWindowRecord @ nbo;
    If[ acpRemoteQ @ window, Throw @ Null ];
    dir = acpNormalizeDirectory @ dir0;
    If[ ! acpValidProjectDirectoryQ[ dir, None ] || dir === Lookup[ window, "ProjectDirectory" ], Throw @ Null ];
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
   location follow. extra: see acpSetProjectDirectory (Sessions.wl restores a session of another folder this way).
   Gives acpSetProjectDirectory's result: the new folder, Null (unchanged) or a Failure (e.g. a folder that doesn't
   exist). *)
acpChangeProjectDirectory // beginDefinition;

acpChangeProjectDirectory[ nbo_NotebookObject, dir_String ] := acpChangeProjectDirectory[ nbo, dir, <| |> ];

acpChangeProjectDirectory[ nbo_NotebookObject, dir_String, extra_Association ] := Module[ { queued, result },
    (* the reset of the folder drops the queued message *)
    queued = acpQueuedPromptOf @ acpWindowGet[ nbo, "QueuedPrompt", None ];
    result = If[ extra === <| |>, acpSetProjectDirectory[ nbo, dir ], acpSetProjectDirectory[ nbo, dir, extra ] ];
    acpSetNotice[ nbo, None ];
    If[ StringQ @ result, acpReturnPendingMessages[ nbo, queued ] ];
    acpDirectoryChanged @ nbo;
    result
];

acpChangeProjectDirectory // endDefinition;


(* A new chat in another folder or on another host (the reset dropped the queued message, queued: taken before it), or a
   restored session (Sessions.wl): the messages that were not sent yet are not sent to it. The one whose attachments are
   being prepared and the queued one go back to the input field (their text before what was typed since, the queued one
   first: it was sent first; their attachments into the draft), with a notice; the messages of prompt notebooks stay in
   their notebooks, whose status says so, also those that are being prepared (PromptNotebook.wl). *)
acpReturnPendingMessages // beginDefinition;

(* A session restored from the same folder (Sessions.wl): nothing resets the window, so the queued message is taken
   here *)
acpReturnPendingMessages[ nbo_NotebookObject ] := Module[ { queued = None },
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ],
                queued = acpQueuedPromptOf @ Lookup[ w, "QueuedPrompt", None ]; <| w, "QueuedPrompt" -> None |>,
                Missing[ "NotFound" ]
            ]
        ]
    ];
    If[ AssociationQ @ queued, acpPersistQueuedPrompt[ nbo, None ] ];
    acpReturnPendingMessages[ nbo, queued ]
];

acpReturnPendingMessages[ nbo_NotebookObject, queued_ ] := Module[ { returned },
    returned = {
        acpCancelPreparation[ nbo, None ],
        If[ AssociationQ @ queued, acpGiveBackDraft[ nbo, queued, acpLabel[ "PromptNotebookNewChat" ] ], False ]
    };
    acpCancelPromptNotebookJobs[ nbo, acpLabel[ "PromptNotebookNewChat" ] ];
    If[ MemberQ[ returned, True ], acpSetNotice[ nbo, acpLabel[ "NoticeMessageReturned" ] ] ];
    Null
];

acpReturnPendingMessages // endDefinition;


(* After the folder changed (a new chat): the input field goes to the top of the empty window, the title follows *)
acpDirectoryChanged // beginDefinition;

acpDirectoryChanged[ nbo_NotebookObject ] := (
    If[ $FrontEnd =!= Null && Quiet @ Cells @ nbo === { }, moveChatInputToTop @ nbo ];
    acpUpdateWindowTitle @ nbo;
    acpPublish[ ];
    Null
);

acpDirectoryChanged // endDefinition;

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
acpErrorAction[ nbo_NotebookObject, "SignIn"          ] := With[ { window = acpEnsureWindowRecord @ nbo },
    acpSetNotice[ nbo, If[ acpRemoteQ @ window, signInRemoteNotice @ window, acpLabel[ "NoticeSignIn" ] ] ]
];
acpErrorAction[ nbo_NotebookObject, "LocateAgent"     ] := With[ { window = acpEnsureWindowRecord @ nbo },
    acpSetNotice[ nbo, If[ acpRemoteQ @ window, locateAgentRemoteNotice @ window, acpLabel[ "NoticeLocateAgent" ] ] ]
];
(* "Choose folder..." (an error's button, or the folder row of a remote window): a remote window's folder is chosen in
   the remote folder picker (FolderPicker.wl); a user action, so it clears the host's failure latch (Remote.wl) *)
acpErrorAction[ nbo_NotebookObject, "ChooseDirectory" ] := With[ { window = acpEnsureWindowRecord @ nbo },
    If[ AssociationQ @ acpWindowSSH @ window,
        acpRemoteClearHostError @ acpWindowHostKey @ window;
        acpFolderPickerOpen @ nbo,
        acpSetNotice[ nbo, acpLabel[ "NoticeNoDirectory" ] ]
    ]
];
acpErrorAction[ nbo_NotebookObject, "Dismiss"         ] := acpSetNotice[ nbo, None ];
acpErrorAction[ _NotebookObject  , action_           ] := (acpLog[ "UnknownErrorAction", action ]; Null);

acpErrorAction // endDefinition;


(* A remote window has no local program to locate: install the agent on the host, or give its command line there *)
locateAgentRemoteNotice // beginDefinition;
locateAgentRemoteNotice[ window_ ] := acpLabel[ "NoticeLocateAgentRemote", <| "host" -> Replace[ acpWindowHostLabel @ window, Except[ _String ] -> "?" ] |> ];
locateAgentRemoteNotice // endDefinition;


(* A remote agent's sign-in runs on its host: the notice gives the terminal command that connects there (as the host key
   advice does), with "Copy command"; invalid stored settings have no command, so the text alone *)
signInRemoteNotice // beginDefinition;

signInRemoteNotice[ window_ ] := Module[ { text, command },
    text    = acpLabel[ "NoticeSignInRemote", <| "host" -> acpRemoteDisplayName @ Replace[ acpWindowHostLabel @ window, Except[ _String ] -> "?" ] |> ];
    command = acpSSHTerminalCommand @ acpWindowSSH @ window;
    If[ StringQ @ command, <| "Text" -> text, "Command" -> command |>, text ]
];

signInRemoteNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToggleErrorDetail*)

(* "Details" / "Hide details" of the toolbar's error view (preemptive): the window's "ErrorDetailOpen" is the key of the
   error whose details are shown (acpErrorKey, Rendering.wl), or None. A new error has another key, so it starts
   closed. *)
acpToggleErrorDetail // beginDefinition;

acpToggleErrorDetail[ nbo_NotebookObject ] := (
    acpCheckSession @ nbo;
    acpEnsureWindowRecord @ nbo;
    acpWindowUpdate[
        nbo,
        Function[ w,
            If[ KeyExistsQ[ w, "Status" ], (* never create a partial record *)
                With[ { key = acpErrorKey @ Lookup[ w, "Error", None ] },
                    <| w, "ErrorDetailOpen" -> If[ key === None || Lookup[ w, "ErrorDetailOpen", None ] === key, None, key ] |>
                ],
                Missing[ "NotFound" ]
            ]
        ]
    ];
    acpPublish[ ];
    acpWindowGet[ nbo, "ErrorDetailOpen", None ]
);

acpToggleErrorDetail // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCopyErrorDetail*)

(* "Copy" in the open details of the toolbar's error view (a preemptive button, never a reader handler): the hint and
   the output of the window's current error, as shown (acpErrorParts) *)
acpCopyErrorDetail // beginDefinition;

acpCopyErrorDetail[ nbo_NotebookObject ] := Module[ { details },
    acpCheckSession @ nbo;
    details = acpErrorParts[ Replace[ acpWindowGet[ nbo, "Error", None ], Except[ _Association ] -> <| |> ] ][ "Details" ];
    If[ StringQ @ details, CopyToClipboard @ details ];
    details
];

acpCopyErrorDetail // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCopyNoticeCommand*)

(* "Copy command" of a notice with a terminal command (a preemptive button, never a reader handler): the command of the
   window's current notice, as the user must type it *)
acpCopyNoticeCommand // beginDefinition;

acpCopyNoticeCommand[ nbo_NotebookObject ] := (
    acpCheckSession @ nbo;
    Replace[
        acpWindowGet[ nbo, "Notice", None ],
        {
            KeyValuePattern[ "Command" -> command_String ] :> (If[ $FrontEnd =!= Null, CopyToClipboard @ command ]; command),
            _ :> Missing[ "NoCommand" ]
        }
    ]
);

acpCopyNoticeCommand // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpSetNotice*)
acpSetNotice // beginDefinition;

acpSetNotice[ nbo_NotebookObject, notice: _String | KeyValuePattern[ "Text" -> _String ] | None ] := (
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
    (* An open Sessions window and folder picker are rebuilt too (Sessions.wl, FolderPicker.wl), the status of a
       message of a prompt notebook that the old kernel prepared or queued is reset (PromptNotebook.wl), and a permission
       details window that the old kernel was writing says that it is incomplete (PermissionDetails.wl); scheduled, so
       the window record exists by then *)
    acpSchedule @ acpSessionsRecover @ nbo;
    acpSchedule @ acpFolderPickerRecover @ nbo;
    acpSchedule @ acpPromptNotebookRecover @ nbo;
    acpSchedule @ acpPermissionDetailsRecover @ nbo;
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
    If[ acpQueuedPromptQ @ Lookup[ window, "QueuedPrompt", None ] && Lookup[ window, "Status" ] === "Ready" && ! acpRunningQ @ window,
        acpSchedule @ acpSendQueuedPrompt @ nbo
    ];
    (* a preparation of attachments that never finished (e.g. its job waits behind a long evaluation of the user's): *)
    If[ MatchQ[ Lookup[ window, "Preparing", None ], KeyValuePattern[ "StartedAt" -> t_? NumberQ /; AbsoluteTime[ ] - t > $acpPrepareTimeout ] ],
        acpLog[ "PreparationTimeout", <| "Notebook" -> nbo |> ];
        acpCancelPreparation[ nbo, acpLabel[ "NoticeAttachmentsTimeout" ] ]
    ];
    (* ... and the same for the messages of the window's prompt notebooks (PromptNotebook.wl) *)
    acpPromptNotebookHousekeeping[ nbo, $acpPrepareTimeout ];
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
