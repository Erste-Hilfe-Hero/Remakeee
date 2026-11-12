#!/usr/bin/env python3
"""Raised-tile cut-outs for the layered overworld look of Eras III to V (docs/ERA_FEEL_TILES.md).

    python3 tools/art/gen_era_raised.py           write art/era<N>/tiles/raised_<region>.png
    python3 tools/art/gen_era_raised.py --check   only verify them (exit 1 on a problem)

Herkunft: every pixel comes from the region's own atlas (art/era<N>/tiles/overworld_<region>.png,
tools/art/gen_tiles_*.py). Nothing is traced.

Same layout as the atlas (column = TilesetFactory.Kind, row = variant, 16 px tiles), but only
the kinds that stand on grass (trees, lamps, towers, signs, fences, rocks), and the grass under
them is cut away: a pixel that equals the same pixel of the best-matching plain grass variant and
reaches the tile edge through such pixels is transparent. EraTerrainLook draws these over the drop shadows, mirrors them in water and lifts
their tops over the people (tree crowns, lamp heads).
"""
import os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGIONS = {"quillmarch": 3, "halcyra": 4, "quivermoor": 5}  # data/eras.json, EraManager.REGION_ERA
KINDS = ["GRASS", "TALL_GRASS", "PATH", "WATER", "TREE", "WALL", "ROOF", "DOOR", "FLOOR",
         "FENCE", "SIGN", "FLOWER", "COUNTER", "INNER_WALL", "SPRING", "RIFT",
         "CLIFF", "STAIRS", "REEDS", "SCREE", "PIER", "TOWER", "LAMP", "ROCK",
         "WADE", "BOULDER", "PLATE", "CRACKED", "VINES", "PLANK"]  # TilesetFactory.Kind order
CUT = ["TREE", "FENCE", "SIGN", "TOWER", "LAMP", "ROCK"]
TILE = 16
GRASS_ROWS = 8  # variants 0..3 and the same four in a building's shadow


def paths(region):
    d = os.path.join(ROOT, "art", "era%d" % REGIONS[region], "tiles")
    return os.path.join(d, "overworld_%s.png" % region), os.path.join(d, "raised_%s.png" % region)


def build(region):
    im = Image.open(paths(region)[0]).convert("RGBA")
    px = im.load()
    out = Image.new("RGBA", im.size, (0, 0, 0, 0))
    op = out.load()
    for kind in CUT:
        ox = KINDS.index(kind) * TILE
        for row in range(im.height // TILE):
            oy = row * TILE
            cells = [(x, y) for y in range(TILE) for x in range(TILE)]
            if not any(px[ox + x, oy + y][3] for x, y in cells):
                continue
            best = max(range(GRASS_ROWS), key=lambda v: sum(px[ox + x, oy + y] == px[x, v * TILE + y] for x, y in cells))
            same = {(x, y) for x, y in cells if px[ox + x, oy + y] == px[x, best * TILE + y]}
            # Only grass that reaches the tile edge is background; the same tone inside a crown stays.
            todo = [c for c in same if c[0] in (0, TILE - 1) or c[1] in (0, TILE - 1)]
            away = set(todo)
            while todo:
                x, y = todo.pop()
                for n in ((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)):
                    if n in same and n not in away:
                        away.add(n)
                        todo.append(n)
            for x, y in cells:
                p = px[ox + x, oy + y]
                if p[3] and (x, y) not in away:
                    op[ox + x, oy + y] = p
    return out


def check():
    bad = 0
    for region in REGIONS:
        dst = paths(region)[1]
        if not os.path.exists(dst):
            print("missing:", os.path.relpath(dst, ROOT))
            bad = 1
            continue
        want, have = build(region), Image.open(dst).convert("RGBA")
        if want.size != have.size or want.tobytes() != have.tobytes():
            print("out of date: run python3 tools/art/gen_era_raised.py (%s)" % region)
            bad = 1
        else:
            print("raised %s OK: %dx%d" % (region, have.width, have.height))
    return bad


if __name__ == "__main__":
    if "--check" not in sys.argv:
        for r in REGIONS:
            build(r).save(paths(r)[1], optimize=True)
    sys.exit(check())
