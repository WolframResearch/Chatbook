---
name: drive-frontend
description: >-
  Drive a real Wolfram front end (WolframNB) to test Chatbook's actual UI: launch a fresh front end on a private
  Xvfb display (optionally with the development Chatbook loaded) or attach to one that is already running, evaluate
  code in its kernel, list notebooks and cells, take screenshots, and click, type, or press buttons by BoxID,
  text, or screenshot coordinates. Use this whenever a task involves seeing or interacting with Chatbook UI -
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

## 1. Get a front end

**Fresh, isolated front end (preferred for testing).** It runs on its own Xvfb display, so it never touches the
user's desktop:

```bash
$fe launch --chatbook   # loads the development Chatbook from this repo (BoxIDs etc. match the source)
$fe launch              # uses the installed Chatbook paclet instead
```

It prints the port, e.g. `fe-2400 ... port 2400`. Startup takes 20-60 s. Always `$fe -s PORT stop` when done (it
quits the front end and its Xvfb). `$fe servers` lists what is running; `$fe servers --prune` cleans up leftovers.

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

**Avoid side effects:** pass `"AutoSaveConversations" -> False` (otherwise chats are saved and titled with an extra
LLM call). Don't click the feedback Send button (it posts to Wolfram), sign-in buttons, or chat bar state setters
(`NAChatbarSetterState*`, minimize/maximize); they persist front end options. Modal dialogs (`ChoiceDialog`,
`DialogInput`) block the kernel: requests time out until the dialog is closed (screenshot, then click a button).

## 4. Troubleshooting

- *"Timed out ... the kernel is busy"*: an evaluation is running; wait, raise `--timeout`, or use `--preemptive`.
- *"does not answer pings either"*: the kernel is blocked; `$fe screenshot --screen` to look for a dialog.
  A launched front end can always be killed with `$fe stop`.
- *"Several front end servers are running"* / *"Several notebooks match"*: add `-s PORT` / use a more specific name.
- *BoxNotFound*: the control may only exist while hovering or while a chat runs, may live in another place
  (`--in sidebar`), or may be missing from the installed Chatbook (use `launch --chatbook`).
- A located rectangle looks wrong: take a screenshot and use `click --image`.
- `$fe --json <command>` prints raw results (and errors as JSON).
