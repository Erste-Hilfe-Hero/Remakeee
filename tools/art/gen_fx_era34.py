#!/usr/bin/env python3
"""Era III and Era IV effect shapes for battle arts (docs/ERA_FEEL_BATTLE.md, slice 3).

    python3 tools/art/gen_fx_era34.py

Built from Chimora's own Era I shape grids (tools/art/gen_fx.py), nothing traced or copied:
  art/era3/fx/<shape>_<shade>.png  10x10, the 8x8 shape with a dark outline, a body tone and a
                                   light edge on its upper left: the 16-bit look.
  art/era4/fx/<shape>_<shade>.png  18x18, the shape doubled with rounded corners, shaded top to
                                   bottom and ringed by a soft glow: the dual-screen look.
Each shape takes the colour of the element it stands for; shade 0 is the darkest set, 3 the
lightest. Deterministic.
"""
from __future__ import annotations

import os
import sys

from PIL import Image

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gen_fx import SHAPES  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))

# Shape -> base colour (the element it stands for, same values as Elements.COLORS).
BASE = {
    "spark": (0xE0, 0x60, 0x3A), "drop": (0x3A, 0x7B, 0xE0), "leaf": (0x4C, 0xAF, 0x50),
    "zag": (0xF2, 0xD0, 0x3B), "rock": (0x9A, 0x7B, 0x55), "streak": (0x9F, 0xD8, 0xE8),
    "glint": (0xFF, 0xF4, 0xC2), "shade": (0x4B, 0x3A, 0x66),
}
# Brightness of each shade set: 0 darkest .. 3 lightest.
SHADE_GAIN = [0.55, 0.8, 1.0, 1.25]


def tone(c: tuple[int, int, int], f: float) -> tuple[int, int, int]:
    if f <= 1.0:
        return tuple(int(v * f) for v in c)
    k = f - 1.0
    return tuple(int(v + (255 - v) * k) for v in c)


def mask(shape: str) -> list[list[bool]]:
    return [[ch == "#" for ch in row] for row in SHAPES[shape]]


def era3(shape: str, shade: int) -> Image.Image:
    m = mask(shape)
    base = tone(BASE[shape], SHADE_GAIN[shade])
    outline = tone(BASE[shape], 0.3)
    hi = tone(base, 1.45)
    img = Image.new("RGBA", (10, 10), (0, 0, 0, 0))

    def on(x: int, y: int) -> bool:
        return 0 <= x < 8 and 0 <= y < 8 and m[y][x]

    for y in range(10):
        for x in range(10):
            sx, sy = x - 1, y - 1
            if on(sx, sy):
                lit = not on(sx - 1, sy) or not on(sx, sy - 1)
                img.putpixel((x, y), (hi if lit else base) + (255,))
            elif any(on(sx + dx, sy + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                img.putpixel((x, y), outline + (255,))
    return img


def era4(shape: str, shade: int) -> Image.Image:
    m = mask(shape)
    big = [[m[y // 2][x // 2] for x in range(16)] for y in range(16)]

    def b(x: int, y: int) -> bool:
        return 0 <= x < 16 and 0 <= y < 16 and big[y][x]

    # Round the corners: a pixel with two empty neighbours at a right angle is dropped.
    rounded = [[big[y][x] and not ((not b(x - 1, y) and not b(x, y - 1)) or (not b(x + 1, y) and not b(x, y + 1))
                                   and sum(b(x + dx, y + dy) for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))) <= 2)
                for x in range(16)] for y in range(16)]

    def r(x: int, y: int) -> bool:
        return 0 <= x < 16 and 0 <= y < 16 and rounded[y][x]

    base = tone(BASE[shape], SHADE_GAIN[shade])
    img = Image.new("RGBA", (18, 18), (0, 0, 0, 0))
    for y in range(18):
        for x in range(18):
            sx, sy = x - 1, y - 1
            if r(sx, sy):
                f = 1.35 - 0.5 * (sy / 15.0)
                img.putpixel((x, y), tone(base, f) + (255,))
            elif any(r(sx + dx, sy + dy) for dx in (-1, 0, 1) for dy in (-1, 0, 1)):
                img.putpixel((x, y), tone(base, 1.3) + (90,))
    return img


def outputs() -> list[str]:
    return ["art/era%d/fx/%s_%d.png" % (e, s, k) for e in (3, 4) for s in SHAPES for k in range(4)]


def main() -> None:
    for era, fn in ((3, era3), (4, era4)):
        out = os.path.join(ROOT, "art", "era%d" % era, "fx")
        os.makedirs(out, exist_ok=True)
        for s in SHAPES:
            for k in range(4):
                fn(s, k).save(os.path.join(out, "%s_%d.png" % (s, k)))
    print("fx: era III and IV, %d shapes x 4 shades" % len(SHAPES))


if __name__ == "__main__":
    main()
