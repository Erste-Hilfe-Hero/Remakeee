"""Quillmarch overworld atlas (Era III "Radierung", the post-game region of data/region3.json).

16-colour look from data/region_looks.json "quillmarch": moss grass with dithered light from the
top left, ferns in two heights, soft path edges that fade into the grass, canal water with a lit
ripple and a stone bank, etched oaks that cast a shadow on the ground, frost flowers and copper
blooms, reeds, cracked scree and boulders with moss, and cliffs drawn with etching hatches.
The other tiles keep the shared shapes of gen_tiles.py, each kind tinted with its own 4-colour ramp
from the same palette. Same layout as gen_tiles.py (column = TilesetFactory.Kind, 16 rows).

Writes art/era3/tiles/overworld_quillmarch.png.
Run: python3 tools/art/gen_tiles_quillmarch.py [--check] (from the repo root).
"""
from __future__ import annotations

import json
import os
import random
import sys

from PIL import Image

import gen_tiles as g
from px import Canvas

T = 16
UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "art", "era3", "tiles", "overworld_quillmarch.png")
LOOK = json.load(open(os.path.join(ROOT, "data", "region_looks.json"), encoding="utf-8"))["regions"]["quillmarch"]
PAL = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in LOOK["palette"]]

# Palette slots (data/region_looks.json order).
INK, SLATE, MOSS_D, MOSS, SAGE, LICHEN, WALNUT, COPPER_D, COPPER, COPPER_L, CANAL_D, CANAL, FROST, STONE, STONE_L, PAPER = range(16)

# Shared shapes are drawn in shades 0..3; each kind maps them to 4 palette slots.
RAMPS = {
    "GRASS": [MOSS_D, MOSS_D, MOSS, SAGE], "WALL": [INK, STONE, STONE_L, PAPER], "ROOF": [INK, WALNUT, COPPER_D, COPPER],
    "DOOR": [INK, WALNUT, COPPER_D, COPPER_L], "FLOOR": [INK, WALNUT, COPPER, STONE_L], "FENCE": [INK, WALNUT, COPPER_D, STONE_L],
    "SIGN": [INK, WALNUT, COPPER, PAPER], "COUNTER": [INK, WALNUT, COPPER_D, COPPER_L], "INNER_WALL": [INK, SLATE, STONE, STONE_L],
    "SPRING": [INK, CANAL_D, CANAL, FROST], "RIFT": [INK, SLATE, CANAL_D, FROST], "STAIRS": [INK, STONE, STONE_L, PAPER],
    "PIER": [INK, WALNUT, COPPER_D, COPPER_L], "TOWER": [INK, STONE, STONE_L, PAPER], "LAMP": [INK, WALNUT, COPPER_L, PAPER],
    "WADE": [INK, CANAL_D, CANAL, FROST], "BOULDER": [INK, SLATE, STONE, STONE_L], "PLATE": [INK, STONE, COPPER, STONE_L],
    "CRACKED": [INK, WALNUT, STONE, STONE_L], "VINES": [INK, MOSS_D, MOSS, SAGE], "PLANK": [INK, WALNUT, COPPER_D, COPPER],
}
DEFAULT_RAMP = [INK, SLATE, STONE, STONE_L]


class Abs(int):
    """A pixel that names a palette slot directly instead of a 0..3 shade."""


def a(i: int) -> Abs:
    return Abs(i)


def dither(c: Canvas, ox: int, oy: int, x0: int, y0: int, w: int, h: int, v: int, phase: int = 0) -> None:
    for y in range(y0, y0 + h):
        for x in range(x0, x0 + w):
            if (x + y + phase) % 2 == 0:
                c.set(ox + x, oy + y, a(v))


def grass(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, a(MOSS))
    rng = random.Random(900 + variant)
    # Light falls from the top left: a sparse sage dither on lit tufts, deep moss under them.
    for _ in range(5):
        x, y = rng.randrange(0, 14), rng.randrange(0, 14)
        c.set(ox + x, oy + y, a(SAGE))
        c.set(ox + x + 1, oy + y, a(SAGE))
        c.set(ox + x + 1, oy + y + 1, a(MOSS_D))
        c.set(ox + x + 2, oy + y + 1, a(MOSS_D))
    for _ in range(3):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), a(LICHEN))
    for _ in range(4):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), a(MOSS_D))


def _blade(c: Canvas, x: int, y: int, h: int) -> None:
    for i in range(h):
        c.set(x, y + i, a(MOSS_D if i == h - 1 else SAGE if i == 0 else MOSS))
    c.set(x - 1, y + h - 1, a(MOSS_D))
    c.set(x + 1, y + 1, a(LICHEN))


def tall_grass(c: Canvas, ox: int, oy: int, variant: int) -> None:
    grass(c, ox, oy, variant)
    rng = random.Random(920 + variant)
    # Ferns in two heights: short ones at the back, tall ones in front.
    for x in range(1, 16, 3):
        _blade(c, ox + x, oy + 1 + rng.randrange(0, 2), 5)
    for x in range(0, 16, 3):
        _blade(c, ox + x + 1, oy + 7 + rng.randrange(0, 2), 8)
    c.hline(ox, ox + 15, oy + 15, a(MOSS_D))


def path(c: Canvas, ox: int, oy: int, mask: int) -> None:
    c.rect(ox, oy, T, T, a(STONE_L))
    rng = random.Random(940 + mask)
    for _ in range(6):
        x, y = rng.randrange(2, 13), rng.randrange(2, 13)
        c.set(ox + x, oy + y, a(STONE))
        c.set(ox + x + 1, oy + y, a(PAPER))
    # Soft edge: two dithered rows fade from grass into the path, no hard seam.
    for side, (x0, y0, w, h) in ((UP, (0, 0, 16, 2)), (DOWN, (0, 14, 16, 2)), (LEFT, (0, 0, 2, 16)), (RIGHT, (14, 0, 2, 16))):
        if not mask & side:
            outer = {UP: (0, 0, 16, 1), DOWN: (0, 15, 16, 1), LEFT: (0, 0, 1, 16), RIGHT: (15, 0, 1, 16)}[side]
            dither(c, ox, oy, x0, y0, w, h, SAGE)
            dither(c, ox, oy, *outer, MOSS, 1)


def water(c: Canvas, ox: int, oy: int, mask: int) -> None:
    c.rect(ox, oy, T, T, a(CANAL))
    for (x, y) in [(2, 3), (9, 8), (4, 12)]:
        c.hline(ox + x, ox + x + 3, oy + y, a(CANAL_D))
        c.hline(ox + x + 1, ox + x + 2, oy + y - 1, a(FROST))
    # Bank: a lit stone rim, its reflection one row below.
    if not mask & UP:
        c.hline(ox, ox + 15, oy, a(STONE_L))
        c.hline(ox, ox + 15, oy + 1, a(STONE))
        dither(c, ox, oy, 0, 2, 16, 1, STONE)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, a(SLATE))
        c.hline(ox, ox + 15, oy + 14, a(CANAL_D))
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, a(STONE_L))
        c.vline(ox + 1, oy, oy + 15, a(STONE))
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, a(SLATE))
        c.vline(ox + 14, oy, oy + 15, a(CANAL_D))


def tree(c: Canvas, ox: int, oy: int, variant: int) -> None:
    grass(c, ox, oy, variant)
    # Ground shadow to the lower right (light from the top left).
    for y in range(11, 16):
        for x in range(5 + (y - 11), 16):
            if (x + y) % 2 == 0 or y > 12:
                c.set(ox + x, oy + y, a(MOSS_D))
    rows = ["....11111.......",
            "..112344311.....",
            ".12345443221....",
            "1234554432221...",
            "1234443322221...",
            "12344332222211..",
            "123433222222221.",
            "1123322222222211",
            "1122222212222211",
            ".11222122222211.",
            "..1111122221111.",
            "....11166111....",
            "......6776......",
            "......6776......",
            ".....667766.....",
            "......6666......"]
    tone = {"1": INK, "2": MOSS_D, "3": MOSS, "4": SAGE, "5": LICHEN, "6": WALNUT, "7": COPPER_D}
    if variant % 2:
        rows = [r[::-1] for r in rows]
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in tone:
                c.set(ox + x, oy + y, a(tone[ch]))


def flower(c: Canvas, ox: int, oy: int, variant: int) -> None:
    grass(c, ox, oy, variant + 2)
    rng = random.Random(960 + variant)
    for i, (x, y) in enumerate([(2, 2), (9, 4), (4, 10), (11, 11)]):
        x += rng.randrange(0, 2)
        hi, mid = (PAPER, FROST) if (i + variant) % 2 else (COPPER_L, COPPER)
        c.set(ox + x + 1, oy + y, a(hi))
        c.set(ox + x, oy + y + 1, a(mid))
        c.set(ox + x + 1, oy + y + 1, a(hi))
        c.set(ox + x + 2, oy + y + 1, a(mid))
        c.set(ox + x + 1, oy + y + 2, a(mid))
        c.set(ox + x + 1, oy + y + 3, a(MOSS_D))


def reeds(c: Canvas, ox: int, oy: int, variant: int) -> None:
    water(c, ox, oy, 15)
    rng = random.Random(980 + variant)
    for x in range(1, 16, 3):
        top = 1 + rng.randrange(0, 5)
        for y in range(top, 15):
            c.set(ox + x, oy + y, a(SAGE if y < top + 2 else MOSS if y < 11 else MOSS_D))
        c.set(ox + x, oy + top, a(COPPER))
        c.set(ox + x + 1, oy + 15, a(CANAL_D))


def _stone(c: Canvas, ox: int, oy: int, x0: int, y0: int, w: int, h: int, moss: bool) -> None:
    for y in range(h):
        for x in range(w):
            edge = y == 0 or x == 0 or y == h - 1 or x == w - 1
            corner = (x in (0, w - 1)) and (y in (0, h - 1))
            if corner:
                continue
            v = INK if edge else STONE_L if (x + y) < (w + h) // 3 else STONE if (x + y) < (w + h) * 2 // 3 else SLATE
            c.set(ox + x0 + x, oy + y0 + y, a(v))
    # A crack across the face and a moss cap on top.
    for i in range(min(w, h) - 2):
        c.set(ox + x0 + 1 + i, oy + y0 + 1 + (i * 2) // 3 + h // 4, a(SLATE))
    if moss:
        for x in range(1, w - 1):
            if x % 3 != 2:
                c.set(ox + x0 + x, oy + y0 + 1, a(MOSS if x % 2 else SAGE))


def scree(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, a(STONE))
    dither(c, ox, oy, 0, 0, 16, 16, STONE_L, variant)
    rng = random.Random(1000 + variant)
    for _ in range(4):
        _stone(c, ox, oy, rng.randrange(0, 11), rng.randrange(0, 11), 5, 4, rng.random() < 0.5)
    c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), a(MOSS))


def rock(c: Canvas, ox: int, oy: int, variant: int) -> None:
    grass(c, ox, oy, variant)
    for x in range(4, 16):
        c.set(ox + x, oy + 14, a(MOSS_D))
        c.set(ox + x - 1, oy + 15, a(MOSS_D))
    _stone(c, ox, oy, 1 + variant % 2, 3, 13, 11, True)


def cliff(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Etched cliff face: diagonal hatching that gets denser away from the light.
    c.rect(ox, oy, T, T, a(STONE))
    for y in range(T):
        for x in range(T):
            d = (x + y) % 4
            if d == 0:
                c.set(ox + x, oy + y, a(SLATE))
            elif d == 2 and x + y > 14:
                c.set(ox + x, oy + y, a(SLATE))
            elif d == 1 and x + y < 8:
                c.set(ox + x, oy + y, a(STONE_L))
    if not mask & UP:
        c.rect(ox, oy, T, 3, a(MOSS))
        dither(c, ox, oy, 0, 0, 16, 1, SAGE)
        c.hline(ox, ox + 15, oy + 3, a(INK))
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, a(INK))
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, a(STONE_L))
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, a(INK))


def render(c: Canvas) -> Image.Image:
    img = Image.new("RGBA", (c.w, c.h), (0, 0, 0, 0))
    px = img.load()
    for y in range(c.h):
        for x in range(c.w):
            v = c.px[y][x]
            if v is None:
                continue
            if isinstance(v, Abs):
                px[x, y] = PAL[int(v)] + (255,)
            else:
                ramp = RAMPS.get(g.KINDS[x // T], DEFAULT_RAMP)
                px[x, y] = PAL[ramp[v]] + (255,)
    return img


def problems(img: Image.Image) -> list[str]:
    out = []
    if img.size != (T * len(g.KINDS), T * g.VARIANT_ROWS):
        out.append("size %s" % (img.size,))
    cols = {p[:3] for p in img.getdata() if p[3] > 0}
    if not cols <= set(PAL):
        out.append("%d colours outside the Quillmarch palette" % len(cols - set(PAL)))
    if len(cols) < 12:
        out.append("only %d colours, Era III wants a rich palette" % len(cols))
    return out


def main(argv: list[str]) -> int:
    if "--check" in argv:
        img = Image.open(OUT).convert("RGBA")
    else:
        g.grass, g.tall_grass, g.path, g.water, g.tree = grass, tall_grass, path, water, tree
        g.flower, g.reeds, g.scree, g.rock, g.cliff = flower, reeds, scree, rock, cliff
        img = render(g.make_tiles())
        os.makedirs(os.path.dirname(OUT), exist_ok=True)
        img.save(OUT)
    bad = problems(img)
    for p in bad:
        print("%s: %s" % (OUT, p))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
