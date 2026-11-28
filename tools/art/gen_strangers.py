"""Era I overworld sheets for the strangers from the map's edge (plan 2, items 145 and 149).

Four own figures in the same layout as tools/art/gen_tiles.py: 4 columns (down, up, left,
right) x 2 step frames of 16 px, in the four Era I shades. All of them wear the torn travelling
cloak of the far map, its hem frayed like a map's edge.

  stranger         wrapped headscarf (Elma, Aldra, Farida, Lejla)
  stranger_hat     wide brim (Amir, Heider, Mirza, Nail)
  stranger_runner  tied bandana with loose tails (Kenan, Leith)
  stranger_kid     small, short cloak (Lipka)

Writes art/era1/chars/<style>.png. Era II colours come from tools/art/era2_colourise.py.
Run: python3 tools/art/gen_strangers.py
"""
from __future__ import annotations

import os

from px import Canvas
from gen_tiles import LEGS, T

HEADS = {
    "stranger": {
        "down": ["................",
                 "....00000000....",
                 "...0111111110...",
                 "..011222222110..",
                 "..012333333210..",
                 "..013033330310..",
                 "..011333333110..",
                 "...0113333110..."],
        "up": ["................",
               "....00000000....",
               "...0111111110...",
               "..011111111110..",
               "..011111111110..",
               "..011111111110..",
               "..011111111110..",
               "...0111111110..."],
        "right": ["................",
                  "....0000000.....",
                  "...011111110....",
                  "..01112222220...",
                  "..01113333330...",
                  "..01113333030...",
                  "..01113333330...",
                  "...011133330...."],
    },
    "stranger_hat": {
        "down": ["................",
                 ".....000000.....",
                 "....01111110....",
                 "..000000000000..",
                 "...0333333330...",
                 "...0303333030...",
                 "...0333333330...",
                 "....03333330...."],
        "up": ["................",
               ".....000000.....",
               "....01111110....",
               "..000000000000..",
               "...0111111110...",
               "...0111111110...",
               "...0111111110...",
               "....01111110...."],
        "right": ["................",
                  ".....000000.....",
                  "....01111110....",
                  "..0000000000000.",
                  "....011333330...",
                  "....011333030...",
                  "....011333330...",
                  ".....0133330...."],
    },
    "stranger_runner": {
        "down": ["................",
                 "................",
                 "....00000000....",
                 "...0222222220...",
                 "...0111111110...",
                 "...0303333030...",
                 "...0333333330...",
                 "....03333330...."],
        "up": ["................",
               "................",
               "....00000000....",
               "...0222222220...",
               "...0111111110...",
               "...0111111110...",
               "...0111221110...",
               "....01022010...."],
        "right": ["................",
                  "................",
                  "....0000000.....",
                  "..00222222220...",
                  ".020111333330...",
                  "...0113333030...",
                  "...0113333330...",
                  "....01333330...."],
    },
    "stranger_kid": {
        "down": ["................",
                 "................",
                 "................",
                 ".....000000.....",
                 "....01011010....",
                 "....03333330....",
                 "....03033030....",
                 ".....033330....."],
        "up": ["................",
               "................",
               "................",
               ".....000000.....",
               "....01011010....",
               "....01111110....",
               "....01111110....",
               ".....011110....."],
        "right": ["................",
                  "................",
                  "................",
                  ".....00000......",
                  "....0101100.....",
                  "....01133330....",
                  "....01133030....",
                  ".....0133330...."],
    },
}

BODIES = {
    # Long cloak with a frayed hem.
    "cloak": {
        "down": ["...0011111100...",
                 "..011121121110..",
                 "..031121121130..",
                 "..011111111110..",
                 "..010101010110.."],
        "up": ["...0011111100...",
               "..011111111110..",
               "..031111111130..",
               "..011111111110..",
               "..011010101010.."],
        "right": ["....00111100....",
                  "....01111210....",
                  "....01131210....",
                  "...011111210....",
                  "...010101010...."],
    },
    "kid_cloak": {
        "down": ["....00222200....",
                 "....01122110....",
                 "....03111130....",
                 "....01010110....",
                 ".....011110....."],
        "up": ["....00111100....",
               "....01222210....",
               "....03222230....",
               "....01101010....",
               ".....011110....."],
        "right": [".....0022100....",
                  ".....0112210....",
                  ".....0113110....",
                  ".....0101010....",
                  "......01110....."],
    },
}

STYLES = {
    "stranger": ("stranger", "cloak"),
    "stranger_hat": ("stranger_hat", "cloak"),
    "stranger_runner": ("stranger_runner", "cloak"),
    "stranger_kid": ("stranger_kid", "kid_cloak"),
}


def build_char(style: str, path_out: str) -> None:
    head_key, body_key = STYLES[style]
    sheet = Canvas(T * 4, T * 2)
    for col, d in enumerate(["down", "up", "left", "right"]):
        src = "right" if d == "left" else d
        for frame in range(2):
            f = Canvas(T, T)
            f.ascii(0, 0, HEADS[head_key][src])
            f.ascii(0, 8, BODIES[body_key][src])
            f.ascii(0, 13, LEGS[src][frame])
            if d == "left":
                f = f.mirrored()
            sheet.blit(f, col * T, frame * T)
    sheet.save(path_out)


def main() -> None:
    for parts in (HEADS, BODIES):
        for k, dirs in parts.items():
            for d, rows in dirs.items():
                assert all(len(r) == T for r in rows), (k, d)
    root = os.path.join(os.path.dirname(__file__), "..", "..", "art", "era1", "chars")
    for style in STYLES:
        build_char(style, os.path.join(root, f"{style}.png"))


if __name__ == "__main__":
    main()
