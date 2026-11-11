"""Era I overworld atlas for Solenne, Act IV (sun and sand), original art made by this script.

Writes art/era1/tiles/overworld_solenne.png with the same layout as overworld.png (column =
TilesetFactory.Kind, row = variant) so TilesetFactory can swap it per region. Ground, plants and
props are redrawn for the desert: sand instead of meadow, dry scrub in the encounter patches,
cacti and date palms for trees, dune ridges for scree, banded sandstone for cliffs and rocks,
succulent blooms for flowers. Buildings (wall, roof, door) keep the shared look.

Still Era I: four shades only, drawn in the Solenne inks from data/region_looks.json (the screen
filter swaps to the same inks while the player is in Solenne).
Run: python3 tools/art/gen_tiles_solenne.py (from the repo root).
"""
from __future__ import annotations

import json
import os
import random

import gen_tiles as g
import px
from px import Canvas

T = 16
ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
UP, DOWN, LEFT, RIGHT = g.UP, g.DOWN, g.LEFT, g.RIGHT


def sand(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, 2)
    rng = random.Random(300 + variant)
    # Wind ripples: short light arcs with a dark underside, offset per variant.
    for _ in range(3):
        x, y = rng.randrange(0, 11), rng.randrange(1, 14)
        c.hline(ox + x, ox + x + 4, oy + y, 3)
        c.hline(ox + x + 1, ox + x + 3, oy + y + 1, 1)
    for _ in range(3):
        c.set(ox + rng.randrange(0, 16), oy + rng.randrange(0, 16), 1)


def scrub(c: Canvas, ox: int, oy: int, variant: int) -> None:
    sand(c, ox, oy, variant)
    # Dry thorn bushes: tangled dark twigs with a few pale burrs.
    bush = ["0..0.0..",
            ".0.00.0.",
            "0300030.",
            ".00300.0",
            "0.0030.0",
            ".010010.",
            "..1111.."]
    for (dx, dy) in [(0 + variant % 2, 1), (8 - variant % 2, 8)]:
        c.ascii(ox + dx, oy + dy, bush, mirror=bool((dx + variant) % 2))


def cactus(c: Canvas, ox: int, oy: int, variant: int) -> None:
    sand(c, ox, oy, variant)
    if variant % 2:
        # Date palm: fanned fronds over a ringed trunk.
        rows = ["..00......00....",
                ".0330.00.0330...",
                "0322303303220...",
                ".0002233220000..",
                "..00322223300...",
                ".03220110223300.",
                "0320..0110..0230",
                "00....0110....00",
                "......0310......",
                "......0110......",
                "......0310......",
                "......0110......",
                "......0310......",
                ".....001100.....",
                "....01111110....",
                "................"]
    else:
        # Column cactus with two raised arms and ribbed sides.
        rows = [".......00.......",
                "......0320......",
                "......0320......",
                "..00..0320......",
                ".0320.0320..00..",
                ".0320.0320.0320.",
                ".0320.0320.0320.",
                ".03200032000320.",
                "..032223222220..",
                "...0002322000...",
                "......0320......",
                "......0320......",
                "......0320......",
                ".....003200.....",
                "....01111110....",
                "................"]
    if variant >= 2:
        rows = [r[::-1] for r in rows]
    c.ascii(ox, oy, rows)


def bloom(c: Canvas, ox: int, oy: int, variant: int) -> None:
    sand(c, ox, oy, variant + 2)
    rng = random.Random(340 + variant)
    spots = [(1, 2), (9, 3), (3, 9), (10, 10)]
    # Small succulent rosettes with a pale flower in the middle.
    for (x, y) in spots[: 3 if variant % 2 else 4]:
        x += rng.randrange(0, 2)
        c.ascii(ox + x, oy + y, [".0.0.", "02320", ".030.", ".111."])


def dunes(c: Canvas, ox: int, oy: int, variant: int) -> None:
    c.rect(ox, oy, T, T, 2)
    # Dune crests: a lit ridge line over a shaded lee slope, wave phase per variant.
    for band, y0 in enumerate((3, 9, 15)):
        for x in range(T):
            y = y0 + (1 if (x + variant * 3 + band * 5) % 8 < 4 else 0) - (1 if (x + variant) % 8 == 0 else 0)
            c.set(ox + x, oy + y - 1, 3)
            c.set(ox + x, oy + y, 1)
            if (x + band) % 3 == 0:
                c.set(ox + x, oy + y + 1, 1)


def mesa_cliff(c: Canvas, ox: int, oy: int, mask: int) -> None:
    # Banded sandstone: horizontal strata with wind-cut notches; a sandy lip on top.
    c.rect(ox, oy, T, T, 1)
    for i, y in enumerate((1, 5, 9, 13)):
        c.hline(ox, ox + 15, oy + y, 2)
        c.hline(ox, ox + 15, oy + y + 3, 0)
        for x in range((i * 5) % 7, T, 7):
            c.set(ox + x, oy + y + 1, 3)
            c.set(ox + x + 1, oy + y + 2, 0)
    if not mask & UP:
        c.rect(ox, oy, T, 3, 2)
        c.hline(ox, ox + 15, oy, 3)
        c.hline(ox, ox + 15, oy + 3, 0)
    if not mask & DOWN:
        c.hline(ox, ox + 15, oy + 14, 0)
        c.checker(ox, oy + 15, T, 1, 1, 2)
    if not mask & LEFT:
        c.vline(ox, oy, oy + 15, 0)
    if not mask & RIGHT:
        c.vline(ox + 15, oy, oy + 15, 0)


def sandstone(c: Canvas, ox: int, oy: int, variant: int) -> None:
    sand(c, ox, oy, variant)
    rows = ["................",
            "...0000000......",
            "..033333330.....",
            ".02222222220....",
            ".01111111110....",
            "0333333333330...",
            "0222222222220...",
            "0111111111110...",
            "0000000000000...",
            "..11111111111...",
            "................"]
    if variant % 2:
        rows = [r[::-1] for r in rows]
    c.ascii(ox, oy + 3, rows)


# Kind name -> desert painter. Kinds not listed keep the shared Era I drawing.
OVERRIDES = {"grass": sand, "tall_grass": scrub, "tree": cactus, "flower": bloom, "scree": dunes,
             "cliff": mesa_cliff, "rock": sandstone}


def inks() -> list[tuple[int, int, int]]:
    look = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))["regions"]["solenne"]
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in look["palette"]]


def main() -> None:
    for name, fn in OVERRIDES.items():
        setattr(g, name, fn)
    px.PALETTE[:] = inks()
    out = os.path.join(ROOT, "art", "era1", "tiles", "overworld_solenne.png")
    g.build_tiles(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
