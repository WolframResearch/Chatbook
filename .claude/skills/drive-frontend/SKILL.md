---
name: drive-frontend
description: >-
  Drive a real Wolfram front end (WolframNB) to test Chatbook's actual UI, on Linux or Windows: launch a fresh front
  end (on Linux on a private Xvfb display; optionally with the development Chatbook loaded) or attach to one that is
  already running, evaluate
  code in its kernel, list notebooks and cells, take screenshots, click, type, or press buttons by BoxID,
  text, or screenshot coordinates, and log the MathLink traffic between front end and kernel to a readable file
  (LinkSnooper). Use this whenever a task involves seeing or interacting with Chatbook UI -
  the notebook assistant window, sidebar, chat bar, chat notebooks, output formatting, buttons and menus - for
  example "check how this renders in the front end", "reproduce this UI bug", "verify the new button works",
  "take a screenshot of the assistant window", or after changing UI code, "make sure it still works".
---

# Driving a Wolfram front end

All tools live in `Developer/FrontEndServer/` (its README.md explains the design). Use the client by absolute path,
since the shell's working directory may change between commands:

```bash
fe=/home/ubuntu/Chatbook/Developer/FrontEndServer/fe.py   # adjust to the repository location
```

**On Windows**, use the Bash tool (Git Bash) and call Python explicitly (`python3` there is usually the Microsoft Store
stub, which the script's shebang would run). Also stop Git Bash from rewriting arguments that start with `/` (it would
turn `type '/explain'` into `type 'C:/Program Files/Git/explain'`); fe.py accepts both `C:/...` and `/c/...` paths:

```bash
export MSYS_NO_PATHCONV=1
fe="python C:/Users/me/Chatbook/Developer/FrontEndServer/fe.py"
```

Avoid running it from PowerShell: Windows PowerShell 5.1 strips double quotes inside arguments of native commands
(`$fe eval 'StringLength["a b"]'` arrives as `StringLength[a b]`) and uses the backtick as its escape character. If you
must, pass code through stdin (`eval -`) or a file (`eval '@code.wl'`, quoted because `@` is an operator there).

## 1. Get a front end

**Fresh front end (preferred for testing).** On Linux it runs on its own Xvfb display, so it never touches the
user's desktop:

```bash
$fe launch --chatbook   # loads the development Chatbook from this repo (BoxIDs etc. match the source)
$fe launch              # uses the installed Chatbook paclet instead
```

It prints the port, e.g. `fe-2400 ... port 2400`. Startup takes 20-60 s. Always `$fe -s PORT stop` when done (it
quits the front end and its Xvfb). `$fe servers` lists what is running; `$fe servers --prune` cleans up leftovers.

**On Windows there is no private display:** the front end opens on the user's desktop. Its windows come to the front,
and `click`, `type`, `key`, `move`, `scroll`, `drag`, `focus`, `select`, `ask`, `locate --text/--cell` and screenshots
(which raise the window, `--cell` included) take over the real mouse pointer and keyboard focus. Only use those while
the user is away or has agreed to it; otherwise stick to `eval`, `press`, `cells`, `read`, `wait`, and
`screenshot NB --no-raise` (captures the window in place, also where it is covered, without changing focus; popup menus
are not included). Mouse commands refuse to click where another application's window covers the point (`--force`
overrides). While the Windows session is locked, screenshots and input fail with an explanation (`eval`, `press` and
`screenshot --fe` still work). If a system dialog or a service window grabs the foreground, Windows silently discards
synthetic input; `click`/`type`/`key` then fail naming the window in front instead of pretending it worked (see
Troubleshooting).

**Memory:** each front end (with its kernels) uses about 1 GB. Run as few as possible at once and stop them promptly;
running a machine out of memory gets unrelated processes killed, which can take down the user's desktop session.
`launch` refuses to start when less than 2 GB is available. Don't launch front ends from parallel subagents.

**The user's own front end.** Ask the user to evaluate:

```wl
Get["<repo>/Developer/FrontEndServer/FrontEndServer.wl"]; Wolfram`ChatbookFrontEndServer`StartFrontEndServer[]
```

Be considerate there: mouse/keyboard input moves the user's real pointer and focus, so prefer read-only commands,
`press` (no mouse) and `eval`, and don't close or modify their notebooks without being asked. `stop` only stops the
server in a front end that `fe.py` did not launch.

**Several servers.** When more than one is running, every command needs `-s PORT` (or `-s NAME`). With exactly one
running, `-s` can be omitted. Other agents may be running their own servers: always pass `-s` with your port.

## 2. Core commands

| Goal | Command |
|---|---|
| Evaluate code in the front end's kernel | `$fe eval 'expr'` (`-` reads stdin, `@file.wl` reads a file) |
| Evaluate as a real input cell (In/Out, like Shift+Enter) | `$fe eval --cell 'expr' [--notebook NB]` |
| Wait for pending evaluations / a condition | `$fe wait` / `$fe wait 'cond' --timeout 120` |
| List notebooks / cells | `$fe nbs` / `$fe cells NB` (`--attached`, `--sidebar`) |
| Read a cell | `$fe read CELLID [--format Markdown]` |
| Screenshot a window (prints a PNG path; view it with Read) | `$fe screenshot NB [--scale 0.5] [-o file.png]` |
| Screenshot a cell / the whole screen | `$fe screenshot --cell CELLID` / `$fe screenshot --screen` |
| Find a control on screen | `$fe locate --box BOXID --notebook NB` (also `--text TEXT`, `--cell CELLID`) |
| Real mouse click | `$fe click --box BOXID --notebook NB`, `--text TEXT`, `--cell ID`, `--image U,V`, or `X,Y` |
| Activate a control without the mouse | `$fe press BOXID --notebook NB` |
| Keyboard | `$fe type 'text' [--cell ID]`, `$fe key shift+Return`, `$fe key ctrl+a BackSpace` |
| Put the cursor into a cell / focus a window | `$fe focus --cell CELLID` / `$fe focus NB` |
| Ask the assistant (window or sidebar) and print the reply | `$fe ask 'question'` / `$fe ask 'question' --sidebar NB` |
| Menu commands | `$fe token SelectAll --notebook NB` (front end tokens; names are not validated) |
| Messages window | `$fe messages [--clear]` |
| Log the MathLink traffic between front end and kernel | `$fe launch --link-snooper` or `$fe snoop`, then `$fe linklog` (see §3) |
| Hover / scroll / drag | `$fe move ...`, `$fe scroll X,Y --clicks 3`, `$fe drag X0,Y0 X1,Y1` |
| Reload server code after editing FrontEndServer.wl | `$fe reload` |

`NB` is a notebook title (exact, or a unique substring), an id from `nbs`, `selected`, `input`, or `messages`.
Cell ids come from `cells`; if an id is ambiguous (attached cells can share ids across notebooks), use the full
`CellObject[...]` from `$fe --json cells ...` (field `object`).

Notes:
- **Requests wait for the kernel.** They run in the kernel's main loop, so while a cell or a chat is evaluating,
  requests are answered only after it finishes; `$fe wait` relies on this. Add `--preemptive` to read state *during*
  a long evaluation (e.g. `$fe --preemptive eval 'Wolfram`Chatbook`$ChatEvaluationCell'`); keep such requests
  read-only. Right after sending a chat, use the queued `wait` (a preemptive check may run before the chat starts).
- Inside `eval`, `EvaluationNotebook[]` is a hidden helper notebook. Refer to notebooks and cells with
  `` Wolfram`ChatbookFrontEndServer`FrontEndServerNotebook["title or id"] `` (and `FrontEndServerCell["id"]`),
  or use `SelectedNotebook[]` / `eval --cell`. `eval` code runs in `` Global` `` of the front end's kernel.
- Use fully qualified names for Chatbook symbols (``Wolfram`Chatbook`...``); Chatbook is not on `$ContextPath`.
- `locate`, and therefore `click --box/--text/--cell`, **moves the notebook's selection** to the target (and scrolls
  it into view). Keep that in mind when testing selection-dependent features (e.g. `AllowSelectionContext`).
  `--text` is case-sensitive; text the front end can't search (inside chat messages, buttons, docked/attached cells)
  falls back to the rectangle of the whole cell containing it.
- Screenshots go to a temp directory (printed); pass `-o` to choose the file. Use `--scale 0.5` for overviews (fewer
  tokens), full scale to read small text. `click --image U,V` maps a point of the *last* screenshot back to the screen.
- After a click or keystroke that changes the UI, `sleep 0.5`-`1` before the next screenshot.
- Key names are the X11 keysym names (`Return`, `BackSpace`, `Escape`, `Prior`, `F5`, `KP_Enter`, `comma`, `ctrl+a`,
  `shift+Return`); on Windows the common ones are supported. `alt` and `meta` are Alt, `win`/`super` the Windows key.
  On Windows, `type` sends the text as Unicode characters.
- Negative coordinates (a monitor left of or above the primary one on Windows) need `--`/`=`: `click -- -100,200`,
  `screenshot --region=-100,0,400,300`.
- Keyboard input goes to the focused window: `click` into the target, `focus --cell ID`, or `select NB` first.
  **Escape** starts an alias inside a notebook (it is not "cancel"), but it does close open menus and popups.
- Cell text containing private-use characters is shown with their names, e.g. `\[FreeformPrompt]`.
- After changing Chatbook source, reload it in the front end's kernel:
  `$fe eval 'PacletDirectoryLoad["<repo>"]; Get["Wolfram`Chatbook`"]'` (UI that is already open keeps the old code;
  reopen windows). Changes to front end resources (stylesheets, `FrontEnd/` files) need `launch --chatbook` again.

## 3. Chatbook recipes

**Notebook assistant window** (each question is a real LLM call):

```bash
$fe eval --timeout 180 'Wolfram`Chatbook`ShowNotebookAssistance[None, "Window", "Input" -> "What is 2+2?",
  "NewChat" -> True, "EvaluateInput" -> True,
  "ChatNotebookSettings" -> <|"AutoSaveConversations" -> False, "AllowSelectionContext" -> False|>]'
$fe cells 'Wolfram AI Assistant'          # ChatInput / ChatOutput cells with their text
$fe ask 'And what is 3+3?'                # types into the input field like a user, sends, prints the reply
$fe screenshot 'Wolfram AI Assistant'
```

The `ShowNotebookAssistance` call blocks until the reply is complete. The window title is "Wolfram AI Assistant".
Step by step instead of `ask`: `click --box AttachedChatInputField --notebook 'Wolfram AI Assistant'`, `type '...'`,
`key Return` (or `click --box NASendChatButton ...`), then `wait 'Wolfram`Chatbook`$ChatEvaluationCell === None'`.

**Sidebar:** `$fe eval 'Wolfram`Chatbook`ShowNotebookAssistance[Wolfram`ChatbookFrontEndServer`FrontEndServerNotebook["NB"], "Sidebar"]'`
(it ignores `"Input"`), then `$fe ask 'question' --sidebar NB`, or click with `--in sidebar`
(`click --box AttachedChatInputField --notebook NB --in sidebar`). List its messages with `$fe cells NB --sidebar`.

**Chat notebook:** `$fe eval 'Wolfram`Chatbook`CreateChatNotebook[]'` creates a notebook with one empty `ChatInput`
cell: `$fe cells NB`, `$fe type 'question' --cell <ChatInput id>`, `$fe key Return` (Return sends; Shift+Return is a
newline in chat input cells). New cells in a chat notebook are `Input` cells: to ask a follow-up, click below the
last cell and type `'` first, which turns the new cell into a `ChatInput`.

**Useful BoxIDs** (only present with the development Chatbook, i.e. `launch --chatbook`):

| Where | BoxIDs |
|---|---|
| Assistant window toolbar | `NANewChatButton`, `NASourcesToggle`, `NAHistoryToggle`, `NAOpenAsChatbookButton` |
| Assistant input | `AttachedChatInputField`, `NASendChatButton`, `NAStopChatButton` (while a chat runs) |
| Output tray (hover over a reply first: `move --cell ID`) | `NARegenerateAssistantMessageButton`, `NAThumbsUpButton`, `NAThumbsDownButton` |
| History overlay | `NAHistoryFirstPage`, `NAHistoryPageLeft`, `NAHistoryPageRight`, `NAHistoryLastPage`, `NAHistorySearchButton` |
| Sidebar (use `--in sidebar`) | `NASidebarNewChat`, `NASidebarSourcesToggle`, `NASidebarHistoryToggle`, `NASidebarOpenAsAssistantWindowButton`, `NASidebarClose`, `AttachedChatInputField`, `NASidebarChatInputCellSendButton` |
| Chat bar (bottom of notebooks) | `AttachedChatInputField`, `NAChatbarChatInputCellSendButton`, `NAChatbarOptionsButton` |
| Inline chat | `NACloseInlineChat`, `NAPopOutAsWorkspaceChat` |

Find more with `grep -rn 'BoxID' Source/Chatbook`. Controls built with `EventHandler` (tool-call expanders, focus
checkboxes, "Copy as" menus, code block buttons) have no BoxID: locate them in a screenshot and `click --image U,V`.

**Chat state from outside:**
- `` Wolfram`Chatbook`$ChatEvaluationCell `` is the chat input cell while a chat runs (in that kernel), else `None`.
- Reply text: `$fe cells NB` (or `--sidebar`), `$fe read ID --format Markdown`, or
  `CurrentValue[cell, {TaggingRules, "CellToStringData"}]`.
- Errors: `$fe messages`; service errors replace the reply with a framed `Text` cell (⚠);
  `Wolfram`Chatbook`$LastChatbookFailureText` holds the last internal failure.

**MathLink traffic** (every packet the front end and the kernel exchange, logged by J/Link's LinkSnooper; e.g. to see
which front end calls a button makes, or where an evaluation waits):

```bash
$fe launch --chatbook --link-snooper   # or `$fe snoop` in a front end fe.py launched (replaces its kernel: state is lost)
$fe linklog --mark                     # skip what has been logged so far
$fe click --box NANewChatButton --notebook 'Wolfram AI Assistant'   # the action
$fe linklog --hide-server              # packets since the mark, one line each: `14:59:50.900 FE <--- K: CallPacket[...]`
$fe linklog --all --grep 'NotebookWrite' --limit 0   # search the whole log; `linklog --path` gives the file
```

- `FE ---> K` goes to the kernel, `FE <--- K` to the front end; `-Pre-` is the preemptive link (Dynamic updates),
  `-Serv-` the service link, the rest the main link. `linklog` continues where it stopped last time, prints at most
  `--limit` (100) packets per call (`--all` too), and cuts each to `--width` (300) characters. `--grep` matches the
  packet as printed, without the time.
- `--hide-server` leaves out fe.py's queued requests, including everything `eval` code does: use it after clicks and
  keys, not to see what an `eval` caused. Requests sent with `--preemptive` are not left out.
- Front end calls get slower (3-6 ms each instead of 0.5 ms). The license key and password and the Wolfram Cloud token
  are written as `<redacted ...>`, but the log still holds the user's name, email address, paths and notebook
  contents: never paste raw logs or unchecked excerpts into issues or PRs. Don't sign in to the Wolfram Cloud while
  logging (that password would be logged). The sandboxed "System" kernel is not logged.
- In the user's own front end, use `$fe snoop --evaluator-only`: it adds an evaluator (use the name it prints, e.g.
  "LinkSnooperLog") that notebooks can be given (`Evaluator -> "LinkSnooperLog"`); the user's kernel stays untouched.
  The evaluator lasts until the front end quits: when done, quit its kernel (`$fe eval --cell 'Quit[]' --notebook NB`)
  and give the notebooks their old Evaluator back (or close scratch notebooks unsaved).
- `stop` keeps the log (`linklog --file PATH`). The README has the details.

**Avoid side effects:** pass `"AutoSaveConversations" -> False` (otherwise chats are saved and titled with an extra
LLM call). Don't click the feedback Send button (it posts to Wolfram), sign-in buttons, or chat bar state setters
(`NAChatbarSetterState*`, minimize/maximize); they persist front end options. Modal dialogs (`ChoiceDialog`,
`DialogInput`) block the kernel: requests time out until the dialog is closed (screenshot, then click a button).

## 4. Troubleshooting

- *"Timed out ... the kernel is busy"*: an evaluation is running; wait, raise `--timeout`, or use `--preemptive`.
- *"does not answer pings either"*: the kernel is blocked; look for a dialog with `$fe windows` and
  `$fe screenshot --window ID` (`$fe screenshot --screen` also works, but on Windows it shows the user's whole desktop).
  A launched front end can always be killed with `$fe stop`.
- *An evaluation never finishes and requests stay queued*: the kernel and the front end can deadlock (seen once, on
  Windows, when a request arrived as the first chat in a fresh kernel started). Then
  `$fe --preemptive eval 'MemberQ[Stack[], MathLink`CallFrontEndHeld]'` stays `True`. Abort the evaluation with
  `$fe key alt+period` while the front end window has the focus (`click X,Y` on it first; neither needs the server).
- *"Several front end servers are running"* / *"Several notebooks match"*: add `-s PORT` / use a more specific name.
- *BoxNotFound*: the control may only exist while hovering or while a chat runs, may live in another place
  (`--in sidebar`), or may be missing from the installed Chatbook (use `launch --chatbook`).
- A located rectangle looks wrong: take a screenshot and use `click --image`.
- `$fe --json <command>` prints raw results (and errors as JSON).
- Windows: *"Python was not found ... Microsoft Store"*: you ran `fe.py` directly; use `python .../fe.py`. Code arriving
  with its double quotes missing: you ran it from PowerShell; use Git Bash, `eval -` or `eval @file.wl`.
- Windows: *"Windows is not showing this desktop"*: the session is locked (or a UAC prompt is up); ask the user to
  unlock it, or use `eval`/`press`/`screenshot --fe`.
- Windows: *"Windows discarded the synthetic pointer input"* (or `key`/`type` reporting the focus is in some other
  window): a more privileged window is holding the foreground, so Windows drops injected mouse and keyboard input while
  reporting success. The error names that window. A stray key combination can cause it (e.g. a cat on the keyboard
  tripping the Sticky Keys prompt); a service window (`GameInputSvc`) was also seen holding it. If the named window is
  a dialog, ask the user to dismiss it (you cannot, since clicks are dropped too). Otherwise keep testing with the
  commands that need no synthetic input - `eval`, `press` (activates a control by BoxID with no mouse), `--preemptive`
  reads, and `screenshot NB --no-raise` - until real input at the machine clears it.
- `snoop` fails or a notebook with a LinkSnooper evaluator never starts evaluating: Java or the kernel did not start;
  look at the end of the LinkSnooper log (`linklog --path`) and of the front end's output
  (`<temp>/ChatbookFrontEndServer-<user>/frontend-<port>.log`; on Windows, Java's own errors may not appear anywhere).
  That evaluator stays unusable for the session; `snoop` again adds a new one.
