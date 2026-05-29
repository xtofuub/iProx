#!/usr/bin/env python3
"""
iProx app icon, visionOS-style frosted-glass tile.

Pure stdlib PNG encoder (zlib + struct) so the repo stays clone-and-build
without Pillow / ImageMagick.

Design notes:
  - pale lavender base gradient (lighter top, deeper purple bottom)
  - bright thin specular highlight along the top edge
  - faint left-edge light catch
  - subtle inner shadow at the bottom + bottom-right corner vignette
  - saturated deep-violet radar glyph (two thin rings + centre dot) floating
    on top, with a soft drop shadow so it reads as 'on glass'
  - cyan core inside the centre dot for accent
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

# Glass tile palette — pale lavender at top, deeper violet at bottom, with a
# soft warm tint baked in so it doesn't read as flat grey.
BG_TOP   = (236, 228, 250)
BG_MID   = (203, 184, 234)
BG_BOT   = (160, 132, 208)

# Glyph palette — saturated deep purple so it pops on the pale glass.
GLYPH    = (62,  22,  140)
CORE     = (96,  220, 255)


# ── PNG ────────────────────────────────────────────────────────────────────

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


# ── Background gradient (3-stop, soft) ─────────────────────────────────────

def glass_bg(size):
    """3-stop vertical gradient: top -> mid (at 55%) -> bot. Easing on each leg
    gives the frosted-glass feel rather than a flat ramp."""
    buf = bytearray(size * size * 3)
    mid_y = 0.55
    for y in range(size):
        t = y / max(1, size - 1)
        if t < mid_y:
            u = (t / mid_y) ** 0.85
            r = int(BG_TOP[0] + (BG_MID[0] - BG_TOP[0]) * u)
            g = int(BG_TOP[1] + (BG_MID[1] - BG_TOP[1]) * u)
            b = int(BG_TOP[2] + (BG_MID[2] - BG_TOP[2]) * u)
        else:
            u = ((t - mid_y) / (1.0 - mid_y)) ** 1.15
            r = int(BG_MID[0] + (BG_BOT[0] - BG_MID[0]) * u)
            g = int(BG_MID[1] + (BG_BOT[1] - BG_MID[1]) * u)
            b = int(BG_MID[2] + (BG_BOT[2] - BG_MID[2]) * u)
        row = bytes((r, g, b)) * size
        buf[y * size * 3:(y + 1) * size * 3] = row
    return buf


# ── Edge effects ───────────────────────────────────────────────────────────

def top_specular(buf, size):
    """Crisp bright line along the very top, fading downward. Reads as the
    light catching on the upper rim of a glass slab."""
    band_h = max(2, int(size * 0.06))
    for y in range(band_h):
        t = 1.0 - y / band_h
        alpha = (t ** 2) * 0.85
        if alpha <= 0:
            continue
        for x in range(size):
            _blend(buf, size, x, y, (255, 255, 255), alpha)


def left_edge_light(buf, size):
    band_w = max(2, int(size * 0.05))
    for x in range(band_w):
        t = 1.0 - x / band_w
        alpha = (t ** 2) * 0.22
        if alpha <= 0:
            continue
        for y in range(int(size * 0.05), int(size * 0.85)):
            _blend(buf, size, x, y, (255, 255, 255), alpha)


def bottom_inner_shadow(buf, size):
    band_h = max(2, int(size * 0.18))
    for y in range(size - band_h, size):
        t = (y - (size - band_h)) / band_h
        alpha = (t ** 2) * 0.18
        for x in range(size):
            _blend(buf, size, x, y, (40, 18, 70), alpha)


def corner_vignette(buf, size):
    """Bottom-right corner darken. Adds depth."""
    cx, cy = size, size
    radius = size * 0.85
    for y in range(int(size * 0.45), size):
        dy2 = (y - cy) ** 2
        for x in range(int(size * 0.45), size):
            d = math.sqrt((x - cx) ** 2 + dy2)
            if d >= radius:
                continue
            t = 1.0 - d / radius
            alpha = (t ** 3) * 0.20
            if alpha > 0:
                _blend(buf, size, x, y, (40, 18, 70), alpha)


# ── Glyph (rings + dot) ────────────────────────────────────────────────────

def aa_ring(buf, size, cx, cy, radius, stroke, color, alpha=1.0):
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
            _blend(buf, size, x, y, color, cov * alpha)


def aa_disc(buf, size, cx, cy, radius, color, alpha=1.0):
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
            cov = max(0.0, min(1.0, radius - d + 0.5)) * alpha
            if cov > 0:
                _blend(buf, size, x, y, color, cov)


def glyph_drop_shadow_ring(buf, size, cx, cy, radius, stroke, offset, alpha):
    """Soft offset shadow for the rings — gives the glyph a 'sitting on
    glass' feel. Just a darker semi-transparent ring shifted down by offset."""
    aa_ring(buf, size, cx, cy + offset, radius, stroke * 1.4,
            (38, 16, 72), alpha=alpha)


def render_glyph(buf, size):
    cx = cy = (size - 1) / 2.0

    stroke_outer = max(1.6, size / 26.0)
    stroke_inner = max(1.4, size / 34.0)
    radius_outer = size * 0.40
    radius_inner = size * 0.22

    # Drop shadows for both rings + the centre dot — small, soft, downward.
    drop = max(1.0, size / 60.0)
    glyph_drop_shadow_ring(buf, size, cx, cy, radius_outer, stroke_outer, drop, 0.22)
    glyph_drop_shadow_ring(buf, size, cx, cy, radius_inner, stroke_inner, drop, 0.18)
    aa_disc(buf, size, cx, cy + drop, max(2.0, size / 16.0), (38, 16, 72), alpha=0.18)

    # Real glyph layer.
    aa_ring(buf, size, cx, cy, radius_outer, stroke_outer, GLYPH)
    aa_ring(buf, size, cx, cy, radius_inner, stroke_inner, GLYPH)
    aa_disc(buf, size, cx, cy, max(2.0, size / 16.0), GLYPH)
    aa_disc(buf, size, cx, cy, max(1.0, size / 32.0), CORE)


# ── Compose ────────────────────────────────────────────────────────────────

def make_icon(size):
    buf = glass_bg(size)
    bottom_inner_shadow(buf, size)
    corner_vignette(buf, size)
    render_glyph(buf, size)
    left_edge_light(buf, size)
    top_specular(buf, size)
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
