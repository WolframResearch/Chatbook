"""PNG encoding and downscaling of packed 8-bit RGB pixel data (Python standard library only).

Shared by the screenshot backends (fe_x11.py on Linux, fe_win32.py on Windows).
"""

import math
import struct
import zlib


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
