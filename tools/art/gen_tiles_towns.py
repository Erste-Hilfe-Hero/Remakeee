"""Town tiles for Acts II-IV (buildings design plan items 26-70): Corvane, Ashmere and Solenne
each get their own houses, roofs and doors (all four door roles) and their own Rift gate.
Of the props (fence, sign, lamp, spring) an act keeps the ones its own atlas generator
(gen_tiles_<act>.py) draws and gets the rest from buildings.py.

Works on art/era1/tiles/overworld_<act>.png (or the shared atlas when the act has none yet), in
the act's own four inks (data/region_looks.json, else the Era I inks).
Run after gen_tiles.py and the act generators: python3 tools/art/gen_tiles_towns.py
"""
from __future__ import annotations

import json
import os

from PIL import Image

import buildings
import gen_tiles as g
from px import Canvas, PALETTE

T = g.T
HERE = os.path.dirname(__file__)
ROOT = os.path.join(HERE, "..", "..")
TILES = os.path.join(ROOT, "art", "era1", "tiles")


def own_props(style: str) -> set:
    """Props the act's own generator draws (it names the kind or patches gen_tiles' function)."""
    path = os.path.join(HERE, "gen_tiles_%s.py" % style)
    if not os.path.exists(path):
        return set()
    src = open(path).read()
    return {k for k in ("FENCE", "SIGN", "LAMP", "SPRING") if '"%s"' % k in src or "g.%s" % k.lower() in src}


def inks(style: str) -> list:
    looks = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))["regions"]
    if style in looks:
        return [tuple(int(h[i:i + 2], 16) for i in (0, 2, 4)) for h in looks[style]["palette"]]
    return list(PALETTE)


def to_canvas(img: Image.Image, pal: list) -> Canvas:
    index = {p: i for i, p in enumerate(pal)}
    c = Canvas(img.width, img.height)
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            r, gg, b, a = px[x, y]
            if a:
                c.px[y][x] = index[(r, gg, b)]
    return c


def to_image(c: Canvas, pal: list) -> Image.Image:
    img = Image.new("RGBA", (c.w, c.h), (0, 0, 0, 0))
    for y in range(c.h):
        for x in range(c.w):
            v = c.px[y][x]
            if v is not None:
                img.putpixel((x, y), pal[v] + (255,))
    return img


def build(style: str, c: Canvas, kinds: list) -> Canvas:
    gx = g.K["GRASS"] * T

    def ground(cv, ox, oy, variant):
        # The act's own ground under props: that variant's cell of the GRASS column.
        for y in range(T):
            for x in range(T):
                cv.set(ox + x, oy + y, c.px[variant % 4 * T + y][gx + x])

    for name in kinds:
        ox = g.K[name] * T
        for v in range(g.VARIANT_ROWS):
            c.rect(ox, v * T, T, T, None)
            buildings.draw(c, name, style, ox, v * T, v, ground)
    return c


def main() -> None:
    shared = to_canvas(Image.open(os.path.join(TILES, "overworld.png")).convert("RGBA"), list(PALETTE))
    for style in buildings.TOWNS:
        path = os.path.join(TILES, "overworld_%s.png" % style)
        pal = inks(style)
        if os.path.exists(path):
            c = to_canvas(Image.open(path).convert("RGBA"), pal)
        else:
            c = to_canvas(Image.open(os.path.join(TILES, "overworld.png")).convert("RGBA"), list(PALETTE))
        kinds = sorted(buildings.STYLED - own_props(style))
        build(style, c, kinds)
        # Lighthouse rows 1 (shaft over the door) and 2 (foot with door) from the shared atlas,
        # in the act's inks and on the act's own ground.
        tx, gx = g.K["TOWER"] * T, g.K["GRASS"] * T
        for y in range(T, 3 * T):
            for x in range(T):
                v = shared.px[y][tx + x]
                c.px[y][tx + x] = c.px[y % T][gx + x] if v == shared.px[y % T][gx + x] else v
        to_image(c, pal).save(path)
        print("wrote", path, "(%s)" % ", ".join(kinds))


if __name__ == "__main__":
    main()
