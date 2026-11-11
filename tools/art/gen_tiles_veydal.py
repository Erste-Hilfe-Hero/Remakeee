"""Act I (Veydal) overworld atlas: a misty heath highland, distinct from the shared atlas.

Pale moor ground with heather, bracken instead of ferns, dark peat tarns, firs, slate
strata cliffs, dry-stone walls, carved waystones and cairns. Same Kind columns and variant
rows as gen_tiles.py, same four Era I inks. Building tiles (WALL, ROOF, DOOR, FLOOR,
COUNTER, INNER_WALL) and the lighthouse (TOWER, LAMP) are copied unchanged from the shared
atlas.
Writes art/era1/tiles/overworld_veydal.png. Run after gen_tiles.py:
python3 tools/art/gen_tiles_veydal.py (from the repo root).
"""
from __future__ import annotations

import os
import random

from PIL import Image

import gen_tiles as g
from px import Canvas

T = g.T
UP, RIGHT, DOWN, LEFT = g.UP, g.RIGHT, g.DOWN, g.LEFT
KEEP = ["WALL", "ROOF", "DOOR", "FLOOR", "COUNTER", "INNER_WALL", "TOWER", "LAMP"]


def heath(c: Canvas, ox: int, oy: int, variant: int) -> None:
    # Pale moor: light ground, mid-tone heather crosses, a few dark peat specks.
    c.rect(ox, oy, T, T, 3)
    rng = random.Random(500 + variant)
    for _ in range(5):
        x, y = rng.randrange(1, 14), rng.randrange(1, 14)
        c.set(ox + x, oy + y, 2)
        c.set(ox + x + 1, oy + y + 1, 2)
        c.set(ox + x + 1, oy + y - 1, 2)
    for _ in range(2):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 1)


def bracken(c: Canvas, ox: int, oy: int, variant: int) -> None:
    heath(c, ox, oy, variant)
    # Curled bracken fronds: a dark stem with paired leaflets, lit on one side.
    frond = ["...0...",
             "..010..",
             ".01210.",
             "0121210",
             ".01210.",
             "0121210",
             ".01110.",
             "..010..",
             "...0..."]
    for (x, y) in [(0 + variant % 2, 0), (8 - variant % 2, 2), (4, 7)]:
        c.ascii(ox + x, oy + y, frond)


def flagstones(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Worn flagstone path: mid slabs with dark joints, edged by a heather rim.
    c.rect(ox, oy, T, T, 2)
    for y in (0, 8):
        c.hline(ox, ox + 15, oy + y, 1)
    for (x, y0) in [(6, 0), (12, 0), (3, 8), (10, 8)]:
        c.vline(ox + x, oy + y0, oy + y0 + 7, 1)
    for (x, y) in [(2, 3), (9, 5), (13, 12), (6, 11)]:
        c.set(ox + x, oy + y, 3)
    if not mask & UP:
        c.hline(ox, ox + 15, oy, 0)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 0)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def tarn(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Dark peat water with mist-ring ripples; pale shore stones where it meets land.
    c.rect(ox, oy, T, T, 0)
    for (x, y) in [(3, 4), (10, 10)]:
        c.ascii(ox + x, oy + y, [".111.", "1...1", ".111."])
    c.set(ox + 12, oy + 3, 1)
    if not mask & UP:
        c.hline(ox, ox + 15, oy, 3)
        c.checker(ox, oy + 1, T, 1, 2, 0)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 2)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 3)
        c.vline(ox + 1, oy, oy + 15, 2)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 3)
        c.vline(ox + 14, oy, oy + 15, 2)


def fir(c: Canvas, ox: int, oy: int, variant: int) -> None:
    heath(c, ox, oy, variant)
    rows = [".......0........",
            "......010.......",
            ".....01210......",
            "....0112110.....",
            "......010.......",
            "....0112110.....",
            "...011121110....",
            ".....01110......",
            "...011121110....",
            "..01111211110...",
            ".0111112111110..",
            "..00011111000...",
            "......010.......",
            "......010.......",
            ".....02220......"]
    c.ascii(ox + (1 if variant % 2 else 0), oy, rows)


def slate_cliff(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Layered slate: horizontal strata, each lit on top, with a heather lip above.
    c.rect(ox, oy, T, T, 1)
    for y in (0, 4, 8, 12):
        c.hline(ox, ox + 15, oy + y, 0)
        c.hline(ox, ox + 15, oy + y + 1, 2)
    for (x, y) in [(5, 2), (11, 6), (3, 10), (9, 14)]:
        c.vline(ox + x, oy + y, oy + y + 1, 0)
    if not mask & UP:
        c.rect(ox, oy, T, 3, 3)
        for x in range(1, 16, 4):
            c.set(ox + x, oy + 1, 2)
        c.hline(ox, ox + 15, oy + 3, 0)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 0)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def stone_steps(c: Canvas, ox: int, oy: int) -> None:
    c.rect(ox, oy, T, T, 1)
    for i, y in enumerate(range(0, T, 4)):
        c.hline(ox + 2 + i % 2, ox + 13 + i % 2, oy + y + 1, 3)
        c.hline(ox + 2 + i % 2, ox + 13 + i % 2, oy + y + 2, 2)
        c.hline(ox + 1, ox + 14, oy + y + 3, 0)
    c.vline(ox, oy, oy + 15, 0)
    c.vline(ox + 15, oy, oy + 15, 0)


def drystone(c: Canvas, ox: int, oy: int, mask: int) -> None:
    heath(c, ox, oy, 1)
    # Dry-stone wall: two courses of uneven stones with a capstone line.
    c.rect(ox, oy + 4, T, 10, 0)
    for (x, y, w) in [(0, 5, 5), (5, 5, 6), (11, 5, 5), (0, 9, 3), (3, 9, 7), (10, 9, 6)]:
        c.rect(ox + x + 1, oy + y, w - 1, 4, 1)
        c.hline(ox + x + 1, ox + x + w - 2, oy + y, 2)
    c.hline(ox, ox + 15, oy + 4, 3)
    if not mask & LEFT:
        c.rect(ox, oy + 4, 2, 10, 3)
    if not mask & RIGHT:
        c.rect(ox + 14, oy + 4, 2, 10, 3)


def waystone(c: Canvas, ox: int, oy: int) -> None:
    heath(c, ox, oy, 2)
    # Carved standing stone with a spiral mark: Veydal's road sign.
    c.ascii(ox + 4, oy + 1, ["..0000..",
                             ".022220.",
                             "02233220",
                             "02300320",
                             "02303320",
                             "02300020",
                             "02233320",
                             "02222220",
                             "02222210",
                             "02222110",
                             "02221110",
                             "02211110",
                             "01111110",
                             "00000000"])
    c.hline(ox + 2, ox + 13, oy + 15, 1)


def heather(c: Canvas, ox: int, oy: int, variant: int) -> None:
    heath(c, ox, oy, variant + 2)
    rng = random.Random(540 + variant)
    for (x, y) in [(2, 2), (9, 3), (3, 9), (10, 10)][: 3 if variant % 2 else 4]:
        x += rng.randrange(0, 2)
        c.ascii(ox + x, oy + y, ["1.1.", "0101", ".10.", ".2.."])


def well(c: Canvas, ox: int, oy: int) -> None:
    heath(c, ox, oy, 3)
    # Moss-stone spring basin.
    c.ascii(ox + 1, oy + 2, [".000000000000.",
                             "02222222222220",
                             "02000000000020",
                             "02011111111020",
                             "02010000001020",
                             "02011111111020",
                             "02000000000020",
                             "02222222222220",
                             "01111111111110",
                             ".000000000000."])


def cattails(c: Canvas, ox: int, oy: int, variant: int) -> None:
    tarn(c, ox, oy, 15)
    rng = random.Random(560 + variant)
    for x in (2, 6, 10, 13):
        y = rng.randrange(1, 5)
        c.rect(ox + x, oy + y, 2, 3, 2)
        c.vline(ox + x, oy + y + 3, oy + 15, 3)


def slate_scree(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, 3)
    rng = random.Random(580 + variant)
    for _ in range(7):
        x, y = rng.randrange(0, 13), rng.randrange(0, 14)
        c.ascii(ox + x, oy + y, ["..01", "0112", "000."])


def cairn(c: Canvas, ox: int, oy: int, variant: int) -> None:
    heath(c, ox, oy, variant)
    c.ascii(ox + 3, oy + 1, ["...0000...",
                             "..022220..",
                             "...0000...",
                             ".00222200.",
                             "0222332220",
                             ".00000000.",
                             "0022223220",
                             "0222222210",
                             ".000000000",
                             "0222322220",
                             "0222222110",
                             "0111111110",
                             ".00000000."])


def build(path_out: str, base_atlas: str) -> None:
    saved = {n: getattr(g, n) for n in ("grass", "tall_grass", "path", "water", "tree", "cliff",
                                         "stairs", "fence", "sign", "flower", "spring", "reeds",
                                         "scree", "rock")}
    g.grass, g.tall_grass, g.path, g.water, g.tree = heath, bracken, flagstones, tarn, fir
    g.cliff, g.stairs, g.fence, g.sign, g.flower = slate_cliff, stone_steps, drystone, waystone, heather
    g.spring, g.reeds, g.scree, g.rock = well, cattails, slate_scree, cairn
    try:
        g.build_tiles(path_out)
    finally:
        for n, f in saved.items():
            setattr(g, n, f)
    out = Image.open(path_out).convert("RGBA")
    base = Image.open(base_atlas).convert("RGBA")
    for name in KEEP:
        x = g.K[name] * T
        out.paste(base.crop((x, 0, x + T, base.height)), (x, 0))
    out.save(path_out)


def main() -> None:
    tiles = os.path.join(os.path.dirname(__file__), "..", "..", "art", "era1", "tiles")
    build(os.path.join(tiles, "overworld_veydal.png"), os.path.join(tiles, "overworld.png"))


if __name__ == "__main__":
    main()
