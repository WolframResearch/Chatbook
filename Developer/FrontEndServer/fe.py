#!/usr/bin/env python3
"""fe.py - drive a Wolfram front end (WolframNB) from the command line.

Talks to a front end server started by StartFrontEndServer[] (Developer/FrontEndServer/FrontEndServer.wl), and uses
X11 (fe_x11.py) or, on Windows, Win32 (fe_win32.py) directly for screenshots, mouse and keyboard input.

Quick start:
    fe.py launch                        # start a fresh front end (Linux: on a private Xvfb display)
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
import hashlib
import json
import os
import re
import secrets
import select
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
WINDOWS = sys.platform.startswith("win")
SIGKILL = getattr(signal, "SIGKILL", signal.SIGTERM)  # on Windows, both terminate the process


def screen_backend():
    """The module that captures the screen and synthesizes input on this platform."""
    if WINDOWS:
        import fe_win32
        return fe_win32
    import fe_x11
    return fe_x11


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
    if hasattr(os, "getuid"):
        status = os.stat(path)
        if status.st_uid != os.getuid():
            raise CLIError(f"{path} belongs to another user; refusing to use it")
        # The server may have created it (for images) with default permissions; the logs and screenshots are private:
        if (status.st_mode & 0o777) != 0o700:
            os.chmod(path, 0o700)
    return path


def screenshot_dir():
    path = os.environ.get("CHATBOOK_FE_SCREENSHOTS") or os.path.join(state_dir(), "screenshots")
    os.makedirs(path, exist_ok=True)
    return path


def win_kernel32():
    import ctypes
    from ctypes import wintypes as wt
    kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
    kernel32.OpenProcess.restype = wt.HANDLE
    kernel32.OpenProcess.argtypes = [wt.DWORD, wt.BOOL, wt.DWORD]
    kernel32.GetExitCodeProcess.argtypes = [wt.HANDLE, ctypes.POINTER(wt.DWORD)]
    kernel32.QueryFullProcessImageNameW.argtypes = [wt.HANDLE, wt.DWORD, wt.LPWSTR, ctypes.POINTER(wt.DWORD)]
    kernel32.GetProcessTimes.argtypes = [wt.HANDLE] + [ctypes.POINTER(wt.FILETIME)] * 4
    kernel32.CreateToolhelp32Snapshot.restype = wt.HANDLE
    kernel32.CreateToolhelp32Snapshot.argtypes = [wt.DWORD, wt.DWORD]
    kernel32.CloseHandle.argtypes = [wt.HANDLE]
    kernel32.GetShortPathNameW.restype = wt.DWORD
    kernel32.GetShortPathNameW.argtypes = [wt.LPCWSTR, wt.LPWSTR, wt.DWORD]
    return kernel32


@contextlib.contextmanager
def win_process(pid):
    """A handle to query a process on Windows (None if it does not exist or cannot be opened)."""
    kernel32 = win_kernel32()
    handle = kernel32.OpenProcess(0x1000, False, int(pid))  # PROCESS_QUERY_LIMITED_INFORMATION
    try:
        yield kernel32, handle
    finally:
        if handle:
            kernel32.CloseHandle(handle)


def win_short_path(path):
    """The 8.3 short form of an existing path on Windows (the path itself if it has none)."""
    import ctypes
    kernel32 = win_kernel32()
    size = kernel32.GetShortPathNameW(path, None, 0)  # including the terminating null
    buffer = ctypes.create_unicode_buffer(size)
    return buffer.value if size and 0 < kernel32.GetShortPathNameW(path, buffer, size) < size else path


def in_code_page(text):
    """Whether text can be written in the Windows system code page (without best-fit replacements)."""
    try:
        text.encode("mbcs")
        return True
    except UnicodeEncodeError:
        return False


def command_line_path(path):
    """A file in the state directory as the front end can pass it on the command line of a program it starts (the
    LinkSnooper of `snoop`). On Windows, that command line goes through the system code page, so a directory whose
    path has other characters (e.g. from the user name) is given by its 8.3 short name."""
    if WINDOWS and not in_code_page(path):
        directory, name = os.path.split(path)
        path = os.path.join(win_short_path(directory), name)
        if not in_code_page(path):
            # (Windows gives no short name to a name that already fits 8.3 after best-fit mapping, e.g. "Łukasz".)
            raise CLIError(f"Cannot log to {directory}: its path has characters outside the system code page that 8.3 "
                           f"short names do not avoid. The front end passes the command line that starts LinkSnooper "
                           f"(Java) in that code page, so Java would not find the log. Run all fe.py commands with the "
                           f"temp directory (TMPDIR, which Git Bash sets, or else TEMP) and, if your user name has "
                           f"such characters, LOGNAME set to plain names.")
    return path


def pid_alive(pid):
    if not pid:
        return False
    if WINDOWS:
        # os.kill(pid, 0) would terminate the process on Windows; ask the process table instead.
        import ctypes
        from ctypes import wintypes as wt
        with win_process(pid) as (kernel32, handle):
            code = wt.DWORD()
            return bool(handle) and bool(kernel32.GetExitCodeProcess(handle, ctypes.byref(code))) and code.value == 259
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
    "kernel": {"WolframKernel", "MathKernel", "wolfram"},
    "frontend": {"WolframNB", "Mathematica"},
    "snooper": {"java", "javaw"},  # LinkSnooper between the front end and a kernel (see `snoop`)
    "xvfb": {"Xvfb"},
    "wm": {"xfwm4", "openbox"},
}
SHELLS = {"sh", "bash", "dash", "zsh"}  # the WolframNB launcher is a shell script


def executable_name(path):
    """The name that PROCESS_NAMES lists for an executable path (on Windows without ".exe", in lower case)."""
    name = os.path.basename(path)
    return os.path.splitext(name)[0].lower() if WINDOWS else name


def win_process_info(pid):
    """([executable path], start time as a Unix time) of a Windows process, or None."""
    import ctypes
    from ctypes import wintypes as wt
    with win_process(pid) as (kernel32, handle):
        if not handle:
            return None
        size = wt.DWORD(32768)
        path = ctypes.create_unicode_buffer(size.value)
        times = [wt.FILETIME() for _ in range(4)]
        if (not kernel32.QueryFullProcessImageNameW(handle, 0, path, ctypes.byref(size))
                or not kernel32.GetProcessTimes(handle, *(ctypes.byref(t) for t in times))):
            return None
        created = (times[0].dwHighDateTime << 32) | times[0].dwLowDateTime  # 100 ns intervals since 1601
        return [path.value], created / 1e7 - 11644473600


def win_process_table():
    """{process id: parent process id} of all Windows processes. Windows does not update the parent id when a parent
    exits, so it can name an unrelated process that later got the same id: check identities and start times."""
    import fe_win32
    return {pid: parent for pid, parent, _ in fe_win32.processes()}


def process_info(pid):
    """(argv, start time as a Unix time) of a process, or None if they cannot be determined. On Windows, argv only
    holds the executable's path."""
    pid = int(pid)
    if WINDOWS:
        return win_process_info(pid)
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
    names = {executable_name(n) for n in PROCESS_NAMES[kind]}
    exe = executable_name(argv[0])
    if exe not in names and not (exe in SHELLS and len(argv) > 1 and os.path.basename(argv[1]) in names):
        return False
    # Any Java program could have that name; where the arguments are known (not on Windows), require LinkSnooper's:
    if kind == "snooper" and len(argv) > 1 and not any("LinkSnooper" in a for a in argv):
        return False
    earliest, latest = started
    return (earliest is None or start >= earliest - 2) and (latest is None or start <= latest + 2)


def kill_pid(pid, kind, sig=signal.SIGTERM, started=(None, None)):
    if pid_is(pid, kind, started):
        kernels = []
        if WINDOWS and kind == "frontend":
            # Also end the front end's kernels (including its sandbox kernel, which fe.py does not track): its child
            # processes that are kernels and started after it (see win_process_table), and LinkSnooper processes
            # between it and a kernel (`snoop`) with their kernels.
            begun = (process_info(pid) or (None, None))[1]
            table = win_process_table()
            children = [child for child, parent in table.items() if parent == int(pid) and begun]
            snoopers = [child for child in children if pid_is(child, "snooper", (begun, None))]
            kernels = [child for child, parent in table.items() if (child in children or parent in snoopers)
                       and pid_is(child, "kernel", (begun, None))] + snoopers
        for target in [pid] + kernels:
            try:
                os.kill(int(target), sig)  # TerminateProcess on Windows
            except OSError:
                pass


def read_json(path):
    try:
        with open(path, encoding="utf-8") as f:
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
        fill_front_end_pid(info)
        launch = read_json(os.path.join(directory, f"{info['Port']}.launch.json"))
        # A launch record only belongs to this server if it was written for the same token (records can be left
        # behind, and an unrelated server may later get the same port):
        info["_launch"] = launch if launch_belongs_to(launch, info) else None
        info["_alive"] = server_alive(info)
        entries.append(info)
    return entries


def server_alive(info):
    """Whether a registered server is running: its kernel process when that can be identified (strict identity checks
    are needed before signalling anyway), otherwise whether it answers an authenticated ping."""
    pid = info.get("KernelPID")
    if not pid_alive(pid):
        return False
    if process_info(pid) is not None:
        return pid_is(pid, "kernel", server_started(info))
    try:
        with socket.create_connection((info.get("Host", "127.0.0.1"), info["Port"]), timeout=1) as sock:
            sock.settimeout(2)
            sock.sendall((json.dumps({"id": 0, "token": info.get("Token"), "command": "ping"}) + "\n").encode())
            data = b""
            while not data.endswith(b"\n"):
                chunk = sock.recv(65536)
                if not chunk:
                    break
                data += chunk
            return json.loads(data.decode("utf-8").split("\n")[0]).get("ok") is True
    except (OSError, KeyError, ValueError):
        return False


def fill_front_end_pid(info):
    """The server reports its kernel's parent process as the front end's. On Windows, servers started by older versions
    of FrontEndServer.wl report 0 instead (that is what $ParentProcessID gives there); the parent is then looked up.
    A kernel that runs through LinkSnooper (`snoop`) is the child of a Java process, which is the front end's child."""
    kernel, parent = info.get("KernelPID"), info.get("FrontEndPID")
    started = server_started(info)
    child, looked_up = kernel, False
    if WINDOWS and not parent and pid_is(kernel, "kernel", started):
        parent, looked_up = win_process_table().get(kernel), True
    if parent and pid_is(parent, "snooper", started):
        info["SnooperPID"] = child = parent
        parent, looked_up = parent_pid(parent), True
    if looked_up:
        # The kernel's (and LinkSnooper's) id is not reused while it runs, but its recorded parent id may have been:
        child_info = process_info(child)
        if child_info and pid_is(parent, "frontend", (None, child_info[1])):
            info["FrontEndPID"] = parent
        elif info.get("SnooperPID"):
            info["FrontEndPID"] = None  # not the Java process, in any case
    return info


def parent_pid(pid):
    """The parent of a process, or None."""
    if WINDOWS:
        return win_process_table().get(int(pid))
    try:
        with open(f"/proc/{int(pid)}/stat") as f:
            return int(f.read().rsplit(")", 1)[1].split()[1])  # field 4: the parent's id
    except (OSError, ValueError, IndexError):
        pass
    if os.path.isdir("/proc"):
        return None
    try:  # no procfs (e.g. macOS)
        out = subprocess.run(["ps", "-o", "ppid=", "-p", str(int(pid))], capture_output=True, text=True, timeout=5)
        return int(out.stdout.strip())
    except (OSError, ValueError, subprocess.SubprocessError):
        return None


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
    return ", ".join(f"{e['Port']} ({e.get('Name')}, display {Server(e).display})" for e in entries) or "none"


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
        self._sock = None
        self._buffer = b""

    @property
    def display(self):
        launch = self.info.get("_launch") or {}
        # On Windows, front ends run on the interactive desktop:
        return launch.get("display") or self.info.get("Display") or ("desktop" if WINDOWS else None)

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

    # All requests of a Server object share one connection: the kernel's socket library does not free everything a
    # connection used when the client hangs up (about 4 handles per connection on Windows), and the server stops
    # answering after a few hundred connections. Responses carry the request id; others (to pings) are skipped.
    def _connection(self, timeout):
        if self._sock is not None and self._peer_closed():
            # The kernel quit or was replaced (e.g. by `snoop`) since the last request; nothing was sent yet:
            self.close()
        if self._sock is None:
            try:
                self._sock = socket.create_connection((self.host, self.port), timeout=min(10.0, timeout))
            except OSError as e:
                raise CLIError(f"Cannot connect to the front end server on port {self.port}: {e}")
            self._buffer = b""
        return self._sock

    def _peer_closed(self):
        """Whether the server has closed the idle connection. Reads what has arrived (e.g. late answers to pings)."""
        try:
            while select.select([self._sock], [], [], 0)[0]:
                chunk = self._sock.recv(1 << 20)
                if not chunk:
                    return True
                self._buffer += chunk
        except OSError:
            return True
        return False

    def close(self):
        if self._sock is not None:
            try:
                self._sock.close()
            except OSError:
                pass
        self._sock = None
        self._buffer = b""

    def _take_response(self, request_id):
        """The response to `request_id` if it has arrived completely (skipping responses to pings), else None."""
        while b"\n" in self._buffer:
            line, self._buffer = self._buffer.split(b"\n", 1)
            if line.strip():
                response = json.loads(line.decode("utf-8"))
                # Errors the server can't attribute to a request (RequestTooLarge, InvalidJSON) have id null; only the
                # request in flight can have caused them, because pings are always valid:
                if response.get("id") in (request_id, None):
                    return response
        return None

    def _send(self, command, args, deadline):
        self._id += 1
        timeout = max(1.0, deadline - time.time())
        payload = {"id": self._id, "token": self.token, "command": command,
                   "args": {k: v for k, v in (args or {}).items() if v is not None}, "deadline": deadline}
        if self.preemptive:
            payload["preemptive"] = True
        sock = self._connection(timeout)
        try:
            sock.sendall((json.dumps(payload) + "\n").encode("utf-8"))
            while True:
                response = self._take_response(self._id)
                if response is not None:
                    return response
                # Wake up every two seconds to ping: the server only fires the front end trigger for queued requests
                # while the kernel is idle, and it can be dropped (e.g. when evaluations are aborted); any incoming
                # request lets the server (re-)fire it once the kernel is idle.
                sock.settimeout(max(0.1, min(2.0, deadline - time.time())))
                try:
                    chunk = sock.recv(1 << 20)
                except socket.timeout:
                    if time.time() >= deadline:
                        raise
                    sock.sendall((json.dumps({"id": 0, "token": self.token, "command": "ping"}) + "\n").encode())
                    continue
                if not chunk:
                    self.close()
                    raise CLIError(f"The server closed the connection without answering {command!r} "
                                   "(did the kernel quit?)")
                self._buffer += chunk
        except socket.timeout:
            # The connection is not reused, so that a late answer can't be taken for the answer to another request:
            self.close()
            raise CLIError(f"Timed out after {timeout:.0f}s waiting for {command!r}. " + self.diagnose())
        except OSError as e:
            self.close()
            raise CLIError(f"Connection to the front end server failed during {command!r}: {e}")
        except ValueError as e:
            self.close()
            raise CLIError(f"Malformed response to {command!r}: {e}")

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
            pending = ping.get("pumpPending")
            return (f"The kernel is busy with another evaluation ({ping.get('queued')} request(s) queued"
                    + (f", processing requested {pending}s ago" if pending is not None else "") + "). Wait for it to "
                    "finish, raise --timeout, or use --preemptive to process requests during the evaluation (small "
                    "risk of a front end deadlock). If it never finishes, check for a kernel/front end deadlock with "
                    "`--preemptive eval 'MemberQ[Stack[], MathLink`CallFrontEndHeld]'` and abort the evaluation "
                    "with `key alt+period` in the front end window.")
        return "The server answers pings, so the command itself is slow; raise --timeout."

    def evaluate(self, code, timeout=60, **kw):
        return self.request("evaluate", dict(kw, code=code, timeout=timeout), timeout=timeout + 10)

    # --- geometry -----------------------------------------------------------------------------------------------------

    def screen(self):
        """A connection to the screen the front end runs on (an X display, or the Windows desktop)."""
        if not self.display:
            raise CLIError("The server did not report an X display (DISPLAY was unset in the front end).")
        return screen_backend().Display(self.display)

    def fe_windows(self, d):
        pid = self.info.get("FrontEndPID")
        windows = d.windows()
        own = [w for w in windows if w["pid"] == pid]
        popups = [w for w in windows if w["override_redirect"] and w["pid"] in (pid, None)
                  and w["width"] > 2 and w["height"] > 2]
        return own, popups

    def match_window(self, d, nb):
        """Find the window of a notebook (as returned by the server's notebook summary). Its x, y, width and height
        are those of the area that the notebook's WindowSize measures (on Windows, the client area)."""
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
                x, y = w.get("outer") or (w["x"], w["y"])  # on Windows, where WindowMargins apply
                return (abs(w["width"] - rect["width"] * scale) + abs(w["height"] - rect["height"] * scale),
                        abs(x - rect["left"] * scale) + abs(y - rect["top"] * scale))
            close = [w for w in (candidates or own) if distance(w)[0] <= 8 and distance(w)[1] <= 120]
            if close:
                return min(close, key=distance)
        raise CLIError(f"Could not find the window of notebook {title!r} on display {self.display}")

    def scale(self, d=None, nbs=None):
        """Screen pixels per front end point, measured by matching notebook windows with their screen windows."""
        if self._scale:
            return self._scale
        own_display = d is None
        d = d or self.screen()
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
                self._scale = d.dpi() / 72 if hasattr(d, "dpi") else 4 / 3
            return self._scale
        finally:
            if own_display:
                d.close()


def window_title(name):
    """The notebook title in a window name like 'Untitled-1 * (Running...) - Wolfram'."""
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


def native_path(path):
    """A file argument as a path that Python understands: on Windows, MSYS/Git Bash style paths like /c/Users/... are
    accepted too (Git Bash does not convert them when MSYS_NO_PATHCONV is set)."""
    if WINDOWS and path:
        match = re.match(r"^/([a-zA-Z])(/.*)?$", path)
        if match:
            return f"{match.group(1).upper()}:{match.group(2) or '/'}"
    return path


def read_code(code):
    try:
        if code == "-":
            return sys.stdin.read()
        if code.startswith("@") and " " not in code and ("/" in code or code.endswith((".wl", ".m", ".wls", ".txt"))):
            path = native_path(code[1:])
            if not os.path.isfile(path):
                raise CLIError(f"File not found: {code[1:]}")
            with open(path, encoding="utf-8-sig") as f:
                return f.read()
    except UnicodeDecodeError as e:
        raise CLIError(f"The code is not UTF-8 encoded: {e}")
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
        rows.append({"port": e["Port"], "name": e.get("Name"), "display": Server(e).display, "status": status,
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
        if port in live_ports or time.time() - max(record.get("startTime", 0), record.get("handoff", 0)) < 300:
            continue  # running, or possibly still starting (or moving to a new kernel: `snoop`)
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
    # MathLink logs (`snoop`): the records of servers that are gone, and logs that have not been written to for a day
    # (unless a running server's record names it: LinkSnooper only writes when there is traffic). On Windows, a log
    # that LinkSnooper has open cannot be deleted. (Logs are compared by file name, since a record may give the
    # directory by its short name: see command_line_path.)
    directory = state_dir()
    in_use = set()
    for name in os.listdir(directory):
        match = re.match(r"linksnooper-(\d+)\.json$", name)
        if match and int(match.group(1)) in live_ports:
            in_use.add(os.path.basename((read_json(os.path.join(directory, name)) or {}).get("log") or ""))
        elif match:
            remove_quietly(os.path.join(directory, name))
    for name in os.listdir(directory):
        path = os.path.join(directory, name)
        if (re.match(r"linksnooper-\d+-.+\.log$", name) and name not in in_use
                and time.time() - os.path.getmtime(path) > 86400 and remove_quietly(path)):
            remove_quietly(path + ".cursor")


def remove_quietly(path):
    """Delete a file if possible; whether it is gone."""
    try:
        os.remove(path)
    except FileNotFoundError:
        pass
    except OSError:
        return False
    return True


def kill_launched(launch, info=None):
    """Stop the processes of a launch record (front end, its kernel, window manager, Xvfb), checking each PID's
    identity first so that a reused PID is never signalled."""
    launch, info = launch or {}, info or {}
    kill_pid(info.get("FrontEndPID"), "frontend", SIGKILL, server_started(info))
    kill_pid(launch.get("launcherPID"), "frontend", SIGKILL, launch_started(launch))
    kill_pid(info.get("KernelPID"), "kernel", SIGKILL, server_started(info))
    kill_pid(info.get("SnooperPID"), "snooper", SIGKILL, server_started(info))
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
        return front_end_binary(explicit)
    candidates = [os.environ.get("WOLFRAMNB"), shutil.which("WolframNB")]
    candidates += registered_front_ends() if WINDOWS else []  # before an older Mathematica that may be on the PATH
    candidates += [shutil.which("Mathematica"), "/usr/local/Wolfram/Wolfram/15.0/Executables/WolframNB"]
    for c in candidates:
        if c and os.path.exists(c):
            return front_end_binary(c)
    raise CLIError("Cannot find the WolframNB executable; pass --front-end PATH")


def front_end_binary(path):
    """On Windows, WolframNB.exe (or Mathematica.exe) in the installation directory is a launcher that starts the
    front end binary and exits at once. Start the binary directly, so that fe.py knows the front end's process."""
    if WINDOWS:
        binary = os.path.join(os.path.dirname(os.path.abspath(path)), "SystemFiles", "FrontEnd", "Binaries",
                              "Windows-x86-64", os.path.basename(path))
        if os.path.isfile(binary):
            return binary
    return path


def registered_front_ends():
    """Front end executables of the Wolfram installations registered on Windows, newest version first."""
    import winreg
    found = []
    for hive in (winreg.HKEY_LOCAL_MACHINE, winreg.HKEY_CURRENT_USER):
        try:
            key = winreg.OpenKey(hive, r"SOFTWARE\Wolfram Research\Installations", 0,
                                 winreg.KEY_READ | winreg.KEY_WOW64_64KEY)
        except OSError:
            continue
        with key:
            for i in range(winreg.QueryInfoKey(key)[0]):
                try:
                    with winreg.OpenKey(key, winreg.EnumKey(key, i), 0, winreg.KEY_READ | winreg.KEY_WOW64_64KEY) as entry:
                        path = winreg.QueryValueEx(entry, "ExecutablePath")[0]
                        version = winreg.QueryValueEx(entry, "ProductVersion")[0]
                except OSError:
                    continue  # e.g. documentation or WolframScript installations
                if executable_name(path) in ("wolframnb", "mathematica"):
                    found.append((tuple(int(v) for v in re.findall(r"\d+", version)), path))
    return [path for _, path in sorted(found, reverse=True)]


def write_bootstrap(port):
    """The init file must live somewhere the front end's sandboxed helper kernel may read (the temp directory),
    otherwise that kernel reports Get::noopen in the Messages window on every launch."""
    init = os.path.join(HERE, "Init.wl").replace("\\", "/")
    # The kernel may not read the file as UTF-8, so write other characters as \:nnnn escapes:
    init = "".join(c if ord(c) < 128 else f"\\:{ord(c):04x}" if ord(c) < 0x10000 else f"\\|{ord(c):06x}"
                   for c in init)
    path = os.path.join(state_dir(), f"Bootstrap-{port}.wl")
    with open(path, "w", encoding="ascii") as f:
        f.write("(* Generated by fe.py launch *)\n"
                'If[ $FrontEnd =!= Null && ! MemberQ[ $CommandLine, "-sandbox" ],\n'
                f'    Get[ "{init}" ]\n'
                "];\n")
    return path


def available_memory_mb():
    if WINDOWS:
        import ctypes

        class MEMORYSTATUSEX(ctypes.Structure):
            _fields_ = [("dwLength", ctypes.c_ulong), ("dwMemoryLoad", ctypes.c_ulong)] + [
                (name, ctypes.c_ulonglong) for name in ("ullTotalPhys", "ullAvailPhys", "ullTotalPageFile",
                                                        "ullAvailPageFile", "ullTotalVirtual", "ullAvailVirtual",
                                                        "ullAvailExtendedVirtual")]

        status = MEMORYSTATUSEX(dwLength=ctypes.sizeof(MEMORYSTATUSEX))
        if ctypes.windll.kernel32.GlobalMemoryStatusEx(ctypes.byref(status)):
            return status.ullAvailPhys // 1024 ** 2
        return None
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
    chatbook = os.path.realpath(native_path(args.chatbook)) if args.chatbook else None
    if chatbook and not os.path.isfile(os.path.join(chatbook, "PacletInfo.wl")):
        raise CLIError(f"Not a paclet directory (no PacletInfo.wl): {chatbook}")
    free = available_memory_mb()
    if free is not None and free < MIN_FREE_MEMORY_MB and not args.force:
        raise CLIError(f"Only {free} MB of memory available; a front end needs about 1 GB and starting one now could "
                       f"make the system run out of memory. Stop other front ends (`fe.py servers`) or pass --force.")
    front_end_path = find_front_end(native_path(args.front_end))
    token = secrets.token_hex(16)
    port = reserve_port(args.port, token)
    record = {"port": port, "token": token, "startTime": time.time()}
    xvfb = wm = front_end = None
    try:
        env = dict(os.environ)
        if WINDOWS:
            if args.display not in (None, "current", "desktop"):
                raise CLIError("On Windows, front ends always run on the desktop; --display is for X11")
            display = record["display"] = "desktop"
        elif args.display in (None, "new"):
            display, xvfb = start_xvfb(args.size)
            record["xvfbPID"] = xvfb.pid
        elif args.display == "current":
            display = os.environ.get("DISPLAY")
            if not display:
                raise CLIError("DISPLAY is not set; pass --display :N")
        else:
            display = args.display
        if not WINDOWS:
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
        # Its own session (process group on Windows), so that Ctrl-C in this terminal does not reach the front end:
        detach = {"creationflags": subprocess.CREATE_NEW_PROCESS_GROUP} if WINDOWS else {"start_new_session": True}
        with open(log_path, "w") as log:
            front_end = subprocess.Popen([front_end_path], env=env, stdout=log, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, **detach)
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
        server = Server(fill_front_end_pid(info))
        while not server.request("ping", timeout=30).get("ready"):
            if time.time() > deadline:
                raise CLIError(f"Timed out waiting for the front end connection on port {port}; see {log_path}")
            time.sleep(0.5)
        if not args.keep_welcome:
            close_startup_windows(server, private_display=bool(xvfb))
        if args.link_snooper:
            server, snooping = start_snooping(server)
            info = server.info
        if chatbook:
            # Init.wl loads it quietly; make sure tests really run against this Chatbook:
            loaded = server.request("info").get("ChatbookLocation")
            if not isinstance(loaded, str) or os.path.normcase(os.path.realpath(loaded)) != os.path.normcase(chatbook):
                raise CLIError(f"The front end loaded Chatbook from {loaded!r} instead of {chatbook}")
    except BaseException:
        # Don't leave a half-started front end (or its Xvfb) running without a way to stop it:
        if front_end and front_end.poll() is None:
            if WINDOWS:  # the front end and the kernels it started
                kill_pid(front_end.pid, "frontend", SIGKILL, launch_started(record))
            else:
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
    note = ""
    if args.link_snooper:
        result["linkSnooperLog"] = snooping["log"]
        note = f"\nIts MathLink traffic is logged to {snooping['log']} (read it with: fe.py -s {port} linklog)"
    emit(args, result, f"Front end server {info.get('Name')} running on port {port}, display {display} "
                       f"(front end pid {info.get('FrontEndPID')}).{note}\nUse: fe.py -s {port} <command>")


def close_startup_windows(server, private_display):
    """Leave a single blank notebook: close the Welcome screen (it is not a notebook, so close it through X11 or
    Win32), the "no open windows" launcher dialog, and the Messages window if it is empty."""
    try:
        # A regular notebook must exist first, otherwise closing the Welcome screen opens the launcher dialog:
        server.evaluate("CreateDocument[]", timeout=20)
    except (CLIError, ServerError):
        pass
    try:
        with server.screen() as d:
            deadline = time.time() + 8
            while time.time() < deadline:
                welcome = [w for w in server.fe_windows(d)[0] if w["name"].startswith("Welcome to Wolfram")]
                if welcome:
                    for w in welcome:
                        if WINDOWS:
                            d.close_window(w["id"])
                            continue
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
        forget_snooping(server, front_end_running=True)
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
    forget_snooping(server, front_end_running=False)


def forget_snooping(server, front_end_running):
    state = snoop_state(server)
    if state:
        remove_quietly(snoop_state_path(server.port))
        print(f"Its MathLink log stays in {state['log']} (`linklog --file` reads it)" +
              (f"; kernels of the evaluator \"{state.get('evaluator')}\" keep logging there until the front end quits"
               if front_end_running else ""))


# ---------------------------------------------------------------------------------------------------------------------
# Commands: evaluation and inspection
# ---------------------------------------------------------------------------------------------------------------------

def cmd_info(args):
    server = Server(select_server(args.server))
    result = server.request("info")
    # The kernel's parent is not the front end when it runs through LinkSnooper (see fill_front_end_pid):
    for key in ("FrontEndPID", "SnooperPID"):
        if key in server.info:
            result[key] = server.info[key]
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
                                         "imagePath": os.path.abspath(native_path(args.image)) if args.image else None},
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
            with server.screen() as d:
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
# Commands: MathLink logging (LinkSnooper)
# ---------------------------------------------------------------------------------------------------------------------

def snoop_state_path(port):
    """The log that `snoop` set up for the server on a port (tied to that server by its token's hash)."""
    return os.path.join(state_dir(), f"linksnooper-{port}.json")


def token_hash(token):
    """What the `snoop` state file keeps of the server's token (which would let anyone who reads it run code in the
    server's kernel)."""
    return hashlib.sha256((token or "").encode("utf-8")).hexdigest()


def snoop_state(server):
    state = read_json(snoop_state_path(server.port))
    return state if isinstance(state, dict) and state.get("tokenHash") == token_hash(server.token) else None


def start_snooping(server, links="main,pre,serv", poll_interval=1, evaluator_only=False, timeout=120):
    """Log the MathLink traffic between the front end and a kernel with J/Link's LinkSnooper (FrontEndServer.wl,
    command "linkSnooper"). Normally the server moves to a new kernel that runs through LinkSnooper and becomes the
    default evaluator; with evaluator_only, there is just a new evaluator for notebooks to use.
    Returns (server, result), where server is the one in the new kernel."""
    launch = server.info.get("_launch")
    if not evaluator_only and not launch:
        raise CLIError("Only the kernel of a front end that fe.py launched can be replaced by one that runs through "
                       "LinkSnooper (that kernel has to start the server again). Use --evaluator-only, and give the "
                       "notebooks to watch that Evaluator.")
    name = f"linksnooper-{server.port}-{time.strftime('%Y%m%d-%H%M%S')}.log"
    log = command_line_path(os.path.join(state_dir(), name))
    old_kernel = server.info.get("KernelPID")
    if not evaluator_only:
        # The registry file is missing while the server moves: keep `servers --prune` from taking the front end for
        # the remains of a failed launch.
        launch["handoff"] = time.time()
        write_launch_record(launch)
    result = server.request("linkSnooper", {"log": log, "links": links, "pollInterval": poll_interval,
                                            "mode": "Evaluator" if evaluator_only else "Kernel", "timeout": timeout})
    # Recorded right away, so that `linklog` finds the log also when something goes wrong below:
    fd = os.open(snoop_state_path(server.port), os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600)
    with os.fdopen(fd, "w") as f:
        json.dump({"tokenHash": token_hash(server.token), "log": log, "evaluator": result.get("evaluator"),
                   "mode": result.get("mode"), "time": time.time()}, f)
    if not evaluator_only:
        # This server stops, the front end starts the new kernel, Init.wl starts the server there, and the old kernel
        # quits. If the new kernel's server does not show up within the timeout, the old kernel starts its own again.
        front_end_log = launch.get("log")
        deadline = time.time() + timeout + 30
        gone = False
        while True:
            entry = next((e for e in registry_entries()
                          if e["Port"] == server.port and e.get("Token") == server.token), None)
            if entry is None:
                gone = True
            elif entry.get("KernelPID") != old_kernel and entry["_alive"]:
                break
            elif gone and entry.get("KernelPID") == old_kernel:
                raise CLIError(f"The kernel that runs through LinkSnooper did not start the server, so it stays in "
                               f"the old kernel. See {log} and {front_end_log}.")
            if time.time() > deadline:
                raise CLIError(f"Timed out waiting for the server to start in the kernel that runs through "
                               f"LinkSnooper. See {log} and {front_end_log}.")
            time.sleep(0.5)
        server = Server(entry)
        while not server.request("ping", timeout=30).get("ready"):
            if time.time() > deadline:
                raise CLIError("Timed out waiting for the front end connection of the new kernel")
            time.sleep(0.5)
    return server, result


def cmd_snoop(args):
    server = Server(select_server(args.server))
    server, result = start_snooping(server, args.links, args.poll_interval, args.evaluator_only, args.timeout)
    evaluator, log = result.get("evaluator"), result.get("log")
    if args.evaluator_only:
        text = (f"Notebooks with Evaluator -> \"{evaluator}\" now get a kernel that runs through LinkSnooper, which "
                f"logs its MathLink traffic to {log}\n"
                f"e.g. fe.py -s {server.port} eval 'NotebookPut[Notebook[{{}}, Evaluator -> \"{evaluator}\"]]' "
                f"(the kernel starts with the first evaluation in such a notebook)\n"
                f"Read the log with: fe.py -s {server.port} linklog")
    else:
        text = (f"The front end's kernel (pid {server.info.get('KernelPID')}) now runs through LinkSnooper, which logs "
                f"all MathLink traffic to {log}\nRead it with: fe.py -s {server.port} linklog")
    emit(args, dict(result, kernelPID=server.info.get("KernelPID")), text)


# Each record of a LinkSnooper log starts with a time stamp; a packet whose text contains newlines continues on the
# following lines.
LOG_RECORD = re.compile(rb"\[(\d\d:\d\d:\d\d\.\d{3})\] ")
# A packet's head, which the front end sometimes sends with its context (System`EvaluatePacket[...]):
LOG_PACKET = re.compile(r"FE (?:--->|<---) K: (?:System`)?(\w+)\[")
# Lines that LinkSnooper(Log) writes when it starts and when the links close:
LOG_SESSION_LINES = ("LinkSnooperLog: Java process", "LinkSnooper command-line params:", "Start Monitoring...",
                     "MathLinkException:")
PUMP_FUNCTION = "Wolfram`ChatbookFrontEndServer`Private`pump[]"


def log_records(path, offset=0):
    """[(start, end, time, text)] of the records in a LinkSnooper log from a byte offset. Only complete lines are read,
    since LinkSnooper may be writing."""
    with open(path, "rb") as f:
        f.seek(offset)
        data = f.read()
    records, current, pos = [], None, offset
    for line in data.split(b"\n")[:-1]:  # the last piece is an incomplete line, or empty
        match = LOG_RECORD.match(line)
        if match or current is None:
            if current:
                records.append(current)
            current = [pos, None, match.group(1).decode() if match else "", [line[match.end():] if match else line]]
        else:
            current[3].append(line)
        pos += len(line) + 1
        current[1] = pos
    if current:
        records.append(current)
    return [(start, end, stamp, b"\n".join(lines).decode("utf-8", "replace").rstrip("\r"))
            for start, end, stamp, lines in records]


class ServerTraffic:
    """Recognizes the traffic of fe.py's own requests. The front end server processes them in main-link evaluations of
    its pump button (from EvaluatePacket[... pump[] ...] to the matching ReturnPacket), which its socket handler
    triggers through the service link (CallPacket[FrontEnd`TriggerControlBoxObject[...]] and its ReturnPacket)."""

    def __init__(self, state=None):
        state = state or {}
        self.depth = state.get("depth", 0)          # nesting of evaluations and calls inside a pump evaluation
        self.trigger = state.get("trigger", False)  # a trigger call on the service link awaits its reply

    def state(self):
        return {"depth": self.depth, "trigger": self.trigger}

    def __call__(self, text):
        """Whether a record (its text without the time stamp and indentation) belongs to a request of fe.py."""
        if text.startswith(LOG_SESSION_LINES):
            # The links closed or a new kernel started (the log is appended to): nothing is pending any more.
            self.depth, self.trigger = 0, False
            return False
        if text.startswith("-Serv-"):
            packet = text[len("-Serv-"):].lstrip()
            head = packet_head(packet)
            if head == "CallPacket" and "FrontEnd`TriggerControlBoxObject[" in packet[:80]:
                self.trigger = True
                return True
            if self.trigger and head == "ReturnPacket" and packet.startswith("FE --->"):
                self.trigger = False
                return True
            return False
        if not text.startswith("FE "):
            return False  # the preemptive link, or LinkSnooper's own messages
        head, to_kernel = packet_head(text), text.startswith("FE --->")
        if not self.depth:
            if to_kernel and head == "EvaluatePacket" and PUMP_FUNCTION in text:
                self.depth = 1
                return True
            return False
        # Evaluations the front end asks for and calls the kernel makes nest; each ends with a ReturnPacket:
        if head == ("EvaluatePacket" if to_kernel else "CallPacket"):
            self.depth += 1
        elif head == "ReturnPacket":
            self.depth -= 1
        return True


def packet_head(text):
    match = LOG_PACKET.match(text)
    return match.group(1) if match else None


def record_text(text):
    """A record's text as `linklog` prints it (and as --grep sees it), without the time stamp."""
    return re.sub(r"^(-Serv-|-Pre-)\s+", r"\1 ", text.lstrip()).replace("\r", "").replace("\n", "\\n")


def format_record(stamp, text, width):
    if width and len(text) > width:
        text = f"{text[:width]}... [{len(text) - width} more characters]"
    return f"{stamp} {text}" if stamp else text


def cmd_linklog(args):
    if args.file:
        path = native_path(args.file)
    else:
        server = Server(select_server(args.server))
        state = snoop_state(server)
        if not state:
            raise CLIError("This front end's MathLink traffic is not being logged; start with `fe.py snoop` (or "
                           "`fe.py launch --link-snooper`), or read a log with --file")
        path = state["log"]
    if args.path:
        return print(path)
    if not os.path.exists(path):
        raise CLIError(f"{path} does not exist (yet): LinkSnooper creates it when its kernel starts")

    # Without --all/--tail, continue where the last call stopped (the cursor file also keeps the state of
    # --hide-server's recognition of fe.py's requests at that point):
    cursor_path = path + ".cursor"
    use_cursor = not (args.all or args.tail)
    cursor = (read_json(cursor_path) or {}) if use_cursor else {}
    offset = cursor.get("offset", 0)
    if not isinstance(offset, int) or not 0 <= offset <= os.path.getsize(path):
        offset, cursor = 0, {}
    records = log_records(path, offset)
    # Packets with newlines are written in pieces, so while the log is growing its last record may be incomplete;
    # leave that one for the next call:
    if use_cursor and not args.mark and records and time.time() - os.path.getmtime(path) < 1:
        records.pop()
    server_traffic = ServerTraffic(cursor)
    hidden = cursor.get("hidden", False)
    grep = re.compile(args.grep) if args.grep else None
    exclude = re.compile(args.exclude) if args.exclude else None
    shown, end, read = [], offset, 0
    for start, stop, stamp, raw in records:
        if use_cursor and not args.mark and args.limit and len(shown) >= args.limit:
            break
        # A record without a time stamp continues one that an earlier call read in part (or precedes LinkSnooper's
        # first line):
        hidden = server_traffic(raw.lstrip()) if stamp else hidden
        end, read = stop, read + 1
        if args.mark or (args.hide_server and hidden):
            continue
        text = record_text(raw)
        if (grep and not grep.search(text)) or (exclude and exclude.search(text)):
            continue
        shown.append({"time": stamp, "text": text, "offset": start})
    if use_cursor:
        try:
            with open(cursor_path, "w") as f:
                json.dump(dict(server_traffic.state(), offset=end, hidden=hidden), f)
        except OSError:
            pass
    if args.mark:
        return print(f"skipped {read} record(s); `linklog` continues from here")
    matching = len(shown)
    if args.tail:
        shown = shown[-args.tail:]
    elif not use_cursor and args.limit:
        shown = shown[:args.limit]
    if args.json:
        return emit(args, shown)
    for record in shown:
        print(format_record(record["time"], record["text"], args.width))
    unread = len(records) - read
    if use_cursor and unread:
        print(f"[{unread} more record(s); run linklog again to continue, or --mark to skip to the end]")
    elif not use_cursor and not args.tail and matching > len(shown):
        print(f"[{matching - len(shown)} more matching record(s); --limit 0 prints all]")
    elif not shown:
        print("(no new traffic)" if use_cursor else "(no matching traffic)")


# ---------------------------------------------------------------------------------------------------------------------
# Commands: screenshots and X11
# ---------------------------------------------------------------------------------------------------------------------

def cmd_screenshot(args):
    server = Server(select_server(args.server))
    if not 0 < args.scale <= 1:
        raise CLIError("--scale must be in (0, 1]")
    if args.fe or not server.display:
        result = server.request("rasterize", {"notebook": args.target, "cell": args.cell, "screen": args.screen or None,
                                              "path": os.path.abspath(native_path(args.output)) if args.output else None})
        # Such an image has no known screen position, so `click --image` must not use it:
        if os.path.exists(screenshot_state_path(server)):
            os.remove(screenshot_state_path(server))
        return emit(args, result, f"{result['path']} ({result['width']}x{result['height']}, front end rendered)")

    with server.screen() as d:
        label, shot, shown = "screen", None, None
        if args.region:
            x, y, w, h = (int(float(v)) for v in args.region.split(","))
        elif args.screen:
            x, y, w, h = d.left, d.top, d.width, d.height
        elif args.window:
            wid = int(args.window, 0)
            geo = d.geometry(wid)
            if not geo:
                raise CLIError(f"No such window {args.window}")
            x, y, w, h = geo[:4]
            label, shown = f"window-{args.window}", wid
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
            content = content_area(server, d, located)
            if y < content[1] - 2 or y + h > content[1] + content[3] + 2:
                print("note: the cell is only partly visible; the screenshot is clipped", file=sys.stderr)
            label = "cell"
        else:
            nb = server.request("notebook", {"notebook": args.target or "selected"})
            if not args.no_raise:
                server.request("select", {"notebook": nb["id"]})
            window = server.match_window(d, nb)
            label, shown = nb.get("title") or "notebook", window["id"]
            # The whole window, including its title bar where the window manager draws one:
            x, y, w, h = window.get("frame") or (window["x"], window["y"], window["width"], window["height"])
            if not args.no_raise:
                d.activate(window["id"])
                time.sleep(args.delay)
            elif WINDOWS:
                # Windows can capture a window's own content, also where other windows cover it:
                if args.pad:
                    raise CLIError("--pad does not apply to --no-raise screenshots on Windows")
                path = native_path(args.output) or default_screenshot_path(server, label)
                shot = d.screenshot_window(path, window["id"], scale=args.scale)
                x, y, w, h = shot.pop("x"), shot.pop("y"), shot.pop("capturedWidth"), shot.pop("capturedHeight")
        if shot is None:
            if args.pad and not args.cell:
                x, y, w, h = x - args.pad, y - args.pad, w + 2 * args.pad, h + 2 * args.pad
            # Clip to the screen, keeping the right and bottom edges where they are:
            x1, y1 = min(x + w, d.left + d.width), min(y + h, d.top + d.height)
            x, y = max(d.left, x), max(d.top, y)
            w, h = x1 - x, y1 - y
            if w <= 0 or h <= 0:
                raise CLIError("The requested region is outside the screen")
            path = native_path(args.output) or default_screenshot_path(server, label)
            shot = d.screenshot(path, x, y, w, h, scale=args.scale)

    downscale = shot["width"] / w  # what was actually applied
    state = {"path": path, "x": x, "y": y, "width": w, "height": h, "scale": downscale, "time": time.time(),
             "window": shown}
    with open(screenshot_state_path(server), "w") as f:
        json.dump(state, f)
    emit(args, dict(shot, origin=[x, y], downscale=downscale),
         f"{path} ({shot['width']}x{shot['height']} px; screen origin {x},{y}"
         + (f"; downscaled {downscale:.2f}x" if downscale != 1 else "") + ")")


# On Windows, the child window that holds the boxes of each scope (the default is the notebook content):
WINDOWS_PANES = {"Docked": "DockedCellsContent", "Sidebar": "SidebarContent"}


def pixel_rects(server, d, located):
    """Convert the front end rectangles (points) from a `locate` result to screen pixel rectangles."""
    scale = server.scale(d)
    dx = dy = 0
    scope = located.get("scope")
    if scope in ("Docked", "Sidebar") or WINDOWS:
        try:
            nb = server.request("notebook", {"notebook": located["notebook"]})
            window = server.match_window(d, nb)
            if scope == "Docked":
                # Docked boxes come relative to the docked area, which starts at the top of the window's client
                # area, below the menu bar on Linux (19 px at 96 dpi, i.e. 14.25 points):
                dy = window["y"] + (MENU_BAR_POINTS * scale if located.get("menuBar") else 0)
            elif scope == "Sidebar" and located.get("content"):
                # Boxes in the sidebar are reported with x relative to the content area, which starts to the right of
                # the sidebar; the sidebar itself starts at the window's left edge.
                dx = window["x"] - located["content"]["left"] * scale
            if WINDOWS:
                # The front end reports the boxes of each pane (docked cells, sidebar, notebook content) as if the
                # pane started at the top left corner of the window's client area:
                name = WINDOWS_PANES.get(scope, "NotebookContent")
                pane = d.pane(window["id"], name)
                if not pane:
                    raise CLIError(f"Could not find the {name} pane of notebook {nb.get('title')!r}")
                dx, dy = dx + pane[0] - window["x"], dy + pane[1] - window["y"]
        except (CLIError, ServerError):
            if WINDOWS:  # the rectangles would all be off by the pane's offset
                raise
    rects = [{"x": r["left"] * scale + dx, "y": r["top"] * scale + dy, "width": r["width"] * scale,
              "height": r["height"] * scale} for r in located.get("rects") or []]
    if located.get("coordinates") == "Document" and rects:
        rects = find_selection_on_screen(server, d, located, rects)
    return rects


def is_whole_cell(located):
    return located.get("target") == "Cell" or located.get("match") == "Cell"


HIGHLIGHT = (48, 140, 198)  # the front end's selection background on Linux (Windows uses the system's)
MENU_BAR_POINTS = 14.25


def content_area(server, d, located, window=None):
    """The notebook's content area (below docked cells, excluding scroll bars) of a `locate` result, in screen pixels:
    (left, top, width, height)."""
    if window is None:
        window = server.match_window(d, server.request("notebook", {"notebook": located["notebook"]}))
    if WINDOWS:
        # The front end reports the whole client area there; the content is a child window:
        pane = d.pane(window["id"], "NotebookContent")
        if pane:
            return pane
    scale = server.scale(d)
    content = located.get("content") or {}
    return (int(content.get("left", 0) * scale) or window["x"], int(content.get("top", 0) * scale) or window["y"],
            int(content.get("width", 0) * scale) or window["width"],
            int(content.get("height", 0) * scale) or window["height"])


def find_selection_on_screen(server, d, located, rects):
    """Text selections in text cells are reported in document coordinates: x is right, but y depends on the scroll
    position, which the front end doesn't expose. The selection has been scrolled into view, so find its highlight
    within the notebook's content area."""
    nb = server.request("select", {"notebook": located["notebook"]})
    window = server.match_window(d, nb)
    d.activate(window["id"])
    time.sleep(0.3)
    left, top, width, height = content_area(server, d, located, window)
    if is_whole_cell(located):
        # A selected cell is reported as one rectangle between its caret positions; search the whole content width
        # and take the union of its highlighted lines.
        rects = [{"x": left, "y": 0, "width": width, "height": rects[0]["height"], "union": True}]
    color = d.selection_color() if hasattr(d, "selection_color") else HIGHLIGHT
    gap = max(6, round(4.5 * server.scale(d)))  # between the lines of a selection (6 px at 96 dpi)
    # The front end may not have repainted the new selection yet: wait until two captures agree.
    previous = None
    for _ in range(6):
        found = highlight_bands(d, rects, top, height, color, gap)
        if found and found == previous:
            return found
        previous = found
        time.sleep(0.25)
    if not found:
        raise CLIError("The selected text is not visible on screen (could not find its highlight)")
    return found


def highlight_bands(d, rects, top, height, color=HIGHLIGHT, gap=6):
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
                       if abs(line[i] - color[0]) < 40 and abs(line[i + 1] - color[1]) < 40
                       and abs(line[i + 2] - color[2]) < 40)
            rows.append(hits > (2 if r.get("union") else 0.25 * w))
        bands, start = [], None
        for i, hit in enumerate(rows + [False]):
            if hit and start is None:
                start = i
            elif not hit and start is not None:
                bands.append((start, i))
                start = None
        if bands and r.get("union"):
            # The cell's highlighted lines: the span of runs of nearly adjacent bands whose height is closest to the
            # cell's, since other things can have the highlight color too (on Windows, controls in the system's
            # accent color). Usually that is the span from the first band to the last.
            runs = [list(bands[0])]
            for b0, b1 in bands[1:]:
                if b0 - runs[-1][1] <= gap:
                    runs[-1][1] = b1
                else:
                    runs.append([b0, b1])
            spans = [(runs[i][0], runs[j][1]) for i in range(len(runs)) for j in range(i, len(runs))]
            b0, b1 = min(spans, key=lambda b: (abs((b[1] - b[0]) - r["height"]), b[0] - b[1]))
            found.append({"x": r["x"], "y": top + b0, "width": r["width"], "height": b1 - b0})
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
    with server.screen() as d:
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
        # On Windows, the window may be covered (`screenshot --no-raise` captures its own content). An X11 screenshot
        # shows the screen as it is, so raising the window there would make the click land on something else:
        if WINDOWS and state.get("window") and d.geometry(state["window"]):
            d.activate(state["window"])
            time.sleep(0.3)
        return state["x"] + u / scale, state["y"] + v / scale
    if getattr(args, "box", None) or getattr(args, "text", None) or getattr(args, "cell", None):
        located = server.request("locate", locate_args(args))
        # Bring the target's window to the front first, so that the pointer doesn't land on another window that
        # covers it; then locate again, since activating can scroll or move things.
        if raise_notebook(server, d, located["notebook"]):
            located = server.request("locate", locate_args(args))
        rects = pixel_rects(server, d, located)
        if not rects:
            raise CLIError("Target was found but has no on-screen rectangle (is it scrolled out of view?)")
        r = rects[0]
        fx, fy = (0.5, 0.5) if not args.at else parse_point(args.at)
        return r["x"] + r["width"] * fx, r["y"] + r["height"] * fy
    if getattr(args, "point", None):
        x, y = parse_point(args.point)
        if getattr(args, "window", None):
            nb = server.request("notebook", {"notebook": args.window})
            raise_notebook(server, d, nb["id"])
            window = server.match_window(d, nb)
            return window["x"] + x, window["y"] + y
        return x, y
    raise CLIError("Give a point (x,y), --image u,v, --box ID, --text TEXT, or --cell ID")


def raise_notebook(server, d, notebook):
    """Select a notebook and raise its window unless it is already focused; returns whether anything changed."""
    nb = server.request("notebook", {"notebook": notebook})
    window = server.match_window(d, nb)
    focused = d.focused_window()
    if focused > 1 and d.toplevel_frame(focused) == d.toplevel_frame(window["id"]):
        return False
    server.request("select", {"notebook": nb["id"]})
    d.activate(window["id"])
    time.sleep(0.3)
    return True


def locate_args(args):
    if not (args.box or args.text or args.cell):
        raise CLIError("Give a target: --box BOXID, --text TEXT, or --cell CELLID")
    return {"notebook": args.notebook, "boxID": args.box, "text": args.text, "cell": args.cell,
            "occurrence": args.occurrence, "scope": SCOPES.get(getattr(args, "within", None))}


SCOPES = {"notebook": "Notebook", "docked": "Docked", "attached": "Attached", "sidebar": "Sidebar"}


def cmd_locate(args):
    server = Server(select_server(args.server))
    located = server.request("locate", locate_args(args))
    with server.screen() as d:
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
    with server.screen() as d:
        x, y = resolve_point(server, d, args)
        if args.offset:
            dx, dy = parse_point(args.offset)
            x, y = x + dx, y + dy
        if not (d.left <= x < d.left + d.width and d.top <= y < d.top + d.height):
            raise CLIError(f"The point {round(x)},{round(y)} is outside the screen ({d.width}x{d.height})")
        ensure_front_end_at(server, d, x, y, args.force)
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
    with server.screen() as d:
        x, y = resolve_point(server, d, args)
        d.move(x, y)
    print(f"moved to {round(x)},{round(y)}")


def cmd_scroll(args):
    server = Server(select_server(args.server))
    with server.screen() as d:
        x, y = resolve_point(server, d, args) if (args.point or args.image) else d.pointer()
        ensure_front_end_at(server, d, x, y, args.force)
        d.scroll(x, y, args.clicks, horizontal=args.horizontal)
    print(f"scrolled {args.clicks} at {round(x)},{round(y)}")


def cmd_drag(args):
    server = Server(select_server(args.server))
    x0, y0 = parse_point(args.start)
    x1, y1 = parse_point(args.end)
    with server.screen() as d:
        ensure_front_end_at(server, d, x0, y0, args.force)
        d.drag(x0, y0, x1, y1)
    print(f"dragged {x0},{y0} -> {x1},{y1}")


def ensure_front_end_at(server, d, x, y, force=False):
    """Refuse to send mouse input to a point where another application's window is in front (where it can be found:
    on Windows). On a shared desktop, the click would go to that application."""
    pid = server.info.get("FrontEndPID")
    if force or not pid or not hasattr(d, "window_at"):
        return
    window = d.window_at(x, y)
    if window and d.window_pid(window) != pid:
        name = next((w["name"] for w in d.windows() if w["id"] == window), "")
        raise CLIError(f"The point {round(x)},{round(y)} is covered by another application's window ({name!r}), so "
                       "no mouse input was sent. Select the notebook first, or pass --force.")


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
    if hasattr(d, "require_input"):
        d.require_input("keyboard")  # when Windows discards input (so focus could not be taken), say that instead
    where = f" (it is in {d.foreground_description()})" if hasattr(d, "foreground_description") else ""
    raise CLIError(f"The keyboard focus is not in this front end's windows{where}, so no keys were sent. Click into "
                   "the target, use --notebook/--cell, or pass --force.")


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
    with server.screen() as d:
        if args.cell:
            info = focus_cell(server, d, args.cell, start=args.start)
            return print(f"cursor in cell {info['cell']} of {info['title']!r}")
        focus_notebook(server, d, args.notebook)
    print(f"focused {args.notebook!r}")


def cmd_key(args):
    server = Server(select_server(args.server))
    with server.screen() as d:
        for combo in args.keys:
            d.parse_key(combo)  # fail before focusing anything
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
    with server.screen() as d:
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


# A failed chat replaces its reply with a generated Text cell (e.g. a service error) or an AssistantOutputError cell:
CHAT_FAILURE_STYLES = {"Text", "AssistantOutputError"}


def chat_outputs(server, notebook, sidebar=False):
    """Chat replies, and the generated cells that replace a reply when the chat fails (e.g. a service error)."""
    cells = server.request("cells", {"notebook": notebook, "maxCharacters": 1000000, "sidebar": sidebar or None})
    return [c for c in cells
            if "ChatOutput" in style_name(c.get("style")) or "AssistantOutput" in style_name(c.get("style"))
            or (c.get("generated") and style_name(c.get("style")) in CHAT_FAILURE_STYLES)]


def cmd_ask(args):
    """Ask the notebook assistant (window or sidebar) a question through its real input field, and print the reply."""
    server = Server(select_server(args.server))
    sidebar = args.sidebar is not None
    notebook = args.sidebar or args.notebook
    before = {cell_ref(c) for c in chat_outputs(server, notebook, sidebar)}
    target = argparse.Namespace(image=None, box="AttachedChatInputField", text=None, cell=None, notebook=notebook,
                                occurrence=None, at=None, within="sidebar" if sidebar else None)
    with server.screen() as d:
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
            if style_name(new[-1].get("style")) in CHAT_FAILURE_STYLES:
                raise CLIError("The chat failed: " + reply["text"])
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
    p.add_argument("--display",
                   help="'new' (default: private Xvfb display), 'current' ($DISPLAY), or an X display like :10 "
                        "(on Windows, front ends always run on the desktop)")
    p.add_argument("--size", default="1920x1200", help="screen size for a new Xvfb display (Linux)")
    p.add_argument("--port", type=int, help="server port (default: first free port in 2400-2499)")
    p.add_argument("--name", help="server name")
    p.add_argument("--chatbook", nargs="?", const=REPO, default=None,
                   help="load a development Chatbook paclet at startup (default path: this repository)")
    p.add_argument("--wm", action="store_true", help="run a window manager (xfwm4/openbox) on the new Xvfb display (Linux)")
    p.add_argument("--wm-command", help="window manager executable to use with --wm")
    p.add_argument("--front-end", help="path to the WolframNB executable")
    p.add_argument("--keep-welcome", action="store_true", help="do not close the Welcome screen")
    p.add_argument("--timeout", type=float, default=180, help="seconds to wait for startup")
    p.add_argument("--force", action="store_true", help="launch even if little memory is available")
    p.add_argument("--link-snooper", action="store_true",
                   help="log all MathLink traffic between the front end and its kernel (see `snoop`, `linklog`)")

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
    p.add_argument("--no-x", action="store_true", help="do not also activate the window on screen")

    p = add("close", cmd_close, "close a notebook without saving")
    p.add_argument("notebook")
    p.add_argument("--save", action="store_true", help="allow the front end to save/prompt")

    p = add("screenshot", cmd_screenshot, "capture a notebook window, cell, region, or the screen to a PNG",
            aliases=["shot"])
    p.add_argument("target", nargs="?", help="notebook reference (default: selected notebook)")
    p.add_argument("-o", "--output", help="output PNG path (default: temp dir)")
    p.add_argument("--screen", action="store_true", help="capture the whole screen")
    p.add_argument("--window", help="capture a window by id (see `windows`)")
    p.add_argument("--region", help="capture x,y,w,h in screen pixels")
    p.add_argument("--cell", help="capture just this cell (by id)")
    p.add_argument("--pad", type=int, default=0, help="extra pixels around the target")
    p.add_argument("--scale", type=float, default=1.0, help="downscale factor (e.g. 0.5)")
    p.add_argument("--no-raise", action="store_true",
                   help="for notebook screenshots: do not raise the window first (on Windows: capture the window's "
                        "own content, also where other windows cover it, but without popup menus)")
    p.add_argument("--delay", type=float, default=0.3, help="seconds to wait after raising")
    p.add_argument("--fe", action="store_true", help="let the front end render the image (no screen access needed)")

    p = add("windows", cmd_windows, "list the front end's windows (including popups)")
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
    p.add_argument("--force", action="store_true", help="click even if another application's window covers the point")

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
    p.add_argument("--clicks", type=int, default=3, help="positive = down (right), negative = up (left)")
    p.add_argument("--horizontal", action="store_true")
    p.add_argument("--force", action="store_true", help="scroll even if another application's window is at the point")

    p = add("drag", cmd_drag, "drag with the left button between two screen points")
    p.add_argument("start")
    p.add_argument("end")
    p.add_argument("--force", action="store_true", help="drag even if another application's window is at the start")

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

    p = add("snoop", cmd_snoop, "log all MathLink traffic between the front end and its kernel to a file (J/Link's "
                                 "LinkSnooper): the kernel is replaced by one that runs through LinkSnooper, which the "
                                 "server moves to (kernel state is lost); read the log with `linklog`")
    p.add_argument("--evaluator-only", action="store_true",
                   help="only add an evaluator (\"LinkSnooperLog\", or \"LinkSnooperLog 2\", ...: the output names "
                        "it) for notebooks to use (Evaluator option); the main kernel stays as it is (this also works "
                        "in a front end that fe.py did not launch)")
    p.add_argument("--links", default="main,pre,serv",
                   help="links to log: main, pre (preemptive: Dynamic updates) and/or serv (service), comma-separated "
                        "(default: %(default)s)")
    p.add_argument("--poll-interval", type=int, default=1,
                   help="milliseconds LinkSnooper waits between checks of its links while there is traffic (it backs "
                        "off to 10 when idle); larger values add latency to every front end call (default: "
                        "%(default)s)")
    p.add_argument("--timeout", type=float, default=120,
                   help="seconds to wait for the server to start in the new kernel before the old kernel takes it "
                        "back (default: %(default)s)")

    p = add("linklog", cmd_linklog, "print MathLink traffic logged by `snoop`: by default the packets logged since "
                                     "the last `linklog`, one line each")
    p.add_argument("--mark", action="store_true", help="print nothing, just skip to the end (do this before an action "
                                                       "to see only the traffic it causes)")
    p.add_argument("--all", action="store_true", help="read from the start of the log, not from where the last "
                                                      "`linklog` stopped (which stays where it is)")
    p.add_argument("--tail", type=int, metavar="N", help="print the last N (matching) packets")
    p.add_argument("--grep", metavar="REGEX",
                   help="only packets whose text (as printed, without the time) matches this regular expression "
                        "(Python syntax)")
    p.add_argument("--exclude", metavar="REGEX", help="leave out packets whose text matches this regular expression")
    p.add_argument("--hide-server", action="store_true",
                   help="leave out the traffic of fe.py's queued requests (everything the server does for `eval`, "
                        "`cells`, `locate`, `press`, ..., but not for --preemptive requests), e.g. to see what a "
                        "click or key press caused")
    p.add_argument("--limit", type=int, default=100, help="packets to print at most (0: no limit; default: %(default)s)")
    p.add_argument("--width", type=int, default=300,
                   help="characters to print per packet at most (0: no limit; default: %(default)s)")
    p.add_argument("--file", help="read this log file (e.g. after `stop`) instead of the selected server's")
    p.add_argument("--path", action="store_true", help="just print the log file's path (to grep or read it directly)")
    return parser


def main(argv=None):
    # Results can contain any character; don't fail on them where the console or pipe encoding is a legacy code page
    # (e.g. on Windows):
    for stream, encoding in ((sys.stdout, "utf-8"), (sys.stderr, "utf-8"), (sys.stdin, "utf-8-sig")):
        if hasattr(stream, "reconfigure") and stream.encoding.lower().replace("-", "") != "utf8":
            stream.reconfigure(encoding=encoding, errors="replace" if stream is not sys.stdin else "strict")
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
        if isinstance(e, screen_backend().ScreenError):
            if args.json:
                error_type = getattr(e, "error_type", "ScreenError")  # InputBlocked: Windows is discarding input
                print(json.dumps({"ok": False, "errorType": error_type, "error": str(e)}, indent=1))
                return 1
            print(f"error ({'Windows' if WINDOWS else 'X11'}): {e}", file=sys.stderr)
            return 1
        raise
    return 0


if __name__ == "__main__":
    sys.exit(main())
