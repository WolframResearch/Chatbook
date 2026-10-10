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
    `acpIsolated,
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
    `acpCanonicalToolName,
    `acpClientInterruptionTextQ,
    `acpDiffStats,
    `acpExecuteToolCalls,
    `acpExecuteToolNames,
    `acpFormatDuration,
    `acpLabel,
    `acpLineDiff,
    `acpNewTurn,
    `acpPreprocessAnswer,
    `acpStripToolOutput,
    `acpToolAction,
    `acpToolSummary,
    `acpToolTitle,
    `acpTurnActivityLabel,
    `acpTurnEndedQ,
    `acpTurnSplit,
    `acpTurnStatusLine,
    `acpTurnToMarkdown,
    `acpWorkedForLabel,

    (* ::**************************************************************************************************************:: *)
    (* Rendering.wl *)
    `acpDiffView,
    `acpDropRenderCache,
    `acpEntityView,
    `acpErrorView,
    `acpFinalCell,
    `acpLiveView,
    `acpPermissionPanel,
    `acpToolbarStatusView,
    `acpUsageMeterView,

    (* ::**************************************************************************************************************:: *)
    (* Agents.wl *)
    `$acpAgents,
    `$acpConnectionStrings,
    `$acpLLMKitEnabled,
    `acpAgentSpec,
    `acpBillingLabel,
    `acpConnectionLabel,
    `acpFindConfigOption,
    `acpFindLLMKitKey,
    `acpFindOpenCode,
    `acpLLMKitAPIKey,
    `acpOpenCodeConfigJSON,
    `acpOpenCodeEnvironment,
    `acpOptionValues,
    `acpPersistedSetting,
    `acpPreferredModel,
    `acpSetPersistedSetting,

    (* ::**************************************************************************************************************:: *)
    (* Connection.wl *)
    `$acpAssumeWindowsOpen,
    `acpAnswerPermission,
    `acpConnectionQ,
    `acpDisconnect,
    `acpEnsureConnected,
    `acpErrorInfo,
    `acpNewSession,
    `acpOnConnectionRemoved,
    `acpOnFailure,
    `acpOnNotification,
    `acpOnPermissionRequest,
    `acpOnResponse,
    `acpReconnect,
    `acpSendPrompt,
    `acpSetConfigOption,
    `acpSetProjectDirectory,
    `acpStop,
    `acpWindowAliveQ,

    (* ::**************************************************************************************************************:: *)
    (* UI.wl *)
    `$acpUIStrings,
    `acpEnsureWindowRecord,
    `acpFinalizeTurn,
    `acpMarkOrphanCells,
    `acpNewChat,
    `acpSendQueuedPrompt,
    `acpSetNotice,
    `acpUpdateWindowTitle,
    `evaluateACPChat
];

EndPackage[ ];
