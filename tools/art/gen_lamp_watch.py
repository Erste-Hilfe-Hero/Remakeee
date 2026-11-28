"""Era I art for the Lamp Watch (data/lamp_watch.json, scripts/core/LampWatch.gd).

Draws the lighthouse lamp as a small storm lantern in the four Era I inks, lit and dark, and the
card strips art/era1/fx/lamp_watch_<n>.png (n = 0..7 lamps lit out of seven) that the lamp room
shows above the card text. Hand-written pixel rows, no third-party input.

Run from the repo root:
  python3 tools/art/gen_lamp_watch.py
"""
from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from px import Canvas  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "era1", "fx")

W, H = 16, 26
GAP = 2
NIGHTS = 7

# 0 outline, 1 dark, 2 mid, 3 light. '.' = transparent.
FRAME = [
    "......0000......",
    ".....011110.....",
    "......0110......",
    ".....000000.....",
    "....01122110....",
    "...0111111110...",
    "..000000000000..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..0.0......0.0..",
    "..000000000000..",
    "...0112222110...",
    "....01111110....",
    ".....000000.....",
]
# Glass panes (inside the frame), rows 7..15, columns 5..10.
GLASS_TOP, GLASS_ROWS, GLASS_X, GLASS_W = 7, 9, 5, 6

FLAME = [
    "..3...",
    "..33..",
    ".333..",
    ".3333.",
    ".3333.",
    "..33..",
]


def lamp(lit: bool) -> Canvas:
    c = Canvas(W, H)
    oy = 4
    if lit:
        # Halo: a dithered ring of light around the glass (no smooth gradients in Era I).
        for y in range(oy + 8, oy + 16):
            for x in (0, 1, W - 2, W - 1):
                if (x + y) % 2 == 0:
                    c.set(x, y, 2)
        for x in (4, 6, 9, 11):
            c.set(x, oy - 2 + (x % 2), 2)
    c.ascii(0, oy, FRAME)
    for y in range(GLASS_ROWS):
        for x in range(GLASS_W):
            if lit:
                c.set(GLASS_X + x, oy + GLASS_TOP + y, 2)
            else:
                c.set(GLASS_X + x, oy + GLASS_TOP + y, 1 if (x + y) % 3 else 0)
    if lit:
        c.ascii(GLASS_X, oy + GLASS_TOP + 1, FLAME)
        c.hline(GLASS_X + 1, GLASS_X + 4, oy + GLASS_TOP + 8, 1)
    else:
        # A cold wick: one dark stroke at the bottom of the glass.
        c.vline(GLASS_X + 2, oy + GLASS_TOP + 6, oy + GLASS_TOP + 8, 2)
        c.vline(GLASS_X + 3, oy + GLASS_TOP + 7, oy + GLASS_TOP + 8, 2)
    return c


def strip(n_lit: int) -> Canvas:
    c = Canvas(NIGHTS * W + (NIGHTS - 1) * GAP, H)
    on, off = lamp(True), lamp(False)
    for i in range(NIGHTS):
        c.blit(on if i < n_lit else off, i * (W + GAP), 0)
    return c


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    lamp(True).save(os.path.join(OUT, "lamp_lit.png"))
    lamp(False).save(os.path.join(OUT, "lamp_dark.png"))
    for n in range(NIGHTS + 1):
        strip(n).save(os.path.join(OUT, "lamp_watch_%d.png" % n))
    print("wrote", OUT)


if __name__ == "__main__":
    main()
