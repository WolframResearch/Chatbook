"""Minimal X11 helpers for driving a Wolfram front end (screenshots, window queries, synthetic input).

Pure Python standard library: talks to libX11/libXtst through ctypes, so no xdotool/ImageMagick/PIL is needed.
All coordinates are X11 root-window pixels unless stated otherwise.
"""

import ctypes
import ctypes.util
import math
import os
import struct
import time
import zlib
from ctypes import (POINTER, Structure, Union, byref, c_char, c_char_p, c_int, c_long, c_uint, c_ulong, c_ubyte,
                    c_void_p)

# ---------------------------------------------------------------------------------------------------------------------
# Library setup
# ---------------------------------------------------------------------------------------------------------------------

Window = c_ulong
Atom = c_ulong
KeySym = c_ulong
Bool = c_int
Time = c_ulong

_xlib = None
_xtst = None


class XImage(Structure):
    _fields_ = [
        ("width", c_int), ("height", c_int), ("xoffset", c_int), ("format", c_int),
        ("data", POINTER(c_char)),
        ("byte_order", c_int), ("bitmap_unit", c_int), ("bitmap_bit_order", c_int), ("bitmap_pad", c_int),
        ("depth", c_int), ("bytes_per_line", c_int), ("bits_per_pixel", c_int),
        ("red_mask", c_ulong), ("green_mask", c_ulong), ("blue_mask", c_ulong),
        ("obdata", c_void_p),
        ("f", c_void_p * 6),
    ]


class XWindowAttributes(Structure):
    _fields_ = [
        ("x", c_int), ("y", c_int), ("width", c_int), ("height", c_int), ("border_width", c_int), ("depth", c_int),
        ("visual", c_void_p), ("root", Window), ("class_", c_int), ("bit_gravity", c_int), ("win_gravity", c_int),
        ("backing_store", c_int), ("backing_planes", c_ulong), ("backing_pixel", c_ulong), ("save_under", Bool),
        ("colormap", c_ulong), ("map_installed", Bool), ("map_state", c_int), ("all_event_masks", c_long),
        ("your_event_mask", c_long), ("do_not_propagate_mask", c_long), ("override_redirect", Bool),
        ("screen", c_void_p),
    ]


class XkbStateRec(Structure):
    _fields_ = [
        ("group", c_ubyte), ("locked_group", c_ubyte), ("base_group", ctypes.c_ushort),
        ("latched_group", ctypes.c_ushort), ("mods", c_ubyte), ("base_mods", c_ubyte), ("latched_mods", c_ubyte),
        ("locked_mods", c_ubyte), ("compat_state", c_ubyte), ("grab_mods", c_ubyte), ("compat_grab_mods", c_ubyte),
        ("lookup_mods", c_ubyte), ("compat_lookup_mods", c_ubyte), ("ptr_buttons", ctypes.c_ushort),
    ]


class XClassHint(Structure):
    _fields_ = [("res_name", c_void_p), ("res_class", c_void_p)]


class _ClientMessageData(Union):
    _fields_ = [("b", c_char * 20), ("s", ctypes.c_short * 10), ("l", c_long * 5)]


class XClientMessageEvent(Structure):
    _fields_ = [
        ("type", c_int), ("serial", c_ulong), ("send_event", Bool), ("display", c_void_p), ("window", Window),
        ("message_type", Atom), ("format", c_int), ("data", _ClientMessageData),
    ]


class XEvent(Union):
    _fields_ = [("xclient", XClientMessageEvent), ("pad", c_long * 24)]


_ERROR_HANDLER_TYPE = ctypes.CFUNCTYPE(c_int, c_void_p, c_void_p)


def _ignore_x_errors(display, event):
    # Windows can disappear between XQueryTree and later requests; never let Xlib abort the process for that.
    return 0


_error_handler = _ERROR_HANDLER_TYPE(_ignore_x_errors)

ZPixmap = 2
XkbUseCoreKbd = 0x0100
IsViewable = 2
ClientMessage = 33
SubstructureRedirectMask = 1 << 20
SubstructureNotifyMask = 1 << 19
RevertToParent = 2
CurrentTime = 0
AnyPropertyType = 0


def _load():
    global _xlib, _xtst
    if _xlib is not None:
        return
    xlib = ctypes.CDLL(ctypes.util.find_library("X11") or "libX11.so.6")
    xtst = ctypes.CDLL(ctypes.util.find_library("Xtst") or "libXtst.so.6")

    xlib.XOpenDisplay.argtypes = [c_char_p]
    xlib.XOpenDisplay.restype = c_void_p
    xlib.XCloseDisplay.argtypes = [c_void_p]
    xlib.XDefaultRootWindow.argtypes = [c_void_p]
    xlib.XDefaultRootWindow.restype = Window
    xlib.XDefaultScreen.argtypes = [c_void_p]
    xlib.XDisplayWidth.argtypes = [c_void_p, c_int]
    xlib.XDisplayHeight.argtypes = [c_void_p, c_int]
    xlib.XSetErrorHandler.argtypes = [_ERROR_HANDLER_TYPE]
    xlib.XSetErrorHandler.restype = c_void_p
    xlib.XGetImage.argtypes = [c_void_p, Window, c_int, c_int, c_uint, c_uint, c_ulong, c_int]
    xlib.XGetImage.restype = POINTER(XImage)
    xlib.XDestroyImage.argtypes = [POINTER(XImage)]
    xlib.XQueryTree.argtypes = [c_void_p, Window, POINTER(Window), POINTER(Window), POINTER(POINTER(Window)),
                                POINTER(c_uint)]
    xlib.XGetWindowAttributes.argtypes = [c_void_p, Window, POINTER(XWindowAttributes)]
    xlib.XTranslateCoordinates.argtypes = [c_void_p, Window, Window, c_int, c_int, POINTER(c_int), POINTER(c_int),
                                           POINTER(Window)]
    xlib.XInternAtom.argtypes = [c_void_p, c_char_p, Bool]
    xlib.XInternAtom.restype = Atom
    xlib.XGetWindowProperty.argtypes = [c_void_p, Window, Atom, c_long, c_long, Bool, Atom, POINTER(Atom),
                                        POINTER(c_int), POINTER(c_ulong), POINTER(c_ulong), POINTER(c_void_p)]
    xlib.XFetchName.argtypes = [c_void_p, Window, POINTER(c_void_p)]
    xlib.XGetClassHint.argtypes = [c_void_p, Window, POINTER(XClassHint)]
    xlib.XFree.argtypes = [c_void_p]
    xlib.XFlush.argtypes = [c_void_p]
    xlib.XSync.argtypes = [c_void_p, Bool]
    xlib.XQueryPointer.argtypes = [c_void_p, Window, POINTER(Window), POINTER(Window), POINTER(c_int), POINTER(c_int),
                                   POINTER(c_int), POINTER(c_int), POINTER(c_uint)]
    xlib.XStringToKeysym.argtypes = [c_char_p]
    xlib.XStringToKeysym.restype = KeySym
    xlib.XKeysymToKeycode.argtypes = [c_void_p, KeySym]
    xlib.XKeysymToKeycode.restype = c_ubyte
    xlib.XDisplayKeycodes.argtypes = [c_void_p, POINTER(c_int), POINTER(c_int)]
    xlib.XGetKeyboardMapping.argtypes = [c_void_p, c_ubyte, c_int, POINTER(c_int)]
    xlib.XGetKeyboardMapping.restype = POINTER(KeySym)
    xlib.XChangeKeyboardMapping.argtypes = [c_void_p, c_int, c_int, POINTER(KeySym), c_int]
    xlib.XSendEvent.argtypes = [c_void_p, Window, Bool, c_long, POINTER(XEvent)]
    xlib.XSetInputFocus.argtypes = [c_void_p, Window, c_int, Time]
    xlib.XRaiseWindow.argtypes = [c_void_p, Window]
    xlib.XMapRaised.argtypes = [c_void_p, Window]
    xlib.XGetInputFocus.argtypes = [c_void_p, POINTER(Window), POINTER(c_int)]
    xlib.XkbGetState.argtypes = [c_void_p, c_uint, POINTER(XkbStateRec)]
    xlib.XkbLockGroup.argtypes = [c_void_p, c_uint, c_uint]

    xtst.XTestQueryExtension.argtypes = [c_void_p, POINTER(c_int), POINTER(c_int), POINTER(c_int), POINTER(c_int)]
    xtst.XTestFakeMotionEvent.argtypes = [c_void_p, c_int, c_int, c_int, c_ulong]
    xtst.XTestFakeButtonEvent.argtypes = [c_void_p, c_uint, Bool, c_ulong]
    xtst.XTestFakeKeyEvent.argtypes = [c_void_p, c_uint, Bool, c_ulong]

    xlib.XSetErrorHandler(_error_handler)
    _xlib, _xtst = xlib, xtst


class X11Error(Exception):
    pass


# ---------------------------------------------------------------------------------------------------------------------
# PNG encoding
# ---------------------------------------------------------------------------------------------------------------------

def _png_chunk(kind, data):
    chunk = kind + data
    return struct.pack(">I", len(data)) + chunk + struct.pack(">I", zlib.crc32(chunk) & 0xFFFFFFFF)


def encode_png(width, height, rgb):
    """Encode packed 8-bit RGB pixel data as a PNG byte string."""
    stride = width * 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]
    return (b"\x89PNG\r\n\x1a\n"
            + _png_chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0))
            + _png_chunk(b"IDAT", zlib.compress(bytes(raw), 6))
            + _png_chunk(b"IEND", b""))


def scale_rgb(width, height, rgb, factor):
    """Downscale packed RGB by `factor` (0 < factor <= 1) with area averaging, so thin lines don't disappear.
    Returns (width, height, rgb)."""
    if factor >= 1:
        return width, height, rgb
    halvings = math.log2(1 / factor)
    if abs(halvings - round(halvings)) < 1e-9:
        # Powers of 1/2 only need the fast 2x2 box filter (odd sizes round up, so no edge pixels are lost):
        for _ in range(round(halvings)):
            if width == 1 and height == 1:
                break
            width, height, rgb = _halve(width, height, rgb)
        return width, height, rgb
    nw, nh = max(1, int(round(width * factor))), max(1, int(round(height * factor)))
    # Halve quickly while the target is at most half the size, then average the rest exactly:
    while width >= 2 * nw and height >= 2 * nh and width >= 2 and height >= 2:
        width, height, rgb = _halve(width, height, rgb)
    if (width, height) != (nw, nh):
        width, height, rgb = _area_scale(width, height, rgb, nw, nh)
    return width, height, rgb


def _halve(width, height, rgb):
    """2x2 box filter. An odd last row/column is repeated, so that it still contributes to the result."""
    if width % 2 or height % 2:
        stride = width * 3
        rows = [bytes(rgb[y * stride:(y + 1) * stride]) for y in range(height)]
        if width % 2:
            rows = [row + row[-3:] for row in rows]
            width += 1
        if height % 2:
            rows.append(rows[-1])
            height += 1
        rgb = b"".join(rows)
    nw, nh = width // 2, height // 2
    out = bytearray(nw * nh * 3)
    stride = width * 3
    for y in range(nh):
        r0 = rgb[2 * y * stride:(2 * y + 1) * stride]
        r1 = rgb[(2 * y + 1) * stride:(2 * y + 2) * stride]
        o = y * nw * 3
        for c in range(3):
            a, b = r0[c::6][:nw], r0[c + 3::6][:nw]
            d, e = r1[c::6][:nw], r1[c + 3::6][:nw]
            out[o + c:o + nw * 3:3] = bytes((p + q + s + t + 2) >> 2 for p, q, s, t in zip(a, b, d, e))
    return nw, nh, out


def _area_weights(n_src, n_dst):
    """For each destination index, the source indices it covers with their (normalized) coverage."""
    step = n_src / n_dst
    weights = []
    for j in range(n_dst):
        a, b = j * step, (j + 1) * step
        row, i = [], int(a)
        while i < b and i < n_src:
            overlap = min(b, i + 1) - max(a, i)
            if overlap > 0:
                row.append((i, overlap / step))
            i += 1
        weights.append(row)
    return weights


def _area_scale(width, height, rgb, nw, nh):
    stride = width * 3
    rows = [rgb[y * stride:(y + 1) * stride] for y in range(height)]
    columns = _area_weights(width, nw)
    out = bytearray(nw * nh * 3)
    for j, row_weights in enumerate(_area_weights(height, nh)):
        acc = [0.0] * stride
        for i, w in row_weights:
            acc = [x + w * v for x, v in zip(acc, rows[i])]
        o = j * nw * 3
        for k, col_weights in enumerate(columns):
            for c in range(3):
                out[o + 3 * k + c] = min(255, int(sum(w * acc[3 * i + c] for i, w in col_weights) + 0.5))
    return nw, nh, out


# ---------------------------------------------------------------------------------------------------------------------
# Display connection
# ---------------------------------------------------------------------------------------------------------------------

class Display:
    """A connection to an X display (e.g. ":99")."""

    def __init__(self, name=None):
        _load()
        self.name = name or os.environ.get("DISPLAY")
        if not self.name:
            raise X11Error("No X display specified (set DISPLAY or pass --display)")
        self.dpy = _xlib.XOpenDisplay(self.name.encode())
        if not self.dpy:
            raise X11Error(f"Cannot open X display {self.name!r}")
        self.screen = _xlib.XDefaultScreen(self.dpy)
        self.root = _xlib.XDefaultRootWindow(self.dpy)
        self.width = _xlib.XDisplayWidth(self.dpy, self.screen)
        self.height = _xlib.XDisplayHeight(self.dpy, self.screen)
        self._atoms = {}
        self._keymap = None

    def close(self):
        if self.dpy:
            _xlib.XCloseDisplay(self.dpy)
            self.dpy = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()

    # --- atoms / properties ------------------------------------------------------------------------------------------

    def atom(self, name):
        if name not in self._atoms:
            self._atoms[name] = _xlib.XInternAtom(self.dpy, name.encode(), False)
        return self._atoms[name]

    def _get_property(self, window, name, req_type=AnyPropertyType):
        actual_type, actual_format = Atom(), c_int()
        nitems, bytes_after, prop = c_ulong(), c_ulong(), c_void_p()
        status = _xlib.XGetWindowProperty(self.dpy, window, self.atom(name), 0, 1 << 16, False, req_type,
                                          byref(actual_type), byref(actual_format), byref(nitems), byref(bytes_after),
                                          byref(prop))
        if status != 0 or not prop.value:
            return None
        try:
            n, fmt = nitems.value, actual_format.value
            if fmt == 8:
                return ctypes.string_at(prop.value, n)
            if fmt == 32:  # format-32 data is returned as an array of C longs
                return list((c_long * n).from_address(prop.value))
            if fmt == 16:
                return list((ctypes.c_short * n).from_address(prop.value))
            return None
        finally:
            _xlib.XFree(prop)

    def window_name(self, window):
        name = self._get_property(window, "_NET_WM_NAME")
        if name is not None:
            return name.decode("utf-8", "replace")
        raw = c_void_p()
        if _xlib.XFetchName(self.dpy, window, byref(raw)) and raw.value:
            value = ctypes.string_at(raw.value).decode("latin-1", "replace")
            _xlib.XFree(raw)
            return value
        return ""

    def window_class(self, window):
        hint = XClassHint()
        if _xlib.XGetClassHint(self.dpy, window, byref(hint)):
            name = ctypes.string_at(hint.res_name).decode("latin-1") if hint.res_name else ""
            klass = ctypes.string_at(hint.res_class).decode("latin-1") if hint.res_class else ""
            if hint.res_name:
                _xlib.XFree(hint.res_name)
            if hint.res_class:
                _xlib.XFree(hint.res_class)
            return name, klass
        return "", ""

    def window_pid(self, window):
        pid = self._get_property(window, "_NET_WM_PID")
        return int(pid[0]) if pid else None

    # --- window tree -------------------------------------------------------------------------------------------------

    def children(self, window):
        root, parent = Window(), Window()
        kids, n = POINTER(Window)(), c_uint()
        if not _xlib.XQueryTree(self.dpy, window, byref(root), byref(parent), byref(kids), byref(n)):
            return []
        try:
            return [kids[i] for i in range(n.value)]
        finally:
            if kids:
                _xlib.XFree(kids)

    def geometry(self, window):
        """Return (x, y, width, height, viewable, override_redirect) in root coordinates, or None."""
        attrs = XWindowAttributes()
        if not _xlib.XGetWindowAttributes(self.dpy, window, byref(attrs)):
            return None
        rx, ry, child = c_int(), c_int(), Window()
        _xlib.XTranslateCoordinates(self.dpy, window, self.root, 0, 0, byref(rx), byref(ry), byref(child))
        return rx.value, ry.value, attrs.width, attrs.height, attrs.map_state == IsViewable, bool(
            attrs.override_redirect)

    def windows(self, only_viewable=True):
        """List top-level client windows (those with a WM_CLASS) in stacking order, bottom to top.

        Override-redirect windows (popup menus, tooltips) are included and flagged.
        """
        found = []

        def visit(window, depth):
            for child in self.children(window):
                geo = self.geometry(child)
                if geo is None:
                    continue
                x, y, w, h, viewable, override = geo
                res_name, res_class = self.window_class(child)
                if res_class or override:
                    if viewable or not only_viewable:
                        found.append({
                            "id": child, "name": self.window_name(child), "class": res_class,
                            "instance": res_name, "pid": self.window_pid(child), "x": x, "y": y, "width": w,
                            "height": h, "viewable": viewable, "override_redirect": override,
                        })
                    if not override and res_class:
                        continue  # client window found; no need to descend further
                if depth < 3:
                    visit(child, depth + 1)

        visit(self.root, 0)
        return found

    def toplevel_frame(self, window):
        """Return the ancestor of `window` that is a direct child of the root (the WM frame, if any)."""
        current = window
        while True:
            root, parent = Window(), Window()
            kids, n = POINTER(Window)(), c_uint()
            if not _xlib.XQueryTree(self.dpy, current, byref(root), byref(parent), byref(kids), byref(n)):
                return current
            if kids:
                _xlib.XFree(kids)
            if parent.value in (0, self.root):
                return current
            current = parent.value

    # --- screenshots -------------------------------------------------------------------------------------------------

    def capture(self, x=0, y=0, width=None, height=None):
        """Capture a region of the root window. Returns (width, height, packed RGB bytes).

        The region is clipped to the screen. Because the root window is captured, this shows exactly what is on screen,
        including popup menus and overlapping windows.
        """
        width = self.width - x if width is None else width
        height = self.height - y if height is None else height
        x0, y0 = max(0, x), max(0, y)
        x1, y1 = min(self.width, x + width), min(self.height, y + height)
        if x1 <= x0 or y1 <= y0:
            raise X11Error(f"Capture region {x},{y} {width}x{height} lies outside the screen")
        w, h = x1 - x0, y1 - y0
        image = _xlib.XGetImage(self.dpy, self.root, x0, y0, w, h, 0xFFFFFFFF, ZPixmap)
        if not image:
            raise X11Error("XGetImage failed")
        try:
            img = image.contents
            masks = (img.red_mask, img.green_mask, img.blue_mask)
            if img.bits_per_pixel != 32 or masks not in ((0xFF0000, 0xFF00, 0xFF), (0xFF, 0xFF00, 0xFF0000)):
                raise X11Error(f"Unsupported pixel format: {img.bits_per_pixel} bits per pixel, depth {img.depth}, "
                               f"masks {tuple(hex(m) for m in masks)}")
            bpl = img.bytes_per_line
            data = ctypes.string_at(img.data, bpl * h)
            if img.byte_order == 0:  # LSBFirst: bytes are B, G, R, X when red_mask is 0xff0000
                offsets = (2, 1, 0) if img.red_mask == 0xFF0000 else (0, 1, 2)
            else:
                offsets = (1, 2, 3) if img.red_mask == 0xFF0000 else (3, 2, 1)
            rgb = bytearray(w * h * 3)
            for row in range(h):
                line = data[row * bpl:row * bpl + w * 4]
                base = row * w * 3
                rgb[base:base + w * 3:3] = line[offsets[0]::4]
                rgb[base + 1:base + w * 3:3] = line[offsets[1]::4]
                rgb[base + 2:base + w * 3:3] = line[offsets[2]::4]
            return w, h, rgb
        finally:
            _xlib.XDestroyImage(image)

    def screenshot(self, path, x=0, y=0, width=None, height=None, scale=1.0):
        w, h, rgb = self.capture(x, y, width, height)
        w, h, rgb = scale_rgb(w, h, rgb, scale)
        with open(path, "wb") as f:
            f.write(encode_png(w, h, rgb))
        return {"path": path, "width": w, "height": h}

    # --- focus -------------------------------------------------------------------------------------------------------

    def has_window_manager(self):
        """EWMH check: the root's _NET_SUPPORTING_WM_CHECK names a window that names itself (a WM that died leaves
        the root property behind, but its window is gone)."""
        check = self._get_property(self.root, "_NET_SUPPORTING_WM_CHECK")
        if not check:
            return False
        window = check[0] & 0xFFFFFFFF
        own = self._get_property(window, "_NET_SUPPORTING_WM_CHECK")
        return bool(own) and (own[0] & 0xFFFFFFFF) == window

    def activate(self, window):
        """Raise and focus a window, through the window manager when one is running."""
        if self.has_window_manager():
            event = XEvent()
            event.xclient.type = ClientMessage
            event.xclient.send_event = True
            event.xclient.window = window
            event.xclient.message_type = self.atom("_NET_ACTIVE_WINDOW")
            event.xclient.format = 32
            event.xclient.data.l[0] = 2  # source indication: pager/tool
            event.xclient.data.l[1] = CurrentTime
            _xlib.XSendEvent(self.dpy, self.root, False, SubstructureRedirectMask | SubstructureNotifyMask,
                             byref(event))
        else:
            _xlib.XMapRaised(self.dpy, window)
            _xlib.XSetInputFocus(self.dpy, window, RevertToParent, CurrentTime)
        _xlib.XSync(self.dpy, False)

    def focused_window(self):
        window, revert = Window(), c_int()
        _xlib.XGetInputFocus(self.dpy, byref(window), byref(revert))
        return window.value

    # --- pointer -----------------------------------------------------------------------------------------------------

    def pointer(self):
        root, child = Window(), Window()
        rx, ry, wx, wy, mask = c_int(), c_int(), c_int(), c_int(), c_uint()
        _xlib.XQueryPointer(self.dpy, self.root, byref(root), byref(child), byref(rx), byref(ry), byref(wx),
                            byref(wy), byref(mask))
        return rx.value, ry.value

    def move(self, x, y):
        _xtst.XTestFakeMotionEvent(self.dpy, -1, int(round(x)), int(round(y)), 0)
        _xlib.XSync(self.dpy, False)

    def button(self, button, press):
        _xtst.XTestFakeButtonEvent(self.dpy, button, bool(press), 0)
        _xlib.XSync(self.dpy, False)

    def click(self, x, y, button=1, count=1, modifiers=(), delay=0.05):
        self.move(x, y)
        time.sleep(delay)
        held = self._press_modifiers(modifiers)
        try:
            for i in range(count):
                self.button(button, True)
                time.sleep(0.01)
                self.button(button, False)
                time.sleep(0.06 if count > 1 else delay)
        finally:
            self._release_modifiers(held)

    def drag(self, x0, y0, x1, y1, button=1, steps=12, delay=0.02):
        self.move(x0, y0)
        time.sleep(delay)
        self.button(button, True)
        for i in range(1, steps + 1):
            self.move(x0 + (x1 - x0) * i / steps, y0 + (y1 - y0) * i / steps)
            time.sleep(delay)
        self.button(button, False)

    def scroll(self, x, y, clicks=3, horizontal=False):
        """Scroll at (x, y). Positive clicks scroll down/right, negative up/left."""
        self.move(x, y)
        time.sleep(0.03)
        if horizontal:
            btn = 7 if clicks > 0 else 6
        else:
            btn = 5 if clicks > 0 else 4
        for _ in range(abs(int(clicks))):
            self.button(btn, True)
            self.button(btn, False)
            time.sleep(0.02)

    # --- keyboard ----------------------------------------------------------------------------------------------------

    # "meta" is Alt (Mod1) on Linux; Meta_L is usually only reachable as a shifted level, which sets no modifier.
    _MODIFIER_KEYSYMS = {
        "ctrl": "Control_L", "control": "Control_L", "shift": "Shift_L", "alt": "Alt_L", "meta": "Alt_L",
        "super": "Super_L", "win": "Super_L", "cmd": "Super_L", "altgr": "ISO_Level3_Shift",
    }

    _KEY_ALIASES = {
        "enter": "Return", "return": "Return", "esc": "Escape", "escape": "Escape", "tab": "Tab",
        "backspace": "BackSpace", "bs": "BackSpace", "delete": "Delete", "del": "Delete", "space": "space",
        "up": "Up", "down": "Down", "left": "Left", "right": "Right", "home": "Home", "end": "End",
        "pageup": "Prior", "pgup": "Prior", "pagedown": "Next", "pgdn": "Next", "insert": "Insert",
        "menu": "Menu", "kp_enter": "KP_Enter",
    }

    _CHAR_KEYSYMS = {
        "\n": "Return", "\r": "Return", "\t": "Tab", "\b": "BackSpace", "\x1b": "Escape", "\x7f": "Delete",
        " ": "space", "!": "exclam", '"': "quotedbl", "#": "numbersign",
        "$": "dollar", "%": "percent", "&": "ampersand", "'": "apostrophe", "(": "parenleft", ")": "parenright",
        "*": "asterisk", "+": "plus", ",": "comma", "-": "minus", ".": "period", "/": "slash", ":": "colon",
        ";": "semicolon", "<": "less", "=": "equal", ">": "greater", "?": "question", "@": "at",
        "[": "bracketleft", "\\": "backslash", "]": "bracketright", "^": "asciicircum", "_": "underscore",
        "`": "grave", "{": "braceleft", "|": "bar", "}": "braceright", "~": "asciitilde",
    }

    def _load_keymap(self):
        lo, hi = c_int(), c_int()
        _xlib.XDisplayKeycodes(self.dpy, byref(lo), byref(hi))
        per = c_int()
        count = hi.value - lo.value + 1
        syms = _xlib.XGetKeyboardMapping(self.dpy, lo.value, count, byref(per))
        mapping, free_codes = {}, []
        try:
            rows = [[syms[i * per.value + j] for j in range(per.value)] for i in range(count)]
        finally:
            _xlib.XFree(syms)
        for i, row in enumerate(rows):
            if not any(row):
                free_codes.append(lo.value + i)
        # Only the first group's two levels are used (the active group is locked to the first while typing).
        # Unshifted occurrences win over shifted ones:
        for level in (0, 1):
            for i, row in enumerate(rows):
                sym = row[level] if level < len(row) else 0
                if sym and sym not in mapping:
                    mapping[sym] = (lo.value + i, level)
        self._keymap = (mapping, free_codes, per.value)

    def keysym(self, name):
        """Resolve a key name ('Return', 'a', 'F5', alias like 'enter') or single character to a keysym."""
        if len(name) == 1:
            if name in self._CHAR_KEYSYMS:
                name = self._CHAR_KEYSYMS[name]
            elif ord(name) < 0x20 or 0x7F <= ord(name) < 0xA0:
                raise X11Error(f"Cannot type control character {name!r}")
            elif ord(name) < 0x100:
                return ord(name)  # Latin-1 keysyms equal their code points
            else:
                return 0x01000000 | ord(name)  # Unicode keysym
        name = self._KEY_ALIASES.get(name.lower(), name)
        sym = _xlib.XStringToKeysym(name.encode())
        if not sym:
            raise X11Error(f"Unknown key name: {name!r}")
        return sym

    def _keycode_for(self, sym):
        """Return (keycode, needs_shift, temporary) for a keysym. A keysym that is not in the keymap is mapped to a
        spare keycode, which the caller must give back with _restore_keycode."""
        if self._keymap is None:
            self._load_keymap()
        mapping, free_codes, per = self._keymap
        if sym in mapping:
            code, level = mapping[sym]
            return code, level == 1, False
        if not free_codes:
            raise X11Error(f"No keycode available for keysym 0x{sym:x}")
        code = free_codes.pop()  # not reused while in use (e.g. by a held modifier)
        syms = (KeySym * per)(*([sym, sym] + [0] * (per - 2)))
        try:
            _xlib.XChangeKeyboardMapping(self.dpy, code, per, syms, 1)
            _xlib.XSync(self.dpy, False)
            time.sleep(0.05)  # give clients a moment to process MappingNotify
        except BaseException:
            self._restore_keycode(code)
            raise
        return code, False, True

    def _restore_keycode(self, code):
        _mapping, free_codes, per = self._keymap
        syms = (KeySym * per)()
        _xlib.XChangeKeyboardMapping(self.dpy, code, per, syms, 1)
        _xlib.XSync(self.dpy, False)
        free_codes.append(code)

    def _key_event(self, code, press):
        _xtst.XTestFakeKeyEvent(self.dpy, code, bool(press), 0)
        _xlib.XSync(self.dpy, False)

    def _press_modifiers(self, modifiers):
        """Press modifier keys; returns [(keycode, temporary)] for _release_modifiers."""
        held = []
        try:
            for mod in modifiers:
                name = self._MODIFIER_KEYSYMS.get(mod.lower())
                if not name:
                    raise X11Error(f"Unknown modifier: {mod!r} (use ctrl, shift, alt, meta, super, or altgr)")
                code, _shift, temporary = self._keycode_for(_xlib.XStringToKeysym(name.encode()))
                held.append((code, temporary))
                self._key_event(code, True)
        except BaseException:
            self._release_modifiers(held)
            raise
        return held

    def _release_modifiers(self, held):
        for code, temporary in reversed(held):
            self._key_event(code, False)
            if temporary:
                self._restore_keycode(code)

    def _tap(self, sym, shift_held=False):
        """Press and release the key for a keysym (adding Shift for shifted levels)."""
        code, shift, temporary = self._keycode_for(sym)
        try:
            extra = self._press_modifiers(["shift"]) if shift and not shift_held else []
            try:
                self._key_event(code, True)
                time.sleep(0.005)
                self._key_event(code, False)
            finally:
                self._release_modifiers(extra)
        finally:
            if temporary:
                time.sleep(0.05)
                self._restore_keycode(code)

    def _first_group(self):
        """Lock the keyboard to its first layout group (the keymap lookup assumes it); returns the previous group."""
        state = XkbStateRec()
        if _xlib.XkbGetState(self.dpy, XkbUseCoreKbd, byref(state)) != 0:
            return None
        if state.locked_group:
            _xlib.XkbLockGroup(self.dpy, XkbUseCoreKbd, 0)
            _xlib.XSync(self.dpy, False)
        return state.locked_group

    def _restore_group(self, group):
        if group:
            _xlib.XkbLockGroup(self.dpy, XkbUseCoreKbd, group)
            _xlib.XSync(self.dpy, False)

    def key(self, combo, repeat=1, delay=0.03):
        """Press a key combination such as 'ctrl+shift+Return', 'Escape', 'shift+Return', 'ctrl+a'."""
        parts = combo.split("+") if combo != "+" else ["+"]
        if parts[-1] == "" and len(parts) > 1:  # e.g. "ctrl++"
            parts = parts[:-2] + ["+"]
        *mods, main = parts
        sym = self.keysym(main)
        group = self._first_group()
        try:
            for _ in range(repeat):
                held = self._press_modifiers(mods)
                try:
                    self._tap(sym, shift_held="shift" in [m.lower() for m in mods])
                finally:
                    self._release_modifiers(held)
                time.sleep(delay)
        finally:
            self._restore_group(group)

    def type_text(self, text, delay=0.012):
        """Type literal text with synthetic key presses (newlines become Return, tabs become Tab)."""
        text = text.replace("\r\n", "\n")
        syms = [self.keysym(ch) for ch in text]  # fail before typing anything
        group = self._first_group()
        try:
            for sym in syms:
                self._tap(sym)
                time.sleep(delay)
        finally:
            self._restore_group(group)
