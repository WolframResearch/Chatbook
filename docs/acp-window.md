# ACP Window (Agent Chats)

The ACP window is a chat window that looks like the notebook assistance window, but talks to an external coding agent (currently [OpenCode](https://opencode.ai)) through the [Agent Client Protocol](https://agentclientprotocol.com) (ACP) instead of using Chatbook's own LLM pipeline. The agent runs as a child process (`opencode acp`), works in a project folder, and asks the user for permission before editing files or running shell commands. The protocol connection is provided by the ACPLink paclet.

Source: `Source/Chatbook/ACP/`. Tests: `Tests/ACPState.wlt`, `Tests/ACPTranscript.wlt`, `Tests/ACPRendering.wlt`, `Tests/ACPWindow.wlt`, `Tests/ACPConnection.wlt`.

## Opening the window

```wl
ShowNotebookAssistance[ "ACPWindow" ]                    (* attached to the current user notebook, if any *)
ShowNotebookAssistance[ nbo, "ACPWindow" ]               (* nbo: NotebookObject or None *)
ShowNotebookAssistance[ cell, "ACPWindow" ]              (* the cell's notebook *)

ShowNotebookAssistance[
    "ACPWindow",
    "Input"                -> "Explain the build script",   (* put text in the input field *)
    "EvaluateInput"        -> True,                         (* and send it (queued until connected) *)
    "NewChat"              -> True,                         (* close the existing ACP window and start over *)
    "ChatNotebookSettings" -> <| "ProjectDirectory" -> "~/src/myproject" |>
]
```

There is at most one ACP window (found by `findCurrentWorkspaceChat["ACP"]`). Calling `ShowNotebookAssistance` again reuses it; an explicit `"ProjectDirectory"` that differs from the window's directory switches the window to it (starting a new session), unless a turn is running. Explicit `"ACPAgent"`, `"ACPAgentExecutable"` and `"ACPModel"` settings are applied to the open window too: a new agent or executable reconnects (after the running turn, if there is one), a new model is selected in the current session, and a window in `"Error"` (e.g. OpenCode was not found) reconnects.

### Settings

`"ChatNotebookSettings"` keys understood by the ACP window (validated by `validateACPWindowSettings` in `ChatModes/ShowNotebookAssistance.wl`; invalid values give `Chatbook::InvalidACPWindowSettings`):

| Key | Values | Default |
|---|---|---|
| `"ProjectDirectory"` | directory (string or `File`), `None`, `Automatic` | `Automatic`: the last project folder used, else the source notebook's folder, else none (the window asks for one) |
| `"ACPAgent"` | `"OpenCode"`, `Automatic` | `"OpenCode"` |
| `"ACPAgentExecutable"` | path to the `opencode` executable, `Automatic` | `Automatic`: search `PATH`, then `~/.opencode/bin`, `~/.local/bin`, `~/.bun/bin`, `~/.npm-global/bin`, then `/opt/homebrew/bin` and `/usr/local/bin` (a front end started from the macOS Dock gives the kernel a minimal `PATH`) |
| `"ACPModel"` | model value such as `"openai/gpt-6.1-sol"`, `Automatic` | the last model chosen for this agent, else `llmkit/gpt-5.4` (if offered), else `openai/gpt-6.1-sol` (if offered), else the agent's default |

User choices are persisted in `CurrentValue[$FrontEnd, {PrivateFrontEndOptions, "InterfaceSettings", "Chatbook", "ACP", ...}]`: `"LastProjectDirectory"`, `{"LastModel", agent}`, `{"LastEffort", agent}` and `{"RecentModels", agent}` (the mode is not persisted).

The window's notebook-level state lives in its `TaggingRules`: `"ChatNotebookSettings"` (with `"AppName" -> "ACP"`, `"ACPWindow" -> True`, `"WorkspaceChat" -> True`) and `"ACP"` (`"ProjectDirectory"`, `"Agent"`, `"Settings"` (the explicit `"ACPAgent"`, `"ACPAgentExecutable"` and `"ACPModel"` settings, so a window rebuilt after a kernel restart connects the same way), `"Input"`, `"Busy"`, `"KernelSessionID"`, `"ResumableSessionID"`).

When OpenCode is not found, the error's "Locate OpenCode..." button opens a file chooser (run by the front end); the chosen file becomes the window's `"ACPAgentExecutable"` setting and the window reconnects.

## Files

| File | Purpose |
|---|---|
| `ACP/ACP.wl` | Package header; loads the files below (listed in `$ChatbookContexts` via `Main.wl`) |
| `ACP/Common.wl` | Declarations of the ACP-internal shared symbols, one section per file. Symbols used outside `ACP/` (e.g. `showACPWindow`, `makeACPChatDockedCell`) are declared in `CommonSymbols.wl` |
| `ACP/State.wl` | Window and turn stores, change symbols and the pump task (scheduled evaluations, publication, housekeeping), opener state, `acpIsolated`, `acpSchedule`, ACPLink loading, front end flags, kernel-restart detection |
| `ACP/Transcript.wl` | The pure turn model: the reducer for ACP session updates and permission events, the final-answer split, tool titles and summaries, activity/duration labels, markdown export and answer preprocessing, and the English strings (`$acpStrings`, `acpLabel`) |
| `ACP/Rendering.wl` | Boxes: the live view, entity views and tool cards, diff view, the final output cell, the permission panel, the toolbar status view, the usage meter and error views |
| `ACP/Agents.wl` | The agent registry, finding the OpenCode executable, the OpenCode config JSON and environment, the LLMKit key lookup, model preference, billing labels, persisted settings, `$acpConnectionStrings` |
| `ACP/Connection.wl` | Connection and session lifecycle on top of ACPLink: connect/initialize/resume/new session, prompts, permissions, Stop, config options, directory changes, disconnect, error mapping (`acpErrorInfo`), housekeeping and the orphan sweeper |
| `ACP/UI.wl` | Window creation and reuse, the toolbar (model/mode/effort menus, project folder row, status row), the attached input cell, send/stop/new chat, writing the user/active/final cells, `acpFinalizeTurn`, kernel-restart recovery, `$acpUIStrings` |

Outside `ACP/`: `ChatModes/ShowNotebookAssistance.wl` (the `"ACPWindow"` entry points), `ChatModes/UI.wl` (the input cell is chosen by `AppName`; Regenerate and feedback buttons are hidden for ACP cells), `ChatModes/Evaluate.wl` (`writeWorkspaceChatInputCell` and `workspaceChatInputCellExpr`, shared with the notebook assistance window; queued prompts are written with an addressed write after the last cell instead, since they are sent from scheduled tasks while the user may be typing or selecting text), `Formatting.wl` (code blocks in ACP cells get Copy and, for Wolfram Language, Insert, but no Evaluate), `Actions.wl` (`ChatbookAction["ACP", ...]` and `"MakeACPChatDockedCell"`).

Stylesheet: `DarkModeSupport/StyleSheets/Wolfram/ACPChat.nb`, built from `Developer/Resources/ACPStyles.wl` with `BuildStylesheets["ACPChat"]` (`Developer/StylesheetBuilder.wl`). It inherits `Wolfram/WorkspaceChat.nb` and replaces the docked cells (progress stripe and the toolbar, which is a `DynamicBox` calling `ChatbookAction["MakeACPChatDockedCell"]`), the notebook settings, and the `"WindowClose"` event action. ACP cells use the standard `UserMessageBox`, `AssistantMessageBox[Active]` and `ThoughtsOpener` templates, so copied or saved cells render anywhere.

## State model

All agent traffic is handled by ACPLink's reader task, which calls Chatbook's handlers asynchronously; nothing waits for the agent. Kernel state is a cache that can be rebuilt from the window's `TaggingRules`.

**Window records** (`$acpWindows[nbo]`): `"Status"` (`"NoDirectory"`, `"Connecting"`, `"Ready"`, `"Running"`, `"Disconnected"`, `"Error"`), `"Error"`, `"ProjectDirectory"`, `"Connection"`, `"SessionID"`, `"ResumableSessionID"`, `"AgentInfo"`, `"ConfigOptions"` (the raw ACP config options: model, mode, effort), `"PendingConfig"`, `"PendingPermissions"` (by request ID, in arrival order), `"Requests"` (continuations of outstanding client requests, keyed by string IDs `"cb-..."`), `"CurrentTurn"`, `"Usage"`, `"Notice"`, `"QueuedPrompt"`, `"QueuedTurn"`, `"Settings"`, and more (see the comments in `UI.wl` and `Connection.wl`).

**Turn records** (`$acpTurns[turnID]`, created by `acpNewTurn`): the prompt, cells, timing, `"StopReason"`, `"ClientCancel"` (`"Stop"`/`"Reject"`), `"Error"`, and the transcript as `"Order"` (a list of entity keys) plus `"Entities"`. Entity keys are lists: `{"Message", id}`, `{"Thought", id}`, `{"Tool", toolCallId}`, `{"Permission", requestID}`, `{"Notice", n}`, `{"Plan"}`. Tool entities keep the canonical tool name (`bash` becomes `"shell"`, `task` becomes `"subagent"`, `apply_patch` becomes `"patch"`), status, `"ClientOutcome"` (`"Declined"`/`"Stopped"`), raw input/output, accumulated diffs and the permission request.

The reducer functions in `Transcript.wl` (`acpApplyUpdate`, `acpApplyPermissionRequest`, `acpApplyPermissionOutcome`, `acpApplyPermissionWithdrawn`, `acpApplyClientCancel`, `acpApplyTurnEnd`, `acpApplyNotice`) are pure: they take a turn and return `<|"Turn" -> new, "Changed" -> {keys...}, "Layout" -> bool|>`, which `acpTurnUpdate` uses to mark the changed views dirty.

`acpTurnSplit[turn]` decides what the final cell shows: the answer is the run of trailing top-level messages after the last non-message entity; everything before it goes into a closed "Worked for ..." opener. If the turn did not end normally (Stop, a declined permission, an error, `max_tokens`, ...) and there is no answer, the last step's tools (from the first one that did not complete normally, or only the last tool if all completed) and the message right before them are shown expanded below the opener, followed by a status line such as "You declined: edit notes.md. Tell OpenCode what to do instead."

**Rendering.** The active output cell has one `Dynamic` that tracks the turn's layout symbol and contains one `Dynamic` per entity, each tracking that entity's change symbol (`acpLayoutSymbol`, `acpEntitySymbol`). Handlers mark symbols dirty; the pump task bumps the dirty ones every 0.2 s while a turn runs, a window connects, or a connection is open. Entity boxes are cached by version; streaming messages only re-format the text after the last blank line. Opener state for live views is kept in `$acpOpen` and toggled by preemptive event handlers. When the turn ends, `acpFinalizeTurn` (UI.wl) replaces the active cell with the static `acpFinalCell`, whose openers are front-end-only `DynamicModule`s, then drops the turn's state: its change symbols (which are removed) and its render caches. Once a turn is claimed for finalization it always ends: rendering failures fall back to simpler cells, and housekeeping finishes a finalization that has not completed after 30 s.

Inline cells inside `ChatOutput` cells must use `boxCell`/`textBoxCell` (`Rendering.wl`): `BoxData` cells need their boxes wrapped in `StyleBox[..., "Text"]`, otherwise strings appear in the code font, and `TextData` cells need the `"Text"` style. `Tests/ACPRendering.wlt` checks this for every fixture.

## Threading rules

These rules apply to all code in `ACP/`:

1. **R1. Nothing blocks.** No ACP code holds an evaluation for the length of a turn. Agent traffic is processed by ACPLink's permanent reader task.
2. **R2. Handlers are interrupts.** Reader handlers only update kernel state and mark views dirty: no front end calls, no `NotebookWrite`, no waiting, no synchronous ACPLink requests (they would deadlock inside the reader's `PreemptProtect`), no dialogs. Strings used in handlers come from `acpConnectionLabel`, which never calls the front end. Front end work is deferred with `acpSchedule`.
3. **R3. Isolation.** Every asynchronous or preemptive entry point (reader handlers, scheduled tasks, `Dynamic` renderers, preemptive buttons and event handlers) runs inside `acpIsolated`, which catches everything, defers aborts, blocks Chatbook's chat globals (so an ACP handler can't disturb a notebook assistance chat it interrupted, and vice versa), and records messages in `$acpDebugLog` instead of printing them. ACP code never calls `withChatState`, `ChatCellEvaluate`, `evaluateWorkspaceChat` or `StopChat`.
4. **R4. Shared state changes only through `acpWindowUpdate` / `acpTurnUpdate`**, which apply a pure function under `PreemptProtect`.
5. **R5. Deferred work goes through one task.** `acpSchedule[eval]` (or `acpSchedule[eval, delay]`) queues `eval` for the pump task, which evaluates everything that is due every 50 ms, in order, each evaluation isolated; the default delay is 50 ms. Never create one-shot `ScheduledTask`s: in the 15.0.1 kernel, several one-shot tasks coming due together (and recurring tasks that remove themselves at a high rate) can deadlock the kernel for good (see ACPLink's UPSTREAM-NOTES.md, "Kernel scheduler deadlocks"), and `{Now}` ones are silently dropped under load. Anything correctness-critical also has a periodic fallback in a housekeeping function (`acpRegisterHousekeeping`), e.g. finalizing a turn that ended more than 1 s ago, or ending a turn whose Stop got no answer within 10 s.
6. **R6. Live views never rebuild stateful widgets**: one `Dynamic` per entity, opener state in kernel state, no scroll panes or `DynamicModule` openers in live views. Window views with buttons or menus (toolbar menus, permission panel, status) only re-render when the part of the window state they show changes (`stableDynamic` in Rendering.wl, `acpWindowDerivedDynamic` in UI.wl).
7. **R7. Throttled publication**: handlers mark dirty; every fourth pump tick (0.2 s), while a turn runs, a window connects, symbols are dirty, or any ACP connection is open, the pump bumps the change symbols and runs the housekeeping functions. Housekeeping must keep running while a connection exists, to detect closed windows and dead or orphaned connections. The pump removes itself after 2 s with nothing queued and no window connected, so windows that are not connected cost nothing; `acpSchedule` and marking symbols dirty start it again. While ACPLink is in use it has its own recurring task (the deferral pump) as well as one read task per connection.
8. **R8. Front-end-side flags**: the input text, the busy flag and the kernel session that owns the window are in the notebook's `TaggingRules`, so they survive kernel quits and re-attaching the input cell. The front end sometimes misses the busy flag's reset at the end of a turn (the Stop button stays); `settleBusyFlag` changes it once more, from `False` to `None`, half a second later. `acpCheckSession` runs on every entry point and, after a kernel restart, replaces orphaned active cells with an "Interrupted" note and rebuilds the toolbar and input field.

Change symbols are created by name (not with `Unique`), and a new window is created invisible and registered before it is shown: the front end does not track symbols created while it evaluates a `DestroyAfterEvaluation` `DynamicBox` (such as the toolbar), so views built from such symbols would never update.

## ACPLink

ACPLink is an optional dependency, loaded on demand by `acpLoadACPLink` (`State.wl`) the first time a window connects:

* `PacletFind["ACPLink"]` is used if the paclet is installed.
* Otherwise, if the environment variable `ACPLINK_DIRECTORY` points to an ACPLink paclet directory (the one containing `PacletInfo.wl`), it is loaded with `PacletDirectoryLoad`. This is the easiest way to develop against an ACPLink working tree: set it in the kernel's environment, or with `SetEnvironment["ACPLINK_DIRECTORY" -> "~/ACPLink/ACPLink"]` (expanded path) before the window connects. `Tests/ACPConnection.wlt` uses `~/ACPLink/ACPLink` if the variable is not set.
* ACPLink must be new enough to support `OpenACPConnection[..., UpdateInterval -> ...]` (the permanent reader task); otherwise the window shows an `"ACPLinkTooOld"` error. A missing paclet gives `"ACPLinkMissing"`.

ACPLink's public symbols are in ``System` ``, so they are only referenced through `acpLink["OpenACPConnection"]` etc., which avoids creating them in kernels (and the MX file) that never open an ACP window.

`Tests/ACPConnection.wlt` runs against a mock agent (`Tests/Data/ACP/MockAgent/mock_acp_agent.py`, needs `python3`) and is skipped when ACPLink or Python is not available.

## OpenCode configuration

OpenCode is started as `opencode acp` in the project folder, with the user's environment (without variables ACPLink cannot pass, such as exported bash functions, which would fail the start with `envval`) plus `OPENCODE_CONFIG_CONTENT`, a JSON config that is merged with the user's own OpenCode configuration (`acpOpenCodeConfigJSON`, `Agents.wl`):

```json
{"$schema": "https://opencode.ai/config.json", "permission": {"edit": "ask", "bash": "ask"}}
```

so file edits and shell commands always ask for permission. `OPENCODE_CONFIG_DIR` is never used: it would replace the user's global configuration (and drop their MCP servers, such as the Wolfram MCP server). If the user has a Wolfram LLMKit subscription (an active Wolfram API key with the `LLMKitAPIs` grant, found or created through the Wolfram cloud while `$CloudConnected`), the config also gets an `llmkit` provider whose key is passed as `LLMKIT_API_KEY` and referenced as `{env:LLMKIT_API_KEY}`; the key is never logged or stored.

Model, mode (build/plan) and reasoning effort are ACP session config options, shown as menus in the toolbar. Models are grouped by provider; each provider submenu is labeled with who pays for its models ("OpenAI (your account)", "Wolfram LLMKit", "OpenCode (free)", ...).

## Permissions

OpenCode sends `session/request_permission` for edits, shell commands and access outside the project. The request is recorded in the window's `"PendingPermissions"` and attached to the matching tool card (which shows an "Awaiting approval" badge). The first pending request is shown in an amber panel above the input field, with the command or diff and the agent's options ("Allow once", "Always allow", "Reject"); "1 of 2" shows when several are queued. The buttons are preemptive and ignore clicks for 0.4 s after the panel appears.

* "Always allow" is remembered by OpenCode for the project (also in future sessions); the text below the buttons (and the button's tooltip) says what is saved. ACP does not send OpenCode's saved patterns, so they are derived the way OpenCode does: for shell commands, one `"<prefix> *"` pattern per subcommand (e.g. `cd build && rm -rf dist` saves `"rm *"`; the prefix length comes from OpenCode's arity table, e.g. `"git status *"`, `"npm run build *"`), skipping directory changes; for access outside the project, the directory (or the repository that contains it); for edits, all edits in the project.
* Reject marks the tool "Declined" (neutral, not an error) and the turn ends with "You declined: ...".
* Stop cancels the prompt and answers all pending requests as cancelled; unfinished tools become "Stopped". A request of the turn that is still pending when the turn is finalized (e.g. one that arrived after Stop, before the agent's response) is answered "cancelled" and removed from the panel.
* A request withdrawn by the agent (`$/cancel_request`) disappears from the panel.
* A request from a background subagent that arrives when no turn is running is cancelled, with a notice.

## Strings

All user-visible text goes through `acpLabel[key]` / `acpLabel[key, <|"slot" -> value|>]` (`Transcript.wl`). With a front end, `acpLabel` uses the text resource `FrontEndResource["ChatbookStrings", "ACP" <> key]` (memoized per session, never throwing); otherwise, or for unknown keys, it uses the English tables `$acpStrings` (`Transcript.wl`), `$acpUIStrings` (`UI.wl`) and `$acpConnectionStrings` (`Agents.wl`). Reader handlers use `acpConnectionLabel`, which only reads `$acpConnectionStrings`.

Every key of the three tables must be in `FrontEnd/TextResources/ChatbookStrings.tr` and in each of the six localized copies as `"ACP" <> key` (English text until localized), and the English resource must equal the table text; the stylesheet's window title is the resource `"ACPWindowTitle"`. `Tests/ACPWindow.wlt` checks this (`TextResources-*` tests). When adding a key, add it to the right table and to all seven `.tr` files.

## Previewing rendering without an agent

`Developer/ACPPreview.wl` replays recorded OpenCode traffic (`Tests/Data/ACP/*.json`) through the real reducer and renderers in a front end, without OpenCode or ACPLink:

```wl
PacletDirectoryLoad[ "path/to/Chatbook" ];
Get[ "Wolfram`Chatbook`" ];
Get[ FileNameJoin @ { "path/to/Chatbook", "Developer", "ACPPreview.wl" } ];

acpPreviewFixtures[ ]                                     (* available fixtures *)
nb = acpPreviewNotebook[ "exp5_C_writes", "Speed" -> 2 ]  (* live view, permission panel, then the final cell *)
acpPreviewStop[ nb ]
acpPreviewFinalNotebook[ "synthetic_cancelled_tools" ]    (* only the final cell *)
acpPreviewReplay[ "exp4b_turn1_reject" ]                  (* the turn record, no front end needed *)
```

The `exp*` fixtures are sanitized recordings (paths replaced by `/project` and `/home/user`, outputs truncated, images replaced). The `synthetic_*` fixtures cover OpenCode tool shapes and edge cases the recordings don't (skill/todo tools, natural-size images, bold text around inline code, a declined edit after several completed tools).

## Debugging

* `Wolfram`Chatbook`ACP`Common`$acpWindows`, `$acpTurns`: the kernel state.
* `Internal`BagPart[ Wolfram`Chatbook`ACP`Common`$acpDebugLog, All ]`: messages and uncaught failures from isolated code (`"Message"`, `"Uncaught"`), unknown session updates, rendering fallbacks (`"FinalCellFailed"`, `"FinalCellFallback"`, `"FinishedFormattingFallback"`), finalizations finished by housekeeping (`"FinalizeTimeout"`). Each `Tests/ACP*.wlt` file ends with a test that fails if anything unexpected was logged as a message or failure while it ran.
* The tests never need a front end; `Tests/ACPWindow.wlt` has a few front-end-only tests that run when the test kernel has one.

## Known limitations

* Only OpenCode is supported as an agent (the registry in `Agents.wl` has room for more).
* The conversation is not forwarded from other notebooks, and notebook context is not attached to prompts.
* There is no "MCP servers starting" indicator in the toolbar: OpenCode often never reports the MCP server's prompts (the listing can time out) even though its tools work. While a turn waits more than 5 s for the first event, the Working header says "Waiting for OpenCode... (MCP servers may still be starting)".
* The model menu uses native `ActionMenu` submenus; long model lists are long menus.
* Localized `.tr` files contain English text for the ACP strings.
* After a kernel restart, the window reconnects and resumes the agent session if the agent supports `session/resume`; turns that were running are shown as interrupted.
* ACPLink keeps the agent's standard output in a file until the connection is closed, so a window that stays connected for a very long time uses more and more disk space until the window is closed or the kernel is restarted (New keeps the connection).
* Saving the window uses Chatbook's Save As (`SaveAsChatNotebook`); ACP cells convert like notebook assistance cells.
* The front end occasionally reports `INTERNAL SELF-TEST ERROR: CellControl|cpp|45` ("overcounted formatting") in the Messages window while a live view updates. In testing (about 30 turns) it appeared in two of three first turns after a kernel restart and once when Stop was pressed while an approval was pending. Isolated experiments (rapidly updated `Dynamic`s with nested inline code cells, watcher `Dynamic`s that bump a sibling's symbol) did not reproduce it.
