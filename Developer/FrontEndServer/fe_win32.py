"""Minimal Win32 helpers for driving a Wolfram front end on Windows (screenshots, window queries, synthetic input).

The Windows counterpart of fe_x11.py, with the same interface. Pure Python standard library: talks to user32/gdi32
through ctypes. The process is made per-monitor DPI aware, so all coordinates are physical screen pixels.
"""

import ctypes
import time
from ctypes import POINTER, Structure, Union, byref, c_int, c_long, c_uint, c_void_p, sizeof
from ctypes import wintypes as wt

from fe_image import encode_png, scale_rgb

user32 = ctypes.WinDLL("user32", use_last_error=True)
gdi32 = ctypes.WinDLL("gdi32", use_last_error=True)
kernel32 = ctypes.WinDLL("kernel32", use_last_error=True)
dwmapi = ctypes.WinDLL("dwmapi")


class ScreenError(Exception):
    pass


# ---------------------------------------------------------------------------------------------------------------------
# Library setup
# ---------------------------------------------------------------------------------------------------------------------

ULONG_PTR = ctypes.c_size_t
WNDENUMPROC = ctypes.WINFUNCTYPE(wt.BOOL, wt.HWND, wt.LPARAM)


class MOUSEINPUT(Structure):
    _fields_ = [("dx", c_long), ("dy", c_long), ("mouseData", wt.DWORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ULONG_PTR)]


class KEYBDINPUT(Structure):
    _fields_ = [("wVk", wt.WORD), ("wScan", wt.WORD), ("dwFlags", wt.DWORD), ("time", wt.DWORD),
                ("dwExtraInfo", ULONG_PTR)]


class HARDWAREINPUT(Structure):
    _fields_ = [("uMsg", wt.DWORD), ("wParamL", wt.WORD), ("wParamH", wt.WORD)]


class _INPUTUNION(Union):
    _fields_ = [("mi", MOUSEINPUT), ("ki", KEYBDINPUT), ("hi", HARDWAREINPUT)]


class INPUT(Structure):
    _fields_ = [("type", wt.DWORD), ("u", _INPUTUNION)]


class BITMAPINFOHEADER(Structure):
    _fields_ = [("biSize", wt.DWORD), ("biWidth", c_long), ("biHeight", c_long), ("biPlanes", wt.WORD),
                ("biBitCount", wt.WORD), ("biCompression", wt.DWORD), ("biSizeImage", wt.DWORD),
                ("biXPelsPerMeter", c_long), ("biYPelsPerMeter", c_long), ("biClrUsed", wt.DWORD),
                ("biClrImportant", wt.DWORD)]


class BITMAPINFO(Structure):
    _fields_ = [("bmiHeader", BITMAPINFOHEADER), ("bmiColors", wt.DWORD * 3)]


INPUT_MOUSE, INPUT_KEYBOARD = 0, 1
MOUSEEVENTF_MOVE, MOUSEEVENTF_ABSOLUTE, MOUSEEVENTF_VIRTUALDESK = 0x0001, 0x8000, 0x4000
MOUSEEVENTF_WHEEL, MOUSEEVENTF_HWHEEL = 0x0800, 0x1000
MOUSE_BUTTONS = {1: (0x0002, 0x0004), 2: (0x0020, 0x0040), 3: (0x0008, 0x0010)}  # X11 button number: (down, up)
KEYEVENTF_EXTENDEDKEY, KEYEVENTF_KEYUP, KEYEVENTF_UNICODE = 0x0001, 0x0002, 0x0004
WHEEL_DELTA = 120

SM_XVIRTUALSCREEN, SM_YVIRTUALSCREEN, SM_CXVIRTUALSCREEN, SM_CYVIRTUALSCREEN = 76, 77, 78, 79
SRCCOPY, CAPTUREBLT = 0x00CC0020, 0x40000000
DIB_RGB_COLORS, BI_RGB = 0, 0
PW_RENDERFULLCONTENT = 2
GA_ROOT = 2
GWL_STYLE, GWL_EXSTYLE = -16, -20
WS_POPUP, WS_CAPTION, WS_EX_TOOLWINDOW = 0x80000000, 0x00C00000, 0x00000080
DWMWA_EXTENDED_FRAME_BOUNDS, DWMWA_CLOAKED = 9, 14
SW_RESTORE = 9
COLOR_HIGHLIGHT = 13
WM_CLOSE = 0x0010
VK_MENU = 0x12
ES_DISPLAY_REQUIRED = 0x00000002
UOI_NAME = 2
DESKTOP_READOBJECTS = 0x0001


def _signatures():
    """Declare argument types, so that 64-bit handles are passed correctly."""
    H = wt.HANDLE
    for name, args, res in [
        ("EnumWindows", [WNDENUMPROC, wt.LPARAM], wt.BOOL),
        ("EnumChildWindows", [wt.HWND, WNDENUMPROC, wt.LPARAM], wt.BOOL),
        ("GetWindowTextW", [wt.HWND, wt.LPWSTR, c_int], c_int),
        ("GetClassNameW", [wt.HWND, wt.LPWSTR, c_int], c_int),
        ("GetWindowThreadProcessId", [wt.HWND, POINTER(wt.DWORD)], wt.DWORD),
        ("GetWindowRect", [wt.HWND, POINTER(wt.RECT)], wt.BOOL),
        ("GetClientRect", [wt.HWND, POINTER(wt.RECT)], wt.BOOL),
        ("ClientToScreen", [wt.HWND, POINTER(wt.POINT)], wt.BOOL),
        ("IsWindow", [wt.HWND], wt.BOOL),
        ("IsWindowVisible", [wt.HWND], wt.BOOL),
        ("IsIconic", [wt.HWND], wt.BOOL),
        ("GetAncestor", [wt.HWND, c_uint], wt.HWND),
        ("GetForegroundWindow", [], wt.HWND),
        ("SetForegroundWindow", [wt.HWND], wt.BOOL),
        ("BringWindowToTop", [wt.HWND], wt.BOOL),
        ("ShowWindow", [wt.HWND, c_int], wt.BOOL),
        ("PostMessageW", [wt.HWND, c_uint, wt.WPARAM, wt.LPARAM], wt.BOOL),
        ("AttachThreadInput", [wt.DWORD, wt.DWORD, wt.BOOL], wt.BOOL),
        ("GetSystemMetrics", [c_int], c_int),
        ("GetSysColor", [c_int], wt.DWORD),
        ("GetDC", [wt.HWND], wt.HDC),
        ("GetWindowDC", [wt.HWND], wt.HDC),
        ("ReleaseDC", [wt.HWND, wt.HDC], c_int),
        ("PrintWindow", [wt.HWND, wt.HDC, c_uint], wt.BOOL),
        ("SendInput", [c_uint, POINTER(INPUT), c_int], c_uint),
        ("SetCursorPos", [c_int, c_int], wt.BOOL),
        ("GetCursorPos", [POINTER(wt.POINT)], wt.BOOL),
        ("WindowFromPoint", [wt.POINT], wt.HWND),
        ("VkKeyScanW", [wt.WCHAR], ctypes.c_short),
        ("MapVirtualKeyW", [c_uint, c_uint], c_uint),
        ("OpenInputDesktop", [wt.DWORD, wt.BOOL, wt.DWORD], H),
        ("GetThreadDesktop", [wt.DWORD], H),
        ("CloseDesktop", [H], wt.BOOL),
        ("GetUserObjectInformationW", [H, c_int, c_void_p, wt.DWORD, POINTER(wt.DWORD)], wt.BOOL),
    ]:
        f = getattr(user32, name)
        f.argtypes, f.restype = args, res
    for name, args, res in [
        ("CreateCompatibleDC", [wt.HDC], wt.HDC),
        ("CreateCompatibleBitmap", [wt.HDC, c_int, c_int], wt.HBITMAP),
        ("SelectObject", [wt.HDC, wt.HGDIOBJ], wt.HGDIOBJ),
        ("BitBlt", [wt.HDC, c_int, c_int, c_int, c_int, wt.HDC, c_int, c_int, wt.DWORD], wt.BOOL),
        ("GetDIBits", [wt.HDC, wt.HBITMAP, c_uint, c_uint, c_void_p, POINTER(BITMAPINFO), c_uint], c_int),
        ("DeleteObject", [wt.HGDIOBJ], wt.BOOL),
        ("DeleteDC", [wt.HDC], wt.BOOL),
    ]:
        f = getattr(gdi32, name)
        f.argtypes, f.restype = args, res
    global _get_window_long
    # GetWindowLongPtrW is an alias of GetWindowLongW in 32-bit Windows:
    _get_window_long = getattr(user32, "GetWindowLongPtrW", None) or user32.GetWindowLongW
    _get_window_long.argtypes, _get_window_long.restype = [wt.HWND, c_int], ctypes.c_ssize_t
    kernel32.GetCurrentThreadId.restype = wt.DWORD
    kernel32.SetThreadExecutionState.argtypes = [wt.DWORD]
    kernel32.SetThreadExecutionState.restype = wt.DWORD
    dwmapi.DwmGetWindowAttribute.argtypes = [wt.HWND, wt.DWORD, c_void_p, wt.DWORD]
    dwmapi.DwmGetWindowAttribute.restype = c_long


def _dpi_aware():
    """Make this process per-monitor DPI aware, so that window rectangles, the cursor and screen captures all use
    physical pixels (otherwise Windows scales them to 96 dpi, e.g. on a 125% display)."""
    try:
        if user32.SetProcessDpiAwarenessContext(c_void_p(-4)):  # DPI_AWARENESS_CONTEXT_PER_MONITOR_AWARE_V2
            return
    except AttributeError:
        pass
    try:
        ctypes.WinDLL("shcore").SetProcessDpiAwareness(2)  # PROCESS_PER_MONITOR_DPI_AWARE
    except (AttributeError, OSError):
        user32.SetProcessDPIAware()


_signatures()
_dpi_aware()


def _check(result, what):
    if not result:
        raise ScreenError(f"{what} failed (Windows error {ctypes.get_last_error()})")
    return result


# ---------------------------------------------------------------------------------------------------------------------
# Display
# ---------------------------------------------------------------------------------------------------------------------

class Display:
    """The interactive Windows desktop. `name` is accepted for compatibility with fe_x11.Display and ignored."""

    def __init__(self, name=None):
        self.name = name or "desktop"
        self.left = user32.GetSystemMetrics(SM_XVIRTUALSCREEN)
        self.top = user32.GetSystemMetrics(SM_YVIRTUALSCREEN)
        self.width = user32.GetSystemMetrics(SM_CXVIRTUALSCREEN)
        self.height = user32.GetSystemMetrics(SM_CYVIRTUALSCREEN)

    def close(self):
        pass

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # --- windows -----------------------------------------------------------------------------------------------------

    @staticmethod
    def _text(func, hwnd, size=512):
        buf = ctypes.create_unicode_buffer(size)
        func(hwnd, buf, size)
        return buf.value

    @staticmethod
    def window_pid(hwnd):
        pid = wt.DWORD()
        user32.GetWindowThreadProcessId(hwnd, byref(pid))
        return pid.value or None

    @staticmethod
    def _cloaked(hwnd):
        """Windows on another virtual desktop (and suspended UWP windows) are visible but cloaked by DWM."""
        cloaked = wt.DWORD()
        return dwmapi.DwmGetWindowAttribute(hwnd, DWMWA_CLOAKED, byref(cloaked), sizeof(cloaked)) == 0 and bool(
            cloaked.value)

    @staticmethod
    def frame(hwnd):
        """The visible window rectangle (without the invisible resize borders): (x, y, width, height)."""
        r = wt.RECT()
        if dwmapi.DwmGetWindowAttribute(hwnd, DWMWA_EXTENDED_FRAME_BOUNDS, byref(r), sizeof(r)) != 0:
            if not user32.GetWindowRect(hwnd, byref(r)):
                return None
        return r.left, r.top, r.right - r.left, r.bottom - r.top

    @staticmethod
    def client(hwnd):
        """The client area (below the title and menu bars, i.e. what WindowSize measures): (x, y, width, height)."""
        r, p = wt.RECT(), wt.POINT(0, 0)
        if not user32.GetClientRect(hwnd, byref(r)) or not user32.ClientToScreen(hwnd, byref(p)):
            return None
        return p.x, p.y, r.right, r.bottom

    def _popup(self, hwnd):
        """Like an override-redirect window in X11: menus, tooltips and other windows without a title bar. Notebook
        windows are never popups, also when they have no title bar (e.g. WindowFrame -> "Frameless")."""
        if self._text(user32.GetClassNameW, hwnd, 256) == "NotebookFrame":
            return False
        style = _get_window_long(hwnd, GWL_STYLE) & 0xFFFFFFFF
        exstyle = _get_window_long(hwnd, GWL_EXSTYLE) & 0xFFFFFFFF
        return bool(style & WS_POPUP and style & WS_CAPTION != WS_CAPTION or exstyle & WS_EX_TOOLWINDOW)

    def geometry(self, window):
        """Return (x, y, width, height, viewable, popup) of a window's visible rectangle, or None."""
        if not user32.IsWindow(window):
            return None
        rect = self.frame(window)
        if not rect:
            return None
        viewable = bool(user32.IsWindowVisible(window)) and not user32.IsIconic(window) and not self._cloaked(window)
        return rect + (viewable, self._popup(window))

    def window_at(self, x, y):
        """The top-level window that is visible at a screen point (and would receive a click there), or None."""
        hwnd = user32.WindowFromPoint(wt.POINT(int(round(x)), int(round(y))))
        return user32.GetAncestor(hwnd, GA_ROOT) if hwnd else None

    def windows(self, only_viewable=True):
        """List top-level windows in stacking order, bottom to top. x, y, width and height are the client area (where
        a notebook's WindowSize applies); `frame` is the visible window rectangle including the title bar, and
        `outer` the top left corner of the window rectangle including its invisible borders (where WindowMargins
        apply)."""
        handles = []

        def visit(hwnd, _):
            handles.append(hwnd)
            return True

        user32.EnumWindows(WNDENUMPROC(visit), 0)
        found = []
        for hwnd in reversed(handles):  # EnumWindows lists the topmost window first
            geo = self.geometry(hwnd)
            if geo is None or (only_viewable and not geo[4]):
                continue
            name_class = self._text(user32.GetClassNameW, hwnd, 256)
            if name_class == "SysShadow":  # the drop shadows of menus
                continue
            client = self.client(hwnd) or geo[:4]
            outer = wt.RECT()
            user32.GetWindowRect(hwnd, byref(outer))
            found.append({
                "id": hwnd, "name": self._text(user32.GetWindowTextW, hwnd), "class": name_class,
                "instance": name_class, "pid": self.window_pid(hwnd), "x": client[0], "y": client[1],
                "width": client[2], "height": client[3], "frame": list(geo[:4]), "outer": [outer.left, outer.top],
                "viewable": geo[4], "override_redirect": geo[5],
            })
        return found

    def toplevel_frame(self, window):
        return user32.GetAncestor(window, GA_ROOT) or window

    def pane(self, window, class_name):
        """The screen rectangle of a window's visible child window of the given class, e.g. a notebook's
        "NotebookContent", "DockedCellsContent" or "SidebarContent" pane: (x, y, width, height), or None."""
        found = []

        def visit(hwnd, _):
            if user32.IsWindowVisible(hwnd) and self._text(user32.GetClassNameW, hwnd, 256) == class_name:
                found.append(hwnd)
                return False
            return True

        user32.EnumChildWindows(window, WNDENUMPROC(visit), 0)
        return self.client(found[0]) if found else None

    @staticmethod
    def dpi():
        try:
            return user32.GetDpiForSystem()
        except AttributeError:  # before Windows 10 1607
            return 96

    @staticmethod
    def selection_color():
        """The front end highlights selections in the system's highlight color."""
        color = user32.GetSysColor(COLOR_HIGHLIGHT)
        return color & 0xFF, (color >> 8) & 0xFF, (color >> 16) & 0xFF

    def close_window(self, window):
        """Ask a window to close, as its close button would."""
        user32.PostMessageW(window, WM_CLOSE, 0, 0)

    # --- session state -----------------------------------------------------------------------------------------------

    @staticmethod
    def input_desktop():
        """Name of the desktop that receives input ("Default" normally, "Winlogon" while the session is locked), or
        None if it cannot be opened (e.g. on the secure desktop of a UAC prompt)."""
        handle = user32.OpenInputDesktop(0, False, DESKTOP_READOBJECTS)
        if not handle:
            return None
        try:
            buf, needed = ctypes.create_unicode_buffer(256), wt.DWORD()
            user32.GetUserObjectInformationW(handle, UOI_NAME, buf, sizeof(buf), byref(needed))
            return buf.value
        finally:
            user32.CloseDesktop(handle)

    def require_interactive(self, what="this"):
        """Screen captures come back black and synthetic input is discarded unless this process's desktop is the one
        receiving input; fail with an explanation instead."""
        kernel32.SetThreadExecutionState(ES_DISPLAY_REQUIRED)  # wake the display, as user input would
        current = user32.GetThreadDesktop(kernel32.GetCurrentThreadId())
        buf, needed = ctypes.create_unicode_buffer(256), wt.DWORD()
        user32.GetUserObjectInformationW(current, UOI_NAME, buf, sizeof(buf), byref(needed))
        active = self.input_desktop()
        if active != buf.value:
            raise ScreenError(f"Windows is not showing this desktop (input desktop: {active or 'secure desktop'}), so "
                           f"{what} is not possible: the session is locked, or a UAC prompt or the screen saver is "
                           "active. Unlock it, or use commands that need no screen: eval, press, screenshot --fe.")

    # --- screenshots -------------------------------------------------------------------------------------------------

    def capture(self, x=0, y=0, width=None, height=None):
        """Capture a region of the screen. Returns (width, height, packed RGB bytes).

        The region is clipped to the (virtual) screen. Because the screen is captured, this shows exactly what is
        visible, including popup menus and overlapping windows.
        """
        width = self.left + self.width - x if width is None else width
        height = self.top + self.height - y if height is None else height
        x0, y0 = max(self.left, x), max(self.top, y)
        x1, y1 = min(self.left + self.width, x + width), min(self.top + self.height, y + height)
        if x1 <= x0 or y1 <= y0:
            raise ScreenError(f"Capture region {x},{y} {width}x{height} lies outside the screen")
        self.require_interactive("taking a screenshot")
        screen = _check(user32.GetDC(None), "GetDC")
        try:
            return self._blit(screen, x0, y0, x1 - x0, y1 - y0)
        finally:
            user32.ReleaseDC(None, screen)

    def capture_window(self, window):
        """Capture a window's own content (even where other windows cover it) with PrintWindow, cropped to its visible
        rectangle. Returns (x, y, width, height, packed RGB bytes); x and y are the rectangle's screen position."""
        outer = wt.RECT()
        _check(user32.GetWindowRect(window, byref(outer)), "GetWindowRect")
        fx, fy, fw, fh = self.frame(window)
        w, h = outer.right - outer.left, outer.bottom - outer.top
        screen = _check(user32.GetDC(None), "GetDC")
        memory = gdi32.CreateCompatibleDC(screen)
        bitmap = gdi32.CreateCompatibleBitmap(screen, w, h)
        old = gdi32.SelectObject(memory, bitmap)
        try:
            _check(user32.PrintWindow(window, memory, PW_RENDERFULLCONTENT), "PrintWindow")
            _, _, rgb = self._read_bitmap(memory, bitmap, w, h)
        finally:
            gdi32.SelectObject(memory, old)
            gdi32.DeleteObject(bitmap)
            gdi32.DeleteDC(memory)
            user32.ReleaseDC(None, screen)
        # Crop the invisible resize borders:
        dx, dy = fx - outer.left, fy - outer.top
        stride = w * 3
        cropped = b"".join(rgb[(dy + row) * stride + dx * 3:(dy + row) * stride + (dx + fw) * 3] for row in range(fh))
        return fx, fy, fw, fh, cropped

    def _blit(self, source, x, y, w, h):
        memory = gdi32.CreateCompatibleDC(source)
        bitmap = gdi32.CreateCompatibleBitmap(source, w, h)
        old = gdi32.SelectObject(memory, bitmap)
        try:
            # CAPTUREBLT includes layered windows (menus, tooltips):
            _check(gdi32.BitBlt(memory, 0, 0, w, h, source, x, y, SRCCOPY | CAPTUREBLT), "BitBlt")
            return self._read_bitmap(memory, bitmap, w, h)
        finally:
            gdi32.SelectObject(memory, old)
            gdi32.DeleteObject(bitmap)
            gdi32.DeleteDC(memory)

    @staticmethod
    def _read_bitmap(memory, bitmap, w, h):
        info = BITMAPINFO()
        info.bmiHeader.biSize = sizeof(BITMAPINFOHEADER)
        info.bmiHeader.biWidth, info.bmiHeader.biHeight = w, -h  # negative height: top-down rows
        info.bmiHeader.biPlanes, info.bmiHeader.biBitCount, info.bmiHeader.biCompression = 1, 32, BI_RGB
        buf = ctypes.create_string_buffer(w * h * 4)
        if gdi32.GetDIBits(memory, bitmap, 0, h, buf, byref(info), DIB_RGB_COLORS) != h:
            raise ScreenError("GetDIBits failed")
        bgrx = buf.raw
        rgb = bytearray(w * h * 3)
        rgb[0::3], rgb[1::3], rgb[2::3] = bgrx[2::4], bgrx[1::4], bgrx[0::4]
        return w, h, rgb

    def screenshot(self, path, x=0, y=0, width=None, height=None, scale=1.0):
        w, h, rgb = self.capture(x, y, width, height)
        return self._save(path, w, h, rgb, scale)

    def screenshot_window(self, path, window, scale=1.0):
        """Screenshot a window without raising it (see capture_window); also returns its screen position."""
        x, y, w, h, rgb = self.capture_window(window)
        return dict(self._save(path, w, h, rgb, scale), x=x, y=y, capturedWidth=w, capturedHeight=h)

    @staticmethod
    def _save(path, w, h, rgb, scale):
        w, h, rgb = scale_rgb(w, h, rgb, scale)
        with open(path, "wb") as f:
            f.write(encode_png(w, h, rgb))
        return {"path": path, "width": w, "height": h}

    # --- focus -------------------------------------------------------------------------------------------------------

    def activate(self, window):
        """Bring a window to the front and give it the keyboard focus.

        Windows only lets the process that owns the foreground window (or that received the last input) change it;
        otherwise SetForegroundWindow just flashes the taskbar button. Attaching to the foreground window's input
        queue lifts that restriction, and as a last resort an injected Alt key press does. Returns whether the window
        is in the foreground now."""
        hwnd = self.toplevel_frame(window)
        if user32.IsIconic(hwnd):
            user32.ShowWindow(hwnd, SW_RESTORE)
        for attempt in range(3):
            if user32.GetForegroundWindow() == hwnd:
                return True
            if attempt == 0:
                user32.SetForegroundWindow(hwnd)
            elif attempt == 1:
                foreground = user32.GetForegroundWindow()
                theirs = user32.GetWindowThreadProcessId(foreground, None) if foreground else 0
                ours = kernel32.GetCurrentThreadId()
                attached = bool(theirs) and theirs != ours and user32.AttachThreadInput(ours, theirs, True)
                try:
                    user32.BringWindowToTop(hwnd)
                    user32.SetForegroundWindow(hwnd)
                finally:
                    if attached:
                        user32.AttachThreadInput(ours, theirs, False)
            else:
                # A tap of Alt makes this process the last one to have sent input. Tapping it twice keeps the
                # window's menu bar from being activated by the lone Alt release.
                self._send_keys([(VK_MENU, False), (VK_MENU, True), (VK_MENU, False), (VK_MENU, True)])
                user32.SetForegroundWindow(hwnd)
            time.sleep(0.05)
        return user32.GetForegroundWindow() == hwnd

    def focused_window(self):
        return user32.GetForegroundWindow() or 0

    # --- pointer -----------------------------------------------------------------------------------------------------

    def pointer(self):
        p = wt.POINT()
        user32.GetCursorPos(byref(p))
        return p.x, p.y

    def _send(self, inputs, what):
        array = (INPUT * len(inputs))(*inputs)
        if user32.SendInput(len(inputs), array, sizeof(INPUT)) != len(inputs):
            self.require_interactive(f"synthetic {what} input")
            raise ScreenError(f"Windows rejected the synthetic {what} input (error {ctypes.get_last_error()}); input "
                           "to windows of elevated processes is blocked")

    @staticmethod
    def _mouse(flags, dx=0, dy=0, data=0):
        return INPUT(type=INPUT_MOUSE, u=_INPUTUNION(mi=MOUSEINPUT(dx=dx, dy=dy, mouseData=data & 0xFFFFFFFF,
                                                                   dwFlags=flags)))

    def move(self, x, y):
        x, y = int(round(x)), int(round(y))
        # Absolute coordinates are normalized to 0..65535 across the virtual screen:
        nx = ((x - self.left) * 65536 + self.width // 2) // max(1, self.width)
        ny = ((y - self.top) * 65536 + self.height // 2) // max(1, self.height)
        self._send([self._mouse(MOUSEEVENTF_MOVE | MOUSEEVENTF_ABSOLUTE | MOUSEEVENTF_VIRTUALDESK, nx, ny)],
                   "pointer motion")
        if self.pointer() != (x, y):  # rounding of the normalized coordinates
            user32.SetCursorPos(x, y)

    def button(self, button, press):
        if button in (4, 5, 6, 7):  # X11 wheel buttons
            if press:
                self._wheel(-1 if button in (5, 7) else 1, horizontal=button in (6, 7))
            return
        down, up = MOUSE_BUTTONS[button]
        self._send([self._mouse(down if press else up)], "button")

    def _wheel(self, notches, horizontal=False):
        # Positive vertical deltas scroll up, positive horizontal ones scroll right:
        delta = notches * WHEEL_DELTA * (-1 if horizontal else 1)
        self._send([self._mouse(MOUSEEVENTF_HWHEEL if horizontal else MOUSEEVENTF_WHEEL, data=delta)], "wheel")

    def click(self, x, y, button=1, count=1, modifiers=(), delay=0.05):
        self.move(x, y)
        time.sleep(delay)
        held = self._press_modifiers(modifiers)
        try:
            for i in range(count):
                self.button(button, True)
                try:
                    time.sleep(0.01)
                finally:
                    self.button(button, False)  # never leave the button held (e.g. on Ctrl-C)
                time.sleep(0.06 if count > 1 else delay)
        finally:
            self._release_modifiers(held)

    def drag(self, x0, y0, x1, y1, button=1, steps=12, delay=0.02):
        self.move(x0, y0)
        time.sleep(delay)
        self.button(button, True)
        try:
            for i in range(1, steps + 1):
                self.move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
                time.sleep(delay)
        finally:
            self.button(button, False)

    def scroll(self, x, y, clicks=3, horizontal=False):
        """Scroll at (x, y). Positive clicks scroll down/right, negative up/left."""
        self.move(x, y)
        time.sleep(0.03)
        for _ in range(abs(int(clicks))):
            self._wheel(-1 if clicks > 0 else 1, horizontal=horizontal)  # a notch "up/left", as X11 buttons 4 and 6
            time.sleep(0.02)

    # --- keyboard ----------------------------------------------------------------------------------------------------

    # Modifier names as in fe_x11 ("meta" is Alt, as on Linux; "win", "super" and "cmd" are the Windows key):
    _MODIFIER_KEYS = {
        "ctrl": 0xA2, "control": 0xA2, "shift": 0xA0, "alt": 0xA4, "meta": 0xA4, "super": 0x5B, "win": 0x5B,
        "cmd": 0x5B, "altgr": 0xA5,
    }

    # X11 keysym names (as accepted by fe_x11), so that key names work the same on both platforms:
    _KEY_ALIASES = {
        "enter": "Return", "return": "Return", "esc": "Escape", "escape": "Escape", "tab": "Tab",
        "backspace": "BackSpace", "bs": "BackSpace", "delete": "Delete", "del": "Delete", "space": "space",
        "up": "Up", "down": "Down", "left": "Left", "right": "Right", "home": "Home", "end": "End",
        "pageup": "Prior", "pgup": "Prior", "pagedown": "Next", "pgdn": "Next", "insert": "Insert",
        "menu": "Menu", "kp_enter": "KP_Enter", "page_up": "Prior", "page_down": "Next",
    }

    # Virtual-key codes; True marks extended keys (which need KEYEVENTF_EXTENDEDKEY):
    _VIRTUAL_KEYS = {
        "Return": (0x0D, False), "KP_Enter": (0x0D, True), "BackSpace": (0x08, False), "Tab": (0x09, False),
        "Escape": (0x1B, False), "space": (0x20, False), "Prior": (0x21, True), "Next": (0x22, True),
        "End": (0x23, True), "Home": (0x24, True), "Left": (0x25, True), "Up": (0x26, True), "Right": (0x27, True),
        "Down": (0x28, True), "Insert": (0x2D, True), "Delete": (0x2E, True), "Menu": (0x5D, True),
        "Pause": (0x13, False), "Print": (0x2C, True), "Caps_Lock": (0x14, False), "Num_Lock": (0x90, True),
        "Scroll_Lock": (0x91, False), "Control_L": (0xA2, False), "Control_R": (0xA3, True),
        "Shift_L": (0xA0, False), "Shift_R": (0xA1, False), "Alt_L": (0xA4, False), "Alt_R": (0xA5, True),
        "Super_L": (0x5B, True), "Super_R": (0x5C, True), "Help": (0x2F, False), "Clear": (0x0C, False),
        "Break": (0x03, True), "Sys_Req": (0x2C, True), "KP_Add": (0x6B, False), "KP_Subtract": (0x6D, False),
        "KP_Multiply": (0x6A, False), "KP_Divide": (0x6F, True), "KP_Decimal": (0x6E, False),
        **{f"KP_{n}": (0x60 + n, False) for n in range(10)},
        **{f"F{n}": (0x6F + n, False) for n in range(1, 25)},
    }

    _CHAR_NAMES = {
        "exclam": "!", "quotedbl": '"', "numbersign": "#", "dollar": "$", "percent": "%", "ampersand": "&",
        "apostrophe": "'", "parenleft": "(", "parenright": ")", "asterisk": "*", "plus": "+", "comma": ",",
        "minus": "-", "period": ".", "slash": "/", "colon": ":", "semicolon": ";", "less": "<", "equal": "=",
        "greater": ">", "question": "?", "at": "@", "bracketleft": "[", "backslash": "\\", "bracketright": "]",
        "asciicircum": "^", "underscore": "_", "grave": "`", "braceleft": "{", "bar": "|", "braceright": "}",
        "asciitilde": "~",
    }

    _CONTROL_CHARACTERS = {"\n": "Return", "\r": "Return", "\t": "Tab", "\b": "BackSpace", "\x1b": "Escape",
                           "\x7f": "Delete"}

    @staticmethod
    def _key(vk, up=False, extended=False, scan=None, unicode=False):
        flags = (KEYEVENTF_KEYUP if up else 0) | (KEYEVENTF_EXTENDEDKEY if extended else 0)
        if unicode:
            return INPUT(type=INPUT_KEYBOARD, u=_INPUTUNION(ki=KEYBDINPUT(wVk=0, wScan=scan,
                                                                          dwFlags=flags | KEYEVENTF_UNICODE)))
        scan = user32.MapVirtualKeyW(vk, 0) if scan is None else scan  # MAPVK_VK_TO_VSC
        return INPUT(type=INPUT_KEYBOARD, u=_INPUTUNION(ki=KEYBDINPUT(wVk=vk, wScan=scan, dwFlags=flags)))

    def _send_keys(self, events):
        """events: [(vk, up)] for keys that are not extended."""
        self._send([self._key(vk, up) for vk, up in events], "key")

    def keysym(self, name):
        """Resolve a key name ('Return', 'a', 'F5', an alias like 'enter', or an X11 name like 'comma') or a single
        character to (virtual-key code, extended, shift needed)."""
        if len(name) == 1 and name in self._CONTROL_CHARACTERS:
            name = self._CONTROL_CHARACTERS[name]
        if len(name) > 1:
            name = self._CHAR_NAMES.get(name, name)
        if len(name) > 1:
            key = self._VIRTUAL_KEYS.get(self._KEY_ALIASES.get(name.lower(), name))
            if not key:
                raise ScreenError(f"Unknown key name: {name!r}")
            return key + (False,)
        if ord(name) < 0x20 or 0x7F <= ord(name) < 0xA0:
            raise ScreenError(f"Cannot type control character {name!r}")
        scan = user32.VkKeyScanW(name)
        if scan == -1 or (scan >> 8) & 0xFE:  # not on the keyboard layout, or needs Ctrl/Alt (AltGr)
            raise ScreenError(f"The key {name!r} is not on the current keyboard layout; type it with `type` instead")
        return scan & 0xFF, False, bool((scan >> 8) & 1)

    def _press_modifiers(self, modifiers):
        """Press modifier keys; returns their virtual-key codes for _release_modifiers."""
        held = []
        try:
            for mod in modifiers:
                vk = self._MODIFIER_KEYS.get(mod.lower())
                if not vk:
                    raise ScreenError(f"Unknown modifier: {mod!r} (use ctrl, shift, alt, meta, super, or altgr)")
                held.append(vk)  # first: releasing a key that was not pressed is harmless
                self._send([self._key(vk, extended=vk in (0xA5, 0x5B))], "key")
        except BaseException:
            self._release_modifiers(held)
            raise
        return held

    def _release_modifiers(self, held):
        for vk in reversed(held):
            self._send([self._key(vk, up=True, extended=vk in (0xA5, 0x5B))], "key")

    def _tap(self, vk, extended=False, shift=False):
        extra = self._press_modifiers(["shift"]) if shift else []
        try:
            self._send([self._key(vk, extended=extended)], "key")
            try:
                time.sleep(0.005)
            finally:
                self._send([self._key(vk, up=True, extended=extended)], "key")  # never leave the key held
        finally:
            self._release_modifiers(extra)

    def parse_key(self, combo):
        """Split a key combination like 'ctrl+shift+Return' into (modifiers, (virtual-key code, extended, shift
        needed)), checking every name."""
        parts = combo.split("+") if combo != "+" else ["+"]
        if parts[-1] == "" and len(parts) > 1:  # e.g. "ctrl++"
            parts = parts[:-2] + ["+"]
        *mods, main = parts
        for mod in mods:
            if mod.lower() not in self._MODIFIER_KEYS:
                raise ScreenError(f"Unknown modifier: {mod!r} (use ctrl, shift, alt, meta, super, or altgr)")
        return mods, self.keysym(main)

    def key(self, combo, repeat=1, delay=0.03):
        """Press a key combination such as 'ctrl+shift+Return', 'Escape', 'shift+Return', 'ctrl+a'."""
        mods, (vk, extended, shift) = self.parse_key(combo)
        shift = shift and "shift" not in [m.lower() for m in mods]
        for _ in range(repeat):
            held = self._press_modifiers(mods)
            try:
                self._tap(vk, extended, shift)
            finally:
                self._release_modifiers(held)
            time.sleep(delay)

    def type_text(self, text, delay=0.012):
        """Type literal text (newlines become Return, tabs become Tab). Characters are sent as Unicode input, so they
        don't depend on the keyboard layout or on Caps Lock."""
        text = text.replace("\r\n", "\n")
        for ch in text:  # fail before typing anything
            if ch in self._CONTROL_CHARACTERS:
                continue
            if ord(ch) < 0x20 or 0x7F <= ord(ch) < 0xA0:
                raise ScreenError(f"Cannot type control character {ch!r}")
        for ch in text:
            if ch in self._CONTROL_CHARACTERS:
                vk, extended, _ = self.keysym(ch)
                self._tap(vk, extended)
            else:
                units = ch.encode("utf-16-le")
                codes = [int.from_bytes(units[i:i + 2], "little") for i in range(0, len(units), 2)]
                self._send([self._key(0, scan=c, unicode=True) for c in codes]
                           + [self._key(0, up=True, scan=c, unicode=True) for c in codes], "key")
            time.sleep(delay)
