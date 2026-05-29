#!/usr/bin/env python3
"""
Generate iProx app icons. No external deps — uses stdlib zlib/struct PNG encode.

Theme: deep purple vertical gradient + white concentric radar rings with a
center origin dot. Reads as 'scanner' at every size.

Output: App/Resources/AppIcon{P}x{P}@{S}x.png for the iPhone set.
"""

import math
import os
import struct
import sys
import zlib


HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.normpath(os.path.join(HERE, "..", "App", "Resources"))
os.makedirs(OUT_DIR, exist_ok=True)

ICON_SET = [
    (20, 2), (20, 3),
    (29, 2), (29, 3),
    (40, 2), (40, 3),
    (60, 2), (60, 3),
]
MARKETING_SIZE = 1024

TOP = (94, 58, 168)
BOT = (34, 18, 70)
RING_COLOR = (255, 255, 255)


def png_encode(width, height, rgb):
    def chunk(t, d):
        return (struct.pack(">I", len(d)) + t + d +
                struct.pack(">I", zlib.crc32(t + d) & 0xffffffff))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    raw = bytearray()
    stride = width * 3
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def gradient(size, top, bot):
    buf = bytearray(size * size * 3)
    for y in range(size):
        t = y / max(1, size - 1)
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        row = bytes((r, g, b)) * size
        buf[y * size * 3:(y + 1) * size * 3] = row
    return buf


def _blend(buf, idx, color, cov):
    inv = 1.0 - cov
    buf[idx]     = int(buf[idx]     * inv + color[0] * cov)
    buf[idx + 1] = int(buf[idx + 1] * inv + color[1] * cov)
    buf[idx + 2] = int(buf[idx + 2] * inv + color[2] * cov)


def aa_ring(buf, size, cx, cy, radius, width, color, alpha=1.0):
    half = width / 2.0
    inner = radius - half
    outer = radius + half
    x0 = max(0, int(cx - outer - 1))
    x1 = min(size, int(cx + outer + 2))
    y0 = max(0, int(cy - outer - 1))
    y1 = min(size, int(cy + outer + 2))
    for y in range(y0, y1):
        dy2 = (y - cy) ** 2
        for x in range(x0, x1):
            d = math.sqrt((x - cx) ** 2 + dy2)
            if d < inner - 1 or d > outer + 1:
                continue
            if inner <= d <= outer:
                cov = 1.0
            elif d < inner:
                cov = max(0.0, 1.0 - (inner - d))
            else:
                cov = max(0.0, 1.0 - (d - outer))
            cov *= alpha
            if cov <= 0:
                continue
            _blend(buf, (y * size + x) * 3, color, cov)


def aa_disc(buf, size, cx, cy, radius, color):
    x0 = max(0, int(cx - radius - 1))
    x1 = min(size, int(cx + radius + 2))
    y0 = max(0, int(cy - radius - 1))
    y1 = min(size, int(cy + radius + 2))
    for y in range(y0, y1):
        dy2 = (y - cy) ** 2
        for x in range(x0, x1):
            d = math.sqrt((x - cx) ** 2 + dy2)
            if d > radius + 1:
                continue
            cov = max(0.0, min(1.0, radius - d + 0.5))
            if cov <= 0:
                continue
            _blend(buf, (y * size + x) * 3, color, cov)


def make_icon(size):
    buf = gradient(size, TOP, BOT)
    cx = cy = (size - 1) / 2.0

    rings = [
        (0.44, 1.0,  size / 26.0),
        (0.32, 0.85, size / 30.0),
        (0.21, 0.7,  size / 34.0),
    ]
    for frac, alpha, width in rings:
        aa_ring(buf, size, cx, cy, size * frac, max(1.0, width), RING_COLOR, alpha)

    aa_disc(buf, size, cx, cy, max(2.0, size / 14.0), RING_COLOR)
    aa_disc(buf, size, cx, cy, max(1.0, size / 36.0), TOP)
    return png_encode(size, size, buf)


def save(name, data):
    path = os.path.join(OUT_DIR, name)
    with open(path, "wb") as f:
        f.write(data)
    print(f"wrote {path}  ({len(data)} bytes)")


def main():
    for point, scale in ICON_SET:
        size = point * scale
        save(f"AppIcon{point}x{point}@{scale}x.png", make_icon(size))
    save("AppIcon1024x1024.png", make_icon(MARKETING_SIZE))


if __name__ == "__main__":
    main()
