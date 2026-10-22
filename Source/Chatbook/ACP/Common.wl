(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Common`" ];

(* Symbols shared between the files in Source/Chatbook/ACP. Symbols that are also used outside of the ACP
   subpackage (e.g. in Actions.wl or ChatModes) are declared in CommonSymbols.wl instead.
   Each section lists the symbols defined by one file; add new shared symbols to your own file's section. *)

HoldComplete[
    (* ::**************************************************************************************************************:: *)
    (* State.wl *)
    `$acpDebugLog,
    `$acpOpen,
    `$acpTurns,
    `$acpWindows,
    `acpCatchAll,
    `acpCheckSession,
    `acpEnsurePublisher,
    `acpEntitySymbol,
    `acpFE,
    `acpFESet,
    `acpFreezeTurnViews,
    `acpIsolated,
    `acpIsolatedAbortable,
    `acpLayoutSymbol,
    `acpLink,
    `acpLinkAvailableQ,
    `acpLoadACPLink,
    `acpLog,
    `acpMarkDirty,
    `acpMarkLayoutDirty,
    `acpMarkWindowDirty,
    `acpOpenQ,
    `acpPublish,
    `acpRegisterHousekeeping,
    `acpSchedule,
    `acpToggleOpen,
    `acpTrackedDynamic,
    `acpTurnCreate,
    `acpTurnDrop,
    `acpTurnGet,
    `acpTurnUpdate,
    `acpTurnViewsFrozenQ,
    `acpWindowDrop,
    `acpWindowGet,
    `acpWindowSet,
    `acpWindowSymbol,
    `acpWindowUpdate,

    (* ::**************************************************************************************************************:: *)
    (* Transcript.wl *)
    `$acpStrings,
    `$acpUIStrings, (* defined in UI.wl; acpLabel falls back to it *)
    `acpApplyClientCancel,
    `acpApplyNotice,
    `acpApplyPermissionOutcome,
    `acpApplyPermissionRequest,
    `acpApplyPermissionWithdrawn,
    `acpApplyTurnEnd,
    `acpApplyUpdate,
    `acpTurnRemote,
    `acpCanonicalToolName,
    `acpClientInterruptionTextQ,
    `acpDiffStats,
    `acpExecuteScript,
    `acpExecuteToolCalls,
    `acpExecuteToolNames,
    `acpExecuteToolReferences,
    `acpFormatDuration,
    `acpLabel,
    `acpLineDiff,
    `acpLineDiffInfo, (* also used by Rendering.wl and PermissionDetails.wl (whether a diff is aligned) *)
    `acpMCPDisplayName,
    `acpNewTurn,
    `acpNotebookToolName,
    `acpPatchRows,
    `acpPermissionNotebooks, (* used by Connection.wl (the notebooks of a permission request, see Rendering.wl) *)
    `acpPreprocessAnswer,
    `acpStripToolOutput,
    `acpToolAction,
    `acpToolSummary,
    `acpToolTitle,
    `acpToolTitleParts,
    `acpTurnActivity,
    `acpTurnActivityLabel,
    `acpTurnEndedQ,
    `acpTurnSplit,
    `acpTurnStatusLine,
    `acpTurnToMarkdown,
    `acpWorkedForLabel,
    `acpWorkedForTooltip,

    (* ::**************************************************************************************************************:: *)
    (* Rendering.wl *)
    `acpBadge,
    `acpColor,
    `acpDiffRows, (* used by PermissionDetails.wl *)
    `acpDiffRowSource,  (* used by PermissionDetails.wl (the rows of a large diff, made in parts) *)
    `acpDiffSourceRows, (* used by PermissionDetails.wl (the same) *)
    `acpDiffSourceLineLengths, (* used by PermissionDetails.wl (the same) *)
    `acpDiffView,
    `acpDropRenderCache,
    `acpEntityView,
    `acpErrorKey,   (* also used by UI.wl (ToggleErrorDetail) *)
    `acpErrorParts, (* also used by UI.wl (CopyErrorDetail) *)
    `acpErrorView,
    `acpFinalCell,
    `acpFitSwitch,
    `acpFitText,
    `acpFitWidth,
    `acpFitWidthSwitch,
    `acpFreezeLiveView,
    `acpLiveView,
    `acpNeutralizeLinearSyntax,
    `acpPermissionDetailsData, (* used by PermissionDetails.wl (what the details window shows) *)
    `acpPermissionKey,         (* used by PermissionDetails.wl (the key of the panel's "View full ..." link) *)
    `acpPermissionPanel,
    `acpSafeText,              (* the agent's text as it is shown; also used by UI.wl, Review.wl and others *)
    `acpToolbarStatusView,
    `acpUsageMeterView,

    (* ::**************************************************************************************************************:: *)
    (* Agents.wl *)
    `$acpAgents,
    `$acpConnectionStrings,
    `$acpLLMKitEnabled,
    `acpAgentSpec,
    `acpBillingLabel,
    `acpClearPersistedLastFolder,
    `acpCommandLineSetting,
    `acpConnectionLabel,
    `acpExecutableFileQ,
    `acpFindConfigOption,
    `acpFindLLMKitKey,
    `acpFindProgram,
    `acpInheritedEnvironment,
    `acpLLMKitAPIKey,
    `acpOpenCodeConfigJSON,
    `acpOpenCodeEnvironment,
    `acpOpenCodeVariables,
    `acpOptionValues,
    `acpOwnAgentCommandQ,     (* used by MCP.wl (acpMCPEnabledQ) *)
    `acpPathDirectories,
    `acpPersistedRemoteHome,
    `acpPersistedSetting,
    `acpPreferredModel,
    `acpProgramEnvironment,
    `acpSetPersistedSetting,

    (* ::**************************************************************************************************************:: *)
    (* SSH.wl *)
    `$acpRemoteClassifyBytes,
    `$acpRemoteMaxPathLength,
    `$acpSSHDefaultOptions,
    `$acpSSHFixedOptions,
    `$acpSSHLaunchCommand,
    `$acpSSHLaunchTrigger,
    `$acpSSHMarkerPrefix,
    `$acpSSHScriptCommand,
    `acpFindSSH,
    `acpLastProjectDirectoryKey,
    `acpNormalizeProjectDirectory,
    `acpPathContext,
    `acpProjectDirectoryQ,
    `acpRemoteAbbreviate,
    `acpRemoteAbsolutePathQ,
    `acpRemoteCheckedPath,
    `acpRemoteChild,
    `acpRemoteDisplayName,
    `acpRemoteExpandHome,
    `acpRemoteFolderLabel,
    `acpRemoteHomeKey,
    `acpRemoteLexicalPath,
    `acpRemoteNormalizeDirectory,
    `acpRemoteParent,
    `acpRemotePathName,
    `acpRemotePathWord,
    `acpRemoteQ,
    `acpSettingsSSH,
    `acpShellQuote,
    `acpShellWords,
    `acpSSHCommand,
    `acpSSHEnvironment,
    `acpSSHExitError,
    `acpSSHExitKind,
    `acpSSHHostKey,
    `acpSSHHostLabel,
    `acpSSHLaunchMarkers,
    `acpSSHLaunchNonce,
    `acpSSHLaunchScript,
    `acpSSHPreferenceKey,
    `acpSSHShortHost,
    `acpSSHTerminalCommand,
    `acpSSHTimeoutError,
    `acpWindowHostKey,
    `acpWindowHostLabel,
    `acpWindowRemoteHome,
    `acpWindowShortHost,
    `acpWindowSSH,
    (* acpSSHSettings, acpRemoteProjectDirectoryQ and acpRemoteCommandLineQ are in CommonSymbols.wl (ShowNotebookAssistance
       validates with them) *)

    (* ::**************************************************************************************************************:: *)
    (* Connection.wl *)
    `$acpAssumeWindowsOpen,
    `$acpBeforeInitializeHook, (* a test hook *)
    `$acpInitSendGrace,
    `$acpMaxDetailLength, (* also used by SSH.wl *)
    `$acpStderrLines,     (* also used by SSH.wl *)
    `acpAnswerPermission,
    `acpConnectionQ,
    `acpDisconnect,
    `acpEnsureConnected,
    `acpErrorInfo,
    `acpLoadSession,
    `acpNewSession,
    `acpOnConnectionRemoved,
    `acpOnFailure,
    `acpOnNotification,
    `acpOnPermissionRequest,
    `acpOnResponse,
    `acpReconnect,
    `acpResetProjectDirectory,
    `acpSendPrompt,
    `acpSendSessionDelete,
    `acpSendSessionList,
    `acpSetConfigOption,
    `acpSetProjectDirectory,
    `acpStop,
    `acpWindowAliveQ,

    (* ::**************************************************************************************************************:: *)
    (* Git.wl *)
    `$acpGitEnabled,
    `$acpGitMaxFiles,
    `acpFindGit,
    `acpGitBuildChangeSet,
    `acpGitChanges,
    `acpGitCheck,
    `acpGitDecode,
    `acpGitMarkStale,
    `acpGitNoteSessionUpdate,
    `acpGitParseFilterDrivers,
    `acpGitParseNumstat,
    `acpGitParseRevParse,
    `acpGitParseStatus,
    `acpGitParseVersion,
    `acpGitRun,
    `acpGitSplitPatch,
    `acpGitSummary,
    `acpGitUnquotePath,
    `acpGitWorkTreeRoot,
    `acpBackgroundRunsQ,   (* also used by State.wl (the pump keeps running for them) *)
    `acpNaturalOrdering,   (* also used by FolderPicker.wl *)
    `acpProcessRun,        (* also used by Remote.wl *)
    `acpProcessRunningQ,   (* also used by Remote.wl *)
    `acpRunCancelledQ,     (* also used by Remote.wl *)
    `acpSetCurrentRequest, (* also used by FolderPicker.wl *)

    (* ::**************************************************************************************************************:: *)
    (* Remote.wl *)
    `$acpRemoteHostAuthFailedAt,
    `$acpRemoteLatchMemory,
    `acpRemoteClearHostError,    (* used by Connection.wl and UI.wl (user actions clear the host latch) *)
    `acpRemoteNoteHostError,     (* used by Connection.wl (the agent's ssh exited) *)
    `$acpRemoteDeadlineSlack,
    `$acpRemoteDrainTimeout,
    `$acpRemoteHostErrors,
    `$acpRemoteListMaxFiles,
    `$acpRemoteListMaxFolders,
    `$acpRemoteListOutputCap,
    `$acpRemoteListScanFiles,
    `$acpRemoteListScanFolders,
    `$acpRemoteMaxBeforeReady,
    `$acpRemoteMaxErrorKept,
    `$acpRemoteMaxFrames,
    `$acpRemoteMaxOutput,
    `$acpRemoteMaxRuns,
    `$acpRemoteMaxScript,
    `$acpRemoteSlotRetry,
    `$acpRemoteTimeout,
    `acpRemoteErrorInfo,
    `acpRemoteHostLatchedQ,
    `acpRemoteListBody,
    `acpRemoteListingParse,
    `acpRemoteMinify,
    `acpRemoteParseFrames,
    `acpRemoteRecentAuthFailureQ, (* also used by Connection.wl (remote errors) *)
    `acpRemoteResult,
    `acpRemoteRun,
    `acpRemoteScript,
    `acpRemoteTemplate,

    (* ::**************************************************************************************************************:: *)
    (* Review.wl *)
    `$acpReviewStrings,
    `acpFileIcon,
    `acpFileIconName,
    `acpReviewButton,
    `acpReviewButtonSignature,
    `acpReviewButtonTexts,  (* used by UI.wl (the folder row's width) *)
    `acpReviewCells,
    `acpReviewChanges,
    `acpReviewDiffView,
    `acpReviewDockedCell,
    `acpReviewNotebook,
    `acpReviewOpenFile,
    `acpReviewRefresh,
    (* shared with PermissionDetails.wl *)
    `acpReviewAppendCells,
    `acpReviewCellBoxes,
    `acpReviewEvaluator,
    `acpReviewFileCard,
    `acpReviewLazyDiff,
    `acpReviewPut,
    `acpReviewSafeLines, (* also used by Rendering.wl (the permission panel's diff rows) *)
    `acpReviewStyleSheet,
    `acpReviewWindowGeometry,
    `acpReviewWindowOptions,

    (* ::**************************************************************************************************************:: *)
    (* PermissionDetails.wl *)
    `acpPermissionDetails,
    `acpPermissionDetailsCloseWindow, (* used by UI.wl (closing the ACP window) *)
    `acpPermissionDetailsNotebook,
    `acpPermissionDetailsRecover,     (* used by UI.wl (kernel restarts) *)
    `acpPermissionDetailsWindowOf,

    (* ::**************************************************************************************************************:: *)
    (* Sessions.wl *)
    `$acpSessionsStrings,
    `acpDeleteSession,
    `acpDeleteSessionAction,
    `acpNewRestore,
    `acpNewSessionIn,
    `acpNewSessionInAction,
    `acpReplayAppend,
    `acpReplayRanges,
    `acpReplayTurn,
    `acpReplayUpdates,
    `acpRestoreAppendUpdate,
    `acpRestoreSession,
    `acpRestoreSessionAction,
    `acpRestoreWriteStep,
    `acpRestoringQ,
    `acpSessionHiddenTitleQ,
    `acpSessionItems,
    `acpSessionTime,
    `acpSessionsBusyLabel,
    `acpSessionsBusyState,
    `acpSessionsButton,
    `acpSessionsCapabilities,
    `acpSessionsCell,
    `acpSessionsClosed,
    `acpSessionsCloseWindow,
    `acpSessionsCoveredQ,
    `acpSessionsDeleteFailed,
    `acpSessionsGeometry,
    `acpSessionsList,
    `acpSessionsListFailed,
    `acpSessionsMarkStale,
    `acpSessionsNotebook,
    `acpSessionsNoteTurnEnd,
    `acpSessionsOf,
    `acpSessionsOnDeleteResponse,
    `acpSessionsOnListResponse,
    `acpSessionsOpened,
    `acpSessionsPlacement,
    `acpSessionsProjects,
    `acpSessionsRebuildWindow,
    `acpSessionsRecover,
    `acpSessionsRefresh,
    `acpSessionsSet,
    `acpSessionsWindowAction,
    `acpSessionsWindowOf,
    `acpShortRelativeTime,
    `acpToggleSessions,
    (* The Sessions window's view helpers, also used by FolderPicker.wl (sessionsKey is not shared: FolderPicker.wl has
       its own pickerKey, since Tests/ACPSessions.wlt binds a global sessionsKey) *)
    `$sessionsAccent,
    `$sessionsBackground,
    `$sessionsButton,
    `$sessionsButtonFrame,
    `$sessionsButtonHover,
    `$sessionsCurrent,
    `$sessionsDanger,
    `$sessionsDangerHover,
    `$sessionsDivider,
    `$sessionsFont,
    `$sessionsHeader,
    `$sessionsHover,
    `$sessionsInactive,
    `$sessionsMuted,
    `$sessionsRefreshIcon,
    `acpOwnerGeometry,
    `sessionsButtonFrame,
    `sessionsButtonLabel,
    `sessionsEvaluator,
    `sessionsFocusOwner,
    `sessionsIconButton,
    `sessionsMoveToActiveDesktop,
    `sessionsRowFrame,
    `sessionsShorten,
    `sessionsTitleView,

    (* ::**************************************************************************************************************:: *)
    (* FolderPicker.wl *)
    `$acpFolderPickerDebounce,
    `$acpFolderPickerFilesShown,
    `$acpFolderPickerPageSize,
    `$acpFolderPickerStrings,
    `$acpFolderPickerTimeout,
    `acpFolderPickerAction,
    `acpFolderPickerAutoOpen,    (* used by UI.wl (a new remote window without a folder, and after a host switch) *)
    `acpFolderPickerChoose,
    `acpFolderPickerCloseWindow, (* used by Connection.wl (acpResetProjectDirectory) and UI.wl (closing the window) *)
    `acpFolderPickerGeometry,
    `acpFolderPickerNotebook,
    `acpFolderPickerOf,
    `acpFolderPickerOnResult,
    `acpFolderPickerOpen,        (* used by UI.wl ("Choose folder..." of a remote window) *)
    `acpFolderPickerPlacement,
    `acpFolderPickerRecover,     (* used by UI.wl (kernel restarts) *)
    `acpFolderPickerStart,
    `acpFolderPickerWindowOf,

    (* ::**************************************************************************************************************:: *)
    (* NotebookTools.wl *)
    `$acpNotebookEditTools,
    `acpAttachableNotebooks, (* used by Attachments.wl (the attach menu) *)
    `acpDefusedCells,        (* used by Attachments.wl (defusing cells before CellToString) *)
    `acpNotebookMarkdown,    (* used by Attachments.wl (the markdown of an attached notebook) *)
    `acpNotebookTitles, (* used by Connection.wl (the notebooks of a permission request, for the permission panel) *)
    `acpNotebookTools,

    (* ::**************************************************************************************************************:: *)
    (* MCP.wl *)
    `$acpMCPServerName,
    `acpMCPAuthorizedQ,       (* the server's "Authentication" function (SocketListen handler) *)
    `acpMCPAvailableQ,
    `acpMCPConnectionStarted, (* used by Connection.wl (acpConnect) *)
    `acpMCPDrain,             (* the ButtonFunction of the hidden pump notebook; called by its full name *)
    `acpMCPEnabledQ,          (* used by Connection.wl (acpConnect) *)
    `acpMCPEnqueue,           (* the server's "EvaluationFunction" (SocketListen handler) *)
    `acpMCPEnsureServer,      (* used by Connection.wl (acpConnect) *)
    `acpMCPKick,
    `acpMainLinkRun,          (* used by UI.wl (the main link job that prepares a message's attachments) *)
    `acpMCPPendingQ,          (* used by State.wl (the pump keeps running for queued tool calls and the server) *)
    `acpMCPServer,
    `acpMCPServersParam,      (* used by Connection.wl (session/new, session/load, session/resume) *)
    `acpMCPStopServer,
    `acpMCPToolPermissions,   (* used by Agents.wl (OpenCode's permission rules) *)

    (* ::**************************************************************************************************************:: *)
    (* Attachments.wl *)
    `$acpAttachmentLimits,
    `acpAddDraftAttachments,    (* used by UI.wl (a message that was not sent gives its attachments back) *)
    `acpAttachButton,           (* used by UI.wl (the input cell) *)
    `acpAttachmentRefs,
    `acpAttachmentRefsOf,
    `acpAttachmentsAction,      (* used by UI.wl (acpAction) *)
    `acpAttachmentsArea,        (* used by UI.wl (the input cell) *)
    `acpByteSizeLabel,
    `acpDraftAttachments,
    `acpEncodeImage,
    `acpFileText,
    `acpImageFormat,
    `acpInertAttachmentTags,
    `acpMessageFitsQ,           (* used by UI.wl (queued messages are merged only as far as they fit into one) *)
    `acpMessageSize,            (* used by UI.wl (the same) *)
    `acpNotebookAttachmentRef,  (* used by PromptNotebook.wl (the prompt notebook as an attachment) *)
    `acpParseAttachmentBlocks,  (* used by Sessions.wl (the replay of a restored session) *)
    `acpPrepareAttachments,     (* used by PromptNotebook.wl (the main link job of a prompt notebook's message) *)
    `acpPrepareAttachmentsJob,  (* used by UI.wl (the main link job of a message with attachments) *)
    `acpPromptBlocks,           (* used by Connection.wl (session/prompt) *)
    `acpPromptCapabilities,
    `acpReencodeImage,
    `acpRenumberImages,         (* used by UI.wl (a merged queued message) *)
    `acpSetDraftAttachments,
    `acpUninertAttachmentTags,
    `acpUserCellExpr,           (* used by UI.wl and Sessions.wl (user cells) *)

    (* ::**************************************************************************************************************:: *)
    (* PromptNotebook.wl *)
    `acpCancelPromptNotebookJobs,     (* used by UI.wl (New, a folder change, a host switch) *)
    `acpNotePromptNotebooks,          (* used by UI.wl (the status of a prompt notebook's message: sent, queued, dropped) *)
    `acpOpenPromptNotebook,
    `acpPromptDockedCell,
    `acpPromptNotebook,
    `acpPromptNotebookAction,         (* used by UI.wl (acpAction) *)
    `acpPromptNotebookButton,         (* used by UI.wl (the input cell) *)
    `acpPromptNotebookCells,
    `acpPromptNotebookHousekeeping,   (* used by UI.wl (housekeeping) *)
    `acpPromptNotebookOf,
    `acpPromptNotebookPlacement,
    `acpPromptNotebookRecover,        (* used by UI.wl (kernel restarts) *)
    `acpPromptNotebooks,
    `acpPromptNotebooksOwnerClosed,   (* used by UI.wl (closing the window) *)
    `acpPromptNotebookSend,
    `acpPromptTargetLabel,
    `acpReplacedPromptAttachments,    (* used by UI.wl (a merged queued message) *)
    `acpSyncPromptTarget,             (* used by UI.wl (acpUpdateWindowTitle) *)

    (* ::**************************************************************************************************************:: *)
    (* UI.wl *)
    `$acpUIStrings,
    `acpAbbreviatePath,
    `acpActionButton,
    `acpActionCode,
    `acpCannotSendNotice, (* used by PromptNotebook.wl (Send of a prompt notebook) *)
    `acpChangeProjectDirectory,
    `acpEnsureWindowRecord,
    `acpFinalizeTurn,
    `acpMarkOrphanCells,
    `acpNormalizeDirectory, (* also used by SSH.wl *)
    `acpNewChat,
    `acpPreparedPrompt, (* used by Attachments.wl (the result of the main link job of a message with attachments) *)
    `acpQueuedPromptOf, (* used by PromptNotebook.wl (the prompt notebooks of the queued messages) *)
    `acpReturnPendingMessages, (* used by Sessions.wl (a session restored from the same folder) *)
    `acpSendPreparedMessage, (* used by PromptNotebook.wl (a prompt notebook's message) *)
    `acpSendQueuedPrompt,
    `acpSetNotice,
    `acpRenderView,
    `acpSyncDerivedView,
    `acpToolbarButtonLabel, (* also used by Sessions.wl (the Sessions button) *)
    `acpUpdateWindowTitle,
    `acpWindowDerivedDynamic, (* also used by Attachments.wl (the chips of the draft) *)
    `acpWindowKey,
    `evaluateACPChat
];

EndPackage[ ];
