#!/usr/bin/env python3
"""
Generate iProx app icons. Pure stdlib (zlib + struct) so the repo clones and
builds without Pillow / ImageMagick.

Theme — 'active scanner with detections':

  - vertical gradient background (vibrant purple → deep indigo)
  - two concentric white rings, brightness modulated so the top is sky-lit
    and the bottom fades into the gradient
  - one cyan sweep wedge radiating from the centre — gives the icon motion
  - small white 'pings' scattered inside the outer ring — reads as detected
    nearby devices
  - centred white origin dot with a cyan core and a soft halo
  - subtle inner top-edge gloss + bottom vignette for iOS depth
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

TOP_COLOR  = (132, 78, 232)
BOT_COLOR  = (24,  14, 60)
RING_COLOR = (255, 255, 255)
CORE_COLOR = (120, 220, 255)
SWEEP_COLOR = (120, 220, 255)


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


# ── Background + gloss ─────────────────────────────────────────────────────

def vgradient(size, top, bot):
    buf = bytearray(size * size * 3)
    for y in range(size):
        t = (y / max(1, size - 1)) ** 0.85
        r = int(top[0] + (bot[0] - top[0]) * t)
        g = int(top[1] + (bot[1] - top[1]) * t)
        b = int(top[2] + (bot[2] - top[2]) * t)
        row = bytes((r, g, b)) * size
        buf[y * size * 3:(y + 1) * size * 3] = row
    return buf


def apply_top_gloss(buf, size):
    band_h = int(size * 0.42)
    for y in range(band_h):
        t = 1.0 - y / band_h
        alpha = (t ** 3) * 0.11
        if alpha <= 0:
            continue
        for x in range(size):
            _blend(buf, size, x, y, (255, 255, 255), alpha)


def apply_bottom_vignette(buf, size):
    band_h = int(size * 0.36)
    for y in range(size - band_h, size):
        t = (y - (size - band_h)) / band_h
        alpha = (t ** 2) * 0.20
        for x in range(size):
            _blend(buf, size, x, y, (0, 0, 0), alpha)


# ── Modulated ring ─────────────────────────────────────────────────────────

def modulated_ring(buf, size, cx, cy, radius, stroke, color,
                   bright_angle_deg=-90, min_bright=0.40, max_bright=1.0):
    half = stroke / 2.0
    inner = radius - half
    outer = radius + half
    x0 = max(0, int(cx - outer - 2))
    x1 = min(size, int(cx + outer + 3))
    y0 = max(0, int(cy - outer - 2))
    y1 = min(size, int(cy + outer + 3))
    bright_rad = math.radians(bright_angle_deg)

    for y in range(y0, y1):
        dy = y - cy
        dy2 = dy * dy
        for x in range(x0, x1):
            dx = x - cx
            d = math.sqrt(dx * dx + dy2)
            if d < inner - 1 or d > outer + 1:
                continue
            if inner <= d <= outer:
                cov = 1.0
            elif d < inner:
                cov = max(0.0, 1.0 - (inner - d))
            else:
                cov = max(0.0, 1.0 - (d - outer))
            if cov <= 0:
                continue

            ang = math.atan2(dy, dx)
            diff = ang - bright_rad
            while diff >  math.pi: diff -= 2 * math.pi
            while diff < -math.pi: diff += 2 * math.pi
            m = (math.cos(diff) + 1.0) * 0.5
            bright = min_bright + (max_bright - min_bright) * m
            _blend(buf, size, x, y, color, cov * bright)


# ── Sweep wedge ────────────────────────────────────────────────────────────

def sweep_wedge(buf, size, cx, cy, radius, start_deg, end_deg, color,
                peak_alpha=0.70, edge_softness_deg=6):
    """Pie slice with radial alpha fade and angular fade at the leading/
    trailing edges. start_deg < end_deg, both in degrees with -90=up."""
    x0 = max(0, int(cx - radius - 2))
    x1 = min(size, int(cx + radius + 3))
    y0 = max(0, int(cy - radius - 2))
    y1 = min(size, int(cy + radius + 3))
    s = math.radians(start_deg)
    e = math.radians(end_deg)
    soft = math.radians(edge_softness_deg)

    for y in range(y0, y1):
        dy = y - cy
        for x in range(x0, x1):
            dx = x - cx
            d = math.sqrt(dx * dx + dy * dy)
            if d > radius:
                continue
            ang = math.atan2(dy, dx)
            # Distance from the wedge angular range.
            if s <= ang <= e:
                ang_factor = 1.0
            elif ang < s:
                gap = s - ang
                ang_factor = max(0.0, 1.0 - gap / soft) if gap < soft else 0.0
            else:
                gap = ang - e
                ang_factor = max(0.0, 1.0 - gap / soft) if gap < soft else 0.0
            if ang_factor <= 0:
                continue
            # Radial fade: bright near centre, gone at the edge. Also gone
            # near the origin so the wedge doesn't fight the centre dot.
            t = d / radius
            radial = max(0.0, math.sin(math.pi * t)) * (1.0 - t * 0.55)
            a = peak_alpha * ang_factor * radial
            if a > 0:
                _blend(buf, size, x, y, color, a)


# ── Discs ──────────────────────────────────────────────────────────────────

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


def soft_halo(buf, size, cx, cy, inner_r, outer_r, color, peak_alpha=0.55):
    x0 = max(0, int(cx - outer_r - 2))
    x1 = min(size, int(cx + outer_r + 3))
    y0 = max(0, int(cy - outer_r - 2))
    y1 = min(size, int(cy + outer_r + 3))
    span = max(1.0, outer_r - inner_r)
    for y in range(y0, y1):
        dy2 = (y - cy) ** 2
        for x in range(x0, x1):
            d = math.sqrt((x - cx) ** 2 + dy2)
            if d >= outer_r:
                continue
            if d <= inner_r:
                a = peak_alpha
            else:
                t = (d - inner_r) / span
                a = peak_alpha * (1.0 - t) ** 2
            if a > 0:
                _blend(buf, size, x, y, color, a)


# ── Compose ────────────────────────────────────────────────────────────────

def make_icon(size):
    buf = vgradient(size, TOP_COLOR, BOT_COLOR)
    cx = cy = (size - 1) / 2.0

    outer_r = size * 0.42
    inner_r = size * 0.24

    # Sweep first so the rings overdraw cleanly on top.
    sweep_wedge(buf, size, cx, cy, outer_r * 0.95,
                start_deg=-90 - 35, end_deg=-90 + 5,
                color=SWEEP_COLOR, peak_alpha=0.78,
                edge_softness_deg=max(3, size / 18))

    # Two rings — outer thicker than inner.
    modulated_ring(buf, size, cx, cy, outer_r,
                   stroke=max(1.6, size / 22.0), color=RING_COLOR,
                   bright_angle_deg=-90, min_bright=0.45, max_bright=1.0)
    modulated_ring(buf, size, cx, cy, inner_r,
                   stroke=max(1.2, size / 30.0), color=RING_COLOR,
                   bright_angle_deg=-90, min_bright=0.40, max_bright=0.95)

    # Detection pings — small white dots inside the outer ring.
    ping_pos = [
        (+0.25, -0.20),
        (-0.22, -0.30),
        (-0.30, +0.18),
        (+0.32, +0.22),
    ]
    ping_r = max(1.5, size / 36.0)
    for fx, fy in ping_pos:
        px = cx + fx * size
        py = cy + fy * size
        soft_halo(buf, size, px, py, ping_r * 0.4, ping_r * 2.4,
                  RING_COLOR, peak_alpha=0.35)
        aa_disc(buf, size, px, py, ping_r, RING_COLOR)

    # Centre origin: halo + white outer + cyan core.
    core_r = max(2.2, size / 14.0)
    soft_halo(buf, size, cx, cy, core_r * 0.6, core_r * 3.0,
              RING_COLOR, peak_alpha=0.45)
    aa_disc(buf, size, cx, cy, core_r,        RING_COLOR)
    aa_disc(buf, size, cx, cy, core_r * 0.55, CORE_COLOR)

    apply_top_gloss(buf, size)
    apply_bottom_vignette(buf, size)
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
