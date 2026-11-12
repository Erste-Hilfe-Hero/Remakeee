"""Act III Ashmere overworld atlas (Era I): ash ground, charred brush, dead snags, brine pools,
salt spikes, cinder scree, slag heaps, braziers and basalt cliffs in Ashmere's own four inks.
Buildings keep the shared Era I shapes. Same layout as gen_tiles.py.

Writes art/era1/tiles/overworld_ashmere.png. Inks come from data/region_looks.json.
Run: python3 tools/art/gen_tiles_ashmere.py (from the repo root).
"""
from __future__ import annotations

import json
import os
import random

import px
import gen_tiles as g
from px import Canvas

T = 16
UP, RIGHT, DOWN, LEFT = 1, 2, 4, 8
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")


def ash(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, 2)
    rng = random.Random(300 + variant)
    # Soot cracks running across the ash, a few live cinders and pale flakes.
    x, y = rng.randrange(0, 8), rng.randrange(3, 13)
    for _ in range(5):
        c.set(ox + x, oy + y, 0)
        x += 1
        y += rng.choice([-1, 0, 0, 1])
        if not (0 <= x < 16 and 0 <= y < 16):
            break
    for _ in range(2):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 1)
    for _ in range(3):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 3)


def char_brush(c: Canvas, ox: int, oy: int, variant: int) -> None:
    ash(c, ox, oy, variant)
    stalk = ["1.1", ".0.", "00.", ".0.", ".00", ".0."]
    rng = random.Random(320 + variant)
    for x in [0, 4, 8, 12]:
        for y in [1, 9]:
            c.ascii(ox + x + rng.randrange(0, 2), oy + y + rng.randrange(0, 2), stalk)


def dead_snag(c: Canvas, ox: int, oy: int, variant: int) -> None:
    ash(c, ox, oy, variant)
    rows = ["0.....0...0.....",
            ".0...0.....0..0.",
            "..0.0...0..0.0..",
            "...00..0...00...",
            "....0.0....0....",
            "....010...01....",
            ".....01..10.....",
            ".....0110110....",
            "......01110.....",
            "......0110......",
            "......0110......",
            "......0110......",
            ".....001100.....",
            "....00111100....",
            "...0000000000...",
            "....11111111...."]
    if variant % 2:
        rows = [r[::-1] for r in rows]
    c.ascii(ox, oy, rows)


def brine(c: Canvas, ox: int, oy: int, mask: int) -> None:
    c.rect(ox, oy, T, T, 0)
    for (x, y) in [(2, 4), (9, 9), (5, 13)]:
        c.hline(ox + x, ox + x + 2, oy + y, 1)
    c.set(ox + 12, oy + 3, 3)
    # Salt crust rim on the land side.
    if not mask & UP:
        c.hline(ox, ox + 15, oy, 3)
        c.checker(ox, oy + 1, T, 1, 3, 2)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 3)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 3)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 3)


def ember_bloom(c: Canvas, ox: int, oy: int, variant: int) -> None:
    ash(c, ox, oy, variant + 2)
    rng = random.Random(340 + variant)
    for (x, y) in [(2, 2), (9, 4), (4, 9), (11, 11)][: 3 if variant % 2 else 4]:
        c.ascii(ox + x + rng.randrange(0, 2), oy + y, ["010", "131", "010", ".0."])


def salt_spikes(c: Canvas, ox: int, oy: int, variant: int) -> None:
    brine(c, ox, oy, 15)
    rng = random.Random(360 + variant)
    for x in [1, 6, 11]:
        y = rng.randrange(2, 7)
        c.ascii(ox + x, oy + y, [".3.", ".3.", "332", "332", "322", "222"])


def cinder_scree(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, 1)
    rng = random.Random(380 + variant)
    for _ in range(8):
        c.ascii(ox + rng.randrange(0, 14), oy + rng.randrange(0, 14), ["02", "00"])
    for _ in range(4):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 3)


def slag_heap(c: Canvas, ox: int, oy: int, variant: int) -> None:
    ash(c, ox, oy, variant)
    c.ascii(ox, oy + 3, ["......00........",
                         ".....0110.......",
                         "....011010......",
                         "...0101101000...",
                         "..010110110110..",
                         ".01011011011010.",
                         ".00101101101100.",
                         "0101101101101010",
                         "0000000000000000",
                         ".11111111111111."])


def brazier(c: Canvas, ox: int, oy: int) -> None:
    ash(c, ox, oy, 1)
    c.ascii(ox, oy, ["......3..3......",
                     ".....313.13.....",
                     "....31113113....",
                     "....11111111....",
                     "..000000000000..",
                     "..011111111110..",
                     "...0101010100...",
                     "....00000000....",
                     "......0110......",
                     "......0110......",
                     "......0110......",
                     ".....001100.....",
                     "....00000000....",
                     "...0..0..0..0...",
                     "..0...0..0...0..",
                     "..111111111111.."])


def basalt(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Hexagonal basalt columns: vertical joints, lit column caps.
    c.rect(ox, oy, T, T, 1)
    for x in [0, 4, 9, 13]:
        c.vline(ox + x, oy, oy + 15, 0)
    for i, x in enumerate([1, 5, 10, 14]):
        c.hline(ox + x, ox + min(x + 2, 15), oy + (3 + 5 * i) % 16, 0)
        c.vline(ox + x, oy + 1, oy + 4, 2)
    if not mask & UP:
        c.rect(ox, oy, T, 3, 2)
        for x in range(1, 16, 4):
            c.hline(ox + x, ox + x + 1, oy + 1, 3)
        c.hline(ox, ox + 15, oy + 3, 0)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 15, 0)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def main() -> None:
    look = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))["regions"]["ashmere"]
    px.PALETTE = [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in look["palette"]]
    g.grass, g.tall_grass, g.tree, g.water = ash, char_brush, dead_snag, brine
    g.flower, g.reeds, g.scree, g.rock = ember_bloom, salt_spikes, cinder_scree, slag_heap
    g.lamp, g.cliff = brazier, basalt
    out = os.path.join(ROOT, "art", "era1", "tiles", "overworld_ashmere.png")
    os.makedirs(os.path.dirname(out), exist_ok=True)
    g.build_tiles(out)


if __name__ == "__main__":
    main()
