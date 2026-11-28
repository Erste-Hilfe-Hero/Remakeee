#!/usr/bin/env python3
"""Era I effect shapes for battle arts (plan area 6, item 2613).

    python3 tools/art/gen_fx.py

Writes art/era1/fx/<shape>_<shade>.png: eight 8x8 shapes (spark, drop, leaf, zag, rock,
streak, glint, shade) in each of the four Era I inks (0 darkest .. 3 lightest), transparent
elsewhere. Drawn from the ASCII grids below, nothing traced or copied. Deterministic.
"""
from __future__ import annotations

import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from px import Canvas  # noqa: E402

ROOT = os.path.normpath(os.path.join(os.path.dirname(__file__), "..", ".."))
OUT = os.path.join(ROOT, "art", "era1", "fx")

# "#" = the shade, "." = transparent. Every grid is 8x8.
SHAPES: dict[str, list[str]] = {
    "spark": [
        "........",
        "...#....",
        "...#....",
        ".######.",
        "...##...",
        "..#..#..",
        ".#....#.",
        "........",
    ],
    "drop": [
        "...#....",
        "...#....",
        "..###...",
        "..###...",
        ".#####..",
        ".#####..",
        "..###...",
        "........",
    ],
    "leaf": [
        "......#.",
        "....###.",
        "..####..",
        ".####...",
        ".###....",
        "#.#.....",
        "#.......",
        "........",
    ],
    "zag": [
        "....##..",
        "...##...",
        "..##....",
        ".#####..",
        "...##...",
        "..##....",
        ".##.....",
        "#.......",
    ],
    "rock": [
        "........",
        "..###...",
        ".#####..",
        "#######.",
        "######..",
        ".####...",
        "........",
        "........",
    ],
    "streak": [
        "........",
        "........",
        "####....",
        "..######",
        "........",
        ".#####..",
        "........",
        "........",
    ],
    "glint": [
        "...#....",
        "...#....",
        "...#....",
        "#######.",
        "...#....",
        "...#....",
        "...#....",
        "........",
    ],
    "shade": [
        "........",
        "..####..",
        ".######.",
        "########",
        "########",
        ".######.",
        "..#..#..",
        "........",
    ],
}


def build(shape: str, shade: int) -> Canvas:
    c = Canvas(8, 8)
    for y, row in enumerate(SHAPES[shape]):
        assert len(row) == 8, (shape, y)
        for x, ch in enumerate(row):
            if ch == "#":
                c.set(x, y, shade)
    return c


def outputs() -> list[str]:
    return ["art/era1/fx/%s_%d.png" % (s, k) for s in SHAPES for k in range(4)]


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    for s in SHAPES:
        assert len(SHAPES[s]) == 8, s
        for k in range(4):
            build(s, k).save(os.path.join(OUT, "%s_%d.png" % (s, k)))
    print("fx: %d shapes x 4 shades -> %s" % (len(SHAPES), OUT))


if __name__ == "__main__":
    main()
