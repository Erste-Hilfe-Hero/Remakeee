#!/usr/bin/env python3
"""Era V (Living) overworld atlas for Quivermoor, the post-game Era V region (data/region5.json).

    python3 tools/art/gen_tiles_quivermoor.py           write art/era5/tiles/overworld_quivermoor.png
    python3 tools/art/gen_tiles_quivermoor.py --check   only verify it (exit 1 on a problem)

Herkunft: every pixel comes from the project's own Era I atlas (art/era1/tiles/overworld.png,
tools/art/gen_tiles.py) and the swatches in data/region_looks.json "quivermoor". Nothing is traced.

Same layout as the shared atlas (column = TilesetFactory.Kind, row = variant, 16 px tiles), so
TilesetFactory reads it unchanged. Era V is the next step up from Era IV's 8 tones: each Era I
shade (0..3) picks one of 12 tones built from the kind's 4-tone swatch, with three steps per shade.
Raised kinds get the top light (upper rows one step lighter) and a soft contact shadow on their
two lowest rows; walls, cliffs and towers also get a darker side face. Flat ground keeps one tone
per shade so it does not stripe, except water, whose top row catches a little light (the bog
breathes). Pixels of the grass under a prop keep the grass swatch.
"""
import json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "era1", "tiles", "overworld.png")
DST = os.path.join(ROOT, "art", "era5", "tiles", "overworld_quivermoor.png")
LOOK = json.load(open(os.path.join(ROOT, "data", "region_looks.json"), encoding="utf-8"))["regions"]["quivermoor"]
ERA1_INKS = ["2a1e2c", "6a4256", "c48a5e", "f2e3c2"]  # EraManager.INK_PALETTE
KINDS = ["GRASS", "TALL_GRASS", "PATH", "WATER", "TREE", "WALL", "ROOF", "DOOR", "FLOOR",
         "FENCE", "SIGN", "FLOWER", "COUNTER", "INNER_WALL", "SPRING", "RIFT",
         "CLIFF", "STAIRS", "REEDS", "SCREE", "PIER", "TOWER", "LAMP", "ROCK",
         "WADE", "BOULDER", "PLATE", "CRACKED", "VINES", "PLANK"]  # TilesetFactory.Kind order
ON_GRASS = {"TREE", "FENCE", "SIGN", "FLOWER", "RIFT", "TOWER", "LAMP", "ROCK", "SPRING"}
RAISED = {"TREE", "WALL", "ROOF", "DOOR", "FENCE", "SIGN", "COUNTER", "INNER_WALL", "CLIFF",
          "TOWER", "LAMP", "ROCK", "BOULDER", "VINES"}
SIDE_FACE = {"WALL", "CLIFF", "TOWER"}
WET = {"WATER", "WADE", "SPRING"}
SIDE_ROWS = 4
TILE = 16
STEPS = 3
TONES = 4 * STEPS


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


INK = {rgb(h): i for i, h in enumerate(ERA1_INKS)}


def ramp(swatch):
    four = [rgb(h) for h in LOOK["swatches"][swatch]]
    out = []
    for i in range(TONES):
        t = i / (TONES - 1) * 3
        a, b = four[int(t)], four[min(int(t) + 1, 3)]
        f = t - int(t)
        out.append(tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return out


def grass_pixels(im):
    px = im.load()
    out = set()
    for col, kind in enumerate(KINDS):
        if kind not in ON_GRASS:
            continue
        for row in range(im.height // TILE):
            ox, oy = col * TILE, row * TILE
            best, best_n = 0, -1
            for v in range(4):  # grass variants: column 0, rows 0..3
                n = sum(px[ox + x, oy + y] == px[x, v * TILE + y] for y in range(TILE) for x in range(TILE))
                if n > best_n:
                    best, best_n = v, n
            for y in range(TILE):
                for x in range(TILE):
                    if px[ox + x, oy + y][3] and px[ox + x, oy + y] == px[x, best * TILE + y]:
                        out.add((ox + x, oy + y))
    return out


def tone_for(kind, shade, ty):
    tone = shade * STEPS + 1
    if kind in RAISED:
        if ty < TILE // 2:
            tone += 1
        if ty >= TILE - 2:
            tone -= 1
        if kind in SIDE_FACE and ty >= TILE - SIDE_ROWS:
            tone -= 1
    elif kind in WET and ty == 0:
        tone += 1
    return max(0, min(TONES - 1, tone))


def build():
    im = Image.open(SRC).convert("RGBA")
    px = im.load()
    ramps = {k: ramp(LOOK["tiles"][k]) for k in KINDS}
    grass = grass_pixels(im)
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    op = out.load()
    for y in range(im.height):
        for x in range(im.width):
            r, g, b, a = px[x, y]
            if a == 0:
                continue
            kind = "GRASS" if (x, y) in grass else KINDS[x // TILE]
            op[x, y] = ramps[kind][tone_for(kind, INK[(r, g, b)], y % TILE)] + (a,)
    return out


def check():
    if not os.path.exists(DST):
        print("missing:", os.path.relpath(DST, ROOT))
        return 1
    want, have = build(), Image.open(DST).convert("RGBA")
    if want.size != have.size or want.tobytes() != have.tobytes():
        print("out of date: run python3 tools/art/gen_tiles_quivermoor.py")
        return 1
    cols = {p[:3] for p in have.getdata() if p[3] > 0}
    print("quivermoor atlas OK: %dx%d, %d colours" % (have.width, have.height, len(cols)))
    return 0


if __name__ == "__main__":
    if "--check" not in sys.argv:
        os.makedirs(os.path.dirname(DST), exist_ok=True)
        build().save(DST, optimize=True)
    sys.exit(check())
