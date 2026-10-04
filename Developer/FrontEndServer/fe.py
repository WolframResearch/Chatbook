#!/usr/bin/env python3
"""fe.py - drive a Wolfram front end (WolframNB) from the command line.

Talks to a front end server started by StartFrontEndServer[] (Developer/FrontEndServer/FrontEndServer.wl), and uses
X11 directly (fe_x11.py) for screenshots, mouse and keyboard input.

Quick start:
    fe.py launch                        # start a fresh front end on a private Xvfb display
    fe.py eval '1 + 1'                  # evaluate in the front end's kernel
    fe.py eval --cell 'Plot[x, {x, 0, 1}]'   # evaluate as a real input cell (like Shift+Enter)
    fe.py nbs                           # list notebooks
    fe.py screenshot selected           # screenshot a notebook window -> prints PNG path
    fe.py click --image 120,340         # click a point in the last screenshot
    fe.py stop                          # quit a launched front end

Run "fe.py <command> -h" for details on each command.
"""

import argparse
import contextlib
import getpass
import json
import os
import re
import secrets
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

REPO = os.path.dirname(os.path.dirname(HERE))
PORT_RANGE = (2400, 2499)


# ---------------------------------------------------------------------------------------------------------------------
# Registry
# ---------------------------------------------------------------------------------------------------------------------

def registry_dir():
    env = os.environ.get("CHATBOOK_FE_SERVER_REGISTRY")
    if env:
        return env
    if sys.platform == "darwin":
        base = os.path.expanduser("~/Library/Wolfram")
    elif sys.platform.startswith("win"):
        base = os.path.join(os.environ.get("APPDATA", os.path.expanduser("~")), "Wolfram")
    else:
        base = os.path.expanduser("~/.Wolfram")
    return os.path.join(base, "ApplicationData", "ChatbookFrontEndServer", "Servers")


def state_dir():
    """Per-user directory for bootstrap init files, logs and screenshots. It must be inside the temp directory, which
    is the only place the front end's sandboxed helper kernel may read the bootstrap init file from."""
    # Same directory as the server uses for its own images ($TemporaryDirectory/ChatbookFrontEndServer-$Username):
    path = os.path.join(tempfile.gettempdir(), "ChatbookFrontEndServer-" + getpass.getuser())
    os.makedirs(path, mode=0o700, exist_ok=True)
    if hasattr(os, "getuid") and os.stat(path).st_uid != os.getuid():
        raise CLIError(f"{path} belongs to another user; refusing to use it")
    return path


def screenshot_dir():
    path = os.environ.get("CHATBOOK_FE_SCREENSHOTS") or os.path.join(state_dir(), "screenshots")
    os.makedirs(path, exist_ok=True)
    return path


def pid_alive(pid):
    if not pid:
        return False
    try:
        os.kill(int(pid), 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except (OSError, ValueError):
        return False


# Executables of the processes fe.py may signal. Together with the process start time, this makes sure a PID that was
# reused by an unrelated process is never signalled.
PROCESS_NAMES = {
    "kernel": {"WolframKernel", "MathKernel"},
    "frontend": {"WolframNB", "Mathematica"},
    "xvfb": {"Xvfb"},
    "wm": {"xfwm4", "openbox"},
}
SHELLS = {"sh", "bash", "dash", "zsh"}  # the WolframNB launcher is a shell script


def process_info(pid):
    """(argv, start time as a Unix time) of a process, or None if they cannot be determined."""
    pid = int(pid)
    try:
        with open(f"/proc/{pid}/cmdline", "rb") as f:
            argv = [a.decode("utf-8", "replace") for a in f.read().split(b"\0") if a]
        with open(f"/proc/{pid}/stat") as f:
            ticks = int(f.read().rsplit(")", 1)[1].split()[19])  # field 22: start time after boot, in clock ticks
        with open("/proc/stat") as f:
            boot = next(int(line.split()[1]) for line in f if line.startswith("btime "))
        return argv, boot + ticks / os.sysconf("SC_CLK_TCK")
    except (OSError, ValueError, IndexError, StopIteration):
        pass
    if os.path.isdir("/proc"):
        return None
    try:  # no procfs (e.g. macOS)
        out = subprocess.run(["ps", "-o", "lstart=", "-o", "args=", "-p", str(pid)], capture_output=True, text=True,
                             timeout=5).stdout.split()
        return out[5:], time.mktime(time.strptime(" ".join(out[:5]), "%a %b %d %H:%M:%S %Y"))
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


def pid_is(pid, kind, started=(None, None)):
    """Whether `pid` is a live process of the given kind that started within `started` (Unix times; None = open).
    False whenever this cannot be established."""
    if not pid or not pid_alive(pid):
        return False
    info = process_info(pid)
    if not info or not info[0]:
        return False
    argv, start = info
    names = PROCESS_NAMES[kind]
    exe = os.path.basename(argv[0])
    if exe not in names and not (exe in SHELLS and len(argv) > 1 and os.path.basename(argv[1]) in names):
        return False
    earliest, latest = started
    return (earliest is None or start >= earliest - 2) and (latest is None or start <= latest + 2)


def kill_pid(pid, kind, sig=signal.SIGTERM, started=(None, None)):
    if pid_is(pid, kind, started):
        try:
            os.kill(int(pid), sig)
        except OSError:
            pass


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def registry_entries():
    directory = registry_dir()
    entries = []
    if not os.path.isdir(directory):
        return entries
    for name in sorted(os.listdir(directory)):
        if not name.endswith(".json") or ".launch" in name or ".screenshot" in name:
            continue
        info = read_json(os.path.join(directory, name))
        if not isinstance(info, dict) or "Port" not in info:
            continue
        info["_file"] = os.path.join(directory, name)
        launch = read_json(os.path.join(directory, f"{info['Port']}.launch.json"))
        # A launch record only belongs to this server if it was written for the same token (records can be left
        # behind, and an unrelated server may later get the same port):
        info["_launch"] = launch if launch_belongs_to(launch, info) else None
        info["_alive"] = pid_is(info.get("KernelPID"), "kernel", server_started(info))
        entries.append(info)
    return entries


def server_started(info):
    """Start-time bounds for a server's kernel and front end: both started before the server registered itself."""
    return None, info.get("StartTime")


def launch_started(launch):
    """Start-time bounds for the processes `launch` started (Xvfb, window manager, the front end's launcher)."""
    start = (launch or {}).get("startTime")
    return (start, start + 600) if start else (None, None)


def launch_belongs_to(launch, info):
    if not isinstance(launch, dict):
        return False
    if "token" in launch:
        return launch["token"] == info.get("Token")
    # Records written by older versions of fe.py have no token: accept them only for a server that started on the
    # same display shortly after the launch.
    started = info.get("StartTime") or 0
    return launch.get("display") == info.get("Display") and 0 <= started - launch.get("startTime", 0) < 300


def launch_records():
    """Launch records by port (including ones without a registry file, e.g. from failed launches)."""
    directory = registry_dir()
    records = {}
    if os.path.isdir(directory):
        for name in os.listdir(directory):
            if name.endswith(".launch.json"):
                record = read_json(os.path.join(directory, name))
                if isinstance(record, dict) and "port" in record:
                    records[record["port"]] = record
    return records


def remove_registry(port, keep_launch=False):
    for suffix in (".json", ".screenshot.json") + (() if keep_launch else (".launch.json",)):
        path = os.path.join(registry_dir(), f"{port}{suffix}")
        if os.path.exists(path):
            os.remove(path)


class CLIError(Exception):
    pass


def select_server(spec=None, include_dead_launched=False):
    spec = spec or os.environ.get("CHATBOOK_FE_SERVER")
    entries = [e for e in registry_entries() if e["_alive"] or (include_dead_launched and e["_launch"])]
    if spec:
        for e in entries:
            if str(e["Port"]) == str(spec) or e.get("Name") == spec:
                return e
        raise CLIError(f"No running front end server matches {spec!r}. Running: " + describe_servers(entries))
    if len(entries) == 1:
        return entries[0]
    if not entries:
        raise CLIError("No running front end servers. Start one with `fe.py launch`, or evaluate "
                       "StartFrontEndServer[] in an existing front end.")
    raise CLIError("Several front end servers are running; choose one with -s PORT. Running: "
                   + describe_servers(entries))


def describe_servers(entries):
    return ", ".join(f"{e['Port']} ({e.get('Name')}, display {e.get('Display')})" for e in entries) or "none"


# ---------------------------------------------------------------------------------------------------------------------
# Protocol
# ---------------------------------------------------------------------------------------------------------------------

class ServerError(Exception):
    def __init__(self, response):
        self.response = response
        super().__init__(f"{response.get('errorType', 'Error')}: {response.get('error')}")


class Server:
    # Global options (set from the command line):
    preemptive = False
    timeout_override = None

    def __init__(self, info):
        self.info = info
        self.port = info["Port"]
        self.host = info.get("Host", "127.0.0.1")
        self.token = info.get("Token")
        self._id = 0
        self._scale = None

    @property
    def display(self):
        launch = self.info.get("_launch") or {}
        return launch.get("display") or self.info.get("Display")

    def request(self, command, args=None, timeout=60):
        """Send one request and return its result.

        Requests are processed by the kernel's main loop (see FrontEndServer.wl), so they wait while the kernel is busy
        with another evaluation. The deadline makes the server drop requests the client has given up on."""
        if self.timeout_override:
            timeout = self.timeout_override
        deadline = time.time() + timeout
        while True:
            response = self._send(command, args, deadline)
            if response.get("ok"):
                return response.get("result")
            # Right after startup the server may be listening before its front end connection is usable:
            if response.get("errorType") == "FrontEndNotReady" and time.time() + 0.5 < deadline:
                time.sleep(0.5)
                continue
            raise ServerError(response)

    def _send(self, command, args, deadline):
        self._id += 1
        timeout = max(1.0, deadline - time.time())
        payload = {"id": self._id, "token": self.token, "command": command,
                   "args": {k: v for k, v in (args or {}).items() if v is not None}, "deadline": deadline}
        if self.preemptive:
            payload["preemptive"] = True
        try:
            sock = socket.create_connection((self.host, self.port), timeout=min(10.0, timeout))
        except OSError as e:
            raise CLIError(f"Cannot connect to the front end server on port {self.port}: {e}")
        data = b""
        try:
            sock.settimeout(timeout)
            sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
            while not data.endswith(b"\n"):
                # Wake up every two seconds to ping: the server only fires the front end trigger for queued requests
                # while the kernel is idle, and it can be dropped (e.g. when evaluations are aborted); any incoming
                # request lets the server (re-)fire it once the kernel is idle.
                sock.settimeout(max(0.1, min(2.0, deadline - time.time())))
                try:
                    chunk = sock.recv(1 << 20)
                except socket.timeout:
                    if time.time() >= deadline:
                        raise
                    self.ping_quietly()
                    continue
                if not chunk:
                    break
                data += chunk
        except socket.timeout:
            raise CLIError(f"Timed out after {timeout:.0f}s waiting for {command!r}. " + self.diagnose())
        except OSError as e:
            raise CLIError(f"Connection to the front end server failed during {command!r}: {e}")
        finally:
            sock.close()
        if not data.strip():
            raise CLIError(f"The server closed the connection without answering {command!r} (did the kernel quit?)")
        try:
            return json.loads(data.decode("utf-8").split("\n")[0])
        except ValueError as e:
            raise CLIError(f"Malformed response to {command!r}: {e}")

    def ping_quietly(self):
        try:
            with socket.create_connection((self.host, self.port), timeout=2) as sock:
                sock.settimeout(2)
                sock.sendall((json.dumps({"id": 0, "token": self.token, "command": "ping"}) + "\n").encode())
                sock.recv(65536)
        except OSError:
            pass

    def diagnose(self):
        """Explain a timeout using a ping, which the server answers even while the kernel is busy."""
        try:
            sock = socket.create_connection((self.host, self.port), timeout=3)
            sock.settimeout(3)
            sock.sendall((json.dumps({"id": 0, "token": self.token, "command": "ping"}) + "\n").encode())
            data = b""
            while not data.endswith(b"\n"):
                chunk = sock.recv(65536)
                if not chunk:
                    break
                data += chunk
            sock.close()
            ping = json.loads(data.decode()).get("result") or {}
        except (OSError, ValueError):
            return ("The server does not answer pings either: the kernel is blocked (e.g. by a modal dialog, "
                    "or a deadlock). Take a screenshot to check for dialogs.")
        if ping.get("pumpPending") is not None or ping.get("queued"):
            return (f"The kernel is busy with another evaluation (request queued for {ping.get('pumpPending')}s, "
                    f"{ping.get('queued')} in queue). Wait for it to finish, raise --timeout, or use --preemptive to "
                    "process requests during the evaluation (small risk of a front end deadlock).")
        return "The server answers pings, so the command itself is slow; raise --timeout."

    def evaluate(self, code, timeout=60, **kw):
        return self.request("evaluate", dict(kw, code=code, timeout=timeout), timeout=timeout + 10)

    # --- geometry -----------------------------------------------------------------------------------------------------

    def x_display(self):
        import fe_x11
        if not self.display:
            raise CLIError("The server did not report an X display (DISPLAY was unset in the front end).")
        return fe_x11.Display(self.display)

    def fe_windows(self, d):
        pid = self.info.get("FrontEndPID")
        windows = d.windows()
        own = [w for w in windows if w["pid"] == pid]
        popups = [w for w in windows if w["override_redirect"] and w["pid"] in (pid, None)
                  and w["width"] > 2 and w["height"] > 2]
        return own, popups

    def match_window(self, d, nb):
        """Find the X window of a notebook (as returned by the server's notebook summary)."""
        title = nb.get("title") or ""
        if nb.get("visible") is False:
            raise CLIError(f"Notebook {title!r} is hidden, so it has no window")
        own = [w for w in self.fe_windows(d)[0] if not w["override_redirect"]]
        candidates = [w for w in own if window_title(w["name"]) == title]
        rect = nb.get("rect")
        if len(candidates) == 1:
            return candidates[0]
        if rect:
            # Several windows with this title (or none, e.g. an untitled dialog): match by size and position. The
            # position can differ by the window manager's frame, so it gets a generous tolerance.
            scale = self.scale(d, nbs=[nb])
            def distance(w):
                return (abs(w["width"] - rect["width"] * scale) + abs(w["height"] - rect["height"] * scale),
                        abs(w["x"] - rect["left"] * scale) + abs(w["y"] - rect["top"] * scale))
            close = [w for w in (candidates or own) if distance(w)[0] <= 8 and distance(w)[1] <= 120]
            if close:
                return min(close, key=distance)
        raise CLIError(f"Could not find the window of notebook {title!r} on display {self.display}")

    def scale(self, d=None, nbs=None):
        """X pixels per front end point, measured by matching notebook windows with X windows."""
        if self._scale:
            return self._scale
        own_display = d is None
        d = d or self.x_display()
        try:
            if not nbs or not any(window_title(w["name"]) == (nbs[0].get("title") or "") for w in self.fe_windows(d)[0]):
                nbs = self.request("notebooks")
            own, _ = self.fe_windows(d)
            ratios = []
            for nb in nbs:
                rect, title = nb.get("rect"), nb.get("title") or ""
                if not rect or not rect.get("width"):
                    continue
                matches = [w for w in own if window_title(w["name"]) == title]
                if len(matches) == 1:
                    ratios.append(matches[0]["width"] / rect["width"])
            if ratios:
                ratios.sort()
                self._scale = round(ratios[len(ratios) // 2] * 48) / 48  # snap to a sane grid (e.g. 1.3333)
            else:
                self._scale = 4 / 3
            return self._scale
        finally:
            if own_display:
                d.close()


def window_title(name):
    """The notebook title in an X window name like 'Untitled-1 * (Running...) - Wolfram'."""
    name = re.sub(r" - Wolfram( Mathematica)?$", "", name)
    name = re.sub(r" \([^()]*\.\.\.\)$", "", name)  # " (Running...)", " (Rendering...)"
    return re.sub(r" \*$", "", name)


# ---------------------------------------------------------------------------------------------------------------------
# Output helpers
# ---------------------------------------------------------------------------------------------------------------------

def emit(args, data, text=None):
    if getattr(args, "json", False) or text is None:
        print(json.dumps(data, indent=1, ensure_ascii=False))
    else:
        print(text)


def parse_point(text):
    try:
        x, y = (float(v) for v in text.split(","))
        return x, y
    except ValueError:
        raise CLIError(f"Expected a point like 120,340 but got {text!r}")


def screenshot_state_path(server):
    return os.path.join(registry_dir(), f"{server.port}.screenshot.json")


def default_screenshot_path(server, label):
    stamp = time.strftime("%Y%m%d-%H%M%S")
    safe = "".join(c if c.isalnum() or c in "-_" else "_" for c in label)[:40] or "shot"
    return os.path.join(screenshot_dir(), f"{server.port}-{stamp}-{int(time.time() * 1000) % 1000:03d}-{safe}.png")


def read_code(code):
    if code == "-":
        return sys.stdin.read()
    if code.startswith("@") and " " not in code and ("/" in code or code.endswith((".wl", ".m", ".wls", ".txt"))):
        if not os.path.isfile(code[1:]):
            raise CLIError(f"File not found: {code[1:]}")
        with open(code[1:]) as f:
            return f.read()
    return code


# ---------------------------------------------------------------------------------------------------------------------
# Commands: servers / launch / stop
# ---------------------------------------------------------------------------------------------------------------------

def cmd_servers(args):
    entries = registry_entries()
    rows = []
    for e in entries:
        status = "running" if e["_alive"] else "dead"
        if args.prune and not e["_alive"]:
            kill_launched(e.get("_launch"), e if e.get("_launch") else None)
            remove_registry(e["Port"])
            status = "removed"
        rows.append({"port": e["Port"], "name": e.get("Name"), "display": e.get("Display"), "status": status,
                     "launched": bool(e.get("_launch")), "kernelPID": e.get("KernelPID"),
                     "frontEndPID": e.get("FrontEndPID")})
    if args.prune:
        prune_orphans({e["Port"] for e in entries if e["_alive"]})
    if args.json:
        return emit(args, rows)
    if not rows:
        print("No front end servers registered in " + registry_dir())
    for r in rows:
        kind = "launched" if r["launched"] else "attached"
        print(f"{r['port']}  {r['name']:<16} display={r['display']}  {r['status']}  ({kind}; kernel {r['kernelPID']}, "
              f"front end {r['frontEndPID']})")


def prune_orphans(live_ports):
    """Clean up after failed launches (launch records without a running server) and old screenshots."""
    for port, record in launch_records().items():
        if port in live_ports or time.time() - record.get("startTime", 0) < 300:
            continue  # running, or possibly still starting
        kill_launched(record)
        remove_registry(port)
        bootstrap = record.get("bootstrap")
        if bootstrap and os.path.exists(bootstrap):
            os.remove(bootstrap)
    shots = screenshot_dir()
    for name in os.listdir(shots):
        path = os.path.join(shots, name)
        if name.endswith(".png") and time.time() - os.path.getmtime(path) > 86400:
            os.remove(path)


def kill_launched(launch, info=None):
    """Stop the processes of a launch record (front end, its kernel, window manager, Xvfb), checking each PID's
    identity first so that a reused PID is never signalled."""
    launch, info = launch or {}, info or {}
    kill_pid(info.get("FrontEndPID"), "frontend", signal.SIGKILL, server_started(info))
    kill_pid(launch.get("launcherPID"), "frontend", signal.SIGKILL, launch_started(launch))
    kill_pid(info.get("KernelPID"), "kernel", signal.SIGKILL, server_started(info))
    kill_pid(launch.get("wmPID"), "wm", started=launch_started(launch))
    kill_pid(launch.get("xvfbPID"), "xvfb", started=launch_started(launch))


@contextlib.contextmanager
def registry_lock():
    """Serialize registry updates between concurrent fe.py processes."""
    os.makedirs(registry_dir(), exist_ok=True)
    with open(os.path.join(registry_dir(), ".lock"), "a") as f:
        try:
            import fcntl
            fcntl.flock(f, fcntl.LOCK_EX)
        except ImportError:  # Windows
            import msvcrt
            msvcrt.locking(f.fileno(), msvcrt.LK_LOCK, 1)
        yield  # released when the file is closed


def reserve_port(requested, token):
    """Pick a port and claim it by creating its launch record, so that concurrent launches can't collide."""
    with registry_lock():
        return reserve_port_locked(requested, token)


def reserve_port_locked(requested, token):
    live = {e["Port"] for e in registry_entries() if e["_alive"]}
    records = launch_records()
    for port in ([requested] if requested else range(PORT_RANGE[0], PORT_RANGE[1] + 1)):
        record = records.get(port)
        busy = port in live or (record and (time.time() - record.get("startTime", 0) < 300
                                            or pid_is(record.get("launcherPID"), "frontend", launch_started(record))))
        if busy:
            if requested:
                raise CLIError(f"Port {port} is already used by another front end server")
            continue
        with socket.socket() as probe:
            try:
                probe.bind(("127.0.0.1", port))
            except OSError:
                if requested:
                    raise CLIError(f"Port {port} is in use")
                continue
        path = os.path.join(registry_dir(), f"{port}.launch.json")
        if record:
            with contextlib.suppress(FileNotFoundError):
                os.remove(path)  # a stale record from an old launch
        try:
            fd = os.open(path, os.O_CREAT | os.O_EXCL | os.O_WRONLY, 0o600)
        except FileExistsError:
            continue  # claimed by a launch that does not take the lock (an older fe.py)
        with os.fdopen(fd, "w") as f:
            json.dump({"port": port, "token": token, "startTime": time.time()}, f)
        return port
    raise CLIError("No free port in range %d-%d" % PORT_RANGE)


def write_launch_record(record):
    path = os.path.join(registry_dir(), f"{record['port']}.launch.json")
    with open(path, "w") as f:
        json.dump(record, f, indent=1)


def start_xvfb(size):
    """Start Xvfb on a free display; returns (display, process)."""
    if not shutil.which("Xvfb"):
        raise CLIError("Xvfb is not installed; use --display :N to run on an existing display")
    try:
        width, height = (int(v) for v in size.lower().split("x"))
    except ValueError:
        raise CLIError(f"Invalid --size {size!r}; expected WIDTHxHEIGHT")
    for number in range(90, 200):
        if os.path.exists(f"/tmp/.X11-unix/X{number}") or os.path.exists(f"/tmp/.X{number}-lock"):
            continue
        xvfb = subprocess.Popen(["Xvfb", f":{number}", "-screen", "0", f"{width}x{height}x24", "-nolisten", "tcp",
                                 "-dpi", "96"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                start_new_session=True)
        for _ in range(50):
            if xvfb.poll() is not None:
                break  # display taken by a concurrent start; try the next one
            if os.path.exists(f"/tmp/.X11-unix/X{number}"):
                return f":{number}", xvfb
            time.sleep(0.1)
        if xvfb.poll() is None:
            xvfb.kill()
    raise CLIError("Could not start Xvfb on any display")


def find_front_end(explicit=None):
    if explicit:
        if not os.path.exists(explicit):
            raise CLIError(f"Front end executable not found: {explicit}")
        return explicit
    candidates = [os.environ.get("WOLFRAMNB"), shutil.which("WolframNB"), shutil.which("Mathematica"),
                  "/usr/local/Wolfram/Wolfram/15.0/Executables/WolframNB"]
    for c in candidates:
        if c and os.path.exists(c):
            return c
    raise CLIError("Cannot find the WolframNB executable; pass --front-end PATH")


def write_bootstrap(port):
    """The init file must live somewhere the front end's sandboxed helper kernel may read (the temp directory),
    otherwise that kernel reports Get::noopen in the Messages window on every launch."""
    init = os.path.join(HERE, "Init.wl").replace("\\", "/")
    path = os.path.join(state_dir(), f"Bootstrap-{port}.wl")
    with open(path, "w") as f:
        f.write("(* Generated by fe.py launch *)\n"
                'If[ $FrontEnd =!= Null && ! MemberQ[ $CommandLine, "-sandbox" ],\n'
                f'    Get[ "{init}" ]\n'
                "];\n")
    return path


def available_memory_mb():
    try:
        with open("/proc/meminfo") as f:
            for line in f:
                if line.startswith("MemAvailable:"):
                    return int(line.split()[1]) // 1024
    except (OSError, ValueError):
        pass
    return None


# A front end with its two kernels needs about 1 GB. Running out of memory can get unrelated processes killed (on a
# shared desktop, that can take the user's whole session down), so refuse to start one when memory is tight.
MIN_FREE_MEMORY_MB = 2000


def cmd_launch(args):
    chatbook = os.path.realpath(args.chatbook) if args.chatbook else None
    if chatbook and not os.path.isfile(os.path.join(chatbook, "PacletInfo.wl")):
        raise CLIError(f"Not a paclet directory (no PacletInfo.wl): {chatbook}")
    free = available_memory_mb()
    if free is not None and free < MIN_FREE_MEMORY_MB and not args.force:
        raise CLIError(f"Only {free} MB of memory available; a front end needs about 1 GB and starting one now could "
                       f"make the system run out of memory. Stop other front ends (`fe.py servers`) or pass --force.")
    front_end_path = find_front_end(args.front_end)
    token = secrets.token_hex(16)
    port = reserve_port(args.port, token)
    record = {"port": port, "token": token, "startTime": time.time()}
    xvfb = wm = front_end = None
    try:
        env = dict(os.environ)
        if args.display in (None, "new"):
            display, xvfb = start_xvfb(args.size)
            record["xvfbPID"] = xvfb.pid
        elif args.display == "current":
            display = os.environ.get("DISPLAY")
            if not display:
                raise CLIError("DISPLAY is not set; pass --display :N")
        else:
            display = args.display
        env["DISPLAY"] = record["display"] = display
        write_launch_record(record)

        if args.wm and xvfb:
            wm_binary = shutil.which(args.wm_command or "xfwm4") or shutil.which("openbox")
            if wm_binary:
                wm = subprocess.Popen([wm_binary], env=env, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                                      start_new_session=True)
                record["wmPID"] = wm.pid

        record["bootstrap"] = bootstrap = write_bootstrap(port)
        env["WOLFRAMINIT"] = f'-initfile "{bootstrap}"' if " " in bootstrap else f"-initfile {bootstrap}"
        env["CHATBOOK_FE_SERVER_PORT"] = str(port)
        env["CHATBOOK_FE_SERVER_TOKEN"] = token
        env["CHATBOOK_FE_SERVER_NAME"] = args.name or f"fe-{port}"
        env["CHATBOOK_FE_SERVER_REGISTRY"] = registry_dir()
        if chatbook:
            env["CHATBOOK_FE_SERVER_CHATBOOK"] = chatbook
        else:
            env.pop("CHATBOOK_FE_SERVER_CHATBOOK", None)

        record["log"] = log_path = os.path.join(state_dir(), f"frontend-{port}.log")
        with open(log_path, "w") as log:
            front_end = subprocess.Popen([front_end_path], env=env, stdout=log, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, start_new_session=True)
        record["launcherPID"] = front_end.pid
        write_launch_record(record)

        deadline = time.time() + args.timeout
        while True:
            if front_end.poll() is not None:
                raise CLIError(f"The front end exited early (code {front_end.returncode}); see {log_path}")
            info = read_json(os.path.join(registry_dir(), f"{port}.json"))
            if info and info.get("Token") == token:
                break
            if time.time() > deadline:
                raise CLIError(f"Timed out waiting for the front end server on port {port}; see {log_path}")
            time.sleep(0.5)

        info["_launch"] = record
        server = Server(info)
        while not server.request("ping", timeout=30).get("ready"):
            if time.time() > deadline:
                raise CLIError(f"Timed out waiting for the front end connection on port {port}; see {log_path}")
            time.sleep(0.5)
        if chatbook:
            # Init.wl loads it quietly; make sure tests really run against this Chatbook:
            loaded = server.request("info").get("ChatbookLocation")
            if not isinstance(loaded, str) or os.path.realpath(loaded) != chatbook:
                raise CLIError(f"The front end loaded Chatbook from {loaded!r} instead of {chatbook}")
        if not args.keep_welcome:
            close_startup_windows(server, private_display=bool(xvfb))
    except BaseException:
        # Don't leave a half-started front end (or its Xvfb) running without a way to stop it:
        if front_end and front_end.poll() is None:
            try:
                os.killpg(front_end.pid, signal.SIGKILL)
            except OSError:
                pass
        for process in (wm, xvfb):
            if process and process.poll() is None:
                process.terminate()
        remove_registry(port)
        if record.get("bootstrap") and os.path.exists(record["bootstrap"]):
            os.remove(record["bootstrap"])
        raise
    result = {"port": port, "name": info.get("Name"), "display": display, "frontEndPID": info.get("FrontEndPID"),
              "kernelPID": info.get("KernelPID"), "log": log_path}
    emit(args, result, f"Front end server {info.get('Name')} running on port {port}, display {display} "
                       f"(front end pid {info.get('FrontEndPID')}).\nUse: fe.py -s {port} <command>")


def close_startup_windows(server, private_display):
    """Leave a single blank notebook: close the Welcome screen (it is not a notebook, so close it through X11),
    the "no open windows" launcher dialog, and the Messages window if it is empty."""
    try:
        # A regular notebook must exist first, otherwise closing the Welcome screen opens the launcher dialog:
        server.evaluate("CreateDocument[]", timeout=20)
    except (CLIError, ServerError):
        pass
    try:
        with server.x_display() as d:
            deadline = time.time() + 8
            while time.time() < deadline:
                welcome = [w for w in server.fe_windows(d)[0] if w["name"].startswith("Welcome to Wolfram")]
                if welcome:
                    for w in welcome:
                        d.activate(w["id"])
                        time.sleep(0.3)
                        # On a shared display, only send the key if it really goes to the Welcome screen:
                        if private_display or d.toplevel_frame(d.focused_window()) == d.toplevel_frame(w["id"]):
                            d.key("ctrl+w")
                    break
                time.sleep(0.3)
    except Exception:  # noqa: BLE001 - tidying up is best effort
        pass
    cleanup = ('NotebookClose /@ Select[Notebooks[], AbsoluteCurrentValue[#, WindowTitle] === "Wolfram" && '
               'AbsoluteCurrentValue[#, WindowFrame] === "ModelessDialog" &]; '
               'If[MatchQ[MessagesNotebook[], _NotebookObject] && Cells[MessagesNotebook[]] === {}, '
               'NotebookClose[MessagesNotebook[]]]; '
               'SetSelectedNotebook /@ Take[Select[Notebooks[], AbsoluteCurrentValue[#, WindowFrame] === "Normal" && '
               'AbsoluteCurrentValue[#, Visible] && # =!= MessagesNotebook[] &], UpTo[1]];')
    for _ in range(4):  # dialogs can appear asynchronously after the Welcome screen closes
        time.sleep(0.5)
        try:
            server.evaluate(cleanup, timeout=10)
        except (CLIError, ServerError):
            pass


def cmd_stop(args):
    server = Server(select_server(args.server, include_dead_launched=True))
    launch = server.info.get("_launch")
    if args.server_only or not launch:
        if not launch and not args.server_only:
            print("This server runs in a front end that fe.py did not launch, so only the server is stopped.")
        try:
            server.request("evaluate", {"code": "Wolfram`ChatbookFrontEndServer`StopFrontEndServer[]"}, timeout=10)
        except (CLIError, ServerError):
            pass
        # Keep the launch record of a launched front end, so that it can still be stopped completely later:
        remove_registry(server.port, keep_launch=bool(launch))
        print(f"Stopped the server on port {server.port}" + (" (the front end is still running)" if launch else ""))
        return
    if server.info["_alive"]:
        try:
            server.request("evaluate", {"code": "SetOptions[#, Saveable -> False] & /@ Notebooks[]; "
                                                "FrontEndTokenExecute[\"FrontEndQuit\"]"}, timeout=5)
        except (CLIError, ServerError):
            pass
        deadline = time.time() + 10
        while time.time() < deadline and pid_is(server.info.get("FrontEndPID"), "frontend", server_started(server.info)):
            time.sleep(0.25)
    kill_launched(launch, server.info)
    remove_registry(server.port)
    bootstrap = launch.get("bootstrap")
    if bootstrap and os.path.exists(bootstrap):
        os.remove(bootstrap)
    print(f"Stopped front end server on port {server.port}")


# ---------------------------------------------------------------------------------------------------------------------
# Commands: evaluation and inspection
# ---------------------------------------------------------------------------------------------------------------------

def cmd_info(args):
    server = Server(select_server(args.server))
    result = server.request("info")
    result["Display"] = server.display
    if server.display:
        try:
            result["PixelsPerPoint"] = server.scale()
        except (CLIError, ServerError, OSError) as e:
            result["PixelsPerPoint"] = f"unknown ({e})"
    emit(args, result)


def format_eval(result):
    value = result.get("result", "")
    lines = [value if isinstance(value, str) else json.dumps(value, ensure_ascii=False)]
    for m in result.get("messages") or []:
        lines.append("[message] " + m.strip())
    for o in result.get("output") or []:
        lines.append("[print] " + o)
    image = result.get("image")
    if image and image.get("path"):
        lines.append(f"[image] {image['path']} ({image.get('width')}x{image.get('height')})")
    if result.get("timedOut"):
        lines.append("[timed out]")
    return "\n".join(lines)


def cmd_eval(args):
    server = Server(select_server(args.server))
    code = read_code(args.code)
    if args.cell:
        started = server.request("evaluateCell", {"code": code, "notebook": args.notebook})
        if args.no_wait:
            return emit(args, started, f"cell {started['cell']} in notebook {started['notebook']}")
        status = wait_for_cell(server, started["cell"], args.timeout, args.max)
        status["cell"] = started["cell"]
        if args.json:
            return emit(args, status)
        for out in status["outputs"]:
            print(f"[{style_name(out['style'])} {out['id']}] {out['text']}")
        if status["evaluating"]:
            print(f"[still evaluating after {args.timeout}s; cell {started['cell']}]")
            sys.exit(2)
        return
    result = server.request("evaluate", {"code": code, "timeout": args.timeout, "maxCharacters": args.max,
                                         "form": args.form,
                                         "imagePath": os.path.abspath(args.image) if args.image else None},
                            timeout=args.timeout + 10)
    emit(args, result, format_eval(result))
    if result.get("timedOut"):
        sys.exit(2)


def style_name(style):
    return style if isinstance(style, str) else "/".join(style or [])


def wait_for_cell(server, cell, timeout, max_chars=None):
    """Poll until the cell has finished evaluating. Since requests are processed by the kernel's main loop, a poll
    issued while the cell is still evaluating is only answered once the kernel is free again."""
    deadline = time.time() + timeout
    delay = 0.1
    while True:
        remaining = max(5.0, deadline - time.time())
        try:
            status = server.request("cellStatus", {"cell": cell, "maxCharacters": max_chars}, timeout=remaining)
        except CLIError:
            if time.time() > deadline:
                return {"evaluating": True, "outputs": []}
            raise
        if not status["evaluating"] or time.time() > deadline:
            return status
        time.sleep(delay)
        delay = min(delay * 1.5, 1.0)


def cmd_wait(args):
    server = Server(select_server(args.server))
    start = time.time()
    deadline = start + args.timeout
    if args.code is None:
        # Requests are processed by the kernel's main loop, so "sync" is answered once the kernel is free; it also
        # reports cells that were sent with `eval --cell` but have not been evaluated yet.
        while True:
            status = server.request("sync", timeout=max(5.0, deadline - time.time()))
            if status.get("idle", True):
                print(f"kernel idle after {time.time() - start:.1f}s")
                return
            if time.time() > deadline:
                print(f"timed out after {args.timeout}s; {status.get('pending')} cell(s) still pending")
                sys.exit(1)
            time.sleep(args.interval)
    code = read_code(args.code)
    while True:
        remaining = max(5.0, deadline - time.time())
        result = server.request("evaluate", {"code": f"TrueQ[{code}]", "timeout": 20}, timeout=remaining + 20)
        if result.get("result") == "True":
            print(f"condition true after {time.time() - start:.1f}s")
            return
        if time.time() > deadline:
            print(f"timed out after {args.timeout}s; last value: {result.get('result')}")
            for m in result.get("messages") or []:
                print("[message] " + m.strip())
            sys.exit(1)
        time.sleep(args.interval)


def cmd_notebooks(args):
    server = Server(select_server(args.server))
    nbs = server.request("notebooks", {"includeHidden": args.all})
    if args.json or not isinstance(nbs, list):
        return emit(args, nbs)
    for nb in nbs:
        rect = nb.get("rect") or {}
        flags = [nb["kind"]] + (["selected"] if nb.get("selected") else []) + ([] if nb.get("visible") else ["hidden"])
        print(f"{nb['id']}  {nb.get('title')!r:<40} cells={nb.get('cells'):<4} {','.join(flags)}  "
              f"style={nb.get('styleSheet')}  frame={nb.get('windowFrame')}  "
              f"rect={rect.get('left')},{rect.get('top')} {rect.get('width')}x{rect.get('height')}pt")


def cmd_cells(args):
    server = Server(select_server(args.server))
    cells = server.request("cells", {"notebook": args.notebook, "attached": args.attached or None,
                                     "sidebar": args.sidebar or None, "style": args.style, "maxCharacters": args.max})
    if args.json:
        return emit(args, cells)
    if not cells:
        print("(no cells)")
    for c in cells:
        flags = "".join([" [evaluating]" if c.get("evaluating") else "", " [generated]" if c.get("generated") else ""])
        tags = f" tags={c['tags']}" if c.get("tags") else ""
        text = (c.get("text") or "").replace("\n", "\\n").replace("\t", "\\t")
        ref = c.get("ref") or c["id"]
        ref = f"'{ref}'" if ref.startswith("CellObject") else ref
        print(f"{c['index']:>3} {ref}  {style_name(c.get('style')):<18}{flags}{tags}  {text}")


def cmd_read(args):
    server = Server(select_server(args.server))
    result = server.request("readCell", {"cell": args.cell, "format": args.format, "maxCharacters": args.max})
    emit(args, result, result["text"])


def cmd_messages(args):
    server = Server(select_server(args.server))
    msgs = server.request("messages", {"clear": args.clear or None})
    if args.json:
        return emit(args, msgs)
    if not msgs:
        print("(Messages window is empty)")
    for m in msgs:
        print(f"[{style_name(m.get('style'))}] {m.get('text')}")


def cmd_token(args):
    server = Server(select_server(args.server))
    emit(args, server.request("token", {"token": args.token, "notebook": args.notebook, "parameter": args.param}),
         f"executed {args.token}")


def cmd_select(args):
    server = Server(select_server(args.server))
    nb = server.request("select", {"notebook": args.notebook})
    if server.display and not args.no_x:
        try:
            with server.x_display() as d:
                window = server.match_window(d, nb)
                d.activate(window["id"])
        except Exception:
            pass
    emit(args, nb, f"selected {nb['title']!r} ({nb['id']})")


def cmd_close(args):
    server = Server(select_server(args.server))
    emit(args, server.request("close", {"notebook": args.notebook, "save": args.save or None}), f"closed {args.notebook}")


def cmd_raw(args):
    server = Server(select_server(args.server))
    payload = json.loads(args.args) if args.args else {}
    emit(args, server.request(args.command, payload, timeout=args.timeout))


def cmd_reload(args):
    server = Server(select_server(args.server))
    path = os.path.join(HERE, "FrontEndServer.wl").replace("\\", "/")
    # PreemptProtect: socket events arriving while definitions are being replaced would be lost
    result = server.request("evaluate", {"code": f'PreemptProtect[Get["{path}"]]; '
                                                 'Wolfram`ChatbookFrontEndServer`FrontEndServerInformation[]["Port"]'})
    emit(args, result, f"reloaded server code (port {result.get('result')})")


# ---------------------------------------------------------------------------------------------------------------------
# Commands: screenshots and X11
# ---------------------------------------------------------------------------------------------------------------------

def cmd_screenshot(args):
    server = Server(select_server(args.server))
    if not 0 < args.scale <= 1:
        raise CLIError("--scale must be in (0, 1]")
    if args.fe or not server.display:
        result = server.request("rasterize", {"notebook": args.target, "cell": args.cell, "screen": args.screen or None,
                                              "path": os.path.abspath(args.output) if args.output else None})
        # Such an image has no known screen position, so `click --image` must not use it:
        if os.path.exists(screenshot_state_path(server)):
            os.remove(screenshot_state_path(server))
        return emit(args, result, f"{result['path']} ({result['width']}x{result['height']}, front end rendered)")

    with server.x_display() as d:
        label = "screen"
        if args.region:
            x, y, w, h = (int(float(v)) for v in args.region.split(","))
        elif args.screen:
            x, y, w, h = 0, 0, d.width, d.height
        elif args.window:
            wid = int(args.window, 0)
            geo = d.geometry(wid)
            if not geo:
                raise CLIError(f"No such window {args.window}")
            x, y, w, h = geo[:4]
            label = f"window-{args.window}"
        elif args.cell:
            located = server.request("locate", {"cell": args.cell})
            if located.get("coordinates") != "Document":
                nb = server.request("select", {"notebook": located["notebook"]})
                d.activate(server.match_window(d, nb)["id"])
            rects = pixel_rects(server, d, located)
            if not rects:
                raise CLIError("The cell has no on-screen rectangle (is it scrolled out of view?)")
            # Don't capture the selection highlight that locating the cell left behind:
            server.request("deselect", {"notebook": located["notebook"]})
            time.sleep(args.delay)
            x, y, w, h = bounding_pixels(rects, pad=args.pad or 8)
            content = located.get("content") or {}
            if content:
                scale = server.scale(d)
                if y < content["top"] * scale - 2 or y + h > (content["top"] + content["height"]) * scale + 2:
                    print("note: the cell is only partly visible; the screenshot is clipped", file=sys.stderr)
            label = "cell"
        else:
            nb = server.request("notebook", {"notebook": args.target or "selected"})
            if not args.no_raise:
                server.request("select", {"notebook": nb["id"]})
            window = server.match_window(d, nb)
            if not args.no_raise:
                d.activate(window["id"])
                time.sleep(args.delay)
            x, y, w, h = window["x"], window["y"], window["width"], window["height"]
            label = nb.get("title") or "notebook"
        if args.pad and not args.cell:
            x, y, w, h = x - args.pad, y - args.pad, w + 2 * args.pad, h + 2 * args.pad
        # Clip to the screen, keeping the right and bottom edges where they are:
        x1, y1 = min(x + w, d.width), min(y + h, d.height)
        x, y = max(0, x), max(0, y)
        w, h = x1 - x, y1 - y
        if w <= 0 or h <= 0:
            raise CLIError("The requested region is outside the screen")
        path = args.output or default_screenshot_path(server, label)
        shot = d.screenshot(path, x, y, w, h, scale=args.scale)

    downscale = shot["width"] / w  # what was actually applied
    state = {"path": path, "x": x, "y": y, "width": w, "height": h, "scale": downscale, "time": time.time()}
    with open(screenshot_state_path(server), "w") as f:
        json.dump(state, f)
    emit(args, dict(shot, origin=[x, y], downscale=downscale),
         f"{path} ({shot['width']}x{shot['height']} px; screen origin {x},{y}"
         + (f"; downscaled {downscale:.2f}x" if downscale != 1 else "") + ")")


def pixel_rects(server, d, located):
    """Convert the front end rectangles (points) from a `locate` result to screen pixel rectangles."""
    scale = server.scale(d)
    dx = dy = 0
    if located.get("scope") in ("Docked", "Sidebar"):
        try:
            nb = server.request("notebook", {"notebook": located["notebook"]})
            window = server.match_window(d, nb)
            if located["scope"] == "Docked":
                # Docked boxes come relative to the docked area, which starts at the top of the window's client
                # area, below the menu bar on Linux (19 px at 96 dpi, i.e. 14.25 points):
                dy = window["y"] + (MENU_BAR_POINTS * scale if located.get("menuBar") else 0)
            elif located.get("content"):
                # Boxes in the sidebar are reported with x relative to the content area, which starts to the right of
                # the sidebar; the sidebar itself starts at the window's left edge.
                dx = window["x"] - located["content"]["left"] * scale
        except (CLIError, ServerError):
            pass
    rects = [{"x": r["left"] * scale + dx, "y": r["top"] * scale + dy, "width": r["width"] * scale,
              "height": r["height"] * scale} for r in located.get("rects") or []]
    if located.get("coordinates") == "Document" and rects:
        rects = find_selection_on_screen(server, d, located, rects)
    return rects


def is_whole_cell(located):
    return located.get("target") == "Cell" or located.get("match") == "Cell"


HIGHLIGHT = (48, 140, 198)  # the front end's selection background
MENU_BAR_POINTS = 14.25


def find_selection_on_screen(server, d, located, rects):
    """Text selections in text cells are reported in document coordinates: x is right, but y depends on the scroll
    position, which the front end doesn't expose. The selection has been scrolled into view, so find its highlight
    within the notebook's content area."""
    scale = server.scale(d)
    content = located.get("content") or {}
    nb = server.request("select", {"notebook": located["notebook"]})
    window = server.match_window(d, nb)
    d.activate(window["id"])
    time.sleep(0.3)
    top = int(content.get("top", 0) * scale) or window["y"]
    height = int(content.get("height", 0) * scale) or window["height"]
    if is_whole_cell(located):
        # A selected cell is reported as one rectangle between its caret positions; search the whole content width
        # and take the union of its highlighted lines.
        left, width = int(content.get("left", 0) * scale) or window["x"], int(content.get("width", 0) * scale) or window["width"]
        rects = [{"x": left, "y": 0, "width": width, "height": rects[0]["height"], "union": True}]
    # The front end may not have repainted the new selection yet: wait until two captures agree.
    previous = None
    for _ in range(6):
        found = highlight_bands(d, rects, top, height)
        if found and found == previous:
            return found
        previous = found
        time.sleep(0.25)
    if not found:
        raise CLIError("The selected text is not visible on screen (could not find its highlight)")
    return found


def highlight_bands(d, rects, top, height):
    found = []
    for r in rects:
        x0, x1 = int(r["x"]) + 1, int(r["x"] + r["width"]) - 1
        if x1 - x0 < 2:
            continue
        w, h, rgb = d.capture(x0, top, x1 - x0, height)
        rows = []
        for row in range(h):
            line = rgb[row * w * 3:(row + 1) * w * 3]
            hits = sum(1 for i in range(0, len(line), 3)
                       if abs(line[i] - HIGHLIGHT[0]) < 40 and abs(line[i + 1] - HIGHLIGHT[1]) < 40
                       and abs(line[i + 2] - HIGHLIGHT[2]) < 40)
            rows.append(hits > (2 if r.get("union") else 0.25 * w))
        bands, start = [], None
        for i, hit in enumerate(rows + [False]):
            if hit and start is None:
                start = i
            elif not hit and start is not None:
                bands.append((start, i))
                start = None
        if bands and r.get("union"):
            found.append({"x": r["x"], "y": top + bands[0][0], "width": r["width"], "height": bands[-1][1] - bands[0][0]})
        elif bands:
            b0, b1 = min(bands, key=lambda b: abs((b[1] - b[0]) - r["height"]))
            found.append({"x": r["x"], "y": top + b0, "width": r["width"], "height": b1 - b0})
    return found


def bounding_pixels(rects, pad=0):
    x0 = int(min(r["x"] for r in rects)) - pad
    y0 = int(min(r["y"] for r in rects)) - pad
    x1 = int(max(r["x"] + r["width"] for r in rects) + 0.999) + pad
    y1 = int(max(r["y"] + r["height"] for r in rects) + 0.999) + pad
    return x0, y0, x1 - x0, y1 - y0


def cmd_windows(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        own, popups = server.fe_windows(d)
        rows = own + [p for p in popups if p not in own]
        if args.all:
            rows = d.windows()
        focused = d.focused_window()
    if args.json:
        return emit(args, rows)
    for w in rows:
        flags = []
        if w["override_redirect"]:
            flags.append("popup")
        if w["id"] == focused:
            flags.append("focused")
        print(f"0x{w['id']:x}  {w['name']!r:<44} {w['x']},{w['y']} {w['width']}x{w['height']}  pid={w['pid']} "
              f"{' '.join(flags)}")


def resolve_point(server, d, args):
    """Turn click/move target arguments into root-window pixel coordinates."""
    if getattr(args, "image", None):
        state = read_json(screenshot_state_path(server))
        if not state:
            raise CLIError("No previous screenshot; take one with `fe.py screenshot` first")
        u, v = parse_point(args.image)
        scale = state.get("scale") or 1.0
        return state["x"] + u / scale, state["y"] + v / scale
    if getattr(args, "box", None) or getattr(args, "text", None) or getattr(args, "cell", None):
        rects = pixel_rects(server, d, server.request("locate", locate_args(args)))
        if not rects:
            raise CLIError("Target was found but has no on-screen rectangle (is it scrolled out of view?)")
        r = rects[0]
        fx, fy = (0.5, 0.5) if not args.at else parse_point(args.at)
        return r["x"] + r["width"] * fx, r["y"] + r["height"] * fy
    if getattr(args, "point", None):
        x, y = parse_point(args.point)
        if getattr(args, "window", None):
            nb = server.request("notebook", {"notebook": args.window})
            window = server.match_window(d, nb)
            return window["x"] + x, window["y"] + y
        return x, y
    raise CLIError("Give a point (x,y), --image u,v, --box ID, --text TEXT, or --cell ID")


def locate_args(args):
    if not (args.box or args.text or args.cell):
        raise CLIError("Give a target: --box BOXID, --text TEXT, or --cell CELLID")
    return {"notebook": args.notebook, "boxID": args.box, "text": args.text, "cell": args.cell,
            "occurrence": args.occurrence, "scope": SCOPES.get(getattr(args, "within", None))}


SCOPES = {"notebook": "Notebook", "docked": "Docked", "attached": "Attached", "sidebar": "Sidebar"}


def cmd_locate(args):
    server = Server(select_server(args.server))
    located = server.request("locate", locate_args(args))
    with server.x_display() as d:
        pixels = [{k: round(v) for k, v in r.items()} for r in pixel_rects(server, d, located)]
        located["scale"] = server.scale(d)
    located["pixels"] = pixels
    text = "\n".join(f"{p['x']},{p['y']} {p['width']}x{p['height']} px  (center {p['x'] + p['width'] // 2},"
                     f"{p['y'] + p['height'] // 2})" for p in pixels) or "(no rectangles)"
    if located.get("match") == "Cell":
        text += "\n(the text is not directly searchable here; this is the rectangle of the cell that contains it)"
    emit(args, located, text)


def cmd_click(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        x, y = resolve_point(server, d, args)
        if args.offset:
            dx, dy = parse_point(args.offset)
            x, y = x + dx, y + dy
        if not (0 <= x < d.width and 0 <= y < d.height):
            raise CLIError(f"The point {round(x)},{round(y)} is outside the screen ({d.width}x{d.height})")
        button = {"left": 1, "middle": 2, "right": 3}[args.button]
        mods = [m for m in (args.mods or "").split("+") if m]
        d.click(x, y, button=button, count=2 if args.double else 1, modifiers=mods)
    print(f"clicked {args.button} at {round(x)},{round(y)}")


def cmd_press(args):
    server = Server(select_server(args.server))
    result = server.request("press", {"boxID": args.box, "notebook": args.notebook,
                                      "scope": SCOPES.get(args.within)})
    emit(args, result, f"pressed {args.box} ({result.get('scope')}; triggered={result.get('triggered')})")


def cmd_move(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        x, y = resolve_point(server, d, args)
        d.move(x, y)
    print(f"moved to {round(x)},{round(y)}")


def cmd_scroll(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        x, y = resolve_point(server, d, args) if (args.point or args.image) else d.pointer()
        d.scroll(x, y, args.clicks, horizontal=args.horizontal)
    print(f"scrolled {args.clicks} at {round(x)},{round(y)}")


def cmd_drag(args):
    server = Server(select_server(args.server))
    x0, y0 = parse_point(args.start)
    x1, y1 = parse_point(args.end)
    with server.x_display() as d:
        d.drag(x0, y0, x1, y1)
    print(f"dragged {x0},{y0} -> {x1},{y1}")


def ensure_front_end_focus(server, d, force=False):
    """Refuse to send keystrokes when the keyboard focus is not in one of this front end's windows: on a shared
    desktop they would go to some other application (e.g. a terminal, where Return runs them)."""
    if force:
        return
    time.sleep(0.1)
    focused = d.focused_window()
    if focused > 1:
        top = d.toplevel_frame(focused)
        for w in server.fe_windows(d)[0]:
            if focused == w["id"] or top == d.toplevel_frame(w["id"]):
                return
    raise CLIError("The keyboard focus is not in this front end's windows, so no keys were sent. Click into the "
                   "target, use --notebook/--cell, or pass --force.")


def focus_notebook(server, d, ref):
    nb = server.request("select", {"notebook": ref})
    window = server.match_window(d, nb)
    d.activate(window["id"])
    time.sleep(0.15)


def focus_cell(server, d, cell, start=False):
    """Put the insertion point into a cell (at its end) and focus its window, so typed keys go there."""
    info = server.request("focusCell", {"cell": cell, "start": start or None})
    nb = server.request("notebook", {"notebook": info["notebook"]})
    d.activate(server.match_window(d, nb)["id"])
    time.sleep(0.15)
    return info


def cmd_focus(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        if args.cell:
            info = focus_cell(server, d, args.cell, start=args.start)
            return print(f"cursor in cell {info['cell']} of {info['title']!r}")
        focus_notebook(server, d, args.notebook)
    print(f"focused {args.notebook!r}")


def cmd_key(args):
    server = Server(select_server(args.server))
    with server.x_display() as d:
        if args.cell:
            focus_cell(server, d, args.cell)
        elif args.notebook:
            focus_notebook(server, d, args.notebook)
        ensure_front_end_focus(server, d, args.force)
        for combo in args.keys:
            d.key(combo, repeat=args.repeat)
    print("pressed " + " ".join(args.keys))


def cmd_type(args):
    server = Server(select_server(args.server))
    text = read_code(args.text)
    with server.x_display() as d:
        if args.cell:
            focus_cell(server, d, args.cell)
        elif args.notebook:
            focus_notebook(server, d, args.notebook)
        ensure_front_end_focus(server, d, args.force)
        d.type_text(text, delay=args.delay)
    print(f"typed {len(text)} characters")


def cell_ref(cell):
    """A reference that identifies a listed cell uniquely (attached cells can share ids across notebooks)."""
    return cell.get("ref") or cell["id"]


def chat_outputs(server, notebook, sidebar=False):
    cells = server.request("cells", {"notebook": notebook, "maxCharacters": 1000000, "sidebar": sidebar or None})
    return [c for c in cells if "ChatOutput" in style_name(c.get("style")) or "AssistantOutput" in style_name(c.get("style"))]


def cmd_ask(args):
    """Ask the notebook assistant (window or sidebar) a question through its real input field, and print the reply."""
    server = Server(select_server(args.server))
    sidebar = args.sidebar is not None
    notebook = args.sidebar or args.notebook
    before = {cell_ref(c) for c in chat_outputs(server, notebook, sidebar)}
    target = argparse.Namespace(image=None, box="AttachedChatInputField", text=None, cell=None, notebook=notebook,
                                occurrence=None, at=None, within="sidebar" if sidebar else None)
    with server.x_display() as d:
        # A newly opened assistant creates its input field asynchronously, and opening the sidebar moves and resizes
        # the window: wait until the field exists and its position is stable.
        deadline = time.time() + 20
        previous = None
        while True:
            try:
                point = tuple(round(v) for v in resolve_point(server, d, target))
                if point == previous:
                    break
                previous = point
            except ServerError as e:
                if e.response.get("errorType") != "BoxNotFound" or time.time() > deadline:
                    raise
            if time.time() > deadline:
                raise CLIError("The assistant's input field did not settle; take a screenshot")
            time.sleep(0.7)
        x, y = point
        d.click(x, y)
        time.sleep(0.2)
        ensure_front_end_focus(server, d)
        d.key("ctrl+a")
        d.type_text(read_code(args.question))
        time.sleep(0.2)
        d.key("Return")
    start = time.time()
    while True:
        time.sleep(1.0)
        remaining = args.timeout - (time.time() - start)
        # Queued requests wait while the chat's evaluation is running:
        idle = server.request("evaluate", {"code": "Wolfram`Chatbook`$ChatEvaluationCell === None"},
                              timeout=max(5.0, remaining))
        new = [c for c in chat_outputs(server, notebook, sidebar) if cell_ref(c) not in before]
        if idle.get("result") == "True" and new:
            reply = server.request("readCell", {"cell": cell_ref(new[-1]), "format": args.format})
            return emit(args, reply, reply["text"])
        if time.time() - start > args.timeout:
            raise CLIError(f"No reply after {args.timeout}s (take a screenshot to see what happened)")


# ---------------------------------------------------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------------------------------------------------

def build_parser():
    parser = argparse.ArgumentParser(prog="fe.py", description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("-s", "--server", help="server port or name (default: the only running server; "
                                               "or set CHATBOOK_FE_SERVER)")
    parser.add_argument("--json", action="store_true", help="print raw JSON results")
    parser.add_argument("--timeout", dest="global_timeout", type=float,
                        help="override the timeout (seconds) of every server request")
    parser.add_argument("--preemptive", action="store_true",
                        help="process requests immediately even while the kernel is evaluating something else "
                             "(handy for inspecting a running chat; small risk of a front end deadlock)")
    sub = parser.add_subparsers(dest="cmd", metavar="COMMAND")

    def add(name, func, help, aliases=()):
        p = sub.add_parser(name, help=help, description=help, aliases=list(aliases))
        p.set_defaults(func=func)
        return p

    p = add("servers", cmd_servers, "list registered front end servers")
    p.add_argument("--prune", action="store_true", help="remove registry entries of dead servers")

    p = add("launch", cmd_launch, "start a new front end with a server")
    p.add_argument("--display", default="new",
                   help="'new' (default: private Xvfb display), 'current' ($DISPLAY), or an X display like :10")
    p.add_argument("--size", default="1920x1200", help="screen size for a new Xvfb display")
    p.add_argument("--port", type=int, help="server port (default: first free port in 2400-2499)")
    p.add_argument("--name", help="server name")
    p.add_argument("--chatbook", nargs="?", const=REPO, default=None,
                   help="load a development Chatbook paclet at startup (default path: this repository)")
    p.add_argument("--wm", action="store_true", help="run a window manager (xfwm4/openbox) on the new Xvfb display")
    p.add_argument("--wm-command", help="window manager executable to use with --wm")
    p.add_argument("--front-end", help="path to the WolframNB executable")
    p.add_argument("--keep-welcome", action="store_true", help="do not close the Welcome screen")
    p.add_argument("--timeout", type=float, default=180, help="seconds to wait for startup")
    p.add_argument("--force", action="store_true", help="launch even if little memory is available")

    p = add("stop", cmd_stop, "quit a launched front end (or stop the server in an attached one)")
    p.add_argument("--server-only", action="store_true", help="only stop the server; leave the front end running")

    add("info", cmd_info, "show server and front end information")

    p = add("eval", cmd_eval, "evaluate Wolfram Language code in the front end's kernel")
    p.add_argument("code", help="code to evaluate; '-' reads stdin, '@file' reads a file")
    p.add_argument("--cell", action="store_true", help="evaluate as an input cell through the front end (like Shift+Enter)")
    p.add_argument("--notebook", help="notebook for --cell (default: a 'Front End Server Console' notebook)")
    p.add_argument("--no-wait", action="store_true", help="with --cell, return immediately")
    p.add_argument("--timeout", type=float, default=60)
    p.add_argument("--form", default="InputForm", choices=["InputForm", "OutputForm", "String", "JSON", "TeXForm"])
    p.add_argument("--max", type=int, help="maximum result characters")
    p.add_argument("--image", help="also export the result as an image to this path")

    p = add("wait", cmd_wait, "wait until a Wolfram Language condition is True, or (without CODE) until the kernel "
                               "has finished pending evaluations")
    p.add_argument("code", nargs="?", help="condition; '-' reads stdin, '@file' reads a file")
    p.add_argument("--timeout", type=float, default=60)
    p.add_argument("--interval", type=float, default=0.5)

    p = add("notebooks", cmd_notebooks, "list notebooks", aliases=["nbs"])
    p.add_argument("--all", action="store_true", help="include hidden notebooks")

    p = add("cells", cmd_cells, "list cells of a notebook")
    p.add_argument("notebook", nargs="?", default="selected",
                   help="notebook: id, title (substring), 'selected', 'input', 'messages', or NotebookObject[...]")
    p.add_argument("--attached", action="store_true",
                   help="list docked/attached cells instead (chat bar, sidebar, overlays, ...)")
    p.add_argument("--sidebar", action="store_true", help="list the notebook assistant sidebar's cells")
    p.add_argument("--style", help="only cells with this style")
    p.add_argument("--max", type=int, default=160, help="characters of text per cell")

    p = add("read", cmd_read, "read a cell's content")
    p.add_argument("cell", help="cell id (from `cells`) or CellObject[...]")
    p.add_argument("--format", default="Plain", choices=["Plain", "InputText", "Markdown", "Expression"])
    p.add_argument("--max", type=int)

    p = add("messages", cmd_messages, "show the Messages window contents")
    p.add_argument("--clear", action="store_true", help="clear the Messages window afterwards")

    p = add("token", cmd_token, "run a front end token (menu command), e.g. EvaluateCells, SelectAll, Copy")
    p.add_argument("token")
    p.add_argument("--notebook")
    p.add_argument("--param", help="token parameter, e.g. a style name for the Style token")

    p = add("select", cmd_select, "bring a notebook window to the front and focus it")
    p.add_argument("notebook")
    p.add_argument("--no-x", action="store_true", help="do not also activate the X window")

    p = add("close", cmd_close, "close a notebook without saving")
    p.add_argument("notebook")
    p.add_argument("--save", action="store_true", help="allow the front end to save/prompt")

    p = add("screenshot", cmd_screenshot, "capture a notebook window, cell, region, or the screen to a PNG",
            aliases=["shot"])
    p.add_argument("target", nargs="?", help="notebook reference (default: selected notebook)")
    p.add_argument("-o", "--output", help="output PNG path (default: temp dir)")
    p.add_argument("--screen", action="store_true", help="capture the whole screen")
    p.add_argument("--window", help="capture an X window by id (see `windows`)")
    p.add_argument("--region", help="capture x,y,w,h in screen pixels")
    p.add_argument("--cell", help="capture just this cell (by id)")
    p.add_argument("--pad", type=int, default=0, help="extra pixels around the target")
    p.add_argument("--scale", type=float, default=1.0, help="downscale factor (e.g. 0.5)")
    p.add_argument("--no-raise", action="store_true", help="do not raise the notebook window first")
    p.add_argument("--delay", type=float, default=0.3, help="seconds to wait after raising")
    p.add_argument("--fe", action="store_true", help="let the front end render the image (no X11 needed)")

    p = add("windows", cmd_windows, "list the front end's X windows (including popups)")
    p.add_argument("--all", action="store_true", help="list all client windows on the display")

    def add_target(p, point=True):
        if point:
            p.add_argument("point", nargs="?", help="x,y in screen pixels (or relative to --window)")
            p.add_argument("--image", metavar="U,V", help="a point in the last screenshot's image coordinates")
            p.add_argument("--window", metavar="NOTEBOOK", help="make x,y relative to this notebook's window")
        p.add_argument("--box", metavar="BOXID", help="a box with this BoxID")
        p.add_argument("--text", help="the first occurrence of this text")
        p.add_argument("--cell", help="a cell id")
        p.add_argument("--notebook", help="notebook to search for --box/--text (default: selected)")
        p.add_argument("--occurrence", type=int, help="which match of --text to use (1-based)")
        p.add_argument("--in", dest="within", choices=sorted(SCOPES),
                       help="only search for --box here (e.g. sidebar vs. the chat bar, which share BoxIDs)")
        p.add_argument("--at", metavar="FX,FY", help="relative position inside the target box (default 0.5,0.5)")

    p = add("locate", cmd_locate, "print the screen rectangle of a box/text/cell")
    add_target(p, point=False)

    p = add("click", cmd_click, "click at a point or on a located target")
    add_target(p)
    p.add_argument("--button", default="left", choices=["left", "middle", "right"])
    p.add_argument("--double", action="store_true")
    p.add_argument("--mods", help="modifiers held during the click, e.g. ctrl+shift")
    p.add_argument("--offset", metavar="DX,DY", help="pixel offset added to the target point")

    p = add("press", cmd_press, "activate a button/control by BoxID through the front end (no mouse input; works "
                                 "for hidden or off-screen controls)")
    p.add_argument("box", metavar="BOXID")
    p.add_argument("--notebook", help="notebook to search (default: selected)")
    p.add_argument("--in", dest="within", choices=sorted(SCOPES), help="only search here")

    p = add("move", cmd_move, "move the mouse pointer (hover)")
    add_target(p)

    p = add("scroll", cmd_scroll, "scroll the mouse wheel")
    p.add_argument("point", nargs="?")
    p.add_argument("--image", metavar="U,V")
    p.add_argument("--window", metavar="NOTEBOOK")
    p.add_argument("--clicks", type=int, default=3, help="positive = down, negative = up")
    p.add_argument("--horizontal", action="store_true")

    p = add("drag", cmd_drag, "drag with the left button between two screen points")
    p.add_argument("start")
    p.add_argument("end")

    p = add("focus", cmd_focus, "focus a notebook window, or put the insertion point into a cell (for typing)")
    p.add_argument("notebook", nargs="?", default="selected")
    p.add_argument("--cell", help="cell id: put the insertion point at the end of this cell")
    p.add_argument("--start", action="store_true", help="with --cell, put it at the start instead")

    p = add("ask", cmd_ask, "ask the notebook assistant a question through its input field and print the reply "
                             "(makes a real LLM call)")
    p.add_argument("question", help="the question; '-' reads stdin")
    p.add_argument("--notebook", default="Wolfram AI Assistant", help="assistant window (default: %(default)s)")
    p.add_argument("--sidebar", metavar="NOTEBOOK", help="ask in the sidebar of this notebook instead (it must be open)")
    p.add_argument("--timeout", type=float, default=240)
    p.add_argument("--format", default="Markdown", choices=["Plain", "InputText", "Markdown", "Expression"])

    p = add("key", cmd_key, "press keys, e.g. `key ctrl+a BackSpace` or `key shift+Return`")
    p.add_argument("keys", nargs="+")
    p.add_argument("--notebook", help="focus this notebook first")
    p.add_argument("--cell", help="put the insertion point into this cell first")
    p.add_argument("--force", action="store_true", help="send the keys even if the focus is not in the front end")
    p.add_argument("--repeat", type=int, default=1)

    p = add("type", cmd_type, "type literal text with synthetic key presses")
    p.add_argument("text", help="text to type; '-' reads stdin")
    p.add_argument("--notebook", help="focus this notebook first")
    p.add_argument("--cell", help="put the insertion point at the end of this cell first")
    p.add_argument("--force", action="store_true", help="type even if the focus is not in the front end")
    p.add_argument("--delay", type=float, default=0.012, help="seconds between characters")

    p = add("raw", cmd_raw, "send a raw server command with JSON arguments")
    p.add_argument("command")
    p.add_argument("args", nargs="?")
    p.add_argument("--timeout", type=float, default=60)

    add("reload", cmd_reload, "reload the server's Wolfram Language code without restarting")
    return parser


def main(argv=None):
    parser = build_parser()
    args = parser.parse_args(argv)
    if not getattr(args, "func", None):
        parser.print_help()
        return 1
    Server.preemptive = args.preemptive
    Server.timeout_override = args.global_timeout
    try:
        args.func(args)
    except ServerError as e:
        if args.json:
            print(json.dumps({k: v for k, v in e.response.items() if k != "id"}, indent=1, ensure_ascii=False))
            return 1
        details = {k: v for k, v in e.response.items() if k not in ("id", "ok", "error", "errorType", "timing")}
        print(f"error ({e.response.get('errorType')}): {e.response.get('error')}", file=sys.stderr)
        if details:
            print(json.dumps(details, indent=1, ensure_ascii=False), file=sys.stderr)
        return 1
    except CLIError as e:
        if args.json:
            print(json.dumps({"ok": False, "errorType": "ClientError", "error": str(e)}, indent=1))
            return 1
        print(f"error: {e}", file=sys.stderr)
        return 1
    except Exception as e:  # noqa: BLE001
        import fe_x11
        if isinstance(e, fe_x11.X11Error):
            print(f"error (X11): {e}", file=sys.stderr)
            return 1
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main())
