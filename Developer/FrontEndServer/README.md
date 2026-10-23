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
| `LinkSnooperLog.java` | Runs J/Link's LinkSnooper with its output in a log file, for logging the MathLink traffic between the front end and a kernel (`fe.py snoop`, see [below](#logging-mathlink-traffic)) |
| `test_fe.py` | End-to-end smoke test: launches a front end, exercises the client, stops it (`python3 test_fe.py`, about two minutes; on Windows it uses the real mouse and keyboard) |

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
Without `CHATBOOK_FE_SERVER_PORT`, every kernel of the front end that reads the init file (e.g. one of another
evaluator) starts a server of its own; with it, only the first one does.

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
$fe snoop ; $fe linklog                       # log the MathLink traffic to the kernel, and read it
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

## Logging MathLink traffic

J/Link's LinkSnooper (`com.wolfram.jlink.util.LinkSnooper`, part of every Wolfram installation, and offered by the
front end as the "LinkSnooper" evaluator) sits between the front end and a kernel, relays their MathLink traffic, and
prints every packet, normally to a console window. `fe.py` runs it with its output going to a log file instead:

```bash
fe.py launch --chatbook --link-snooper   # a front end whose kernel runs through LinkSnooper
fe.py snoop                              # or switch a front end that fe.py launched earlier (its kernel is replaced)
fe.py linklog --mark                     # skip what has been logged so far
fe.py click --box NANewChatButton --notebook 'Wolfram AI Assistant'   # do something
fe.py linklog --hide-server              # the packets it caused, one line each
```

A log line is one packet: `14:57:29.795 FE ---> K: EnterExpressionPacket[...]` (front end to kernel) or
`FE <--- K: ...` (kernel to front end); `-Serv-` marks the service link and `-Pre-` the preemptive link (Dynamic
updates), the others are on the main link. Expressions are printed by J/Link's `Expr.toString` (`Rule[a, b]`, strings
in quotes); LinkSnooper elides a few large packets (`FrontEnd`SetKernelSymbolContexts`, ...).

`linklog` prints the packets logged since its last call (it keeps its position in `<log>.cursor`), at most `--limit`
(100) of them, each cut to `--width` (300) characters. `--mark` skips to the end, `--all` and `--tail N` read the whole
log (`--all` also stops at `--limit` packets; `--limit 0` prints all), `--grep`/`--exclude` filter by a regular
expression matched against the packet as printed (without the time), and `--hide-server` leaves out the traffic of
fe.py's queued requests: everything from the front end's evaluation of the server's pump button
(`EvaluatePacket[... pump[] ...]`) to the matching `ReturnPacket`, which includes what code run by `eval` (or `press`,
`token`, ...) does, and the service link calls that trigger it. Requests sent with `--preemptive` run in the server's
socket handler, and their front end calls (`-Serv-`) are not left out. `--path` prints the log file's name, for `grep`
or reading it directly. Logs are named `<temp>/ChatbookFrontEndServer-<user>/linksnooper-<port>-<time>.log`; `stop`
leaves the log in place (read it with `linklog --file`), and `servers --prune` deletes logs that have not been written
to for a day (except the current log of a running server).

How it works:

* `snoop` adds an evaluator named "LinkSnooperLog" (or "LinkSnooperLog 2", ... if that name is taken) whose kernel the
  front end starts through LinkSnooper, with `LinkSnooperLog.java` run in Java's single-file source mode by the Java
  runtime that comes with Wolfram (`java -classpath JLink.jar LinkSnooperLog.java LOG -nowindow -timestamps
  -pollinterval 1 -links main,pre,serv -kernelname WolframKernel`). Unlike LinkSnooper's own `-logfile` option, which
  also prints everything to standard output (that is, into the front end's output) and truncates the file whenever
  the kernel restarts, it appends to the log only, logs J/Link errors too, and redacts secrets (see below).
* `EvaluatorNames` is set in `$FrontEndSession`, so nothing is saved with the preferences (setting it in `$FrontEnd`
  would save it in `FrontEnd/init.m`). The "Local" evaluator cannot be redirected this way: the front end ignores
  changes to its `MLOpenArguments` while it runs. Instead, `snoop` makes the new evaluator the session's default
  evaluator, which is the evaluator of every notebook that does not set its own (including the server's pump notebook
  and Chatbook's windows), and moves the server into its kernel: once it has answered, the server stops, the front end
  starts the new kernel (`FrontEndToken["EvaluatorStart", name]`), whose `Init.wl` starts the server again on the same
  port with the same token, and the old kernel quits. If the server does not come up in the new kernel within
  `snoop --timeout` (two minutes), the old kernel takes it back and restores the default evaluator.
  This only works in front ends that `fe.py launch` started (the new kernel must run `Init.wl`), and the old kernel's
  state is lost.
* `snoop --evaluator-only` just adds the evaluator, in any front end, and prints its name. Notebooks given that
  `Evaluator` then share one more kernel (about 300 MB) that runs through LinkSnooper; the server stays where it is.
  The evaluator lasts until the front end quits (`stop` does not remove it), and so does its kernel unless it is quit
  (e.g. `Quit[]` in such a notebook); give the notebooks their old `Evaluator` back before they are saved.
* A kernel that runs through LinkSnooper is the child of a Java process, which is the front end's child; `fe.py` takes
  the Java process's parent as the front end (to find its windows, and in `stop`).

Costs and caveats:

* **Speed.** Every packet goes through Java and is formatted: a front end call from the kernel takes about 3-6 ms
  instead of 0.5 ms, so UI code that makes many calls is noticeably slower. LinkSnooper sleeps between checks of its
  links: 1 ms while there is traffic (`snoop --poll-interval`), 10 ms after a second without (at 1 ms an idle
  LinkSnooper would use about 11% of a CPU core, at 10 ms about 1%, but each call would take about 40 ms). LinkSnooper
  always prints all links; `snoop --links` leaves the others out of the log only after they were redacted.
* **Size.** About 1 MB for a kernel startup and 2 MB for a notebook assistant chat. On Linux the temp directory is often
  in memory (tmpfs).
* **Secrets.** The log would hold everything that crosses the link in both directions, including the license
  activation record with its activation key and password (the front end sends it to every new kernel) and the Wolfram
  Cloud authentication token (`FrontEnd`WolframCloud`GetAuthentication[]`, e.g. for a notebook assistant chat).
  `LinkSnooperLog.java` redacts those before writing. It learns their values as they pass: `ActivationKey`, `Password`
  and `MachineID` from the front end's reply that holds the activation record, and tokens from the front end's reply to
  the kernel's `GetAuthentication` call, from the kernel's `FrontEnd`WolframCloud`ConnectionEstablished[..., {token}]`
  call, and from token-shaped strings (`Compress` output) in its other `FrontEnd`WolframCloud` calls. From then on it
  writes `<redacted Password>` etc. wherever they appear (`$ActivationKey` evaluated in a cell, too); strings shaped like
  activation keys (`1234-5678-ABCDEF`) and machine IDs (`1234-12345-12345`) are redacted even if never learned. The
  values are never passed to it or stored, and LinkSnooper options that would get around this (`-logfile`, `-noinit`,
  `-feside`, `-kernelside`) are refused. Not redacted: the license holder's name and organization, the machine name,
  the Wolfram ID (email address), file paths, notebook contents, and secrets in any other form (e.g. a Wolfram ID
  password typed into the cloud sign-in dialog, which sends it to the kernel, or `CloudConnect[id, password]`). So
  still do not attach raw logs, or excerpts that have not been checked, to issues.
* **Not logged:** the front end's sandboxed "System" kernel (some Chatbook controls evaluate there), kernels of other
  evaluators, and errors before LinkSnooper has opened its log (a Java compile error, an unwritable log file). On
  Linux those go to the front end's output (`frontend-<port>.log` in the temp directory for launched front ends); on
  Windows, where the front end starts `javaw`, they are probably lost: run the evaluator's command line by hand
  (`CurrentValue[$FrontEndSession, EvaluatorNames]`) to see them.
* **Failed starts.** An evaluator whose kernel failed to start stays unusable for the rest of the front end session
  (evaluations in it wait forever), so each `snoop` adds an evaluator with a new name.
* **Windows** is untested: the front end runs `javaw` there, and file names in the evaluator's command line are
  written with forward slashes.

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
