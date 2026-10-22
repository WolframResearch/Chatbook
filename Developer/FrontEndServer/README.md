# Front End Server

Tools for driving a real Wolfram front end (`WolframNB`) programmatically, so that Chatbook's actual UI (notebook
assistant window, sidebar, chat bar, chat notebooks) can be exercised and inspected by scripts and AI agents.

| File | Purpose |
|---|---|
| `FrontEndServer.wl` | Wolfram Language package (``Wolfram`ChatbookFrontEndServer` ``) defining `StartFrontEndServer`, `StopFrontEndServer`, and `FrontEndServerInformation` |
| `Init.wl` | Kernel init file that starts a server automatically (used by `fe.py launch`) |
| `fe.py` | Command line client (Python 3 standard library only) |
| `fe_x11.py` | Linux: X11 screenshots and synthetic mouse/keyboard input via `ctypes` (libX11 + libXtst; no xdotool or ImageMagick needed) |
| `fe_win32.py` | Windows: the same through Win32 (`user32`/`gdi32` via `ctypes`) |
| `fe_image.py` | PNG encoding and downscaling shared by both |
| `test_fe.py` | End-to-end smoke test: launches a front end, exercises the client, stops it (`python3 test_fe.py`, about a minute; on Windows it uses the real mouse and keyboard) |

## Two ways to get a server

### Attach to a front end that is already running

Evaluate this in a notebook of the front end you want to drive:

```wl
Get[ "/path/to/Chatbook/Developer/FrontEndServer/FrontEndServer.wl" ];
Wolfram`ChatbookFrontEndServer`StartFrontEndServer[ ]
```

The server listens on the first free port in 2400–2499 on 127.0.0.1 (or pass a port:
`StartFrontEndServer[ 2450 ]`). Several front ends can each run a server; each gets its own port.
Stop it with `` Wolfram`ChatbookFrontEndServer`StopFrontEndServer[ ] `` or `fe.py stop`.

### Launch a fresh front end

```bash
Developer/FrontEndServer/fe.py launch               # private Xvfb display (default); doesn't touch your desktop
Developer/FrontEndServer/fe.py launch --chatbook    # ... and load the development Chatbook from this repository
Developer/FrontEndServer/fe.py launch --display :10 # on an existing X display instead
Developer/FrontEndServer/fe.py launch --wm          # run a window manager (xfwm4/openbox) on the Xvfb display
Developer/FrontEndServer/fe.py stop                 # quit it again (also stops its Xvfb)
```

On Windows there is no private display: `launch` opens the front end on the desktop, where its windows come to the
front and mouse/keyboard commands use the real pointer and keyboard focus (see [Windows](#windows)). The front end is
taken from the `WOLFRAMNB` environment variable, `WolframNB` on the `PATH`, or the Wolfram installations registered
in the Windows registry (newest version first); or pass `--front-end PATH`.

`launch` starts `WolframNB` with `WOLFRAMINIT="-initfile <bootstrap>"`. The bootstrap file is written to a per-user
directory in the temp directory (`<temp>/ChatbookFrontEndServer-<user>/`, i.e. `/tmp/...` on Linux and `%TEMP%\...` on
Windows, which also holds logs, screenshots, and images exported by `eval`) because
the front end's sandboxed helper kernel (which also receives `WOLFRAMINIT`) may only read files there; it does nothing
in that kernel and loads `Init.wl` in the main one. Startup windows are tidied so that a single blank notebook remains.
If startup fails or is interrupted, everything that was started is stopped again.

To start a server manually the same way:

```bash
export WOLFRAMINIT="-initfile /tmp/bootstrap.wl"   # a copy of Init.wl, or a file that Gets it
WolframNB
```

`Init.wl` reads optional environment variables: `CHATBOOK_FE_SERVER_PORT`, `CHATBOOK_FE_SERVER_TOKEN`,
`CHATBOOK_FE_SERVER_NAME`, `CHATBOOK_FE_SERVER_REGISTRY`, and `CHATBOOK_FE_SERVER_CHATBOOK` (a paclet directory to load).

## Using the client

```bash
fe=Developer/FrontEndServer/fe.py       # on Windows: fe="python Developer/FrontEndServer/fe.py" (see below)
$fe servers                                   # list servers (port, display, launched/attached)
$fe -s 2401 info                              # pick a server when several are running
$fe eval 'Notebooks[]'                        # evaluate in the front end's kernel
$fe eval --cell 'Plot[Sin[x], {x, 0, 10}]'    # evaluate as an input cell (like Shift+Enter) and show the outputs
$fe nbs                                       # list notebooks
$fe cells 'Wolfram AI Assistant'              # list cells of a notebook (by title, id, or "selected")
$fe screenshot 'Wolfram AI Assistant'         # PNG of a notebook window (prints the path)
$fe locate --box NASendChatButton --notebook 'Wolfram AI Assistant'
$fe click --box NANewChatButton --notebook 'Wolfram AI Assistant'   # real mouse click
$fe press NAHistoryToggle --notebook 'Wolfram AI Assistant'         # trigger through the front end, no mouse
$fe click --image 120,340                     # click a point of the last screenshot
$fe type 'Hello' ; $fe key Return             # keyboard input to the focused window
$fe type 'more text' --cell CELLID            # put the cursor at the end of a cell first
$fe ask 'What is 2+2?'                        # ask the assistant window through its input field, print the reply
$fe wait                                      # wait until the kernel has finished pending evaluations
$fe messages                                  # contents of the Messages window
```

Run `fe.py -h` and `fe.py <command> -h` for all options. The skill in `.claude/skills/drive-frontend/SKILL.md`
has recipes for Chatbook's UI.

## How it works

* **Protocol.** Newline-delimited JSON over TCP on 127.0.0.1:
  `{"id", "token", "command", "args", "deadline", "preemptive"}` → `{"id", "ok", "result" | "error", "errorType"}`.
* **Registry.** Each server writes `<port>.json` (mode 0600, including a random access token) to
  `$UserBaseDirectory/ApplicationData/ChatbookFrontEndServer/Servers/` (mode 0700). `fe.py` discovers servers there and
  sends the token with each request; requests without the right token are rejected. `fe.py launch` also writes
  `<port>.launch.json` (the processes it started, tied to the server by its token) so that `stop` can end them; before
  signalling a process it checks that the PID still belongs to a front end/kernel/Xvfb process.
* **Main-link processing.** A `SocketListen` handler runs *preemptively*, like a `Dynamic`: its front end calls use
  the front end's service link, and doing real front end work there can deadlock the kernel against the front end
  (observed while a notebook assistant window was initializing). So the handler only validates and queues requests,
  then fires a `Method -> "Queued"` button in a hidden notebook. The front end runs the queued requests as an ordinary
  main-link evaluation, exactly like a button click. Consequences:
  * while the kernel is busy evaluating something else, requests wait until it is done (`fe.py wait` relies on this);
  * `EvaluationNotebook[]` inside `fe.py eval` is the hidden pump notebook (use
    `` Wolfram`ChatbookFrontEndServer`FrontEndServerNotebook["title"] ``, `SelectedNotebook[]`, or `eval --cell`);
  * code is read and evaluated one top-level expression at a time (like a notebook or `Get`), in `` Global` ``;
  * `fe.py --preemptive ...` processes a request directly in the handler instead, to inspect state during a long
    evaluation (e.g. a streaming chat). Use it for read-only queries.
  * `ping` is always answered directly and reports the queue state.
* **Coordinates.** Front end geometry is in points; the screen is in pixels. The scale (e.g. 4/3 at 96 dpi, 2 on a
  HiDPI setup, 5/3 at 125% scaling on Windows) is measured by matching notebook windows to screen windows. Box
  locations come from
  `FrontEnd`GetSelectionBoundingBoxes` after selecting the box (`FrontEnd`BoxReferenceFind` with the right search
  scope; boxes in docked and attached cells and in the assistant sidebar are found too). Boxes in docked cells and in
  the sidebar are reported relative to the content area by the front end and are corrected for that (and for
  window-manager title bars). Text selections in text cells are reported in document coordinates (the scroll position
  is not exposed), so the client finds their selection highlight in a screenshot instead.
* **Screenshots** are taken from the X root window (`XGetImage`) or the Windows screen (`BitBlt`), so they show exactly
  what is on screen, including attached cells, popup menus and dialogs. `fe.py screenshot --fe` uses front end
  rendering instead (`CurrentNotebookImage`), which needs no screen access but is low resolution and cropped.

## Windows

Everything works on Windows too (tested with Windows 11 and Wolfram 15.0, at 125% display scaling), with these
differences:

* **No isolation.** `launch` starts the front end on your desktop; there is no Windows counterpart of Xvfb. (A hidden
  desktop from `CreateDesktop` was tried: the front end runs there, but it does not paint notebook contents on a desktop
  that is not displayed, whatever its `NotebookRenderingEngine`, so nothing could be captured.) Screenshots raise the
  window first unless you pass `--no-raise`, which captures the window's own content with `PrintWindow` without
  changing the focus or stacking order, also where other windows cover it (popup menus are separate windows and are
  not included). Since other applications share the screen, `click`, `drag` and `scroll` refuse points where another
  application's window is in front (`--force` overrides), and `click --image` raises the window the screenshot showed.
* **Running the client.** Run `python fe.py ...`: running `fe.py` directly goes through its `python3` shebang, which is
  usually the Microsoft Store stub on Windows. Prefer Git Bash, with `export MSYS_NO_PATHCONV=1` so that it doesn't
  rewrite arguments that start with `/` (file arguments may be `C:/...` or `/c/...`). Windows PowerShell 5.1 strips
  double quotes inside arguments of native commands (`eval 'StringLength["a b"]'` arrives as `StringLength[a b]`) and
  treats the backtick as its escape character; there, pass code through stdin (`eval -`) or a file (`eval '@code.wl'`).
* **Coordinates.** The client is per-monitor DPI aware, so it works in physical pixels. The front end reports a box in
  any pane of a window (docked cells, sidebar, notebook content) as if that pane started at the top left corner of the
  window's client area; the client shifts it by the pane's real position (the `DockedCellsContent`, `SidebarContent`
  and `NotebookContent` child windows). Text selections are found in the system highlight color.
* **Locked sessions.** While the session is locked (or a UAC prompt is shown), Windows does not let other programs see
  the screen or send input; those commands fail with an explanation, while `eval`, `press`, `cells` and
  `screenshot --fe` keep working. Captures work while the monitor is merely switched off.
* **Input.** Text is typed as Unicode characters (independent of the keyboard layout); key names are the common X11
  ones (`Return`, `BackSpace`, `Prior`, `F5`, `KP_Enter`, `comma`, `ctrl+a`, ...). `meta` and `alt` are Alt;
  `super`/`win` is the Windows key. Input to windows of elevated (administrator) processes is blocked by Windows.
* **Multiple monitors.** Coordinates span the virtual screen, which can start at negative coordinates; write those as
  `click -- -100,200` or `--region=-100,0,400,300`. Monitors with different scaling are untested: keep the front end's
  windows on one monitor.
* **Processes.** `$ParentProcessID` is 0 on Windows, so the client finds the front end as the kernel's parent process
  (after checking the kernel's identity, since Windows reuses process ids); `stop` ends the front end together with its
  kernels (including the sandbox kernel), but only processes it has identified as such.

## Caveats

* Linux/X11 and Windows only for screenshots and input; the server itself and the evaluation/inspection commands are
  portable.
* Each front end with its kernels uses about 1 GB of memory. `launch` refuses to start one when less than 2 GB is
  available (`--force` overrides), since running out of memory can get unrelated processes killed.
* A launched front end shares your `$UserBaseDirectory`: preferences (it writes `FrontEnd/init.m` when it quits),
  installed paclets, and credentials (needed for LLM access). `launch --chatbook` runs `PacletDirectoryLoad`, which
  rewrites `Autoload/PacletManager/Configuration/FrontEnd/init_*.m`, so the next front end you start also sees the
  development Chatbook's front end resources until a kernel startup resets it.
* Modal dialogs (`ChoiceDialog`, `DialogInput`) block the kernel; requests time out until the dialog is closed
  (e.g. by clicking it).
* `locate` (and `click --box/--text/--cell`) moves the notebook's selection to the target.
* Synthetic input moves the real pointer and goes to the focused window; on your own desktop it can interfere with
  what you are doing.
* The Escape key starts an alias in a notebook (it is not "cancel").
