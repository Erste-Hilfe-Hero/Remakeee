"""Act II Corvane overworld atlas (Era I, 4 tones): the dye fens.

Corvane is a wet dye country: peat sod instead of meadow, sedge tussocks, boardwalks over
stained fen water, drooping dye-willows, woad spikes, cattails, wattle hurdles, dye vats and
hooked fen lanterns. Same atlas layout as gen_tiles.py (column = kind, row = variant), so
TilesetFactory picks the right cell without any extra rules. Buildings (WALL, ROOF, DOOR,
TOWER) keep the base shapes on purpose. The palette is data/region_looks.json "corvane".

Writes art/era1/tiles/overworld_corvane.png.
Run: python3 tools/art/gen_tiles_corvane.py (from the repo root).
"""
from __future__ import annotations

import json
import os
import random

from PIL import Image

from gen_tiles import K, T, UP, RIGHT, DOWN, LEFT, VARIANT_ROWS, make_tiles
from px import Canvas

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def palette() -> list[tuple[int, int, int]]:
    looks = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in looks["regions"]["corvane"]["palette"]]


def clear(c: Canvas, ox: int, oy: int) -> None:
    c.rect(ox, oy, T, T, None)


def peat(c: Canvas, ox: int, oy: int, variant: int) -> None:
    # Damp peat sod: mid tone with dark seep cracks and pale moss cushions.
    c.rect(ox, oy, T, T, 2)
    rng = random.Random(300 + variant)
    for _ in range(2):
        x, y = rng.randrange(0, 12), rng.randrange(1, 15)
        for i in range(rng.randrange(3, 6)):
            c.set(ox + x + i, oy + y + (i % 2), 1)
    for _ in range(2):
        x, y = rng.randrange(1, 13), rng.randrange(1, 13)
        c.ascii(ox + x, oy + y, [".3.", "333", ".1."])


def sedge(c: Canvas, ox: int, oy: int, variant: int) -> None:
    peat(c, ox, oy, variant)
    tuft = ["0.0.0.0",
            "03.3.30",
            ".03330.",
            "0233320",
            "0122210",
            ".00000."]
    for dx, dy in [(0 + variant % 2, 1), (8 - variant % 2, 2), (4, 9)]:
        c.ascii(ox + dx, oy + dy, tuft)


def boardwalk(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Planks over the mud; runs vertical unless it only joins left/right.
    horizontal = bool(mask & (LEFT | RIGHT)) and not mask & (UP | DOWN)
    c.rect(ox, oy, T, T, 3)
    for k in range(0, T, 4):
        if horizontal:
            c.vline(ox + k, oy + 1, oy + 14, 2)
            c.set(ox + k + 2, oy + 3, 1)
            c.set(ox + k + 2, oy + 12, 1)
        else:
            c.hline(ox + 1, ox + 14, oy + k, 2)
            c.set(ox + 3, oy + k + 2, 1)
            c.set(ox + 12, oy + k + 2, 1)
    edges = [(UP, (0, 0, T, 1)), (DOWN, (0, 15, T, 1)), (LEFT, (0, 0, 1, T)), (RIGHT, (15, 0, 1, T))]
    for bit, (x, y, w, h) in edges:
        if not mask & bit:
            c.rect(ox + x, oy + y, w, h, 0)


def fen_water(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Dye-stained water: dark with slanted pale streaks, no wave dashes.
    c.rect(ox, oy, T, T, 1)
    for (x, y) in [(1, 4), (7, 9), (3, 13)]:
        for i in range(5):
            c.set(ox + x + i, oy + y - i // 2, 2)
        c.set(ox + x + 5, oy + y - 3, 3)
    c.set(ox + 12, oy + 2, 0)
    c.set(ox + 13, oy + 2, 0)
    if not mask & UP:
        c.hline(ox, ox + 15, oy, 0)
        c.checker(ox, oy + 1, T, 1, 2, 1)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 0)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 0)
        c.checker(ox + 1, oy, 1, T, 2, 1)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def dye_willow(c: Canvas, ox: int, oy: int, variant: int) -> None:
    peat(c, ox, oy, variant)
    rows = ["......0000......",
            "....00122100....",
            "..001122221100..",
            ".01112222211110.",
            "0111.0122100111.",
            "01.1.0.110.1.10.",
            "01.1.0.110.1.10.",
            "0..1.1.110.1..0.",
            "0..1.1.110.1..0.",
            "...1.1.110.1....",
            "...0.1.110.0....",
            ".....0.110......",
            ".......110......",
            "......01100.....",
            ".....0011100....",
            "......00000....."]
    if variant % 2:
        rows = [r[::-1] for r in rows]
    c.ascii(ox, oy, rows)


def woad(c: Canvas, ox: int, oy: int, variant: int) -> None:
    peat(c, ox, oy, variant)
    spike = [".3.", "313", ".3.", "313", ".0.", ".0.", ".0."]
    rng = random.Random(400 + variant)
    for x in (2, 7, 11):
        c.ascii(ox + x, oy + rng.randrange(2, 8), spike)


def cattails(c: Canvas, ox: int, oy: int, variant: int) -> None:
    fen_water(c, ox, oy, 15)
    rng = random.Random(500 + variant)
    for x in [1, 5, 9, 13]:
        y = rng.randrange(0, 5)
        c.ascii(ox + x, oy + y, [".3", "00", "00", "00", "0."])
        c.vline(ox + x, oy + y + 5, oy + 15, 3)


def silt(c: Canvas, ox: int, oy: int, variant: int) -> None:
    # Dried dye silt: pale crust cut by dark cracks.
    c.rect(ox, oy, T, T, 3)
    rng = random.Random(600 + variant)
    for _ in range(4):
        x, y = rng.randrange(0, 14), rng.randrange(0, 14)
        for i in range(4):
            c.set(ox + x + i, oy + y + rng.randrange(0, 2), 1)
    for _ in range(5):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 2)


def hurdle(c: Canvas, ox: int, oy: int, mask: int) -> None:
    peat(c, ox, oy, 0)
    for y in (4, 7, 10):
        for x in range(T):
            c.set(ox + x, oy + y + (1 if (x // 2 + y) % 2 else 0), 3 if (x // 2) % 2 else 1)
    for x in (1, 7, 13):
        c.vline(ox + x, oy + 2, oy + 14, 0)
    if not mask & LEFT:
        c.rect(ox, oy + 3, 1, 10, 2)
    if not mask & RIGHT:
        c.rect(ox + 15, oy + 3, 1, 10, 2)


def stake_sign(c: Canvas, ox: int, oy: int) -> None:
    peat(c, ox, oy, 1)
    c.ascii(ox, oy, ["................",
                     ".000000000000...",
                     ".033333333330...",
                     ".031131133130...",
                     ".033333333330...",
                     ".031311313130...",
                     ".000000000000...",
                     "......00........",
                     "......00........",
                     "......00........",
                     "......00........",
                     ".....0000.......",
                     "....011110......"])


def dye_vat(c: Canvas, ox: int, oy: int, variant: int) -> None:
    peat(c, ox, oy, variant)
    c.ascii(ox, oy + 1, ["................",
                         "..000000000000..",
                         ".03333333333330.",
                         ".01000000000010.",
                         ".01" + ("0" if variant % 2 else "1") * 10 + "10.",
                         ".03333333333330.",
                         ".02222222222220.",
                         ".00000000000000.",
                         ".02222222222220.",
                         ".02222222222220.",
                         ".00000000000000.",
                         ".02222222222220.",
                         "..022222222220..",
                         "...0000000000...",
                         "................"])


def fen_lantern(c: Canvas, ox: int, oy: int) -> None:
    peat(c, ox, oy, 2)
    c.ascii(ox, oy, ["....0000000.....",
                     "....0....00.....",
                     "...000...00.....",
                     "..03330..00.....",
                     "..03230..00.....",
                     "..03230..00.....",
                     "..03330..00.....",
                     "...000...00.....",
                     ".........00.....",
                     ".........00.....",
                     ".........00.....",
                     ".........00.....",
                     ".........00.....",
                     "........0000....",
                     ".......011110...",
                     "................"])


SCATTER = {"GRASS": peat, "TALL_GRASS": sedge, "TREE": dye_willow, "FLOWER": woad,
           "REEDS": cattails, "SCREE": silt, "ROCK": dye_vat}
MASK = {"PATH": boardwalk, "WATER": fen_water, "FENCE": hurdle}
SINGLE = {"SIGN": stake_sign, "LAMP": fen_lantern}


def build(path_out: str) -> None:
    c = make_tiles()
    for v in range(VARIANT_ROWS):
        oy = v * T
        for name, fn in SCATTER.items():
            clear(c, K[name] * T, oy)
            fn(c, K[name] * T, oy, v % 4)
        for name, fn in MASK.items():
            clear(c, K[name] * T, oy)
            fn(c, K[name] * T, oy, v)
        for name, fn in SINGLE.items():
            clear(c, K[name] * T, oy)
            fn(c, K[name] * T, oy)
    pal = palette()
    img = Image.new("RGBA", (c.w, c.h), (0, 0, 0, 0))
    for y in range(c.h):
        for x in range(c.w):
            v = c.px[y][x]
            if v is not None:
                img.putpixel((x, y), pal[v] + (255,))
    img.save(path_out)


def main() -> None:
    build(os.path.join(ROOT, "art", "era1", "tiles", "overworld_corvane.png"))


if __name__ == "__main__":
    main()
