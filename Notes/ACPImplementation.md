# ACP window: implementation notes

Notes for future work on the `feature/acp-integration` branch. They record what was learned while adding the MCP
server of the notebook tools (October 2026) that the code and [docs/acp-window.md](../docs/acp-window.md) don't say
or explain. Read docs/acp-window.md first: it is the reference for the design, threading rules R1-R8, settings, the
debug log and the tests. These notes cover the decisions behind it, measured behaviour of the kernel, front end and
OpenCode, and how to test and debug.

## Repositories

| Repository | Branch | What it has |
|---|---|---|
| Chatbook | `feature/acp-integration` | The ACP window (`Source/Chatbook/ACP/`); the notebook tools (`NotebookTools.wl`) and their MCP server (`MCP.wl`) |
| AgentTools | `feature/local-socket-server` | `StartMCPSocketServer` / `MCPSocketServerObject` (`Kernel/Server/Socket.wl`, `HTTP.wl`), see its `docs/socket-server.md` |
| ACPLink | `feature/chatbook-fixes` | The ACP client used by the window. The MCP work only added tests: the mock agent's `mcp_request` step and a mock MCP server (`Tests/MockAgent/`, `Tests/ACP/MockMCP1.wlt`) |

* The work is in these commits:
  * Chatbook 367e1f61: the formatter fixes, see [Fixed bugs that also exist on main](#fixed-bugs-that-also-exist-on-main);
  * Chatbook 3a5f5f87: the MCP server and the notebook tools;
  * AgentTools f7de2ea: `StartMCPSocketServer`;
  * ACPLink f92afca: the mock agent's `mcp_request` step.

  The AgentTools branch has not been pushed yet.
* ACPLink's branch exists only locally: it is never pushed. The user gets it as `~/ACPLink.zip` (the repository
  with `.git`, without `__pycache__`), which is rebuilt after each ACPLink commit. Bugs found in ACPLink are fixed in
  ACPLink on that branch. Don't use or rely on its `research/chatbook-acp-ux` branch.
* Chatbook's tests run their own copy of ACPLink's mock agent (`Tests/Data/ACP/MockAgent/mock_acp_agent.py`, with its
  scenarios). It is identical to ACPLink's `Tests/MockAgent/mock_acp_agent.py`, so a change to the mock agent has to
  be made in both repositories.
* AgentTools has unrelated uncommitted changes under `.claude/skills/`. Leave them out of commits and don't revert them.
* Development checkouts are loaded with environment variables, which the code and the tests read:
  `ACPLINK_DIRECTORY` (the directory with ACPLink's `PacletInfo.wl`, e.g. `~/ACPLink/ACPLink`) and
  `AGENTTOOLS_DIRECTORY` (e.g. `~/AgentTools`). The ACP test files default to those locations when the variables are
  not set.
* **Release dependency.** Neither the installed AgentTools (2.2.0) nor the one that comes with Wolfram 15.0 has
  `StartMCPSocketServer`. Until an AgentTools release has it, ACP windows offer no notebook tools unless
  `AGENTTOOLS_DIRECTORY` is set. Chatbook checks the paclet's `PacletInfo.wl` `"Symbols"` for the function, so a
  release needs nothing else on Chatbook's side.

## Decisions

### The user's decisions

These are binding unless the user says otherwise:

* Tool calls run on the kernel's **main link**: the SocketListen handler only queues the call, `acpSchedule` wakes the
  pump, and the pump fires a hidden notebook's `Method -> "Queued"` button that drains the queue (the technique of
  `Developer/FrontEndServer`). The handler and the pump are preemptive evaluations, which must stay short.
* AgentTools got a **new exported function** (`StartMCPSocketServer`), not an option of `StartMCPServer`. Its
  `"EvaluationFunction"` option is how the caller chooses where calls are evaluated.
* **Tools:** ListNotebooks, ReadNotebook, CreateNotebook, InsertCells, ReplaceCells, DeleteCells. The three edit tools
  need the user's approval through OpenCode's `"ask"` permission rules. There is no tool that evaluates code in the
  user's session.
* **Remote (SSH) windows** get no MCP server (`mcpServers -> {}`): their agent can't reach this computer's 127.0.0.1.
* Real OpenCode sessions in the test project folder (`~/TestProject`) may be used for testing, as long as usage isn't
  extreme.
* The formatter fixes are a commit of their own, to be split into a PR against `main` (see
  [Fixed bugs that also exist on main](#fixed-bugs-that-also-exist-on-main)).

### Design choices made during the work

These can be revisited:

* No approval check on Chatbook's side, and the permission panel's options are unchanged. Approval rests on OpenCode's
  rules (`OPENCODE_CONFIG_CONTENT`).
* `"ACPMCPServer" -> Automatic` offers the server only when Chatbook starts the agent's own program. A command line
  that runs a wrapper (docker, env, ssh, ...) may not pass `OPENCODE_CONFIG_CONTENT` on, so its agent could edit
  notebooks without asking; it gets the server only with `True`.
* **An AgentTools that is already loaded is never reloaded**, with one exception: if it has no `StartMCPSocketServer`
  (it is too old, e.g. the installed 2.2.0 that the front end preloads), and `AGENTTOOLS_DIRECTORY` names an AgentTools
  that has the function and is the one `Needs` would load, that one is loaded with `Get` instead. An AgentTools that
  already has the function is kept for the kernel session, even when the checkout is newer or was edited. Restart
  the kernel to pick up AgentTools edits.

## Measured behaviour (Wolfram 15.0 front end, 15.0.1 kernel)

Measured with experiments; the design depends on them.

* **Preemptive evaluations.** SocketListen handlers and ScheduledTask bodies (the pump) are preemptive: a 5 s job in
  either gave 0 `Dynamic` updates. A queued button's evaluation runs on the main link, and Dynamics keep updating.
  The front end merges the triggers of a button while a run is pending, and drops the pending run when the evaluation
  ahead of it is aborted, so a watchdog must fire it again.
* **Scheduler deadlock.** Bursts of one-shot ScheduledTasks (also `SessionSubmit`) can hang the kernel for good. Use
  one recurring task that drains a queue (`acpSchedule`); ACPLink's `Integration1.wlt` checks its sources for this.
* **SocketListen leaks file descriptors.** About 4 for each connection the client closes and about 2 for each one the
  server refuses. They are never given back, not even by `DeleteObject` of the listener. Starting and stopping a server
  without connections leaks nothing. Counting `/proc/self/fd` costs about 0.13 ms.
* **What happens past 1024 file descriptors** (select()'s limit) is uncertain. It was observed once, on 2026-10-10:
  the front end server's listener in a front end's kernel stopped answering above 1024, and a wolframscript kernel
  segfaulted at 1064. In this work, a wolframscript kernel still answered at 1953. So the server stops when idle, and
  the file descriptor guard (`MCP.wl`) stops it at 768, 75% of 1024, as a precaution.
* **Stalls.** After the main evaluation ran inside `PreemptProtect`, an overdue recurring ScheduledTask runs before the
  SocketListen data events that queued up meanwhile. AgentTools' maintenance pass therefore notices a stall when it
  runs more than two intervals (10 s) late. The 30 s timeout of a partial request then counts from the end of the
  stall, so the client gets no 408 for it. Shorter stalls still count against the client.
* Inside a ScheduledTask, `Stack[_]` also holds the frames of the main evaluation it interrupted. Code that inspects
  the stack from the pump or a handler (such as internal-failure reporting) must not walk it: it may hold large user
  data.
* `CheckAbort` does not see `TimeConstrained`'s abort; `WithCleanup` does. Use `WithCleanup` for cleanup that must
  also run on a time-out.
* **What the kernel sees.** In a real front end's kernel, `$Notebooks` is `True` and `$ParentLink` is a `LinkObject`.
  Under `UsingFrontEnd` (the tests, CI), the main evaluation has `$Notebooks` and a front end but no parent link, and
  the pump's tasks see `$FrontEnd === Null` and `$Notebooks` `False`. `notebookFrontEndQ` relies on this, and it was
  confirmed in a real front end (`"MCPToolCall"` logs `"Mode" -> "MainLink"`).
* **The front end preloads AgentTools.** The front end's kernel loads the installed AgentTools at startup, because the
  AI Settings preferences use it (`MiscExpressions.tr` references `` Wolfram`AgentTools`DetectedMCPClients ``). So a
  `PacletDirectoryLoad` of a checkout is not enough in a front end; `AGENTTOOLS_DIRECTORY` (or Reconnect after setting
  it) is.
* **Linear syntax runs code.** The private-use characters U+F7C0 to U+F7CD in a string are the front end's linear
  syntax (`\!\(...\)` as the kernel reads it inside a string literal). The front end turns such strings into boxes
  when they are box data, and the box constructor (U+F7C8, `\*`) makes it evaluate any box expression in the kernel.
  Box data is what MakeBoxes, ToBoxes, `clickToCopy`, a string in `Cell[BoxData[...]]` and code cells produce. Strings
  in `TextData` and plain string cells are shown as text. Typed ASCII backslashes are inert. `ToExpression[boxes, StandardForm, HoldComplete]` of a `TemplateBox` with an `InterpretationFunction` runs
  that function: `HoldComplete` does not protect box parsing.
* Aborting the main link from outside: a preemptive `FrontEndTokenExecute["EvaluatorAbort"]` aborted the wrong
  evaluation; a real Alt+. keystroke (`fe.py key alt+period`) works.

## OpenCode 2.0.26

* It advertises `agentCapabilities.mcpCapabilities.http` and takes ACP MCP servers as
  `{"type": "http", "name", "url", "headers": [{"name", "value"}]}` in `session/new`, `session/load` and
  `session/resume`.
* It registers an ACP session's MCP servers per project folder, by name. A server named `Wolfram` would replace the
  user's own Wolfram MCP server, hence `WolframNotebooks`.
* It appends `?codemode=false` to the URL, sends no `Origin`, keeps connections alive, and gets 405 for `GET` (fine).
  Its HTTP client (Bun) drops a request that gets no bytes for about 5-6 minutes, so a pending call's event stream
  needs keep-alive comments (AgentTools sends one every 15 s).
* **Code Mode** (the default): the model calls the tools from JavaScript in OpenCode's `execute` tool, e.g.
  `return await tools.WolframNotebooks.InsertCells({notebook: "c6d32676", markdown: "..."});`. The script runs in a
  restricted interpreter (acorn-based) where the `tools` identifier is the only way to reach a tool: no `eval`,
  `Function` constructor, `globalThis`, getters or `with`.
* **Permissions.** OpenCode checks the permission `<server>_<tool>` (e.g. `WolframNotebooks_InsertCells`) before it
  calls an MCP tool, and allows MCP tools by default. A Code Mode permission request names neither the tool nor its
  input: its `toolCall` is `{name: "execute", rawInput: {code}}`, checked in OpenCode's bundled code. That is why the
  permission panel parses the script (`acpExecuteScript` in `Transcript.wl`). The parse is best effort, and the panel
  always shows the script itself.
* "Always allow" is saved in OpenCode's database (`~/.local/share/opencode/opencode.db`), and saved rules take
  precedence over the config's `"ask"` rules (the last matching rule wins). Never modify that database. To test
  approval prompts, use a project folder without saved grants for the tool, and click "Allow once" only.
* Pass permission rules through `OPENCODE_CONFIG_CONTENT`, never `OPENCODE_CONFIG_DIR`.
* An OpenCode process connected to the user's Wolfram MCP server uses about 1.5 GB of memory.

## Security model

* **Tokens.** Each connection gets its own bearer token (256 random bits). It is a secret: it never reaches a message,
  a log entry, the queue, the TaggingRules, a persisted setting, the disk, or a `Failure`'s `"Evaluation"` or
  `"Arguments"`. The in-memory `"Stack"` of a Chatbook internal failure (a delayed value, e.g. of a failure kept in
  `$acpDebugLog`) can hold it, so never print an expanded `"Stack"`. Tests compare tokens but never print them. Don't
  write a token to a file or to output while debugging, not even to a scratch file.
* **Untrusted text.** Everything the agent, a tool result or a web page says is untrusted. The ACP window formats it
  under `withUntrustedContent`: no image imports, no special forms that evaluate or look things up online, no entity
  decoding. `neutralizeLinearSyntax` replaces linear-syntax characters with U+FFFD in text, code, the characters that
  formatting creates (HTML entities, TeX `\char`) and tool-call views. Both are defined in `Formatting.wl`.
  `withUntrustedContent` alone does not stop linear syntax.
* **Known gaps that were left alone** (out of scope; each has a `FIXME` comment):
  * `sandboxFormatter` (`Sandbox.wl`): sandbox results are shown live, so their dynamic content (or linear syntax in
    their strings) runs code in the user's kernel when shown.
  * `makeToolCallOutputSection` (`Formatting.wl`): tool formatters other than `toolAutoFormatter` get results that are
    not neutralized.
  * `insertSelectionMarkers0` (`ChatModes/Context.wl`): the left selection marker is dropped before an inline cell
    with no string right before it. ReadNotebook works around it.
* **AgentTools' internal failures** redact secrets before anything reaches a message, a bug report or a log file:
  the values of secret keys, `Authorization` header lines, `Bearer` tokens, and every occurrence of secrets registered
  with `` Wolfram`AgentTools`Common`withFailureSecrets `` (the socket server registers its tokens and each request's
  token). The evaluation stack is not searched (it may hold the user's data, see above). The `InternalFailures` log
  directory is made private (0700).
* **File descriptors.** The guard (a count every 5 s, Linux only) catches slow growth, such as many OpenCode
  reconnects, but not a deliberate local flood of connections. What limits an attack is that the server listens only
  while a window uses it, and for 30 s after that.

## Testing

* Use the TestReport tool, or `wolframscript` runners in a scratch directory. Never run a kernel with a repository
  root as its working directory: a run there once left a stray `Resources/` cache in Chatbook.
* Run one kernel at a time with a lock, e.g. `flock -w 3600 <scratch>/kernel.lock wolframscript -f run.wl`, when
  several agents test at once.
* **CI-like run.** CI runs every test file in one kernel, under `UsingFrontEnd`, in the context `` PacletCICDTest` ``,
  in `FileNames` order. A file passing on its own is not enough. Before relying on CI, run all `Tests/ACP*.wlt` that
  way, then the whole suite (`CurrentChatSettings.wlt` first).
* Results at the end of this work:
  * the 12 ACP files in one kernel: 1015/1015;
  * the whole Chatbook suite: 1645/1646, the failure being the flake below;
  * AgentTools: 3543/3543, each file in its own kernel.
* **Known flaky or pre-existing failures:**
  * CodeCheck `11_03_brackets` hits its 1 s limit on a loaded machine. It also fails on HEAD.
  * The headless front end of `UsingFrontEnd` sometimes segfaults at kernel shutdown, after the results (exit code 0).
  * ACPConnection `Session-New` timing, rarely.
  * `ACPMCP-Queue-DrainAbortReleases` is probabilistic (300 seeded random aborts).
  * `Formatting.wlt` `Markdown-External-Slash-ToolCall` fails only after the Reasoning and Skills tests in the same
    kernel.
* The MCP server and mock-agent tests need AgentTools with `StartMCPSocketServer`, ACPLink and python3. CI has none of
  them, so those tests give `Missing["TestSkipped"]` there: run them locally.
* Each fix of this work was checked with a mutation run: the fix is reverted and the new test must fail. Keep doing
  that for security-relevant tests.
* The MX file was not built during this work (`Scripts/BuildMX.wls` disables the installed Chatbook paclet). MX safety
  rests on the code:
  * no literal AgentTools symbols (`agentTools["name"]`);
  * the pump button's `ButtonFunction` is the fully qualified `` Wolfram`Chatbook`ACP`Common`acpMCPDrain ``;
  * state symbols are initialized under `If` guards.

  Build and test the MX before a release.
* Don't write test IDs' `@@` suffixes: the pre-commit hook (`Scripts/.githooks`, `Scripts/FormatFiles.wls`, in
  Chatbook and AgentTools) adds them. The hook rewrites every staged `.wlt` file and stages it whole, so re-run those
  tests after a commit.

### End-to-end check in a real front end

Use the drive-frontend skill (`Developer/FrontEndServer/fe.py`). Run one front end at a time, and stop it afterwards.
`fe.py` opens a new socket connection for every request and ping, and each one leaks file descriptors in the front
end's kernel. A long `fe.py` session (e.g. a long `fe.py wait`) can therefore trip the MCP server's file descriptor
guard, which turns the notebook tools off for the kernel session (`"MCPServerFdLimit"`). Keep waits short, check
`ls /proc/<kernel pid>/fd | wc -l`, and restart the front end well before 768. `~/TestProject` has saved "always"
grants for edits and some shell commands, but none for the `WolframNotebooks_*` tools, so it works for approval tests.

1. `fe.py launch --chatbook`, then in its kernel:

   ```wl
   SetEnvironment["ACPLINK_DIRECTORY" -> ".../ACPLink/ACPLink"];
   SetEnvironment["AGENTTOOLS_DIRECTORY" -> ".../AgentTools"]
   ```

2. Open a notebook to work on (e.g. one titled `OrbitNotes`), then
   `ShowNotebookAssistance[None, "ACPWindow", "ChatNotebookSettings" -> <|"ProjectDirectory" -> dir|>]`.
3. The debug log (`` Internal`BagPart[Wolfram`Chatbook`ACP`Common`$acpDebugLog, All] ``) should show
   `"MCPAgentToolsReloaded"` (version of the checkout) and `"MCPServerStarted"`.
4. Send a prompt with `ShowNotebookAssistance[None, "ACPWindow", "Input" -> "...", "EvaluateInput" -> True]`, for
   example asking it to append a paragraph to `OrbitNotes` with InsertCells.
5. The permission panel shows the tool, the notebook's title and id, the markdown, and the script. Take a screenshot
   and click "Allow once" (`fe.py click --image U,V`).
6. Expect `"MCPToolCall"` with `"Mode" -> "MainLink"`, and the new cell in the notebook.
7. Close the window. About 30 s later, expect `"MCPServerStopped"` (`"Reason" -> "Idle"`) and no `opencode` process.

This passed near the end of the work, before the last review round's smaller fixes to the script parser and the
formatter. An earlier run also checked a call waiting behind the user's `Pause[40]` and recovery with Alt+. Abort and
wait behaviour can only be checked in a real front end.

## Open issues and ideas

* Release AgentTools with `StartMCPSocketServer` (see [Repositories](#repositories)).
* **The permission panel's summary of a script** is best effort against agent-written JavaScript. Each review round
  found new shapes that hid a call: decoys in comments, regex literals or templates; aliases; unusual whitespace. The
  current rule adds "and other tools" whenever the parse is unsure. A real fix needs OpenCode to put the tool's name
  and input in its permission requests; that is worth raising upstream.
* `acpPermissionNotebooks` parses the script in ACPLink's reader handler. Parsing is linear and bounded (at most about
  0.4 s for a 100 KB adversarial script), but it could move to the pump.
* The 15.0.1 SocketListen file descriptor leak should be reported against the kernel.
* An abort in the last few evaluation steps of `StartMCPSocketServer`'s return can still leave a server running.
  This is documented in AgentTools.
* Remote windows would need ssh reverse forwarding to offer the server.
* Switching `"ACPMCPServer"` between `Automatic` and `True` reconnects a local window even when what is offered stays
  the same.
* The localized `.tr` files hold English text for the ACP strings.

## Fixed bugs that also exist on main

Found while making the window's formatting safe, and fixed in commit 367e1f61. It changes `Formatting.wl` and
`Tests/Formatting.wlt`. It also declares `neutralizeLinearSyntax` and `withUntrustedContent` in `CommonSymbols.wl`,
which the tests need, and adds the `sandboxFormatter` FIXME in `Sandbox.wl`. For a PR against `main`, cherry-pick the
whole commit. It applies cleanly to `main`, and `Formatting.wlt` passes there (63/63). The fixes:

* A `DateObject` with non-literal options (e.g. `TimeZone -> (code; 0)`) or an entity with a non-literal qualifier in
  a model's reply or a tool result ran that code when the chat formatted it. Such expressions now stay plain code.
* Linear-syntax characters in a reply, a tool result (e.g. a fetched web page), a tool call's parameters, or created
  from `&#xF7C1;` or TeX `\char` ran kernel code when shown. They now show as U+FFFD (also in `StringToBoxes`). A model
  that repeats genuine linear-syntax output now shows the box text instead of the formatted expression.
* HTML entity decoding lowercased anything shaped like `&...;` and decoded inside code, corrupting code such as
  `Map[#^2 &, M];` and `"&amp;" -> "&"`. Now only real entities are decoded, and only outside code.
