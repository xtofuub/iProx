#!/usr/bin/env python3
"""
Generate iProx app icons. Pure stdlib PNG encoder (zlib + struct), so the
repo clones and builds without Pillow / ImageMagick.

Design: minimal. Solid deep-purple field, two thin white concentric rings,
one filled centre dot. No gradients, no sweeps, no gloss. Reads as 'target'
at 40 px and stays clean at 1024.
"""

import math
import os
import struct
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

BG_COLOR    = (38, 22, 92)     # solid deep purple, no gradient
RING_COLOR  = (255, 255, 255)


def png_encode(width, height, rgb):
    def chunk(t, d):
        return (struct.pack(">I", len(d)) + t + d +
                struct.pack(">I", zlib.crc32(t + d) & 0xffffffff))
    sig = b"\x89PNG\r\n\x1a\n"
    ihdr = struct.pack(">IIBBBBB", width, height, 8, 2, 0, 0, 0)
    stride = width * 3
    raw = bytearray()
    for y in range(height):
        raw.append(0)
        raw += rgb[y * stride:(y + 1) * stride]
    idat = zlib.compress(bytes(raw), 9)
    return sig + chunk(b"IHDR", ihdr) + chunk(b"IDAT", idat) + chunk(b"IEND", b"")


def _blend(buf, size, x, y, color, cov):
    if cov <= 0:
        return
    if cov > 1:
        cov = 1.0
    idx = (y * size + x) * 3
    inv = 1.0 - cov
    buf[idx]     = int(buf[idx]     * inv + color[0] * cov)
    buf[idx + 1] = int(buf[idx + 1] * inv + color[1] * cov)
    buf[idx + 2] = int(buf[idx + 2] * inv + color[2] * cov)


def solid(size, color):
    row = bytes(color) * size
    return bytearray(row * size)


def aa_ring(buf, size, cx, cy, radius, stroke, color):
    half = stroke / 2.0
    inner = radius - half
    outer = radius + half
    x0 = max(0, int(cx - outer - 2))
    x1 = min(size, int(cx + outer + 3))
    y0 = max(0, int(cy - outer - 2))
    y1 = min(size, int(cy + outer + 3))
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
            _blend(buf, size, x, y, color, cov)


def aa_disc(buf, size, cx, cy, radius, color):
    x0 = max(0, int(cx - radius - 2))
    x1 = min(size, int(cx + radius + 3))
    y0 = max(0, int(cy - radius - 2))
    y1 = min(size, int(cy + radius + 3))
    for y in range(y0, y1):
        dy2 = (y - cy) ** 2
        for x in range(x0, x1):
            d = math.sqrt((x - cx) ** 2 + dy2)
            if d > radius + 1:
                continue
            cov = max(0.0, min(1.0, radius - d + 0.5))
            _blend(buf, size, x, y, color, cov)


def make_icon(size):
    buf = solid(size, BG_COLOR)
    cx = cy = (size - 1) / 2.0

    # Stroke scales so the rings stay readable at 40 px but don't get heavy
    # at 1024. Two rings: outer at 0.41 of size, inner at 0.22.
    stroke_outer = max(1.5, size / 30.0)
    stroke_inner = max(1.2, size / 38.0)
    aa_ring(buf, size, cx, cy, size * 0.41, stroke_outer, RING_COLOR)
    aa_ring(buf, size, cx, cy, size * 0.22, stroke_inner, RING_COLOR)
    aa_disc(buf, size, cx, cy, max(2.0, size / 18.0), RING_COLOR)

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
