(* ::Section::Closed:: *)
(*Package Header*)
BeginPackage[ "Wolfram`Chatbook`ACP`Transcript`" ];
Begin[ "`Private`" ];

Needs[ "Wolfram`Chatbook`"            ];
Needs[ "Wolfram`Chatbook`Common`"     ];
Needs[ "Wolfram`Chatbook`ACP`Common`" ];

(* Pure turn model (see docs/acp-window.md, "State model"): reducer, permission bookkeeping, final-answer split, tool titles/summaries,
   labels, markdown export.

   All reducer functions (acpApplyUpdate, acpApplyPermission*, acpApplyTurnEnd, acpApplyClientCancel) are pure: they take
   a turn record and return <| "Turn" -> newTurn, "Changed" -> { entityKey... }, "Layout" -> True|False |>, which is the
   form accepted by acpTurnUpdate. They make no front end calls and perform no I/O (apart from acpLog), so they can run
   inside acpTurnUpdate (PreemptProtect) from reader handlers. Updates that change nothing return the original turn with
   "Changed" -> {} and do not bump any version.

   Entity keys are lists: { "Message", id }, { "Thought", id }, { "Tool", toolCallId } (or { "Tool", toolCallId, n } when
   an agent reuses the ID of a finished call), { "Permission", requestID }, { "Notice", n }, { "Plan" }. *)

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Configuration*)
$unfinishedToolStatus        = "pending" | "in_progress";
$terminalToolStatus          = "completed" | "failed";
$significantWaitingTime      = 5;   (* seconds of waiting for approval before it's mentioned in "Worked for" labels *)
$silenceThreshold            = 5;   (* seconds without events before the activity label says we're waiting for the agent *)
$maxTitleObjectLength        = 60;
$defaultAgentName            = "OpenCode";

(* Error texts reported by OpenCode for tool calls that were interrupted by a client action: *)
$clientInterruptionText = Alternatives[
    "The user declined this tool call",
    "The user dismissed this question",
    "Tool execution interrupted",
    "Command cancelled",
    "Command canceled",
    "Cancelled",
    "Canceled"
];

(* Wolfram MCP server tool names and the names Chatbook uses for them: *)
$mcpToolDisplayNames = <|
    "WolframLanguageEvaluator" -> "Wolfram Language Evaluator",
    "WolframAlpha"             -> "Wolfram|Alpha",
    "WolframAlphaContext"      -> "Wolfram|Alpha Context",
    "WolframContext"           -> "Wolfram Context",
    "WolframLanguageContext"   -> "Wolfram Language Context",
    "DocumentationSearcher"    -> "Documentation Searcher",
    "DocumentationLookup"      -> "Documentation Lookup",
    "SymbolDefinition"         -> "Symbol Definition",
    "CodeInspector"            -> "Code Inspector",
    "TestReport"               -> "Test Report",
    "ReadNotebook"             -> "Read Notebook",
    "WriteNotebook"            -> "Write Notebook",
    "NotebookViewer"           -> "Notebook Viewer"
|>;

(* Canonical tool name -> label group used for "Tool<Group><Tense>" string keys. Covers OpenCode's built-in tools (2.x:
   read, edit, write, patch, shell, glob, grep, subagent, webfetch, websearch, question, skill, execute; plus models in
   code mode) and the older 1.x names (list, multiedit, codesearch, lsp, todowrite, todoread, invalid). Anything else
   (e.g. MCP tools called directly) uses the "Generic" group. *)
$toolLabelGroups = <|
    "read"       -> "Read",
    "list"       -> "List",
    "edit"       -> "Edit",
    "patch"      -> "Edit",
    "multiedit"  -> "Edit",
    "write"      -> "Write",
    "shell"      -> "Shell",
    "glob"       -> "Search",
    "grep"       -> "Search",
    "codesearch" -> "CodeSearch",
    "lsp"        -> "LSP",
    "webfetch"   -> "WebFetch",
    "websearch"  -> "WebSearch",
    "execute"    -> "Execute",
    "subagent"   -> "Subagent",
    "todowrite"  -> "Todo",
    "todoread"   -> "TodoRead",
    "skill"      -> "Skill",
    "question"   -> "Question",
    "models"     -> "Models",
    "invalid"    -> "Invalid"
|>;

(* ACP tool kind -> label group (fallback for agents that don't send OpenCode's "name" field): *)
$kindLabelGroups = <|
    "read"    -> "Read",
    "edit"    -> "Edit",
    "delete"  -> "Delete",
    "move"    -> "Move",
    "search"  -> "Search",
    "execute" -> "Shell",
    "fetch"   -> "WebFetch",
    "think"   -> "Think"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Strings*)

(* English defaults for every user-visible string produced by Transcript.wl and Rendering.wl.
   acpLabel[key] first tries the front end text resource "ChatbookStrings" -> "ACP" <> key and falls back to this table
   (then to $acpUIStrings, defined in UI.wl, and $acpConnectionStrings, defined in Agents.wl). Every key of the three
   tables must also be in FrontEnd/TextResources/ChatbookStrings.tr and the localized copies as "ACP" <> key, with the
   same English text (checked by Tests/ACPWindow.wlt). Templates use StringTemplate slots: `name`. *)
$acpStrings = <|
    (* Durations *)
    "DurationSeconds"              -> "`s`s",
    "DurationMinutes"              -> "`m`m `s`s",
    "DurationHours"                -> "`h`h `m`m",

    (* Turn labels *)
    "Working"                      -> "Working",
    "WorkedFor"                    -> "Worked for `time`",
    "WorkedForWaiting"             -> "Worked for `time` (+`waiting` waiting for approval)",
    "StoppedAfter"                 -> "Stopped after `time`",
    "FailedAfter"                  -> "Failed after `time`",
    "Thinking"                     -> "Thinking\[Ellipsis]",
    "ThoughtForSeconds"            -> "Thought for `n` seconds",
    "ThoughtForOneSecond"          -> "Thought for a second",
    "Thought"                      -> "Thought",
    "SubagentHeader"               -> "Subagent: `title`",
    "TurnUnavailable"              -> "This response is no longer available (the kernel was restarted).",
    "DoneNoReply"                  -> "Done.",

    (* Activity labels (Working header) *)
    "ActivityWaitingForApproval"   -> "Waiting for your approval",
    "ActivityRetrying"             -> "Retrying in `time` (attempt `attempt`)",
    "ActivityRetryingRateLimited"  -> "Retrying in `time` (rate limited, attempt `attempt`)",
    "ActivityRetryingNow"          -> "Retrying (attempt `attempt`)\[Ellipsis]",
    "ActivityThinking"             -> "Thinking\[Ellipsis]",
    "ActivityWritingAnswer"        -> "Writing answer\[Ellipsis]",
    "ActivityWaitingForAgent"      -> "Waiting for `agent`\[Ellipsis] `time`",
    "ActivityWaitingForAgentMCP"   -> "Waiting for `agent`\[Ellipsis] `time` (MCP servers may still be starting)",
    "ActivityFinishing"            -> "Finishing\[Ellipsis]",
    "ActivityStopping"             -> "Stopping\[Ellipsis]",

    (* Status lines shown below the "Worked for" opener *)
    "StatusStoppedByYou"           -> "Stopped by you after `time`.",
    "StatusCancelled"              -> "Cancelled after `time`.",
    "StatusDeclined"               -> "You declined: `action`. Tell `agent` what to do instead.",
    "StatusDeclinedGeneric"        -> "You declined the request. Tell `agent` what to do instead.",
    "StatusMaxTokens"              -> "Response cut off (max tokens).",
    "StatusMaxTurnRequests"        -> "Stopped: step limit reached.",
    "StatusRefusal"                -> "`agent` refused to continue.",
    "StatusOther"                  -> "Stopped (`reason`).",
    "StatusError"                  -> "Failed: `message`",

    (* Tool titles: generic forms built from an infinitive verb phrase *)
    "ToolAwaiting"                 -> "Wants to `verb` `object`",
    "ToolFailed"                   -> "Couldn't `verb` `object`",
    "ToolDeclined"                 -> "Declined: `verb` `object`",
    "ToolStopped"                  -> "Stopped: `verb` `object`",
    "ToolDeclinedTitle"            -> "Declined: `title`",
    "ToolStoppedTitle"             -> "Stopped: `title`",
    "ToolFailedTitle"              -> "Failed: `title`",

    (* Per group: Verb (infinitive, for the generic forms above), Pending (no input yet), Running, Done, and optionally
       DoneNoObject (finished, but the input says nothing about what was done) *)
    "ToolReadVerb"                 -> "read",
    "ToolReadPending"              -> "Reading a file\[Ellipsis]",
    "ToolReadRunning"              -> "Reading `object`",
    "ToolReadDone"                 -> "Read `object`",
    "ToolReadDoneNoObject"         -> "Read a file",

    "ToolListVerb"                 -> "list",
    "ToolListPending"              -> "Listing a folder\[Ellipsis]",
    "ToolListRunning"              -> "Listing `object`",
    "ToolListDone"                 -> "Listed `object`",
    "ToolListDoneNoObject"         -> "Listed the project folder",

    "ToolEditVerb"                 -> "edit",
    "ToolEditPending"              -> "Editing a file\[Ellipsis]",
    "ToolEditRunning"              -> "Editing `object`",
    "ToolEditDone"                 -> "Edited `object`",
    "ToolEditDoneNoObject"         -> "Edited files",

    "ToolWriteVerb"                -> "write",
    "ToolWritePending"             -> "Writing a file\[Ellipsis]",
    "ToolWriteRunning"             -> "Writing `object`",
    "ToolWriteDone"                -> "Wrote `object`",
    "ToolWriteDoneNoObject"        -> "Wrote a file",
    "ToolWriteCreated"             -> "Created `object`",

    "ToolShellVerb"                -> "run",
    "ToolShellPending"             -> "Preparing a command\[Ellipsis]",
    "ToolShellRunning"             -> "Running `object`",
    "ToolShellDone"                -> "Ran `object`",
    "ToolShellDoneNoObject"        -> "Ran a command",

    "ToolSearchVerb"               -> "search for",
    "ToolSearchVerbNoObject"       -> "search",
    "ToolSearchPending"            -> "Searching\[Ellipsis]",
    "ToolSearchRunning"            -> "Searching for `object`",
    "ToolSearchDone"               -> "Searched for `object`",
    "ToolSearchDoneNoObject"       -> "Searched the project",

    "ToolCodeSearchVerb"           -> "search the code for",
    "ToolCodeSearchVerbNoObject"   -> "search the code",
    "ToolCodeSearchPending"        -> "Searching the code\[Ellipsis]",
    "ToolCodeSearchRunning"        -> "Searching the code for `object`",
    "ToolCodeSearchDone"           -> "Searched the code for `object`",
    "ToolCodeSearchDoneNoObject"   -> "Searched the code",

    "ToolLSPVerb"                  -> "look up",
    "ToolLSPPending"               -> "Asking the language server\[Ellipsis]",
    "ToolLSPRunning"               -> "Looking up `object`",
    "ToolLSPDone"                  -> "Looked up `object`",
    "ToolLSPDoneNoObject"          -> "Asked the language server",
    "ToolLSPObject"                -> "`operation` in `file`",

    "ToolWebFetchVerb"             -> "fetch",
    "ToolWebFetchPending"          -> "Fetching a page\[Ellipsis]",
    "ToolWebFetchRunning"          -> "Fetching `object`",
    "ToolWebFetchDone"             -> "Fetched `object`",
    "ToolWebFetchDoneNoObject"     -> "Fetched a page",

    "ToolWebSearchVerb"            -> "search the web for",
    "ToolWebSearchVerbNoObject"    -> "search the web",
    "ToolWebSearchPending"         -> "Searching the web\[Ellipsis]",
    "ToolWebSearchRunning"         -> "Searching the web for `object`",
    "ToolWebSearchDone"            -> "Searched the web for `object`",
    "ToolWebSearchDoneNoObject"    -> "Searched the web",

    "ToolExecuteVerb"              -> "use",
    "ToolExecutePending"           -> "Preparing code\[Ellipsis]",
    "ToolExecuteRunning"           -> "Using `object`",
    "ToolExecuteDone"              -> "Used `object`",
    "ToolExecuteRunningCode"       -> "Running code",
    "ToolExecuteDoneCode"          -> "Ran code",

    "ToolSubagentVerb"             -> "run subagent",
    "ToolSubagentPending"          -> "Starting a subagent\[Ellipsis]",
    "ToolSubagentRunning"          -> "Subagent: `object`",
    "ToolSubagentDone"             -> "Subagent: `object`",
    "ToolSubagentDoneNoObject"     -> "Ran a subagent",

    "ToolTodoVerb"                 -> "update",
    "ToolTodoPending"              -> "Updating the to-do list\[Ellipsis]",
    "ToolTodoRunning"              -> "Updating `object`",
    "ToolTodoDone"                 -> "Updated `object`",
    "ToolTodoObject"               -> "the to-do list",

    "ToolTodoReadVerb"             -> "read",
    "ToolTodoReadPending"          -> "Reading the to-do list\[Ellipsis]",
    "ToolTodoReadRunning"          -> "Reading `object`",
    "ToolTodoReadDone"             -> "Read `object`",

    "ToolSkillVerb"                -> "load skill",
    "ToolSkillPending"             -> "Loading a skill\[Ellipsis]",
    "ToolSkillRunning"             -> "Loading skill `object`",
    "ToolSkillDone"                -> "Loaded skill `object`",
    "ToolSkillDoneNoObject"        -> "Loaded a skill",

    "ToolQuestionVerb"             -> "ask",
    "ToolQuestionPending"          -> "Preparing a question\[Ellipsis]",
    "ToolQuestionRunning"          -> "Asking `object`",
    "ToolQuestionDone"             -> "Asked `object`",
    "ToolQuestionDoneNoObject"     -> "Asked a question",
    "ToolQuestionMore"             -> "`question` (+`n` more)",

    "ToolModelsVerb"               -> "search the models for",
    "ToolModelsVerbNoObject"       -> "search the models",
    "ToolModelsPending"            -> "Searching the models\[Ellipsis]",
    "ToolModelsRunning"            -> "Searching the models for `object`",
    "ToolModelsDone"               -> "Searched the models for `object`",
    "ToolModelsDoneNoObject"       -> "Listed the available models",

    "ToolInvalidVerb"              -> "call",
    "ToolInvalidPending"           -> "Preparing a tool call\[Ellipsis]",
    "ToolInvalidRunning"           -> "Calling `object`",
    "ToolInvalidDone"              -> "Invalid tool call: `object`",
    "ToolInvalidDoneNoObject"      -> "Invalid tool call",

    "ToolDeleteVerb"               -> "delete",
    "ToolDeletePending"            -> "Deleting\[Ellipsis]",
    "ToolDeleteRunning"            -> "Deleting `object`",
    "ToolDeleteDone"               -> "Deleted `object`",
    "ToolDeleteDoneNoObject"       -> "Deleted a file",

    "ToolMoveVerb"                 -> "move",
    "ToolMovePending"              -> "Moving\[Ellipsis]",
    "ToolMoveRunning"              -> "Moving `object`",
    "ToolMoveDone"                 -> "Moved `object`",
    "ToolMoveDoneNoObject"         -> "Moved a file",

    "ToolThinkVerb"                -> "think about",
    "ToolThinkVerbNoObject"        -> "think",
    "ToolThinkPending"             -> "Thinking\[Ellipsis]",
    "ToolThinkRunning"             -> "Thinking about `object`",
    "ToolThinkDone"                -> "Thought about `object`",
    "ToolThinkDoneNoObject"        -> "Thought",

    "ToolGenericVerb"              -> "use",
    "ToolGenericPending"           -> "Preparing `object`\[Ellipsis]",
    "ToolGenericPendingNoObject"   -> "Preparing a tool call\[Ellipsis]",
    "ToolGenericRunning"           -> "Using `object`",
    "ToolGenericDone"              -> "Used `object`",
    "ToolGenericDoneNoObject"      -> "Used a tool",

    "ToolExternalDirectory"        -> "Access outside the project: `object`",
    "ToolExternalDirectoryVerb"    -> "access",

    (* One-line tool summaries *)
    "SummaryLines"                 -> "`n` lines",
    "SummaryLine"                  -> "1 line",
    "SummaryNoOutput"              -> "no output",
    "SummaryExit"                  -> "exit `code`",
    "SummaryAdded"                 -> "+`a`",
    "SummaryDiff"                  -> "+`a` \[Minus]`d`",
    "SummaryFiles"                 -> "`n` files",
    "SummaryFile"                  -> "1 file",
    "SummaryNoFiles"               -> "No files found",
    "SummaryMatches"               -> "`n` matches",
    "SummaryMatch"                 -> "1 match",
    "SummaryCalls"                 -> "`n` calls",
    "SummaryCall"                  -> "1 call",
    "SummaryEntries"               -> "`n` entries",
    "SummaryEntry"                 -> "1 entry",
    "SummaryTodos"                 -> "`done` of `total` done",

    (* Notices *)
    "NoticeRetryingRateLimited"    -> "Rate limited; retrying (attempt `attempt`)\[Ellipsis]",
    "NoticeRetryingError"          -> "Provider error; retrying (attempt `attempt`)\[Ellipsis]",
    "NoticeRetriedRateLimited"     -> "Rate limited; retried `n`\[Times] over `time`",
    "NoticeRetriedError"           -> "Provider error; retried `n`\[Times] over `time`",
    "NoticeCompacting"             -> "Compacting the conversation\[Ellipsis]",
    "NoticeCompacted"              -> "Conversation compacted",
    "NoticeCompactionFailed"       -> "Conversation compaction failed",

    (* Badges *)
    "BadgeAwaitingApproval"        -> "Awaiting approval",
    "BadgeAllowedOnce"             -> "Allowed once",
    "BadgeAllowedAlways"           -> "Allowed (always)",
    "BadgeDeclined"                -> "Declined",
    "BadgeStopped"                 -> "Stopped",
    "BadgeCancelled"               -> "Cancelled",
    "BadgeNewFile"                 -> "new file",
    "BadgeContentsWritten"         -> "contents written",

    (* Tool card sections *)
    "SectionInput"                 -> "Input",
    "SectionOutput"                -> "Output",
    "SectionChanges"               -> "Changes",
    "SectionDetails"               -> "Details",
    "SectionScript"                -> "Script",
    "SectionError"                 -> "Error",
    "TruncatedEarlierLines"        -> "\[Ellipsis] `n` earlier lines",
    "TruncatedMoreLines"           -> "\[Ellipsis] `n` more lines",
    "ImageUnavailable"             -> "[image]",

    (* Permission panel *)
    "PermissionRun"                -> "`agent` wants to run a command",
    "PermissionEdit"               -> "`agent` wants to edit `path`",
    "PermissionWrite"              -> "`agent` wants to write `path`",
    "PermissionRead"               -> "`agent` wants to read `path`",
    "PermissionExternal"           -> "`agent` wants to access `path` outside the project",
    "PermissionGeneric"            -> "`agent` wants to `action`",
    "PermissionQueue"              -> "`i` of `n`",
    "PermissionAllowOnce"          -> "Allow once",
    "PermissionAllowAlways"        -> "Always allow",
    "PermissionReject"             -> "Reject",
    "PermissionAlwaysScopeEdit"    -> "\"Always allow\" lets `agent` make all file edits in `project` without asking again. `agent` saves this choice, so it also applies to future sessions.",
    "PermissionAlwaysScopeShell"   -> "\"Always allow\" lets `agent` run commands matching `patterns` in `project` without asking again. `agent` saves this choice, so it also applies to future sessions.",
    "PermissionAlwaysScopeShellRelated" -> "\"Always allow\" lets `agent` run commands matching `patterns` (and the commands nested in this one) in `project` without asking again. `agent` saves this choice, so it also applies to future sessions.",
    "PermissionAlwaysScopeExternal" -> "\"Always allow\" lets `agent` access files in `dir` (or in the repository that contains it) without asking again. `agent` saves this choice, so it also applies to future sessions.",
    "PermissionAlwaysScopeGeneric" -> "\"Always allow\" lets `agent` do this kind of thing in `project` without asking again. `agent` saves this choice, so it also applies to future sessions.",

    (* Toolbar status and usage *)
    "ToolbarNoDirectory"           -> "Choose a project folder to start",
    "ToolbarConnecting"            -> "Connecting to `agent`\[Ellipsis]",
    "ToolbarReady"                 -> "`agent` `version`",
    "ToolbarDisconnected"          -> "Disconnected",
    "ToolbarError"                 -> "Error",
    "UsageMeter"                   -> "`used` / `size`",
    "UsageTooltip"                 -> "Context window: `used` of `size` tokens used",
    "UsageHigh"                    -> "The context window is almost full; consider sending /compact.",
    "UsageCost"                    -> "$`cost`",

    (* Error actions *)
    "ActionReconnect"              -> "Reconnect",
    "ActionChooseModel"            -> "Choose another model",
    "ActionLocateAgent"            -> "Locate `agent`\[Ellipsis]",
    "ActionSignIn"                 -> "Sign in\[Ellipsis]",
    "LocateAgentDialogTitle"       -> "Locate `agent`"
|>;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpLabel*)

(* acpLabel[key] gives the string for key; acpLabel[key, params] applies it as a StringTemplate. Never throws.
   Strings are memoized per session once a front end has been consulted, so this is cheap enough for Dynamics. *)
If[ ! AssociationQ @ $labelCache   , $labelCache    = <| |> ];
If[ ! AssociationQ @ $templateCache, $templateCache = <| |> ];

acpLabel // beginDefinition;

acpLabel[ key_String ] := Lookup[ $labelCache, key, resolveLabel @ key ];

acpLabel[ key_String, params_Association ] := Quiet @ Replace[
    TemplateApply[ labelTemplate @ key, params ],
    Except[ _String ] :> acpLabel @ key
];

acpLabel[ key_, ___ ] := ToString @ key;

acpLabel // endDefinition;


resolveLabel // beginDefinition;

resolveLabel[ key_String ] := Module[ { fe, string },
    fe = frontEndLabel @ key;
    string = If[ StringQ @ fe, fe, defaultLabel @ key ];
    (* Only memoize once a front end has been consulted, so a front end that attaches later is still used: *)
    If[ fe =!= None, $labelCache[ key ] = string ];
    string
];

resolveLabel // endDefinition;


defaultLabel // beginDefinition;

defaultLabel[ key_String ] := Replace[
    FirstCase[
        { $acpStrings, $acpUIStrings, $acpConnectionStrings },
        table_Association /; StringQ @ table[ key ] :> table[ key ],
        Missing[ ]
    ],
    Except[ _String ] :> (acpLog[ "MissingLabel", key ]; key)
];

defaultLabel // endDefinition;


(* Returns a string, $Failed (front end available but key unknown), or None (no front end). *)
frontEndLabel // beginDefinition;

frontEndLabel[ _String ] /; $acpNoFrontEndLabels || ! frontEndAvailableQ[ ] := None;

frontEndLabel[ key_String ] := Module[ { result = $Failed },
    (* Never throws: messages, failures and (tagged or untagged) Throws all give $Failed *)
    Quiet @ Catch[ Catch[ result = Check[ FrontEndResource[ "ChatbookStrings", "ACP" <> key ], $Failed ] ], _, Null & ];
    Replace[ result, Except[ _String? (StringLength[ # ] > 0 &) ] :> $Failed ]
];

frontEndLabel // endDefinition;

$acpNoFrontEndLabels = False;


frontEndAvailableQ // beginDefinition;
frontEndAvailableQ[ ] := $FrontEnd =!= Null;
frontEndAvailableQ // endDefinition;


labelTemplate // beginDefinition;

labelTemplate[ key_String ] := Lookup[
    $templateCache,
    key,
    With[ { template = StringTemplate @ acpLabel @ key },
        If[ KeyExistsQ[ $labelCache, key ], $templateCache[ key ] = template ];
        template
    ]
];

labelTemplate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn Records*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpNewTurn*)

(* Creates a turn record. Callers usually provide "ID", "Notebook", "SessionID", "Prompt", "InputCell", "OutputCell",
   "RequestID", "ProjectDirectory", "AgentName" and "StartTime"; everything else gets its initial value. *)
acpNewTurn // beginDefinition;

acpNewTurn[ ] := acpNewTurn @ <| |>;

acpNewTurn[ props_Association ] := Module[ { time },
    time = Replace[ Lookup[ props, "StartTime", Automatic ], Except[ _? NumberQ ] :> AbsoluteTime[ ] ];
    Join[
        <|
            "ID"               -> "acp-turn-" <> CreateUUID[ ],
            "Notebook"         -> None,
            "SessionID"        -> None,
            "Prompt"           -> "",
            "InputCell"        -> None,
            "OutputCell"       -> None,
            "RequestID"        -> None,
            "ProjectDirectory" -> None,
            "AgentName"        -> $defaultAgentName,
            "Status"           -> "Running",
            "EndTime"          -> None,
            "StopReason"       -> None,
            "ClientCancel"     -> None,
            "Error"            -> None,
            "Usage"            -> None,
            "ContextUsage"     -> None,
            "Order"            -> { },
            "Entities"         -> <| |>,
            "Version"          -> 0,
            "WaitingTime"      -> 0,
            "WaitingSince"     -> None,
            "PendingPermissions" -> { },
            "RetryInfo"        -> None,
            "RetryEpisode"     -> None,
            "LastEventTime"    -> time,
            "FirstEventTime"   -> None,
            "NoticeCount"      -> 0,
            "Index"            -> <|
                "Segments"     -> <| |>, (* { type, messageId, childID } -> current segment key *)
                "SegmentCount" -> <| |>, (* { type, messageId } -> number of segments *)
                "Tool"         -> <| |>, (* toolCallId -> current entity key *)
                "ToolCount"    -> <| |>, (* toolCallId -> number of instances *)
                "Permission"   -> <| |>, (* requestID -> entity key *)
                "Notice"       -> <| |>, (* { kind, id } -> entity key *)
                "LastKey"      -> <| |>  (* childID (or None) -> last entity key from that session *)
            |>
        |>,
        KeyDrop[ props, "StartTime" ],
        <| "StartTime" -> time |>
    ]
];

acpNewTurn // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnEndedQ*)
acpTurnEndedQ // beginDefinition;
acpTurnEndedQ[ turn_Association ] := ! And[ Lookup[ turn, "EndTime", None ] === None, Lookup[ turn, "StopReason", None ] === None, Lookup[ turn, "Error", None ] === None ];
acpTurnEndedQ[ _ ] := False;
acpTurnEndedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Reducer results*)
reducerResult // beginDefinition;
reducerResult[ turn_Association, changed_List, layout_ ] := <| "Turn" -> turn, "Changed" -> DeleteDuplicates @ changed, "Layout" -> TrueQ @ layout |>;
reducerResult // endDefinition;

noChange // beginDefinition;
noChange[ turn_Association ] := <| "Turn" -> turn, "Changed" -> { }, "Layout" -> False |>;
noChange // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Entity helpers*)

(* Appends a new entity: *)
addEntity // beginDefinition;

addEntity[ turn0_Association, key_List, entity_Association ] := Module[ { turn = turn0 },
    turn[ "Entities", key ] = Append[ entity, "Version" -> 1 ];
    turn[ "Order" ] = Append[ turn[ "Order" ], key ];
    turn[ "Version" ] = turn[ "Version" ] + 1;
    turn[ "Index", "LastKey", childID @ entity ] = key;
    turn
];

addEntity // endDefinition;


(* Applies f to an entity. Returns { newTurn, changedQ }; versions only change if the entity changed. *)
updateEntity // beginDefinition;

updateEntity[ turn0_Association, key_List, f_ ] := Module[ { turn = turn0, old, new },
    old = Lookup[ turn[ "Entities" ], Key @ key, Missing[ ] ];
    If[ ! AssociationQ @ old, Return[ { turn, False }, Module ] ];
    new = f @ old;
    If[ ! AssociationQ @ new || new === old, Return[ { turn, False }, Module ] ];
    new[ "Version" ] = Lookup[ old, "Version", 0 ] + 1;
    turn[ "Entities", key ] = new;
    turn[ "Version" ] = turn[ "Version" ] + 1;
    { turn, True }
];

updateEntity // endDefinition;


(* Applies f to several entities, returning { newTurn, changedKeys }: *)
updateEntities // beginDefinition;

updateEntities[ turn0_Association, keys_List, f_ ] := Module[ { turn = turn0, changed = { }, res },
    Do[
        res = updateEntity[ turn, key, f ];
        turn = First @ res;
        If[ Last @ res, AppendTo[ changed, key ] ],
        { key, keys }
    ];
    { turn, changed }
];

updateEntities // endDefinition;


entityKeysOfType // beginDefinition;
entityKeysOfType[ turn_Association, type_String ] := Select[ turn[ "Order" ], MatchQ[ #, { type, ___ } ] & ];
entityKeysOfType // endDefinition;


childID // beginDefinition;
childID[ KeyValuePattern[ "Child" -> KeyValuePattern[ "ID" -> id_ ] ] ] := id;
childID[ _ ] := None;
childID // endDefinition;


(* Child session info from OpenCode's _meta["opencode/child-session"]: *)
childInfo // beginDefinition;

childInfo[ KeyValuePattern[ "_meta" -> KeyValuePattern[ "opencode/child-session" -> info_Association ] ] ] := <|
    "ID"       -> Lookup[ info, "id", Lookup[ info, "sessionId", None ] ],
    "ParentID" -> SelectFirst[ Lookup[ info, { "parentID", "parentId" }, None ], StringQ, None ],
    "Title"    -> Replace[ Lookup[ info, "title", None ], Except[ _String ] -> None ],
    "Depth"    -> Replace[ Lookup[ info, "depth", 1 ], Except[ _Integer ] -> 1 ]
|>;

childInfo[ _ ] := None;

childInfo // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*acpApplyUpdate*)

(* acpApplyUpdate[ turn, update, time ] applies one ACP session/update (the "update" association, which has a
   "sessionUpdate" key) received at AbsoluteTime `time`. *)
acpApplyUpdate // beginDefinition;

acpApplyUpdate[ turn_Association, update_Association ] :=
    acpApplyUpdate[ turn, update, AbsoluteTime[ ] ];

acpApplyUpdate[ turn_Association, update_Association, time_? NumberQ ] :=
    noteEventTime[ applyUpdate[ Lookup[ update, "sessionUpdate", None ], turn, update, time ], time ];

acpApplyUpdate // endDefinition;


noteEventTime // beginDefinition;

noteEventTime[ res: KeyValuePattern[ "Turn" -> turn0_Association ], time_ ] := Module[ { turn = turn0 },
    turn[ "LastEventTime" ] = time;
    If[ turn[ "FirstEventTime" ] === None, turn[ "FirstEventTime" ] = time ];
    Append[ res, "Turn" -> turn ]
];

noteEventTime // endDefinition;


applyUpdate // beginDefinition;

applyUpdate[ "agent_message_chunk", turn_, update_, time_ ] := applyChunk[ "Message", turn, update, time ];
applyUpdate[ "agent_thought_chunk", turn_, update_, time_ ] := applyChunk[ "Thought", turn, update, time ];
applyUpdate[ "tool_call"          , turn_, update_, time_ ] := applyToolCall[ turn, update, time ];
applyUpdate[ "tool_call_update"   , turn_, update_, time_ ] := applyToolCallUpdate[ turn, update, time ];
applyUpdate[ "plan"               , turn_, update_, time_ ] := applyPlan[ turn, update, time ];
applyUpdate[ "usage_update"       , turn_, update_, _     ] := applyUsage[ turn, update ];
applyUpdate[ "session_info_update", turn_, update_, time_ ] := applySessionInfo[ turn, update, time ];

(* Window-level updates (handled by Connection.wl) and replayed user messages: *)
applyUpdate[
    "user_message_chunk" | "available_commands_update" | "config_option_update" | "current_mode_update",
    turn_,
    _,
    _
] := noChange @ turn;

applyUpdate[ other_, turn_, update_, _ ] := (
    acpLog[ "UnknownSessionUpdate", <| "Kind" -> other, "Update" -> Short[ update, 5 ] |> ];
    noChange @ turn
);

applyUpdate // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Message and thought chunks*)

(* Chunks are keyed by messageId. A new segment ("<id>#n") starts when another entity from the same session was
   appended after this message's last chunk (models may interleave text and tool calls within one step). Chunks without
   a messageId continue the last entity if it's an anonymous segment of the same type. *)
applyChunk // beginDefinition;

applyChunk[ type_String, turn0_Association, update_Association, time_ ] := Module[
    { turn, extra, content, mid, child, cid, current, key, entity, res },

    turn    = endRetryEpisode[ turn0, time ];
    extra   = retryChangedKeys[ turn0, turn ];
    content = Lookup[ update, "content", <| |> ];
    mid     = Replace[ Lookup[ update, "messageId", None ], Except[ _String ] -> None ];
    child   = childInfo @ update;
    cid     = Lookup[ Replace[ child, None -> <| |> ], "ID", None ];
    current = Lookup[ turn[ "Index", "Segments" ], Key @ { type, mid, cid }, None ];

    If[ current =!= None && Lookup[ turn[ "Index", "LastKey" ], Key @ cid, None ] === current,
        (* Continue the current segment: *)
        res = updateEntity[ turn, current, appendChunkContent[ #, content, time ] & ];
        reducerResult[ First @ res, Join[ extra, If[ Last @ res, { current }, { } ] ], False ],

        (* Start a new segment: *)
        key = newSegmentKey[ turn, type, mid ];
        entity = appendChunkContent[
            <|
                "Type"      -> type,
                "ID"        -> Last @ key,
                "MessageID" -> mid,
                "Text"      -> "",
                "Blocks"    -> { },
                "FirstTime" -> time,
                "LastTime"  -> time,
                "Child"     -> child
            |>,
            content,
            time
        ];
        turn = addEntity[ turn, key, entity ];
        turn[ "Index", "Segments", { type, mid, cid } ] = key;
        turn[ "Index", "SegmentCount", { type, mid } ] = Lookup[ turn[ "Index", "SegmentCount" ], Key @ { type, mid }, 0 ] + 1;
        reducerResult[ turn, Append[ extra, key ], True ]
    ]
];

applyChunk // endDefinition;


newSegmentKey // beginDefinition;

newSegmentKey[ turn_Association, type_String, mid_ ] := Module[ { n, base },
    n = Lookup[ turn[ "Index", "SegmentCount" ], Key @ { type, mid }, 0 ] + 1;
    base = Replace[ mid, None -> "segment" ];
    { type, If[ n === 1 && StringQ @ mid, mid, base <> "#" <> ToString @ n ] }
];

newSegmentKey // endDefinition;


appendChunkContent // beginDefinition;

appendChunkContent[ entity_Association, KeyValuePattern @ { "type" -> "text", "text" -> text_String }, time_ ] :=
    <| entity, "Text" -> entity[ "Text" ] <> text, "LastTime" -> time |>;

appendChunkContent[ entity_Association, block_Association, time_ ] /; block =!= <| |> :=
    <| entity, "Blocks" -> Append[ entity[ "Blocks" ], block ], "LastTime" -> time |>;

appendChunkContent[ entity_Association, _, _ ] :=
    entity;

appendChunkContent // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Tool calls*)
applyToolCall // beginDefinition;

applyToolCall[ turn0_Association, update_Association, time_ ] := Module[ { turn, id, key },
    turn = endRetryEpisode[ turn0, time ];
    id   = toolCallIDString @ Lookup[ update, "toolCallId", None ];
    key  = Lookup[ turn[ "Index", "Tool" ], id, None ];
    If[ key =!= None && ! terminalToolQ @ turn[ "Entities", key ],
        (* A repeated tool_call for an unfinished call is treated as an update: *)
        mergeToolUpdate[ turn, retryChangedKeys[ turn0, turn ], key, update, time ],
        (* New call, or the ID of a finished call was reused (new instance): *)
        createTool[ turn, retryChangedKeys[ turn0, turn ], id, update, time ]
    ]
];

applyToolCall // endDefinition;


applyToolCallUpdate // beginDefinition;

applyToolCallUpdate[ turn0_Association, update_Association, time_ ] := Module[ { turn, id, key },
    turn = endRetryEpisode[ turn0, time ];
    id   = toolCallIDString @ Lookup[ update, "toolCallId", None ];
    key  = Lookup[ turn[ "Index", "Tool" ], id, None ];
    If[ key === None,
        createTool[ turn, retryChangedKeys[ turn0, turn ], id, update, time ], (* update for an unseen call: create a placeholder *)
        mergeToolUpdate[ turn, retryChangedKeys[ turn0, turn ], key, update, time ]
    ]
];

applyToolCallUpdate // endDefinition;


toolCallIDString // beginDefinition;
toolCallIDString[ id_String ] := id;
toolCallIDString[ id_Integer ] := ToString @ id;
toolCallIDString[ _ ] := "unknown";
toolCallIDString // endDefinition;


createTool // beginDefinition;

createTool[ turn0_Association, extra_List, id_String, update_Association, time_ ] := Module[ { turn = turn0, n, key, entity },
    n   = Lookup[ turn[ "Index", "ToolCount" ], id, 0 ] + 1;
    key = If[ n === 1, { "Tool", id }, { "Tool", id, n } ];
    entity = mergeToolFields[ newToolEntity[ id, update, time ], update, time ];
    turn = addEntity[ turn, key, entity ];
    turn[ "Index", "Tool", id ] = key;
    turn[ "Index", "ToolCount", id ] = n;
    reducerResult[ turn, Append[ extra, key ], True ]
];

createTool // endDefinition;


mergeToolUpdate // beginDefinition;

mergeToolUpdate[ turn_Association, extra_List, key_, update_Association, time_ ] := Module[ { res },
    res = updateEntity[ turn, key, mergeToolFields[ #, update, time ] & ];
    reducerResult[ First @ res, Join[ extra, If[ Last @ res, { key }, { } ] ], False ]
];

mergeToolUpdate // endDefinition;


newToolEntity // beginDefinition;

newToolEntity[ id_String, update_Association, time_ ] := <|
    "Type"          -> "Tool",
    "ToolCallID"    -> id,
    "Name"          -> None,
    "RawName"       -> None,
    "Kind"          -> None,
    "Title"         -> None,
    "AgentTitle"    -> None,
    "Status"        -> "pending",
    "ClientOutcome" -> None,
    "RawInput"      -> None,
    "RawOutput"     -> None,
    "Content"       -> { },
    "Diffs"         -> { },
    "Locations"     -> { },
    "Permission"    -> None,
    "ExitCode"      -> None,
    "StartTime"     -> time,
    "EndTime"       -> None,
    "Child"         -> childInfo @ update
|>;

newToolEntity // endDefinition;


(* Merges a tool_call / tool_call_update into a tool entity, following the ACP patch semantics: omitted or null fields
   are unchanged, content and locations replace, diffs accumulate in "Diffs", titles are never downgraded. *)
mergeToolFields // beginDefinition;

mergeToolFields[ entity0_Association, update_Association, time_ ] := Module[
    { entity = entity0, name, kind, title, status, rawInput, rawOutput, content, locations, exit },

    name = Lookup[ update, "name", None ];
    If[ StringQ @ name && entity[ "Name" ] === None,
        entity[ "RawName" ] = name;
        entity[ "Name"    ] = acpCanonicalToolName @ name
    ];

    kind = Lookup[ update, "kind", None ];
    If[ StringQ @ kind, entity[ "Kind" ] = kind ];

    title = Lookup[ update, "title", None ];
    If[ StringQ @ title,
        entity[ "AgentTitle" ] = title;
        entity[ "Title" ] = betterTitle[ entity[ "Title" ], title, entity ]
    ];

    status = Lookup[ update, "status", None ];
    If[ StringQ @ status, entity[ "Status" ] = status ];

    rawInput = Lookup[ update, "rawInput", Null ];
    If[ ! MatchQ[ rawInput, Null | _Missing ] && ! (rawInput === <| |> && nonEmptyQ @ entity[ "RawInput" ]),
        entity[ "RawInput" ] = rawInput;
        entity = synthesizeDiffs @ entity
    ];

    (* Full-text diffs from the content are added before the metadata patches of rawOutput, so a completed update that
       carries both (OpenCode's edit/patch completions) keeps only the full text: *)
    content = Lookup[ update, "content", Null ];
    If[ ListQ @ content,
        entity[ "Content" ] = content;
        entity = addDiffs[ entity, Cases[ content, d: KeyValuePattern[ "type" -> "diff" ] :> normalizeDiff[ d, "Update" ] ] ]
    ];

    rawOutput = Lookup[ update, "rawOutput", Null ];
    If[ ! MatchQ[ rawOutput, Null | _Missing ],
        entity[ "RawOutput" ] = rawOutput;
        exit = rawOutputExitCode @ rawOutput;
        If[ IntegerQ @ exit, entity[ "ExitCode" ] = exit ];
        entity = addDiffs[ entity, metadataDiffs @ rawOutput ]
    ];

    locations = Lookup[ update, "locations", Null ];
    If[ ListQ @ locations, entity[ "Locations" ] = locations ];

    If[ entity[ "Child" ] === None, entity[ "Child" ] = childInfo @ update ];

    If[ MatchQ[ entity[ "Status" ], $terminalToolStatus ] && entity[ "EndTime" ] === None, entity[ "EndTime" ] = time ];

    entity
];

mergeToolFields // endDefinition;


nonEmptyQ // beginDefinition;
nonEmptyQ[ as_Association ] := Length @ as > 0;
nonEmptyQ[ s_String ] := StringLength @ s > 0;
nonEmptyQ[ l_List ] := Length @ l > 0;
nonEmptyQ[ _ ] := False;
nonEmptyQ // endDefinition;


terminalToolQ // beginDefinition;
terminalToolQ[ KeyValuePattern[ "Status" -> status_ ] ] := MatchQ[ status, $terminalToolStatus ];
terminalToolQ[ _ ] := False;
terminalToolQ // endDefinition;


(* A bare title (the tool name or kind) never replaces a more specific one: *)
betterTitle // beginDefinition;
betterTitle[ old_String, new_String, entity_ ] /; bareTitleQ[ new, entity ] && ! bareTitleQ[ old, entity ] := old;
betterTitle[ _, new_String, _ ] := new;
betterTitle // endDefinition;


bareTitleQ // beginDefinition;

bareTitleQ[ title_String, entity_Association ] := Or[
    StringTrim @ title === "",
    MemberQ[
        ToLowerCase @ Cases[ Lookup[ entity, { "RawName", "Name", "Kind" } ], _String ],
        ToLowerCase @ StringTrim @ title
    ]
];

bareTitleQ[ _, _ ] := True;

bareTitleQ // endDefinition;


rawOutputExitCode // beginDefinition;
rawOutputExitCode[ KeyValuePattern[ "metadata" -> KeyValuePattern[ "exit" -> code_Integer ] ] ] := code;
rawOutputExitCode[ KeyValuePattern[ "exitCode" -> code_Integer ] ] := code;
rawOutputExitCode[ _ ] := None;
rawOutputExitCode // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*Diffs*)

(* Normalized diff items:
     <| "Path" -> _String, "OldText" -> _String|None (None = new file), "NewText" -> _String|None, "Patch" -> _String|None,
        "Source" -> "Permission"|"Update"|"Metadata"|"RawInput", "Synthesized" -> True|False, "Additions", "Deletions" |>
   Real diffs (from the permission request, updates, or metadata patches) replace synthesized ones for the same file. *)
normalizeDiff // beginDefinition;

normalizeDiff[ d_Association, source_String ] := <|
    "Path"        -> Replace[ Lookup[ d, "path", "" ], Except[ _String ] -> "" ],
    "OldText"     -> Replace[ Lookup[ d, "oldText", None ], Except[ _String ] -> None ],
    "NewText"     -> Replace[ Lookup[ d, "newText", None ], Except[ _String ] -> None ],
    "Patch"       -> None,
    "Source"      -> source,
    "Synthesized" -> False
|>;

normalizeDiff // endDefinition;


metadataDiffs // beginDefinition;

metadataDiffs[ KeyValuePattern[ "metadata" -> KeyValuePattern[ "files" -> files_List ] ] ] := Cases[
    files,
    KeyValuePattern @ { "file" -> file_String, "patch" -> patch_String } :> <|
        "Path"        -> file,
        "OldText"     -> None,
        "NewText"     -> None,
        "Patch"       -> patch,
        "Source"      -> "Metadata",
        "Synthesized" -> False
    |>
];

metadataDiffs[ _ ] := { };

metadataDiffs // endDefinition;


addDiffs // beginDefinition;

addDiffs[ entity_Association, { } ] := entity;

addDiffs[ entity_Association, diffs_List ] := Fold[ addDiff, entity, diffs ];

addDiffs // endDefinition;


addDiff // beginDefinition;

addDiff[ entity_Association, diff_Association ] := Module[ { existing, path, real },
    existing = entity[ "Diffs" ];
    path     = diff[ "Path" ];
    real     = Select[ existing, ! TrueQ @ #[ "Synthesized" ] && samePathQ[ #[ "Path" ], path ] & ];
    Which[
        (* duplicate (e.g. the same diff in the permission request and in the completed update): *)
        AnyTrue[ real, sameDiffQ[ #, diff ] & ],
            entity,
        (* synthesized diffs never replace real ones: *)
        TrueQ @ diff[ "Synthesized" ] && real =!= { },
            entity,
        (* metadata patches are redundant if we already have the full text for this file: *)
        StringQ @ diff[ "Patch" ] && AnyTrue[ real, StringQ @ #[ "NewText" ] & ],
            entity,
        True,
            <|
                entity,
                "Diffs" -> Append[ DeleteCases[ existing, d_ /; supersededDiffQ[ d, diff ] ], diff ]
            |>
    ]
];

addDiff // endDefinition;


(* Whether an earlier diff d is replaced by the new diff for the same file:
     * synthesized diffs (from the tool input) are replaced by any real diff;
     * a full-text diff replaces patch-only diffs (rawOutput metadata, which may arrive in an earlier update);
     * the diff of a completed update (read back after the write, e.g. after a formatter ran) replaces the preview of the
       permission request (an identical one was already dropped as a duplicate). *)
supersededDiffQ // beginDefinition;

supersededDiffQ[ d_Association, diff_Association ] := samePathQ[ d[ "Path" ], diff[ "Path" ] ] && Or[
    TrueQ @ d[ "Synthesized" ],
    ! TrueQ @ diff[ "Synthesized" ] && StringQ @ diff[ "NewText" ] && Or[
        StringQ @ d[ "Patch" ] && d[ "NewText" ] === None,
        diff[ "Source" ] === "Update" && d[ "Source" ] === "Permission"
    ]
];

supersededDiffQ // endDefinition;


sameDiffQ // beginDefinition;
sameDiffQ[ a_Association, b_Association ] := And[
    samePathQ[ a[ "Path" ], b[ "Path" ] ],
    a[ "OldText" ] === b[ "OldText" ],
    a[ "NewText" ] === b[ "NewText" ],
    a[ "Patch"   ] === b[ "Patch"   ]
];
sameDiffQ // endDefinition;


(* Paths may be relative (OpenCode's rawInput and metadata) or absolute (diff content and locations): *)
samePathQ // beginDefinition;
samePathQ[ a_String, a_String ] := True;
samePathQ[ a_String, b_String ] /; StringLength @ a > 0 && StringLength @ b > 0 :=
    StringEndsQ[ a, "/" <> StringTrim[ b, "./" ] ] || StringEndsQ[ b, "/" <> StringTrim[ a, "./" ] ];
samePathQ[ _, _ ] := False;
samePathQ // endDefinition;


(* When no real diff is available (e.g. edits that don't require approval), show what we know from rawInput: *)
synthesizeDiffs // beginDefinition;

synthesizeDiffs[ entity_Association ] := Module[ { input, path, diff },
    input = entity[ "RawInput" ];
    path  = rawInputPath @ input;
    If[ ! StringQ @ path, Return[ entity, Module ] ];
    diff = Switch[ entity[ "Name" ],
        "write",
            If[ StringQ @ input[ "content" ],
                <| "Path" -> path, "OldText" -> None, "NewText" -> input[ "content" ], "Patch" -> None, "Source" -> "RawInput", "Synthesized" -> True, "Write" -> True |>,
                None
            ],
        "edit",
            If[ StringQ @ Lookup[ input, "oldString", None ] && StringQ @ Lookup[ input, "newString", None ],
                <| "Path" -> path, "OldText" -> input[ "oldString" ], "NewText" -> input[ "newString" ], "Patch" -> None, "Source" -> "RawInput", "Synthesized" -> True, "Snippet" -> True |>,
                None
            ],
        _,
            None
    ];
    If[ AssociationQ @ diff, addDiff[ entity, diff ], entity ]
];

synthesizeDiffs // endDefinition;


rawInputPath // beginDefinition;
rawInputPath[ input_Association ] := SelectFirst[ Lookup[ input, { "path", "filePath", "file_path", "filepath" }, None ], StringQ, None ];
rawInputPath[ _ ] := None;
rawInputPath // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Plans*)
applyPlan // beginDefinition;

applyPlan[ turn0_Association, update_Association, time_ ] := Module[ { turn = turn0, entries, key = { "Plan" }, res },
    entries = Replace[ Lookup[ update, "entries", { } ], Except[ _List ] -> { } ];
    If[ KeyExistsQ[ turn[ "Entities" ], key ],
        res = updateEntity[ turn, key, <| #, "Entries" -> entries, "LastTime" -> time |> & ];
        reducerResult[ First @ res, If[ Last @ res, { key }, { } ], False ],
        turn = addEntity[ turn, key, <| "Type" -> "Plan", "Entries" -> entries, "FirstTime" -> time, "LastTime" -> time, "Child" -> childInfo @ update |> ];
        reducerResult[ turn, { key }, True ]
    ]
];

applyPlan // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Usage*)
applyUsage // beginDefinition;

applyUsage[ turn_Association, update_Association ] := Module[ { usage },
    usage = <|
        "Used" -> Lookup[ update, "used", None ],
        "Size" -> Lookup[ update, "size", None ],
        "Cost" -> Lookup[ update, "cost", None ]
    |>;
    If[ usage === turn[ "ContextUsage" ],
        noChange @ turn,
        reducerResult[ <| turn, "ContextUsage" -> usage |>, { }, False ]
    ]
];

applyUsage // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*Session info (retries and compaction)*)
applySessionInfo // beginDefinition;

applySessionInfo[ turn_Association, update_Association, time_ ] := Module[ { meta, res },
    meta = Replace[ Lookup[ update, "_meta", <| |> ], Except[ _Association ] -> <| |> ];
    res  = noChange @ turn;
    If[ KeyExistsQ[ meta, "opencode/retry" ],
        res = combineResults[ res, applyRetry[ res[ "Turn" ], meta[ "opencode/retry" ], time ] ]
    ];
    If[ KeyExistsQ[ meta, "opencode/compaction" ],
        res = combineResults[ res, applyCompaction[ res[ "Turn" ], meta[ "opencode/compaction" ], time ] ]
    ];
    res
];

applySessionInfo // endDefinition;


combineResults // beginDefinition;
combineResults[ a_Association, b_Association ] := <|
    "Turn"    -> b[ "Turn" ],
    "Changed" -> DeleteDuplicates @ Join[ a[ "Changed" ], b[ "Changed" ] ],
    "Layout"  -> TrueQ[ a[ "Layout" ] || b[ "Layout" ] ]
|>;
combineResults // endDefinition;


(* A retry episode is summarized by one Retry notice; it ends when the agent produces output again. *)
applyRetry // beginDefinition;

applyRetry[ turn0_Association, info_Association, time_ ] := Module[ { turn = turn0, error, retry, key, res },
    error = Replace[ Lookup[ info, "error", <| |> ], Except[ _Association ] -> <| |> ];
    retry = <|
        "Attempt"     -> Lookup[ info, "attempt", None ],
        "NextRetryAt" -> isoToAbsoluteTime @ Lookup[ info, "nextRetryAt", None ],
        "Message"     -> Replace[ Lookup[ error, "message", "" ], Except[ _String ] -> "" ],
        "ErrorType"   -> Replace[ Lookup[ error, "type", None ], Except[ _String ] -> None ],
        "Status"      -> Lookup[ error, "status", None ]
    |>;
    turn[ "RetryInfo" ] = retry;
    key = turn[ "RetryEpisode" ];
    If[ key === None || ! KeyExistsQ[ turn[ "Entities" ], key ],
        turn[ "NoticeCount" ] = turn[ "NoticeCount" ] + 1;
        key = { "Notice", turn[ "NoticeCount" ] };
        turn = addEntity[
            turn,
            key,
            <|
                "Type" -> "Notice",
                "Kind" -> "Retry",
                "Text" -> retry[ "Message" ],
                "Data" -> <|
                    "FirstAttempt" -> retry[ "Attempt" ],
                    "LastAttempt"  -> retry[ "Attempt" ],
                    "StartTime"    -> time,
                    "EndTime"      -> None,
                    "ErrorType"    -> retry[ "ErrorType" ],
                    "Status"       -> retry[ "Status" ],
                    "NextRetryAt"  -> retry[ "NextRetryAt" ],
                    "Active"       -> True
                |>,
                "Child" -> None
            |>
        ];
        turn[ "RetryEpisode" ] = key;
        reducerResult[ turn, { key }, True ],
        res = updateEntity[
            turn,
            key,
            Function[ e, <| e, "Text" -> retry[ "Message" ], "Data" -> <| e[ "Data" ], "LastAttempt" -> retry[ "Attempt" ], "NextRetryAt" -> retry[ "NextRetryAt" ], "Active" -> True, "EndTime" -> None |> |> ]
        ];
        reducerResult[ First @ res, If[ Last @ res, { key }, { } ], False ]
    ]
];

(* null: the scheduled retry has started *)
applyRetry[ turn0_Association, Null | None, time_ ] := Module[ { turn = turn0, key, res },
    turn[ "RetryInfo" ] = None;
    key = turn[ "RetryEpisode" ];
    If[ key === None,
        If[ turn === turn0, noChange @ turn, reducerResult[ turn, { }, False ] ],
        res = updateEntity[ turn, key, Function[ e, <| e, "Data" -> <| e[ "Data" ], "Active" -> False, "EndTime" -> time |> |> ] ];
        reducerResult[ First @ res, If[ Last @ res, { key }, { } ], False ]
    ]
];

applyRetry[ turn_Association, _, _ ] := noChange @ turn;

applyRetry // endDefinition;


(* Keys of entities changed by endRetryEpisode: *)
retryChangedKeys // beginDefinition;
retryChangedKeys[ old_Association, new_Association ] := With[ { key = old[ "RetryEpisode" ] },
    If[ key =!= None && old[ "Entities", key ] =!= new[ "Entities", key ], { key }, { } ]
];
retryChangedKeys // endDefinition;


(* Ends a retry episode once the agent produces output: *)
endRetryEpisode // beginDefinition;

endRetryEpisode[ turn_Association, _ ] /; turn[ "RetryEpisode" ] === None && turn[ "RetryInfo" ] === None := turn;

endRetryEpisode[ turn0_Association, time_ ] := Module[ { turn = turn0, key },
    key = turn[ "RetryEpisode" ];
    turn[ "RetryInfo" ] = None;
    turn[ "RetryEpisode" ] = None;
    If[ key =!= None,
        turn = First @ updateEntity[
            turn,
            key,
            Function[ e, <| e, "Data" -> <| e[ "Data" ], "Active" -> False, "EndTime" -> Replace[ e[ "Data", "EndTime" ], None -> time ] |> |> ]
        ]
    ];
    turn
];

endRetryEpisode // endDefinition;


applyCompaction // beginDefinition;

applyCompaction[ turn0_Association, info_Association, time_ ] := Module[ { turn = turn0, id, status, key, res },
    id     = Replace[ Lookup[ info, "messageId", "compaction" ], Except[ _String ] -> "compaction" ];
    status = Replace[ Lookup[ info, "status", "started" ], Except[ _String ] -> "started" ];
    key    = Lookup[ turn[ "Index", "Notice" ], Key @ { "Compaction", id }, None ];
    If[ key === None,
        turn[ "NoticeCount" ] = turn[ "NoticeCount" ] + 1;
        key = { "Notice", turn[ "NoticeCount" ] };
        turn = addEntity[
            turn,
            key,
            <|
                "Type"  -> "Notice",
                "Kind"  -> "Compaction",
                "Text"  -> Replace[ Lookup[ info, "error", "" ], Except[ _String ] -> "" ],
                "Data"  -> <| "Status" -> status, "Reason" -> Lookup[ info, "reason", None ], "StartTime" -> time, "EndTime" -> None |>,
                "Child" -> childInfo @ info
            |>
        ];
        turn[ "Index", "Notice", { "Compaction", id } ] = key;
        reducerResult[ turn, { key }, True ],
        res = updateEntity[
            turn,
            key,
            Function[ e,
                <|
                    e,
                    "Text" -> Replace[ Lookup[ info, "error", e[ "Text" ] ], Except[ _String ] -> e[ "Text" ] ],
                    "Data" -> <| e[ "Data" ], "Status" -> status, "EndTime" -> If[ status === "started", None, time ] |>
                |>
            ]
        ];
        reducerResult[ First @ res, If[ Last @ res, { key }, { } ], False ]
    ]
];

applyCompaction[ turn_Association, _, _ ] := noChange @ turn;

applyCompaction // endDefinition;


isoToAbsoluteTime // beginDefinition;

isoToAbsoluteTime[ s_String ] := Module[ { parts },
    parts = StringCases[
        s,
        RegularExpression[ "(\\d{4})-(\\d\\d)-(\\d\\d)T(\\d\\d):(\\d\\d):(\\d\\d(?:\\.\\d+)?)" ] :>
            ToExpression @ { "$1", "$2", "$3", "$4", "$5", "$6" },
        1
    ];
    If[ MatchQ[ parts, { { __? NumberQ } } ],
        Replace[ Quiet @ AbsoluteTime @ DateObject[ First @ parts, TimeZone -> 0 ], Except[ _? NumberQ ] -> None ],
        None
    ]
];

isoToAbsoluteTime[ _ ] := None;

isoToAbsoluteTime // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyNotice*)

(* Appends a Notice entity, e.g. for events that are not session updates (a subagent's permission request that was
   cancelled because no turn was running): notice is <| "Kind" -> "Info"|"Error"|..., "Text" -> _String, "Data" -> _ |>. *)
acpApplyNotice // beginDefinition;

acpApplyNotice[ turn_Association, notice_Association ] := acpApplyNotice[ turn, notice, AbsoluteTime[ ] ];

acpApplyNotice[ turn0_Association, notice_Association, time_? NumberQ ] := Module[ { turn = turn0, key },
    turn[ "NoticeCount" ] = turn[ "NoticeCount" ] + 1;
    key  = { "Notice", turn[ "NoticeCount" ] };
    turn = addEntity[
        turn,
        key,
        <|
            "Type"  -> "Notice",
            "Kind"  -> Replace[ Lookup[ notice, "Kind", "Info" ], Except[ _String ] -> "Info" ],
            "Text"  -> Replace[ Lookup[ notice, "Text", "" ], Except[ _String ] -> "" ],
            "Data"  -> Lookup[ notice, "Data", <| |> ],
            "Time"  -> time,
            "Child" -> None
        |>
    ];
    reducerResult[ turn, { key }, True ]
];

acpApplyNotice // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Permissions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyPermissionRequest*)

(* Attaches a session/request_permission request to the tool entity with the same toolCallId (its diffs are merged into
   "Diffs", its name is adopted if the tool has none; its status and title are NOT merged into the tool). If no tool
   matches (e.g. OpenCode's external_directory asks), a standalone Permission entity is created. *)
acpApplyPermissionRequest // beginDefinition;

acpApplyPermissionRequest[ turn_Association, reqID_, params_Association ] :=
    acpApplyPermissionRequest[ turn, reqID, params, AbsoluteTime[ ] ];

acpApplyPermissionRequest[ turn0_Association, reqID_, params_Association, time_? NumberQ ] := Module[
    { turn = turn0, toolCall, tid, perm, key, res, changed },

    If[ KeyExistsQ[ turn[ "Index", "Permission" ], reqID ], Return[ noChange @ turn, Module ] ];

    toolCall = Replace[ Lookup[ params, "toolCall", <| |> ], Except[ _Association ] -> <| |> ];
    tid      = toolCallIDString @ Lookup[ toolCall, "toolCallId", None ];
    perm     = <|
        "RequestID"  -> reqID,
        "Options"    -> Replace[ Lookup[ params, "options", { } ], Except[ _List ] -> { } ],
        "Title"      -> Replace[ Lookup[ toolCall, "title", None ], Except[ _String ] -> None ],
        "Kind"       -> Replace[ Lookup[ toolCall, "kind", None ], Except[ _String ] -> None ],
        "Outcome"    -> None,
        "OptionID"   -> None,
        "AskedAt"    -> time,
        "AnsweredAt" -> None
    |>;
    key = Lookup[ turn[ "Index", "Tool" ], tid, None ];

    If[ ListQ @ key && KeyExistsQ[ turn[ "Entities" ], key ],
        res = updateEntity[ turn, key, attachPermission[ #, perm, toolCall ] & ];
        turn = First @ res;
        changed = { key },

        key = { "Permission", reqID };
        turn = addEntity[
            turn,
            key,
            <|
                "Type"       -> "Permission",
                "RequestID"  -> reqID,
                "Params"     -> params,
                "Title"      -> perm[ "Title" ],
                "Options"    -> perm[ "Options" ],
                "Outcome"    -> None,
                "OptionID"   -> None,
                "AskedAt"    -> time,
                "AnsweredAt" -> None,
                "Child"      -> Replace[ childInfo @ toolCall, None :> childInfo @ params ]
            |>
        ];
        changed = { key }
    ];

    turn[ "Index", "Permission", reqID ] = key;
    turn[ "PendingPermissions" ] = Append[ turn[ "PendingPermissions" ], reqID ];
    turn = updateWaiting[ turn, time ];
    reducerResult[ turn, changed, MatchQ[ key, { "Permission", _ } ] ]
];

acpApplyPermissionRequest // endDefinition;


attachPermission // beginDefinition;

attachPermission[ tool0_Association, perm_Association, toolCall_Association ] := Module[ { tool = tool0, name, input, locations, kind },
    tool[ "Permission" ] = perm;
    name = Lookup[ toolCall, "name", None ];
    If[ StringQ @ name && tool[ "Name" ] === None, tool[ "RawName" ] = name; tool[ "Name" ] = acpCanonicalToolName @ name ];
    kind = Lookup[ toolCall, "kind", None ];
    If[ StringQ @ kind && tool[ "Kind" ] === None, tool[ "Kind" ] = kind ];
    input = Lookup[ toolCall, "rawInput", None ];
    If[ nonEmptyQ @ input && ! nonEmptyQ @ tool[ "RawInput" ], tool[ "RawInput" ] = input; tool = synthesizeDiffs @ tool ];
    locations = Lookup[ toolCall, "locations", None ];
    If[ nonEmptyQ @ locations && ! nonEmptyQ @ tool[ "Locations" ], tool[ "Locations" ] = locations ];
    If[ tool[ "Child" ] === None, tool[ "Child" ] = childInfo @ toolCall ];
    addDiffs[
        tool,
        Cases[
            Replace[ Lookup[ toolCall, "content", { } ], Except[ _List ] -> { } ],
            d: KeyValuePattern[ "type" -> "diff" ] :> normalizeDiff[ d, "Permission" ]
        ]
    ]
];

attachPermission // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyPermissionOutcome*)

(* Records the user's answer. `option` is the selected optionId (e.g. "once"), an option kind (e.g. "allow_once"),
   or None/"cancelled". A request that was already answered or withdrawn is left unchanged. *)
acpApplyPermissionOutcome // beginDefinition;

acpApplyPermissionOutcome[ turn_Association, reqID_, option_ ] :=
    acpApplyPermissionOutcome[ turn, reqID, option, AbsoluteTime[ ] ];

acpApplyPermissionOutcome[ turn_Association, reqID_, option_, time_? NumberQ ] :=
    setPermissionOutcome[ turn, reqID, option, time, False ];

acpApplyPermissionOutcome // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyPermissionWithdrawn*)

(* The agent withdrew its request ($/cancel_request). The tool's own updates decide its status. *)
acpApplyPermissionWithdrawn // beginDefinition;

acpApplyPermissionWithdrawn[ turn_Association, reqID_ ] :=
    acpApplyPermissionWithdrawn[ turn, reqID, AbsoluteTime[ ] ];

acpApplyPermissionWithdrawn[ turn_Association, reqID_, time_? NumberQ ] :=
    setPermissionOutcome[ turn, reqID, "withdrawn", time, True ];

acpApplyPermissionWithdrawn // endDefinition;


setPermissionOutcome // beginDefinition;

setPermissionOutcome[ turn0_Association, reqID_, option_, time_, withdrawn_ ] := Module[
    { turn = turn0, key, entity, perm, outcome, res, changed = { } },

    key = Lookup[ turn[ "Index", "Permission" ], reqID, None ];
    If[ key === None, Return[ noChange @ turn, Module ] ];
    entity = turn[ "Entities", key ];
    perm   = If[ entity[ "Type" ] === "Tool", entity[ "Permission" ], entity ];
    If[ ! AssociationQ @ perm || perm[ "Outcome" ] =!= None, Return[ noChange @ turn, Module ] ];

    outcome = If[ TrueQ @ withdrawn, "withdrawn", permissionOutcome[ perm[ "Options" ], option ] ];

    res = updateEntity[
        turn,
        key,
        Function[ e,
            If[ e[ "Type" ] === "Tool",
                <|
                    e,
                    "Permission"    -> <| e[ "Permission" ], "Outcome" -> outcome, "OptionID" -> optionIDString @ option, "AnsweredAt" -> time |>,
                    "ClientOutcome" -> If[ outcome === "reject" && e[ "ClientOutcome" ] === None, "Declined", e[ "ClientOutcome" ] ]
                |>,
                <| e, "Outcome" -> outcome, "OptionID" -> optionIDString @ option, "AnsweredAt" -> time |>
            ]
        ]
    ];
    turn = First @ res;
    If[ Last @ res, changed = { key } ];

    If[ outcome === "reject" && turn[ "ClientCancel" ] === None, turn[ "ClientCancel" ] = "Reject" ];
    turn[ "PendingPermissions" ] = DeleteCases[ turn[ "PendingPermissions" ], reqID ];
    turn = updateWaiting[ turn, time ];
    reducerResult[ turn, changed, False ]
];

setPermissionOutcome // endDefinition;


optionIDString // beginDefinition;
optionIDString[ s_String ] := s;
optionIDString[ _ ] := None;
optionIDString // endDefinition;


permissionOutcome // beginDefinition;

permissionOutcome[ _, None | Null | "cancelled" ] := "cancelled";
permissionOutcome[ _, "withdrawn" ] := "withdrawn";

permissionOutcome[ options_List, option_String ] := Module[ { kind },
    kind = SelectFirst[ options, Lookup[ #, "optionId", None ] === option &, <| |> ][ "kind" ];
    kind = If[ StringQ @ kind, kind, option ];
    Switch[ kind,
        "allow_once" | "once"                     , "once",
        "allow_always" | "always"                 , "always",
        "reject_once" | "reject_always" | "reject", "reject",
        _                                         , option
    ]
];

permissionOutcome[ _, _ ] := "cancelled";

permissionOutcome // endDefinition;


(* Tracks the time spent waiting for the user's approval: *)
updateWaiting // beginDefinition;

updateWaiting[ turn0_Association, time_ ] := Module[ { turn = turn0, pending },
    pending = turn[ "PendingPermissions" ] =!= { };
    Which[
        pending && turn[ "WaitingSince" ] === None,
            turn[ "WaitingSince" ] = time,
        ! pending && turn[ "WaitingSince" ] =!= None,
            turn[ "WaitingTime"  ] = turn[ "WaitingTime" ] + Max[ 0, time - turn[ "WaitingSince" ] ];
            turn[ "WaitingSince" ] = None
    ];
    turn
];

updateWaiting // endDefinition;


(* Marks every pending permission as cancelled: *)
cancelPendingPermissions // beginDefinition;

cancelPendingPermissions[ turn0_Association, time_ ] := Module[ { turn = turn0, changed = { }, res },
    Do[
        res = setPermissionOutcome[ turn, reqID, None, time, False ];
        turn = res[ "Turn" ];
        changed = Join[ changed, res[ "Changed" ] ],
        { reqID, turn[ "PendingPermissions" ] }
    ];
    turn[ "PendingPermissions" ] = { };
    { updateWaiting[ turn, time ], changed }
];

cancelPendingPermissions // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Turn End and Client Actions*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyClientCancel*)

(* Records what the client did: "Stop" (the user pressed Stop) or "Reject" (the user rejected a permission request).
   Stop marks unfinished tools as "Stopped" and cancels pending permissions; it is not undone by a later Reject. *)
acpApplyClientCancel // beginDefinition;

acpApplyClientCancel[ turn_Association, kind_String ] :=
    acpApplyClientCancel[ turn, kind, AbsoluteTime[ ] ];

acpApplyClientCancel[ turn0_Association, "Stop", time_? NumberQ ] := Module[ { turn = turn0, changed, res },
    turn[ "ClientCancel" ] = "Stop";
    { turn, changed } = cancelPendingPermissions[ turn, time ];
    res = updateEntities[
        turn,
        entityKeysOfType[ turn, "Tool" ],
        Function[ e,
            If[ MatchQ[ e[ "Status" ], $unfinishedToolStatus ] && e[ "ClientOutcome" ] === None,
                <| e, "ClientOutcome" -> "Stopped" |>,
                e
            ]
        ]
    ];
    turn = First @ res;
    reducerResult[ turn, Join[ changed, Last @ res ], turn =!= turn0 ]
];

acpApplyClientCancel[ turn_Association, "Reject", _? NumberQ ] :=
    If[ turn[ "ClientCancel" ] === None,
        reducerResult[ <| turn, "ClientCancel" -> "Reject" |>, { }, True ],
        noChange @ turn
    ];

acpApplyClientCancel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpApplyTurnEnd*)

(* Applies the session/prompt response: <| "StopReason" -> _, "Error" -> <| "Code", "Message", "Data" |>, "Usage" -> _ |>
   (any subset; the raw ACP result keys "stopReason" and "usage" are accepted too). Sets EndTime, StopReason, Error and
   Usage; cancels pending permissions; unfinished tools become "Stopped"; tools that failed because of a client action
   ("The user declined this tool call", "Tool execution interrupted") get a neutral ClientOutcome.
   The turn "Status" is not changed (finalization in UI.wl moves it to "Finalizing"/"Done"); use acpTurnEndedQ. *)
acpApplyTurnEnd // beginDefinition;

acpApplyTurnEnd[ turn_Association, info_Association ] :=
    acpApplyTurnEnd[ turn, info, AbsoluteTime[ ] ];

acpApplyTurnEnd[ turn0_Association, info_Association, time_? NumberQ ] := Module[
    { turn = turn0, stopReason, error, usage, changed, res, retryKey },

    stopReason = Replace[ Lookup[ info, "StopReason", Lookup[ info, "stopReason", None ] ], Except[ _String ] -> None ];
    error      = Replace[ Lookup[ info, "Error", None ], Except[ _Association ] -> None ];
    usage      = Lookup[ info, "Usage", Lookup[ info, "usage", None ] ];

    If[ turn[ "EndTime" ] === None, turn[ "EndTime" ] = time ];
    If[ turn[ "StopReason" ] === None && StringQ @ stopReason, turn[ "StopReason" ] = stopReason ];
    If[ turn[ "Error" ] === None && AssociationQ @ error, turn[ "Error" ] = error ];
    If[ AssociationQ @ usage, turn[ "Usage" ] = usage ];

    { turn, changed } = cancelPendingPermissions[ turn, time ];

    retryKey = turn[ "RetryEpisode" ];
    turn = endRetryEpisode[ turn, time ];
    If[ retryKey =!= None, AppendTo[ changed, retryKey ] ];

    res = updateEntities[ turn, entityKeysOfType[ turn, "Tool" ], finishTool[ #, turn ] & ];
    turn = First @ res;

    reducerResult[ turn, Join[ changed, Last @ res ], True ]
];

acpApplyTurnEnd // endDefinition;


finishTool // beginDefinition;

finishTool[ tool_Association, turn_Association ] := Which[
    tool[ "ClientOutcome" ] =!= None,
        tool,
    MatchQ[ tool[ "Status" ], $unfinishedToolStatus ],
        <| tool, "ClientOutcome" -> "Stopped" |>,
    tool[ "Status" ] === "failed" && turn[ "ClientCancel" ] =!= None && clientInterruptionQ @ tool,
        <| tool, "ClientOutcome" -> If[ permissionOutcomeOf @ tool === "reject", "Declined", "Stopped" ] |>,
    True,
        tool
];

finishTool // endDefinition;


clientInterruptionQ // beginDefinition;
clientInterruptionQ[ tool_Association ] := AnyTrue[ toolErrorTexts @ tool, acpClientInterruptionTextQ ];
clientInterruptionQ // endDefinition;


(* True for the texts OpenCode reports for a tool call that was declined or interrupted by the client (they repeat
   what the "Declined"/"Stopped" badge already says, so tool cards don't show them as output). *)
acpClientInterruptionTextQ // beginDefinition;
acpClientInterruptionTextQ[ text_String ] := StringMatchQ[ StringTrim @ text, $clientInterruptionText, IgnoreCase -> True ];
acpClientInterruptionTextQ[ _ ] := False;
acpClientInterruptionTextQ // endDefinition;


toolErrorTexts // beginDefinition;
toolErrorTexts[ tool_Association ] := Join[
    Cases[ { tool[ "RawOutput" ] }, KeyValuePattern[ "error" -> e_String ] :> e ],
    Cases[ tool[ "Content" ], KeyValuePattern @ { "type" -> "content", "content" -> KeyValuePattern @ { "type" -> "text", "text" -> t_String } } :> t ]
];
toolErrorTexts // endDefinition;


permissionOutcomeOf // beginDefinition;
permissionOutcomeOf[ KeyValuePattern[ "Permission" -> KeyValuePattern[ "Outcome" -> o_ ] ] ] := o;
permissionOutcomeOf[ KeyValuePattern @ { "Type" -> "Permission", "Outcome" -> o_ } ] := o;
permissionOutcomeOf[ _ ] := None;
permissionOutcomeOf // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Derived Information*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnSplit*)

(* One rule for every stop reason: the answer is the run of trailing top-level messages after the last non-message
   entity. If the turn did not end normally (stop reason other than end_turn, or an error) and has no such answer,
   "Tail" holds the last step's visible items (its messages and the tool calls that followed them) so they can be shown
   expanded below the "Worked for" opener. *)
acpTurnSplit // beginDefinition;

acpTurnSplit[ turn_Association ] := Module[ { order, entities, answer, rest, tail, work },
    order    = turn[ "Order" ];
    entities = turn[ "Entities" ];
    answer   = Reverse @ TakeWhile[ Reverse @ order, answerEntityQ @ entities[ # ] & ];
    rest     = Drop[ order, -Length @ answer ];
    tail     = If[ answer === { } && abnormalEndQ @ turn, lastStepItems[ rest, entities ], { } ];
    work     = Select[ rest, ! MemberQ[ tail, # ] & ];
    <| "Work" -> work, "Answer" -> answer, "Tail" -> tail |>
];

acpTurnSplit[ _ ] := <| "Work" -> { }, "Answer" -> { }, "Tail" -> { } |>;

acpTurnSplit // endDefinition;


answerEntityQ // beginDefinition;
answerEntityQ[ KeyValuePattern @ { "Type" -> "Message", "Child" -> None } ] := True;
answerEntityQ[ _ ] := False;
answerEntityQ // endDefinition;


abnormalEndQ // beginDefinition;
abnormalEndQ[ turn_Association ] := acpTurnEndedQ @ turn && (turn[ "StopReason" ] =!= "end_turn" || turn[ "Error" ] =!= None);
abnormalEndQ // endDefinition;


lastStepItems // beginDefinition;

(* The trailing run of tool cards can span several model steps when the agent writes no text between tool calls, so
   only the tools from the first one that did not complete normally (declined, stopped, failed, still pending) are
   shown expanded; if they all completed, only the last one is. Messages are included only if they immediately
   precede those tools. *)
lastStepItems[ keys_List, entities_Association ] := Module[ { tools, unfinished, before, messages },
    tools    = Reverse @ TakeWhile[ Reverse @ keys, visibleWorkItemQ @ entities[ # ] & ];
    If[ tools === { }, Return[ { }, Module ] ];
    unfinished = Select[ tools, ! completedNormallyQ @ entities[ # ] & ];
    tools    = If[ unfinished === { },
                   { Last @ tools },
                   Drop[ tools, First @ FirstPosition[ tools, First @ unfinished ] - 1 ]
               ];
    before   = Drop[ keys, -Length @ tools ];
    messages = Reverse @ TakeWhile[ Reverse @ before, answerEntityQ @ entities[ # ] & ];
    Join[ messages, tools ]
];

lastStepItems // endDefinition;


completedNormallyQ // beginDefinition;
completedNormallyQ[ KeyValuePattern @ { "Type" -> "Tool", "Status" -> "completed", "ClientOutcome" -> None } ] := True;
completedNormallyQ[ KeyValuePattern @ { "Type" -> "Notice" } ] := True;
completedNormallyQ[ _ ] := False;
completedNormallyQ // endDefinition;


visibleWorkItemQ // beginDefinition;
visibleWorkItemQ[ KeyValuePattern @ { "Type" -> "Tool" | "Permission" | "Notice", "Child" -> None } ] := True;
visibleWorkItemQ[ _ ] := False;
visibleWorkItemQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpCanonicalToolName*)
acpCanonicalToolName // beginDefinition;

acpCanonicalToolName[ name_String ] := Replace[
    ToLowerCase @ StringTrim @ name,
    { "bash" -> "shell", "task" -> "subagent", "apply_patch" -> "patch" }
];

acpCanonicalToolName[ _ ] := None;

acpCanonicalToolName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpFormatDuration*)
acpFormatDuration // beginDefinition;

acpFormatDuration[ secs_? NumberQ ] := Module[ { s },
    s = Max[ 1, Round @ secs ];
    Which[
        s < 60,
            acpLabel[ "DurationSeconds", <| "s" -> s |> ],
        s < 3600,
            acpLabel[ "DurationMinutes", <| "m" -> Quotient[ s, 60 ], "s" -> Mod[ s, 60 ] |> ],
        True,
            acpLabel[ "DurationHours", <| "h" -> Quotient[ s, 3600 ], "m" -> Quotient[ Mod[ s, 3600 ], 60 ] |> ]
    ]
];

acpFormatDuration[ q_Quantity ] := acpFormatDuration @ QuantityMagnitude @ UnitConvert[ q, "Seconds" ];

acpFormatDuration[ _ ] := acpFormatDuration[ 0 ];

acpFormatDuration // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpWorkedForLabel*)

(* "Worked for 2m 13s", "Worked for 20s (+11m 3s waiting for approval)", "Stopped after 45s", "Failed after 12s". *)
acpWorkedForLabel // beginDefinition;

acpWorkedForLabel[ turn_Association ] := acpWorkedForLabel[ turn, AbsoluteTime[ ] ];

acpWorkedForLabel[ turn_Association, now_? NumberQ ] := Module[ { total, waiting, work },
    total   = turnDuration[ turn, now ];
    waiting = waitingDuration[ turn, now ];
    work    = Max[ 0, total - waiting ];
    Which[
        turn[ "Error" ] =!= None,
            acpLabel[ "FailedAfter", <| "time" -> acpFormatDuration @ total |> ],
        stoppedQ @ turn,
            acpLabel[ "StoppedAfter", <| "time" -> acpFormatDuration @ total |> ],
        waiting >= $significantWaitingTime,
            acpLabel[ "WorkedForWaiting", <| "time" -> acpFormatDuration @ work, "waiting" -> acpFormatDuration @ waiting |> ],
        True,
            acpLabel[ "WorkedFor", <| "time" -> acpFormatDuration @ work |> ]
    ]
];

acpWorkedForLabel // endDefinition;


turnDuration // beginDefinition;
turnDuration[ turn_Association, now_ ] := Max[ 0, Replace[ turn[ "EndTime" ], Except[ _? NumberQ ] -> now ] - turn[ "StartTime" ] ];
turnDuration // endDefinition;


waitingDuration // beginDefinition;
waitingDuration[ turn_Association, now_ ] := turn[ "WaitingTime" ] + If[ NumberQ @ turn[ "WaitingSince" ],
    Max[ 0, Replace[ turn[ "EndTime" ], Except[ _? NumberQ ] -> now ] - turn[ "WaitingSince" ] ],
    0
];
waitingDuration // endDefinition;


stoppedQ // beginDefinition;
stoppedQ[ turn_Association ] := turn[ "ClientCancel" ] === "Stop" || (turn[ "StopReason" ] === "cancelled" && turn[ "ClientCancel" ] === None);
stoppedQ // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnStatusLine*)

(* The status line shown below the "Worked for" opener of a turn that did not end normally (None otherwise). *)
acpTurnStatusLine // beginDefinition;

acpTurnStatusLine[ turn_Association ] := acpTurnStatusLine[ turn, AbsoluteTime[ ] ];

acpTurnStatusLine[ turn_Association, now_? NumberQ ] := Module[ { agent, declined },
    agent = agentName @ turn;
    Which[
        ! acpTurnEndedQ @ turn,
            None,
        turn[ "Error" ] =!= None,
            acpLabel[ "StatusError", <| "message" -> errorMessage @ turn[ "Error" ] |> ],
        turn[ "ClientCancel" ] === "Stop",
            acpLabel[ "StatusStoppedByYou", <| "time" -> acpFormatDuration @ turnDuration[ turn, now ] |> ],
        turn[ "ClientCancel" ] === "Reject",
            declined = SelectFirst[ Reverse @ turn[ "Order" ], declinedEntityQ @ turn[ "Entities", # ] &, None ];
            If[ declined === None,
                acpLabel[ "StatusDeclinedGeneric", <| "agent" -> agent |> ],
                acpLabel[ "StatusDeclined", <| "action" -> declinedAction[ turn[ "Entities", declined ], turn ], "agent" -> agent |> ]
            ],
        turn[ "StopReason" ] === "cancelled",
            acpLabel[ "StatusCancelled", <| "time" -> acpFormatDuration @ turnDuration[ turn, now ] |> ],
        turn[ "StopReason" ] === "max_tokens",
            acpLabel[ "StatusMaxTokens" ],
        turn[ "StopReason" ] === "max_turn_requests",
            acpLabel[ "StatusMaxTurnRequests" ],
        turn[ "StopReason" ] === "refusal",
            acpLabel[ "StatusRefusal", <| "agent" -> agent |> ],
        StringQ @ turn[ "StopReason" ] && turn[ "StopReason" ] =!= "end_turn",
            acpLabel[ "StatusOther", <| "reason" -> turn[ "StopReason" ] |> ],
        True,
            None
    ]
];

acpTurnStatusLine[ _, ___ ] := None;

acpTurnStatusLine // endDefinition;


declinedEntityQ // beginDefinition;
declinedEntityQ[ KeyValuePattern @ { "Type" -> "Tool", "ClientOutcome" -> "Declined" } ] := True;
declinedEntityQ[ KeyValuePattern @ { "Type" -> "Permission", "Outcome" -> "reject" } ] := True;
declinedEntityQ[ _ ] := False;
declinedEntityQ // endDefinition;


declinedAction // beginDefinition;
declinedAction[ entity_Association, turn_ ] := acpToolAction[ entity, turn ];
declinedAction // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolAction*)

(* Infinitive phrase for a tool call, e.g. "edit hello.txt", "run `ls -la`", "use Wolfram Language Evaluator". *)
acpToolAction // beginDefinition;

acpToolAction[ tool_Association ] := acpToolAction[ tool, <| |> ];

acpToolAction[ perm: KeyValuePattern[ "Type" -> "Permission" ], turn_ ] :=
    StringTrim[ acpLabel[ "ToolExternalDirectoryVerb" ] <> " " <> permissionObject[ perm, turn ] ];

acpToolAction[ tool_Association, turn_ ] := Module[ { vo },
    vo = toolVerbObject[ tool, turn ];
    If[ TrueQ @ vo[ "UseTitle" ],
        vo[ "Object" ],
        StringTrim[ vo[ "Verb" ] <> " " <> vo[ "Object" ] ]
    ]
];

acpToolAction // endDefinition;


errorMessage // beginDefinition;
errorMessage[ KeyValuePattern[ "Message" -> msg_String ] ] := msg;
errorMessage[ KeyValuePattern[ "Code" -> code_ ] ] := ToString @ code;
errorMessage[ _ ] := "";
errorMessage // endDefinition;


agentName // beginDefinition;
agentName[ turn_Association ] := Replace[ Lookup[ turn, "AgentName", $defaultAgentName ], Except[ _String ] -> $defaultAgentName ];
agentName[ _ ] := $defaultAgentName;
agentName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnActivityLabel*)

(* One-line description of what the agent is doing, for the "Working" header of a running turn. *)
acpTurnActivityLabel // beginDefinition;

acpTurnActivityLabel[ turn_Association ] := acpTurnActivityLabel[ turn, AbsoluteTime[ ] ];

acpTurnActivityLabel[ turn_Association, now_? NumberQ ] := Module[ { agent, retry, running, last, silence },
    agent   = agentName @ turn;
    retry   = turn[ "RetryInfo" ];
    running = SelectFirst[ Reverse @ entityKeysOfType[ turn, "Tool" ], runningToolQ @ turn[ "Entities", # ] &, None ];
    last    = If[ turn[ "Order" ] === { }, None, turn[ "Entities", Last @ turn[ "Order" ] ] ];
    silence = now - Replace[ turn[ "LastEventTime" ], Except[ _? NumberQ ] -> now ];
    Which[
        acpTurnEndedQ @ turn,
            acpLabel[ "ActivityFinishing" ],
        turn[ "ClientCancel" ] === "Stop",
            acpLabel[ "ActivityStopping" ],
        turn[ "PendingPermissions" ] =!= { },
            acpLabel[ "ActivityWaitingForApproval" ],
        AssociationQ @ retry,
            retryActivityLabel[ retry, now ],
        running =!= None,
            acpToolTitle[ turn[ "Entities", running ], Automatic, turn ],
        silence >= $silenceThreshold,
            acpLabel[
                If[ turn[ "FirstEventTime" ] === None, "ActivityWaitingForAgentMCP", "ActivityWaitingForAgent" ],
                <| "agent" -> agent, "time" -> acpFormatDuration @ silence |>
            ],
        MatchQ[ last, KeyValuePattern[ "Type" -> "Message" ] ],
            acpLabel[ "ActivityWritingAnswer" ],
        MatchQ[ last, KeyValuePattern[ "Type" -> "Tool" ] ],
            acpToolTitle[ last, Automatic, turn ],
        True,
            acpLabel[ "ActivityThinking" ]
    ]
];

acpTurnActivityLabel // endDefinition;


runningToolQ // beginDefinition;
runningToolQ[ tool_Association ] := tool[ "Status" ] === "in_progress" && tool[ "ClientOutcome" ] === None && ! permissionPendingQ @ tool;
runningToolQ // endDefinition;


permissionPendingQ // beginDefinition;
permissionPendingQ[ KeyValuePattern[ "Permission" -> KeyValuePattern[ "Outcome" -> None ] ] ] := True;
permissionPendingQ[ KeyValuePattern @ { "Type" -> "Permission", "Outcome" -> None } ] := True;
permissionPendingQ[ _ ] := False;
permissionPendingQ // endDefinition;


retryActivityLabel // beginDefinition;

retryActivityLabel[ retry_Association, now_ ] := Module[ { next, attempt },
    next    = retry[ "NextRetryAt" ];
    attempt = Replace[ retry[ "Attempt" ], Except[ _Integer ] -> "?" ];
    If[ NumberQ @ next && next - now >= 0.5,
        acpLabel[
            If[ retry[ "ErrorType" ] === "provider.rate-limit", "ActivityRetryingRateLimited", "ActivityRetrying" ],
            <| "time" -> acpFormatDuration[ next - now ], "attempt" -> attempt |>
        ],
        acpLabel[ "ActivityRetryingNow", <| "attempt" -> attempt |> ]
    ]
];

retryActivityLabel // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolTitle*)

(* acpToolTitle[ tool ] / acpToolTitle[ tool, tense ] / acpToolTitle[ tool, tense, turn ]
   tense: Automatic (from the tool's state), "Pending" (input not known yet), "Awaiting" (permission pending),
          "Running", "Done", "Failed", "Declined", "Stopped".
   Commands and patterns are wrapped in backticks, which renderers show as code. *)
acpToolTitle // beginDefinition;

acpToolTitle[ tool_Association ] := acpToolTitle[ tool, Automatic, <| |> ];
acpToolTitle[ tool_Association, tense_ ] := acpToolTitle[ tool, tense, <| |> ];

acpToolTitle[ tool: KeyValuePattern[ "Type" -> "Permission" ], _, turn_ ] :=
    acpLabel[ "ToolExternalDirectory", <| "object" -> permissionObject[ tool, turn ] |> ];

acpToolTitle[ tool_Association, Automatic, turn_ ] := acpToolTitle[ tool, toolTense @ tool, turn ];

acpToolTitle[ tool_Association, tense_String, turn_ ] := Module[ { vo, group, object },
    vo     = toolVerbObject[ tool, turn ];
    group  = vo[ "Group" ];
    object = vo[ "Object" ];
    Which[
        (* Agents without OpenCode's "name" field usually send descriptive titles: *)
        vo[ "UseTitle" ],
            titleWithTense[ object, tense ],
        tense === "Pending" || (object === "" && MatchQ[ tense, "Running" | "Awaiting" ]),
            pendingTitle[ group, object ],
        tense === "Running",
            If[ group === "Execute" && object === "", acpLabel[ "ToolExecuteRunningCode" ], acpLabel[ "Tool" <> group <> "Running", <| "object" -> object |> ] ],
        tense === "Done",
            doneTitle[ group, object, tool ],
        tense === "Awaiting",
            acpLabel[ "ToolAwaiting" , <| "verb" -> vo[ "Verb" ], "object" -> object |> ],
        tense === "Failed",
            acpLabel[ "ToolFailed"   , <| "verb" -> vo[ "Verb" ], "object" -> object |> ],
        tense === "Declined",
            acpLabel[ "ToolDeclined" , <| "verb" -> vo[ "Verb" ], "object" -> object |> ],
        tense === "Stopped",
            acpLabel[ "ToolStopped"  , <| "verb" -> vo[ "Verb" ], "object" -> object |> ],
        True,
            doneTitle[ group, object, tool ]
    ] // StringTrim
];

acpToolTitle // endDefinition;


pendingTitle // beginDefinition;
pendingTitle[ "Generic", "" ] := acpLabel[ "ToolGenericPendingNoObject" ];
pendingTitle[ "Generic", object_ ] := acpLabel[ "ToolGenericPending", <| "object" -> object |> ];
pendingTitle[ group_String, _ ] := acpLabel[ "Tool" <> group <> "Pending" ];
pendingTitle // endDefinition;


doneTitle // beginDefinition;

doneTitle[ "Execute", "", _ ] := acpLabel[ "ToolExecuteDoneCode" ];

doneTitle[ "Read", object_, tool_ ] /; directoryReadQ @ tool := doneTitle[ "List", object, tool ];

doneTitle[ "Write", object_, tool_ ] /; object =!= "" && newFileQ @ tool := acpLabel[ "ToolWriteCreated", <| "object" -> object |> ];

(* Nothing is known about what the tool did (e.g. its input was never sent): never echo the bare tool name *)
doneTitle[ group_String, "", _ ] /; KeyExistsQ[ $acpStrings, "Tool" <> group <> "DoneNoObject" ] :=
    acpLabel[ "Tool" <> group <> "DoneNoObject" ];

doneTitle[ group_String, object_, _ ] := acpLabel[ "Tool" <> group <> "Done", <| "object" -> object |> ];

doneTitle // endDefinition;


titleWithTense // beginDefinition;
titleWithTense[ title_String, "Declined" ] := acpLabel[ "ToolDeclinedTitle", <| "title" -> title |> ];
titleWithTense[ title_String, "Stopped"  ] := acpLabel[ "ToolStoppedTitle" , <| "title" -> title |> ];
titleWithTense[ title_String, "Failed"   ] := acpLabel[ "ToolFailedTitle"  , <| "title" -> title |> ];
titleWithTense[ title_String, _          ] := title;
titleWithTense // endDefinition;


toolTense // beginDefinition;

toolTense[ tool_Association ] := Which[
    tool[ "ClientOutcome" ] === "Declined"              , "Declined",
    tool[ "ClientOutcome" ] === "Stopped"               , "Stopped",
    permissionPendingQ @ tool                           , "Awaiting",
    tool[ "Status" ] === "completed"                    , "Done",
    tool[ "Status" ] === "failed"                       , If[ permissionOutcomeOf @ tool === "reject", "Declined", "Failed" ],
    tool[ "Status" ] === "in_progress"                  , "Running",
    True                                                , "Pending"
];

toolTense // endDefinition;


directoryReadQ // beginDefinition;
directoryReadQ[ tool_Association ] := AnyTrue[ toolOutputTexts @ tool, StringStartsQ[ #, "Read directory" ] & ];
directoryReadQ // endDefinition;


newFileQ // beginDefinition;
newFileQ[ tool_Association ] := AnyTrue[ tool[ "Diffs" ], ! TrueQ @ #[ "Synthesized" ] && #[ "OldText" ] === None && StringQ @ #[ "NewText" ] & ];
newFileQ // endDefinition;


(* Returns <| "Group" -> labelGroup, "Verb" -> infinitive, "Object" -> object string ("" if unknown), "UseTitle" -> bool |> *)
toolVerbObject // beginDefinition;

toolVerbObject[ tool_Association, turn_ ] := Module[ { name, group, object, useTitle },
    name     = tool[ "Name" ];
    group    = Which[
        StringQ @ name, Lookup[ $toolLabelGroups, name, "Generic" ],
        StringQ @ tool[ "Kind" ], Lookup[ $kindLabelGroups, tool[ "Kind" ], "Generic" ],
        True, "Generic"
    ];
    useTitle = ! StringQ @ name && descriptiveTitleQ @ tool;
    object   = Replace[ If[ useTitle, tool[ "Title" ], toolObject[ name, group, tool, turn ] ], Except[ _String ] -> "" ];
    <|
        "Group"    -> group,
        "Verb"     -> toolVerb[ group, object ],
        "Object"   -> object,
        "UseTitle" -> useTitle
    |>
];

toolVerbObject // endDefinition;


(* "search for `x`", but "search" when there is no object ("Stopped: search" rather than "Stopped: search for"): *)
toolVerb // beginDefinition;
toolVerb[ group_String, "" ] /; KeyExistsQ[ $acpStrings, "Tool" <> group <> "VerbNoObject" ] := acpLabel[ "Tool" <> group <> "VerbNoObject" ];
toolVerb[ group_String, _ ] := acpLabel[ "Tool" <> group <> "Verb" ];
toolVerb // endDefinition;


descriptiveTitleQ // beginDefinition;
descriptiveTitleQ[ tool_Association ] := StringQ @ tool[ "Title" ] && ! bareTitleQ[ tool[ "Title" ], tool ];
descriptiveTitleQ // endDefinition;


toolObject // beginDefinition;

toolObject[ _, "Read"|"List"|"Edit"|"Write"|"Delete"|"Move", tool_, turn_ ] :=
    Replace[ toolPath @ tool, { p_String :> displayPath[ p, turn ], _ :> fallbackObject @ tool } ];

toolObject[ _, "Shell", tool_, _ ] :=
    Replace[ toolCommand @ tool, { c_String :> codeQuote @ c, _ :> "" } ];

toolObject[ _, "Search", tool_, _ ] := Replace[
    rawInputValue[ tool, { "pattern", "query", "regex" } ],
    { p_String :> codeQuote @ p, _ :> fallbackObject @ tool }
];

toolObject[ _, "CodeSearch"|"WebSearch"|"Models", tool_, _ ] :=
    Replace[ rawInputValue[ tool, { "query", "search" } ], { q_String :> quoted @ q, _ :> fallbackObject @ tool } ];

toolObject[ _, "WebFetch", tool_, _ ] := Replace[ rawInputValue[ tool, { "url" } ], { u_String :> shorten[ u, $maxTitleObjectLength ], _ :> fallbackObject @ tool } ];
toolObject[ _, "Execute", tool_, _ ] := StringRiffle[ acpExecuteToolNames @ tool, ", " ];

toolObject[ _, "Subagent", tool_, _ ] := Replace[
    rawInputValue[ tool, { "description", "title" } ],
    { d_String :> shorten[ d, $maxTitleObjectLength ], _ :> fallbackObject @ tool }
];

(* OpenCode 2.x sends { "id" }, 1.x sent { "name" }; the completed call's metadata has the skill's display name: *)
toolObject[ _, "Skill", tool_, _ ] := FirstCase[
    {
        rawInputValue[ tool, { "name", "id", "skill" } ],
        Replace[ tool[ "RawOutput" ], { KeyValuePattern[ "metadata" -> KeyValuePattern[ "name" -> n_String ] ] :> n, _ -> None } ],
        fallbackObject @ tool
    },
    s_String /; StringTrim @ s =!= "" :> shorten[ s, $maxTitleObjectLength ],
    ""
];

toolObject[ _, "Question", tool_, _ ] := questionObject @ tool;
toolObject[ _, "LSP", tool_, turn_ ] := lspObject[ tool, turn ];
toolObject[ _, "Invalid", tool_, _ ] := Replace[ rawInputValue[ tool, { "tool" } ], { t_String :> codeQuote @ t, _ :> "" } ];
toolObject[ _, "Todo"|"TodoRead", _, _ ] := acpLabel[ "ToolTodoObject" ];
toolObject[ _, "Think", tool_, _ ] := fallbackObject @ tool;
toolObject[ _, "Generic", tool_, _ ] := Replace[ tool[ "RawName" ], { n_String :> mcpDisplayName @ n, _ :> fallbackObject @ tool } ];
toolObject[ ___ ] := "";

toolObject // endDefinition;


(* A descriptive title from the agent (never the bare tool name, which would give titles like "Used skill skill"): *)
fallbackObject // beginDefinition;
fallbackObject[ tool_Association ] := Which[
    StringQ @ tool[ "Title" ] && ! bareTitleQ[ tool[ "Title" ], tool ],
        shorten[ tool[ "Title" ], $maxTitleObjectLength ],
    MatchQ[ tool[ "Permission" ], KeyValuePattern[ "Title" -> t_String /; ! bareTitleQ[ t, tool ] ] ],
        shorten[ tool[ "Permission", "Title" ], $maxTitleObjectLength ],
    True,
        ""
];
fallbackObject // endDefinition;


quoted // beginDefinition;
quoted[ s_String ] := "\"" <> shorten[ firstLine @ s, $maxTitleObjectLength ] <> "\"";
quoted // endDefinition;


(* OpenCode's question tool: { "questions" -> { <| "header", "question", "options" |>... } } *)
questionObject // beginDefinition;

questionObject[ tool_Association ] := Module[ { questions, first, text },
    questions = Replace[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], "questions", { } ], Except[ _List ] -> { } ];
    first     = Replace[ First[ questions, None ], Except[ _Association ] -> <| |> ];
    text      = SelectFirst[ Lookup[ first, { "question", "header" }, None ], StringQ[ # ] && StringTrim[ # ] =!= "" &, None ];
    Which[
        ! StringQ @ text, fallbackObject @ tool,
        Length @ questions > 1, acpLabel[ "ToolQuestionMore", <| "question" -> quoted @ text, "n" -> Length @ questions - 1 |> ],
        True, quoted @ text
    ]
];

questionObject // endDefinition;


(* LSP tool: { "operation", "filePath", "line", "character" } -> "`goToDefinition` in src/a.ts" *)
lspObject // beginDefinition;

lspObject[ tool_Association, turn_ ] := Module[ { operation, file },
    operation = rawInputValue[ tool, { "operation" } ];
    file      = Replace[ rawInputPath @ tool[ "RawInput" ], p_String :> displayPath[ p, turn ] ];
    Which[
        StringQ @ operation && StringQ @ file, acpLabel[ "ToolLSPObject", <| "operation" -> codeQuote @ operation, "file" -> file |> ],
        StringQ @ operation, codeQuote @ operation,
        StringQ @ file, file,
        True, fallbackObject @ tool
    ]
];

lspObject // endDefinition;


toolPath // beginDefinition;
toolPath[ tool_Association ] := FirstCase[
    {
        rawInputPath @ tool[ "RawInput" ],
        Replace[ tool[ "Permission" ], { KeyValuePattern[ "Title" -> t_String ] /; StringStartsQ[ t, "/" ] :> t, _ -> None } ],
        Replace[ tool[ "Locations" ], { { KeyValuePattern[ "path" -> p_String ], ___ } :> p, _ -> None } ]
    },
    _String? (StringLength[ # ] > 0 &),
    None
];
toolPath // endDefinition;


toolCommand // beginDefinition;
toolCommand[ tool_Association ] := Which[
    StringQ @ rawInputValue[ tool, { "command", "cmd" } ], rawInputValue[ tool, { "command", "cmd" } ],
    StringQ @ tool[ "Title" ] && ! bareTitleQ[ tool[ "Title" ], tool ], tool[ "Title" ],
    True, None
];
toolCommand // endDefinition;


rawInputValue // beginDefinition;
rawInputValue[ tool_Association, keys_List ] := If[ AssociationQ @ tool[ "RawInput" ],
    SelectFirst[ Lookup[ tool[ "RawInput" ], keys, None ], StringQ[ # ] && StringLength[ # ] > 0 &, None ],
    None
];
rawInputValue // endDefinition;


(* Paths are shown relative to the project directory when possible: *)
displayPath // beginDefinition;

displayPath[ path_String, turn_ ] := Module[ { root, rel },
    root = Replace[ Lookup[ Replace[ turn, Except[ _Association ] -> <| |> ], "ProjectDirectory", None ], Except[ _String ] -> None ];
    rel = Which[
        StringQ @ root && path === root, FileNameTake @ path,
        StringQ @ root && StringStartsQ[ path, StringTrim[ root, "/" ~~ EndOfString ] <> "/" ],
            StringDrop[ path, StringLength @ StringTrim[ root, "/" ~~ EndOfString ] + 1 ],
        StringStartsQ[ path, "/" ], FileNameTake @ path,
        True, path
    ];
    shorten[ If[ rel === "", path, rel ], $maxTitleObjectLength ]
];

displayPath // endDefinition;


codeQuote // beginDefinition;
codeQuote[ s_String ] := "`" <> StringReplace[ shorten[ firstLine @ s, $maxTitleObjectLength ], "`" -> "'" ] <> "`";
codeQuote // endDefinition;


firstLine // beginDefinition;
firstLine[ s_String ] := With[ { lines = StringSplit[ StringTrim @ s, "\n" ] }, If[ Length @ lines > 1, First @ lines <> " \[Ellipsis]", StringTrim @ s ] ];
firstLine // endDefinition;


shorten // beginDefinition;
shorten[ s_String, n_Integer ] := If[ StringLength @ s > n, StringTake[ s, n - 1 ] <> "\[Ellipsis]", s ];
shorten // endDefinition;


permissionObject // beginDefinition;
permissionObject[ perm_Association, _ ] := Module[ { params, toolCall, path },
    params   = Replace[ Lookup[ perm, "Params", <| |> ], Except[ _Association ] -> <| |> ];
    toolCall = Replace[ Lookup[ params, "toolCall", <| |> ], Except[ _Association ] -> <| |> ];
    path     = FirstCase[
        {
            Replace[ toolCall[ "locations" ], { { KeyValuePattern[ "path" -> p_String ], ___ } :> p, _ -> None } ],
            rawInputPath @ toolCall[ "rawInput" ],
            Replace[ toolCall[ "title" ], Except[ _String ] -> None ],
            Replace[ Lookup[ perm, "Title", None ], Except[ _String ] -> None ]
        },
        _String,
        ""
    ];
    shorten[ path, $maxTitleObjectLength ]
];
permissionObject // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*MCP tools (OpenCode code mode)*)

(* OpenCode runs MCP tools through its "execute" tool (JavaScript calling tools.<Server>.<Tool>(...)). Returns the
   display names of the MCP tools used, from rawOutput.metadata.toolCalls or, while running, from the script. *)
acpExecuteToolNames // beginDefinition;

acpExecuteToolNames[ tool_Association ] := DeleteDuplicates[ mcpDisplayName /@ acpExecuteToolCalls[ tool ][[ All, "Tool" ]] ];

acpExecuteToolNames // endDefinition;


(* Returns { <| "Tool" -> "Server.Tool", "Input" -> _Association|None, "Code" -> _String|None |>... } *)
acpExecuteToolCalls // beginDefinition;

acpExecuteToolCalls[ tool_Association ] := Module[ { meta, code },
    meta = Replace[ tool[ "RawOutput" ], { KeyValuePattern[ "metadata" -> KeyValuePattern[ "toolCalls" -> calls_List ] ] :> calls, _ -> None } ];
    If[ ListQ @ meta && meta =!= { },
        Cases[ meta, call: KeyValuePattern[ "tool" -> name_String ] :> executeToolCall[ name, Lookup[ call, "input", None ] ] ],
        code = rawInputValue[ tool, { "code", "script" } ];
        If[ StringQ @ code, parseExecuteScript @ code, { } ]
    ]
];

acpExecuteToolCalls // endDefinition;


executeToolCall // beginDefinition;
executeToolCall[ name_String, input_Association ] := <| "Tool" -> name, "Input" -> input, "Code" -> Replace[ Lookup[ input, "code", None ], Except[ _String ] -> None ] |>;
executeToolCall[ name_String, _ ] := <| "Tool" -> name, "Input" -> None, "Code" -> None |>;
executeToolCall // endDefinition;


parseExecuteScript // beginDefinition;

parseExecuteScript[ code_String ] := StringCases[
    code,
    "tools." ~~ server: (WordCharacter|"_").. ~~ "." ~~ name: (WordCharacter|"_").. ~~ WhitespaceCharacter... ~~ "(" ~~ args: Shortest[ ___ ] ~~ ")" ~~ WhitespaceCharacter... ~~ (")"|";"|","|"\n"|EndOfString) :> <|
        "Tool"  -> server <> "." <> name,
        "Input" -> None,
        "Code"  -> scriptCodeArgument @ args
    |>
];

parseExecuteScript // endDefinition;


(* Extracts the `code` argument of an MCP tool call from the JavaScript source: *)
scriptCodeArgument // beginDefinition;

scriptCodeArgument[ args_String ] := Module[ { literal },
    literal = StringCases[
        args,
        {
            "code" ~~ WhitespaceCharacter... ~~ ":" ~~ WhitespaceCharacter... ~~ s: ("\"" ~~ Shortest[ ___ ] ~~ Except[ "\\" ] ~~ "\"") :> jsStringValue @ s,
            "code" ~~ WhitespaceCharacter... ~~ ":" ~~ WhitespaceCharacter... ~~ "`" ~~ s: Shortest[ ___ ] ~~ "`" :> s,
            "code" ~~ WhitespaceCharacter... ~~ ":" ~~ WhitespaceCharacter... ~~ "'" ~~ s: Shortest[ ___ ] ~~ Except[ "\\" ] ~~ "'" :> StringReplace[ s, { "\\'" -> "'", "\\n" -> "\n", "\\\\" -> "\\" } ]
        },
        1
    ];
    Replace[ literal, { { s_String } :> s, _ -> None } ]
];

scriptCodeArgument // endDefinition;


jsStringValue // beginDefinition;
jsStringValue[ s_String ] := Replace[ Quiet @ Developer`ReadRawJSONString @ s, Except[ _String ] :> StringTrim[ s, "\"" ] ];
jsStringValue // endDefinition;


mcpDisplayName // beginDefinition;

mcpDisplayName[ name_String ] := Module[ { parts, server, tool },
    parts  = StringSplit[ name, "." | ("_"..), 2 ];
    { server, tool } = If[ Length @ parts === 2 && KeyExistsQ[ $mcpToolDisplayNames, Last @ parts ], parts, { None, name } ];
    Which[
        KeyExistsQ[ $mcpToolDisplayNames, tool ], $mcpToolDisplayNames[ tool ],
        StringContainsQ[ name, "." ], StringReplace[ name, "." -> ": " ],
        True, name
    ]
];

mcpDisplayName // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpToolSummary*)

(* One-line result summary for a tool card header ("" when there is nothing useful to say):
   "42 lines", "exit 1", "+6 -2", "3 files", "2 calls", "No files found". *)
acpToolSummary // beginDefinition;

acpToolSummary[ tool: KeyValuePattern[ "Type" -> "Tool" ] ] := Module[ { group },
    group = toolVerbObject[ tool, <| |> ][ "Group" ];
    Which[
        tool[ "ClientOutcome" ] =!= None, "",
        MatchQ[ group, "Edit"|"Write" ] && tool[ "Diffs" ] =!= { }, diffSummary @ tool[ "Diffs" ],
        tool[ "Status" ] =!= "completed", "",
        group === "Shell", shellSummary @ tool,
        MatchQ[ group, "Read"|"List" ], readSummary @ tool,
        group === "Search", searchSummary @ tool,
        group === "Execute", countLabel[ Length @ acpExecuteToolCalls @ tool, "SummaryCall", "SummaryCalls" ],
        group === "Todo", todoSummary @ tool,
        True, ""
    ]
];

acpToolSummary[ _ ] := "";

acpToolSummary // endDefinition;


(* todowrite: { "todos" -> { <| "content", "status" |>... } } -> "2 of 5 done" *)
todoSummary // beginDefinition;

todoSummary[ tool_Association ] := Module[ { todos },
    todos = Cases[ Lookup[ Replace[ tool[ "RawInput" ], Except[ _Association ] -> <| |> ], "todos", { } ], _Association ];
    If[ todos === { },
        "",
        acpLabel[ "SummaryTodos", <| "done" -> Count[ todos, KeyValuePattern[ "status" -> "completed" ] ], "total" -> Length @ todos |> ]
    ]
];

todoSummary // endDefinition;


countLabel // beginDefinition;
countLabel[ 0, _, _ ] := "";
countLabel[ 1, one_String, _ ] := acpLabel @ one;
countLabel[ n_Integer, _, many_String ] := acpLabel[ many, <| "n" -> n |> ];
countLabel // endDefinition;


shellSummary // beginDefinition;

shellSummary[ tool_Association ] := Module[ { exit, lines },
    exit = tool[ "ExitCode" ];
    If[ IntegerQ @ exit && exit =!= 0,
        acpLabel[ "SummaryExit", <| "code" -> exit |> ],
        lines = outputLineCount @ tool;
        If[ lines === 0, acpLabel[ "SummaryNoOutput" ], countLabel[ lines, "SummaryLine", "SummaryLines" ] ]
    ]
];

shellSummary // endDefinition;


readSummary // beginDefinition;

readSummary[ tool_Association ] := Module[ { text, range },
    text = StringRiffle[ toolOutputTexts @ tool, "\n" ];
    Which[
        StringContainsQ[ text, "entries " ~~ DigitCharacter.. ~~ "-" ~~ DigitCharacter.. ],
            range = First @ StringCases[ text, "entries " ~~ a: DigitCharacter.. ~~ "-" ~~ b: DigitCharacter.. :> ToExpression[ b ] - ToExpression[ a ] + 1, 1 ];
            countLabel[ range, "SummaryEntry", "SummaryEntries" ],
        StringContainsQ[ text, ", 0 entries" ],
            acpLabel[ "SummaryEntries", <| "n" -> 0 |> ],
        StringContainsQ[ text, "lines " ~~ DigitCharacter.. ~~ "-" ~~ DigitCharacter.. ],
            range = First @ StringCases[ text, "lines " ~~ a: DigitCharacter.. ~~ "-" ~~ b: DigitCharacter.. :> ToExpression[ b ] - ToExpression[ a ] + 1, 1 ];
            countLabel[ range, "SummaryLine", "SummaryLines" ],
        True,
            countLabel[ outputLineCount @ tool, "SummaryLine", "SummaryLines" ]
    ]
];

readSummary // endDefinition;


searchSummary // beginDefinition;

searchSummary[ tool_Association ] := Module[ { text, count },
    text  = StringRiffle[ toolOutputTexts @ tool, "\n" ];
    count = Replace[ tool[ "RawOutput" ], { KeyValuePattern[ "metadata" -> KeyValuePattern[ "count" -> n_Integer ] ] :> n, _ -> None } ];
    Which[
        StringContainsQ[ text, "No files found" | "No matches found", IgnoreCase -> True ] || count === 0,
            acpLabel[ "SummaryNoFiles" ],
        IntegerQ @ count && tool[ "Name" ] === "grep",
            countLabel[ count, "SummaryMatch", "SummaryMatches" ],
        IntegerQ @ count,
            countLabel[ count, "SummaryFile", "SummaryFiles" ],
        True,
            countLabel[ Length @ Select[ StringSplit[ text, "\n" ], StringTrim[ # ] =!= "" & ], "SummaryFile", "SummaryFiles" ]
    ]
];

searchSummary // endDefinition;


diffSummary // beginDefinition;

diffSummary[ diffs_List ] := Module[ { stats, a, d },
    stats = acpDiffStats /@ diffs;
    a = Total @ stats[[ All, 1 ]];
    d = Total @ stats[[ All, 2 ]];
    Which[
        a === 0 && d === 0, "",
        d === 0, acpLabel[ "SummaryAdded", <| "a" -> a |> ],
        True, acpLabel[ "SummaryDiff", <| "a" -> a, "d" -> d |> ]
    ]
];

diffSummary // endDefinition;


outputLineCount // beginDefinition;
outputLineCount[ tool_Association ] := Length @ StringSplit[ StringTrim[ StringRiffle[ acpStripToolOutput /@ toolOutputTexts @ tool, "\n" ], "\n".. ], "\n" ];
outputLineCount // endDefinition;


(* Text items of the tool's (latest) content, without OpenCode's "Exited with code n" note: *)
toolOutputTexts // beginDefinition;
toolOutputTexts[ tool_Association ] := Select[
    Cases[ tool[ "Content" ], KeyValuePattern @ { "type" -> "content", "content" -> KeyValuePattern @ { "type" -> "text", "text" -> t_String } } :> t ],
    ! StringMatchQ[ StringTrim @ #, "Exited with code " ~~ DigitCharacter.. ] &
];
toolOutputTexts // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsubsection::Closed:: *)
(*acpDiffStats*)

(* { additions, deletions } for a normalized diff item: *)
acpDiffStats // beginDefinition;

acpDiffStats[ KeyValuePattern @ { "Patch" -> patch_String } ] := {
    Count[ StringSplit[ patch, "\n" ], l_ /; StringStartsQ[ l, "+" ] && ! StringStartsQ[ l, "+++" ] ],
    Count[ StringSplit[ patch, "\n" ], l_ /; StringStartsQ[ l, "-" ] && ! StringStartsQ[ l, "---" ] ]
};

acpDiffStats[ KeyValuePattern @ { "OldText" -> old_, "NewText" -> new_ } ] := Module[ { ops },
    ops = acpLineDiff[ Replace[ old, Except[ _String ] -> "" ], Replace[ new, Except[ _String ] -> "" ] ];
    { Count[ ops, { "+", _ } ], Count[ ops, { "-", _ } ] }
];

acpDiffStats[ _ ] := { 0, 0 };

acpDiffStats // endDefinition;


(* Line diff: list of { op, line } with op "=", "-" or "+": *)
acpLineDiff // beginDefinition;

acpLineDiff[ old_String, new_String ] := Module[ { a, b },
    a = splitLines @ old;
    b = splitLines @ new;
    Which[
        a === b, { "=", # } & /@ a,
        a === { }, { "+", # } & /@ b,
        b === { }, { "-", # } & /@ a,
        Length @ a * Length @ b > 4*^6, Join[ { "-", # } & /@ a, { "+", # } & /@ b ],
        True, Flatten[ alignmentOps /@ SequenceAlignment[ a, b ], 1 ]
    ]
];

acpLineDiff // endDefinition;


splitLines // beginDefinition;
splitLines[ "" ] := { };
splitLines[ s_String ] := StringSplit[ StringDelete[ s, "\n" ~~ EndOfString ], "\n", All ];
splitLines // endDefinition;


alignmentOps // beginDefinition;
alignmentOps[ { removed_List, added_List } ] := Join[ { "-", # } & /@ removed, { "+", # } & /@ added ];
alignmentOps[ common_List ] := { "=", # } & /@ common;
alignmentOps // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Text Processing*)

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpPreprocessAnswer*)

(* Markdown fixes applied to agent message text before Chatbook's formatter sees it (live and final views). Lines inside
   fenced code blocks are left alone.
     * GitHub task-list items: "- [ ] step" -> "- \:2610 step", "- [x] step" -> "- \:2611 step" (ballot boxes).
     * Bold (or bold italic) spans containing inline code, which Chatbook's formatter does not support (it shows the
       asterisks): the markers are moved inside, around the text pieces between the code spans, and dropped for pieces
       without letters or digits:
         "**`Prime[Range[10]]`:**"     -> "`Prime[Range[10]]`:"
         "**`2+2` \[RightArrow] `4`**"            -> "`2+2` \[RightArrow] `4`"
         "**Result of `f` is `x`**"    -> "**Result of** `f` **is** `x`" *)
acpPreprocessAnswer // beginDefinition;

acpPreprocessAnswer[ text_String ] /; StringFreeQ[ text, "[" | "**" ] := text;

acpPreprocessAnswer[ text_String ] := StringRiffle[ preprocessLines @ StringSplit[ text, "\n", All ], "\n" ];

acpPreprocessAnswer[ other_ ] := other;

acpPreprocessAnswer // endDefinition;


preprocessLines // beginDefinition;

preprocessLines[ lines_List ] := Module[ { fence = None },
    Map[
        Function[ line,
            Which[
                (* opening or closing code fence (but not "```code```" on one line, which is inline code): *)
                fenceLineQ[ line, fence ],
                    fence = If[ fence === None, StringTake[ StringTrim[ line, StartOfString ~~ (" "|"\t").. ], 3 ], None ];
                    line,
                fence =!= None,
                    line,
                True,
                    preprocessLine @ line
            ]
        ],
        lines
    ]
];

preprocessLines // endDefinition;


fenceLineQ // beginDefinition;

fenceLineQ[ line_String, None ] := With[ { trimmed = StringTrim[ line, StartOfString ~~ (" "|"\t").. ] },
    StringStartsQ[ trimmed, "```" | "~~~" ] && StringFreeQ[ StringDrop[ trimmed, 3 ], StringTake[ trimmed, 3 ] ]
];

fenceLineQ[ line_String, fence_String ] := StringStartsQ[ StringTrim[ line, StartOfString ~~ (" "|"\t").. ], fence ];

fenceLineQ // endDefinition;


preprocessLine // beginDefinition;

preprocessLine[ line_String ] := rewriteBoldCode @ StringReplace[
    line,
    StartOfString ~~ ws: (" "|"\t")... ~~ b: ("-"|"*"|"+") ~~ (" "|"\t").. ~~ "[" ~~ c: (" "|"x"|"X") ~~ "]" ~~ e: (" "|"\t"|EndOfString) :>
        ws <> b <> " " <> If[ c === " ", "\:2610", "\:2611" ] <> e
];

preprocessLine // endDefinition;


(* Like Chatbook's formatter, which takes inline code spans out first and then pairs ** markers in the remaining text,
   the line is split into code spans, ** / *** markers and text, and markers are paired from the left. A marker opens a
   span if it is followed by something other than whitespace and closes the open span (same marker) if it follows
   something other than whitespace. Only spans that contain code are rewritten. *)
rewriteBoldCode // beginDefinition;

rewriteBoldCode[ line_String ] /; StringFreeQ[ line, "**" ] || StringFreeQ[ line, "`" ] := line;

rewriteBoldCode[ line_String ] := Module[ { tokens, out = { }, buffer = { }, marker = None, token, n },
    tokens = Replace[
        StringSplit[
            line,
            {
                c: ("`" ~~ Except[ "`" ].. ~~ "`") :> { "Code", c },
                d: ("***" | "**") :> { "Marker", d }
            }
        ],
        s_String :> { "Text", s },
        { 1 }
    ];
    n = Length @ tokens;
    Do[
        token = tokens[[ i ]];
        Which[
            marker === None && token[[ 1 ]] === "Marker" && i < n && openerFollowerQ @ tokens[[ i + 1 ]],
                marker = token[[ 2 ]];
                buffer = { },
            marker === None,
                AppendTo[ out, token[[ 2 ]] ],
            token === { "Marker", marker } && buffer =!= { } && closerPredecessorQ @ Last @ buffer,
                out = Join[ out, If[ MemberQ[ buffer, { "Code", _ } ], boldCodePieces[ marker, buffer ], Flatten @ { marker, buffer[[ All, 2 ]], marker } ] ];
                marker = None,
            True,
                AppendTo[ buffer, token ]
        ],
        { i, n }
    ];
    If[ marker =!= None, out = Join[ out, { marker }, buffer[[ All, 2 ]] ] ];
    StringJoin @ out
];

rewriteBoldCode // endDefinition;


openerFollowerQ // beginDefinition;
openerFollowerQ[ { "Code", _ } ] := True;
openerFollowerQ[ { "Text", s_String } ] := ! StringStartsQ[ s, WhitespaceCharacter ];
openerFollowerQ[ _ ] := False;
openerFollowerQ // endDefinition;


closerPredecessorQ // beginDefinition;
closerPredecessorQ[ { "Code", _ } ] := True;
closerPredecessorQ[ { "Text", s_String } ] := ! StringEndsQ[ s, WhitespaceCharacter ];
closerPredecessorQ[ _ ] := False;
closerPredecessorQ // endDefinition;


(* Code spans are kept as they are; the text between them is emphasized on its own: *)
boldCodePieces // beginDefinition;

boldCodePieces[ marker_String, tokens_List ] := Flatten @ Replace[
    SplitBy[ tokens, First[ # ] === "Code" & ],
    {
        code: { { "Code", _ }.. } :> code[[ All, 2 ]],
        text_List :> boldPiece[ marker, StringJoin @ text[[ All, 2 ]] ]
    },
    { 1 }
];

boldCodePieces // endDefinition;


(* Whitespace stays outside the markers ("** x **" is not emphasis in markdown): *)
boldPiece // beginDefinition;

boldPiece[ _String, text_String ] /; StringFreeQ[ text, LetterCharacter | DigitCharacter ] := text;

boldPiece[ marker_String, text_String ] := StringJoin[
    First[ StringCases[ text, StartOfString ~~ w: WhitespaceCharacter.. :> w, 1 ], "" ],
    marker,
    StringTrim @ text,
    marker,
    First[ StringCases[ text, w: WhitespaceCharacter.. ~~ EndOfString :> w, 1 ], "" ]
];

boldPiece // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpStripToolOutput*)

(* Removes <system-reminder> blocks and terminal escape sequences from tool output. *)
acpStripToolOutput // beginDefinition;

acpStripToolOutput[ text_String ] := StringDelete[
    StringReplace[
        StringReplace[ text, "\r\n" -> "\n" ],
        {
            Shortest[ "<system-reminder>" ~~ ___ ~~ "</system-reminder>" ] -> "",
            RegularExpression[ "\\x1b\\][^\\x07\\x1b]*(?:\\x07|\\x1b\\\\)" ] -> "",
            RegularExpression[ "\\x1b\\[[0-9;?]*[ -/]*[@-~]" ] -> "",
            RegularExpression[ "\\x1b[@-Z\\\\-_]" ] -> "",
            "\r" -> ""
        }
    ],
    WhitespaceCharacter.. ~~ EndOfString
];

acpStripToolOutput[ other_ ] := other;

acpStripToolOutput // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Subsection::Closed:: *)
(*acpTurnToMarkdown*)

(* Markdown for the final output cell's "CellToStringData" (copy as text, chat history): the visible tail and answer,
   followed by the status line for turns that did not end normally. *)
acpTurnToMarkdown // beginDefinition;

acpTurnToMarkdown[ turn_Association ] := Module[ { split, entities, tail, answer, status, parts },
    split    = acpTurnSplit @ turn;
    entities = turn[ "Entities" ];
    tail     = StringRiffle[ DeleteCases[ itemMarkdown[ entities[ # ], turn ] & /@ split[ "Tail" ], "" ], "\n\n" ];
    answer   = StringRiffle[ DeleteCases[ StringTrim[ entities[ #, "Text" ] ] & /@ split[ "Answer" ], "" ], "\n\n" ];
    status   = acpTurnStatusLine @ turn;
    parts    = DeleteCases[ { tail, answer, If[ StringQ @ status, "_" <> status <> "_", "" ] }, "" ];
    If[ parts === { } && acpTurnEndedQ @ turn, acpLabel[ "DoneNoReply" ], StringRiffle[ parts, "\n\n" ] ]
];

acpTurnToMarkdown // endDefinition;


itemMarkdown // beginDefinition;
itemMarkdown[ KeyValuePattern @ { "Type" -> "Message", "Text" -> text_String }, _ ] := StringTrim @ text;
itemMarkdown[ tool: KeyValuePattern[ "Type" -> "Tool"|"Permission" ], turn_ ] := "_" <> acpToolTitle[ tool, Automatic, turn ] <> "_";
itemMarkdown[ _, _ ] := "";
itemMarkdown // endDefinition;

(* ::**************************************************************************************************************:: *)
(* ::Section::Closed:: *)
(*Package Footer*)
addToMXInitialization[
    Null
];

End[ ];
EndPackage[ ];
