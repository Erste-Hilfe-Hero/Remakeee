"""Era I landmarks (map design plan item 509): one tall thing per outdoor place that you know
it by. Every act draws its own set, nothing is shared between acts, so Veydal, Corvane and
Ashmere never look alike even where their maps have the same shape.

  veydal  (heath and lake):  standing_stone, cairn, beacon, tide_post
  corvane (dye fens):        heron_post, drying_rack, sluice_wheel, dye_mill
  ashmere (ash and salt):    smelter_stack, bell_frame, salt_obelisk
  vellmarch (canal towns):   customs_crane, great_candle, lock_wheel, masked_statue, last_lamp
                             (one per town, so no two Vellmarch towns share a landmark)

Each sprite is 16 x 32: the bottom tile stands on the landmark's (solid) map cell, the top
tile reaches over the cell above. Drawn in 4 indices and saved in the act's own inks
(data/region_looks.json, Veydal keeps the base Ink), like the act's tile atlas.
Placement and texts: data/landmarks.json (scripts/overworld/Landmarks.gd).

Writes art/era1/landmarks/<region>_<kind>.png.
Run: python3 tools/art/gen_landmarks.py (from the repo root).
"""
from __future__ import annotations

import json
import os

from PIL import Image

from px import PALETTE, Canvas

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
OUT = os.path.join(ROOT, "art", "era1", "landmarks")
W, H = 16, 32


def inks(region: str) -> list[tuple[int, int, int]]:
    looks = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))["regions"]
    if region not in looks:
        return list(PALETTE)
    return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in looks[region]["palette"]]


def shadow(c: Canvas, x0: int, x1: int) -> None:
    c.hline(x0, x1, 31, 0)
    c.hline(x0 + 1, x1 - 1, 30, 1)


def outline(c: Canvas) -> None:
    """Dark rim around every filled pixel that touches transparency (keeps shapes readable)."""
    edge = []
    for y in range(H):
        for x in range(W):
            if c.get(x, y) is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                if not (0 <= x + dx < W and 0 <= y + dy < H) or c.get(x + dx, y + dy) is None:
                    edge.append((x, y))
                    break
    for x, y in edge:
        c.set(x, y, 0)


# --- Veydal: heath, bracken and the lake ----------------------------------------------------
def standing_stone(c: Canvas) -> None:
    # A tall menhir leaning a little west, carved spiral, lichen spots.
    for y in range(4, 30):
        lean = (30 - y) // 9
        half = 3 if y < 8 else 4
        for x in range(8 - half - lean, 8 + half - lean):
            c.set(x, y, 2)
        c.set(8 + half - lean - 1, y, 1)
    c.ascii(5, 13, [".33.", "3..3", "3.3.", ".3.."])
    for x, y in ((7, 8), (9, 20), (5, 24)):
        c.set(x, y, 3)
    outline(c)
    shadow(c, 3, 13)


def cairn(c: Canvas) -> None:
    # Stacked flat stones, widest at the bottom, a marker stick on top.
    stones = [(26, 12), (22, 10), (18, 8), (14, 6), (11, 4)]
    for y, w in stones:
        x0 = 8 - w // 2
        c.rect(x0, y, w, 4 if y > 11 else 3, 2)
        c.hline(x0, x0 + w - 1, y, 3)
        c.hline(x0, x0 + w - 1, y + (3 if y > 11 else 2), 1)
    c.vline(8, 3, 10, 1)
    c.rect(9, 3, 3, 2, 3)
    outline(c)
    shadow(c, 1, 14)


def beacon(c: Canvas) -> None:
    # A stone post with an iron fire basket and a thin flame.
    c.rect(6, 12, 4, 18, 2)
    c.vline(9, 12, 29, 1)
    c.rect(5, 27, 6, 3, 1)
    c.ascii(3, 7, ["0........0",
                   "02.2.2.2.0",
                   ".02222220.",
                   "..011110..",
                   "...0000..."])
    c.ascii(5, 1, ["..3...",
                   ".333..",
                   ".3233.",
                   "33223.",
                   ".3223."])
    outline(c)
    shadow(c, 3, 12)


def tide_post(c: Canvas) -> None:
    # A wooden post in the water with notches and a small bell on an arm.
    c.rect(7, 4, 3, 26, 2)
    c.vline(9, 4, 29, 1)
    for y in range(10, 28, 4):
        c.hline(7, 8, y, 0)
    c.hline(4, 9, 5, 1)
    c.ascii(3, 6, [".00.", "0330", "0230", "0000", ".0.."])
    c.hline(4, 12, 29, 3)
    c.hline(5, 11, 30, 3)
    outline(c)


# --- Corvane: the dye fens ------------------------------------------------------------------
def heron_post(c: Canvas) -> None:
    # A carved heron on a tall pole, beak pointing at the road.
    c.vline(8, 14, 29, 1)
    c.vline(7, 14, 29, 2)
    c.ascii(2, 1, ["......00........",
                   ".....0330.......",
                   "0000003030......",
                   ".....03330......",
                   "......0330......",
                   "......03330.....",
                   ".....0333330....",
                   "....033332220...",
                   "....0333222210..",
                   ".....022221100..",
                   "......0000000...",
                   "........0.0....."])
    c.rect(5, 28, 6, 2, 1)
    outline(c)
    shadow(c, 3, 12)


def drying_rack(c: Canvas) -> None:
    # Two poles and a crossbar with long strips of dyed cloth.
    c.vline(2, 4, 29, 1)
    c.vline(13, 4, 29, 1)
    c.hline(1, 14, 4, 0)
    c.hline(1, 14, 5, 2)
    for x, n, v in ((3, 17, 3), (6, 21, 2), (9, 15, 3)):
        c.rect(x, 6, 4, n, v)
        c.vline(x + 2, 6, 5 + n, 1 if v == 2 else 2)
        c.set(x + 3, 5 + n, None)
    outline(c)
    shadow(c, 1, 14)


def sluice_wheel(c: Canvas) -> None:
    # A paddle wheel on a timber frame above a stone channel.
    cx, cy, r = 8, 15, 7
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if r - 1.5 <= d <= r:
                c.set(x, y, 2)
    for dx, dy in ((0, -1), (1, 0), (0, 1), (-1, 0), (1, 1), (-1, -1), (1, -1), (-1, 1)):
        for i in range(1, r):
            c.set(cx + dx * i if dx * dy == 0 else cx + dx * (i * 7 // 10),
                  cy + dy * i if dx * dy == 0 else cy + dy * (i * 7 // 10), 1)
    c.rect(7, 14, 3, 3, 3)
    c.vline(2, 8, 29, 1)
    c.vline(13, 8, 29, 1)
    c.rect(1, 24, 14, 6, 2)
    c.hline(1, 14, 24, 3)
    c.hline(3, 12, 27, 1)
    outline(c)


def dye_mill(c: Canvas) -> None:
    # A narrow mill house with four cloth sails, a blue-black vat by the door.
    c.rect(5, 15, 6, 15, 2)
    c.vline(10, 15, 29, 1)
    c.ascii(5, 11, ["..00..", ".0110.", "011110", "011110"])
    c.rect(7, 25, 2, 5, 0)
    for (x0, y0, x1, y1) in ((8, 12, 1, 3), (8, 12, 15, 3), (8, 12, 1, 21), (8, 12, 15, 21)):
        steps = max(abs(x1 - x0), abs(y1 - y0))
        for i in range(steps + 1):
            x = x0 + (x1 - x0) * i // steps
            y = y0 + (y1 - y0) * i // steps
            c.set(x, y, 1)
            if i > steps // 3:
                c.set(x + (1 if x1 > x0 else -1), y, 3)
    c.rect(11, 26, 4, 4, 1)
    c.hline(11, 14, 26, 3)
    outline(c)
    shadow(c, 3, 14)


# --- Ashmere: ash, basalt and salt ----------------------------------------------------------
def smelter_stack(c: Canvas) -> None:
    # A brick chimney with bands, a crooked cap and a smoke plume.
    for y in range(8, 30):
        w = 4 + (y - 8) // 6
        c.rect(8 - w // 2, y, w, 1, 1)
        c.set(8 - w // 2, y, 2)
    for y in range(10, 30, 5):
        c.hline(5, 11, y, 2)
    c.rect(5, 7, 7, 2, 0)
    c.ascii(6, 0, ["..33..", ".3223.", "322223", ".3223.", "..33..", "...3.."])
    c.rect(4, 26, 8, 4, 1)
    c.rect(7, 27, 2, 3, 0)
    outline(c)
    shadow(c, 2, 13)


def bell_frame(c: Canvas) -> None:
    # A charred timber frame with a cracked fire bell.
    c.vline(2, 6, 29, 1)
    c.vline(3, 6, 29, 2)
    c.vline(12, 6, 29, 1)
    c.vline(13, 6, 29, 2)
    c.hline(1, 14, 5, 0)
    c.hline(1, 14, 6, 1)
    c.ascii(4, 7, ["...00...",
                   "..0220..",
                   ".022320.",
                   ".022320.",
                   "0222232.",
                   "02222320",
                   "00000000",
                   "...00..."])
    c.set(6, 10, 0)
    c.set(7, 11, 0)
    c.hline(1, 14, 22, 1)
    outline(c)
    shadow(c, 1, 14)


def salt_obelisk(c: Canvas) -> None:
    # A jagged spike of grown salt crystals, pale with dark seams.
    for y in range(2, 30):
        half = max(1, (y - 2) // 5)
        for x in range(8 - half, 8 + half):
            c.set(x, y, 3)
        c.set(8 + half - 1, y, 2)
    c.ascii(2, 18, ["..3.", ".33.", "332.", "332."])
    c.ascii(11, 21, [".3..", ".33.", ".323", ".323"])
    for x, y0, y1 in ((7, 6, 12), (6, 15, 22), (9, 20, 27)):
        c.vline(x, y0, y1, 1)
    outline(c)
    shadow(c, 1, 14)


# --- Vellmarch: quays, canals and candle smoke --------------------------------------------------
def customs_crane(c: Canvas) -> None:
    # A timber quay crane: mast, slanted jib, a chained crate hanging from it.
    c.rect(4, 6, 3, 24, 2)
    c.vline(6, 6, 29, 1)
    for i in range(10):
        c.set(5 + i, 6 - i // 2, 2)
        c.set(5 + i, 7 - i // 2, 1)
    for i in range(6):
        c.set(7 + i, 12 - i, 1)
    c.vline(13, 3, 15, 0)
    c.rect(11, 16, 5, 5, 3)
    c.hline(11, 15, 18, 1)
    c.vline(13, 16, 20, 1)
    c.rect(2, 27, 7, 3, 1)
    c.hline(2, 8, 27, 3)
    outline(c)
    shadow(c, 1, 12)


def great_candle(c: Canvas) -> None:
    # A candle as thick as a man, wax run down one side, on a stone drum.
    c.rect(5, 8, 6, 18, 3)
    c.vline(10, 8, 25, 2)
    c.vline(9, 10, 25, 2)
    c.ascii(4, 8, ["3.....", "33....", "33....", "3.....", "3....."])
    c.ascii(10, 9, [".3", ".3", "33", "3."])
    c.vline(8, 5, 7, 0)
    c.ascii(6, 0, ["..3..", ".323.", ".323.", "32223", ".323."])
    c.rect(3, 26, 10, 4, 2)
    c.hline(3, 12, 26, 3)
    c.hline(3, 12, 29, 1)
    outline(c)
    shadow(c, 2, 13)


def lock_wheel(c: Canvas) -> None:
    # The wheel that opens a canal lock, on a post, a boat hook hung below.
    cx, cy, r = 8, 9, 7
    for y in range(H):
        for x in range(W):
            d = ((x + 0.5 - cx) ** 2 + (y + 0.5 - cy) ** 2) ** 0.5
            if r - 1.6 <= d <= r:
                c.set(x, y, 2)
    for i in range(1, r - 1):
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            c.set(cx + dx * i, cy + dy * i, 1)
    c.rect(7, 8, 3, 3, 3)
    c.rect(7, 16, 3, 14, 2)
    c.vline(9, 16, 29, 1)
    c.ascii(11, 16, ["0..", "0..", "0.0", "000"])
    c.rect(5, 28, 7, 2, 1)
    outline(c)
    shadow(c, 3, 12)


def masked_statue(c: Canvas) -> None:
    # A robed figure on a plinth holding a blank mask where its face should be.
    c.ascii(4, 2, ["..0000..",
                   ".033330.",
                   "03033030",
                   "03333330",
                   ".033330.",
                   "..0330.."])
    c.ascii(3, 8, ["...22.....",
                   "..2222....",
                   ".222222...",
                   ".2222221..",
                   "22222221..",
                   "22222221..",
                   "222222211.",
                   "222222211.",
                   "222222211.",
                   "2222222111",
                   "2222222111",
                   "2222222111"])
    c.vline(6, 12, 19, 1)
    c.rect(2, 20, 12, 3, 3)
    c.rect(3, 23, 10, 7, 2)
    c.vline(12, 23, 29, 1)
    c.hline(5, 10, 26, 1)
    outline(c)
    shadow(c, 2, 13)


def last_lamp(c: Canvas) -> None:
    # A tall iron street lamp leaning over the marsh, its glass the only bright thing.
    c.vline(7, 10, 29, 1)
    c.vline(8, 10, 29, 2)
    c.ascii(4, 1, ["...00...",
                   "..0110..",
                   ".011110.",
                   "02333320",
                   "02333320",
                   "02333320",
                   "02333320",
                   ".022220.",
                   "..0110.."])
    c.hline(5, 10, 14, 1)
    c.set(4, 15, 1)
    c.set(11, 15, 1)
    c.rect(5, 26, 6, 4, 1)
    c.hline(5, 10, 26, 2)
    outline(c)
    shadow(c, 3, 12)


KINDS = {
    "veydal": {"standing_stone": standing_stone, "cairn": cairn, "beacon": beacon, "tide_post": tide_post},
    "corvane": {"heron_post": heron_post, "drying_rack": drying_rack, "sluice_wheel": sluice_wheel, "dye_mill": dye_mill},
    "ashmere": {"smelter_stack": smelter_stack, "bell_frame": bell_frame, "salt_obelisk": salt_obelisk},
    "vellmarch": {"customs_crane": customs_crane, "great_candle": great_candle, "lock_wheel": lock_wheel,
                  "masked_statue": masked_statue, "last_lamp": last_lamp},
}


def render(region: str, kind: str) -> Image.Image:
    c = Canvas(W, H)
    KINDS[region][kind](c)
    pal = inks(region)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    for y in range(H):
        for x in range(W):
            v = c.px[y][x]
            if v is not None:
                img.putpixel((x, y), pal[v] + (255,))
    return img


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    n = 0
    for region, kinds in KINDS.items():
        for kind in kinds:
            render(region, kind).save(os.path.join(OUT, "%s_%s.png" % (region, kind)))
            n += 1
    print("wrote %d landmarks to %s" % (n, OUT))


if __name__ == "__main__":
    main()
