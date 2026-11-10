#!/usr/bin/env python3
"""Era II (Aquarell, Corvane) art: colours the Era I drawings, no redrawing.

    python3 tools/art/era2_colourise.py            write art/era2/ from art/era1/
    python3 tools/art/era2_colourise.py --check    only verify art/era2/ (exit 1 on a problem)
    python3 tools/art/era2_colourise.py --sheet P  also write a contact sheet to P (era1 vs era2 atlas,
                                                   plus a TEST colouring of the 81 spirlings, not shipped)

The existing 81 Spirlings keep their Era I ink look in every era (owner decision 2026-11-10),
so art/era2/spirlings/ is not written; their palettes are only used for the test sheet.

Every Era I pixel is one of the four inks (EraManager.INK_PALETTE). Its shade index 0..3 is
mapped to the 4-tone palette of what it belongs to, from tools/art/era2_palettes.json:
spirlings by element (line keeps one family), tiles by atlas column (TilesetFactory.Kind),
chars by figure, fx by element. Alpha is copied unchanged.
"""
import colorsys, glob, json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "era1")
DST = os.path.join(ROOT, "art", "era2")
PAL = json.load(open(os.path.join(ROOT, "tools", "art", "era2_palettes.json"), encoding="utf-8"))
TILE = 16
KINDS = list(PAL["tiles"].keys())  # same order as TilesetFactory.Kind / gen_tiles.KINDS
# Kinds drawn over a grass tile in gen_tiles.py: their grass pixels keep the grass palette.
ON_GRASS = {"TREE", "FENCE", "SIGN", "FLOWER", "RIFT", "TOWER", "LAMP", "ROCK"}


def rgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


INK = {rgb(h): i for i, h in enumerate(PAL["ink"])}


def shades(im: Image.Image) -> list:
    """Shade index per pixel (None where transparent)."""
    out = []
    for r, g, b, a in im.getdata():
        out.append(None if a == 0 else INK[(r, g, b)])
    return out


def recolour(im: Image.Image, pal_at) -> Image.Image:
    """pal_at(x, y) -> list of 4 rgb tuples."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()
    out = Image.new("RGBA", (w, h))
    op = out.load()
    for y in range(h):
        for x in range(w):
            r, g, b, a = px[x, y]
            if a == 0:
                op[x, y] = (0, 0, 0, 0)
                continue
            op[x, y] = pal_at(x, y)[INK[(r, g, b)]] + (a,)
    return out


def shift_hue(c: tuple, deg: float) -> tuple:
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
    r, g, b = colorsys.hls_to_rgb((h + deg / 360) % 1, l, s)
    return (round(r * 255), round(g * 255), round(b * 255))


def spirling_palettes() -> dict:
    species = json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))
    rules = PAL["spirling_rules"]
    lines: dict = {}
    for sp in species:  # first member in dex order fixes the line's elements
        lines.setdefault(sp["line_id"], sp["elements"])
    seen: dict = {}
    line_pal = {}
    for line, els in lines.items():
        key = tuple(els)
        n = seen.get(key, 0)
        seen[key] = n + 1
        step = ((n + 1) // 2) * (1 if n % 2 else -1) * rules["line_hue_step"]  # 0, +s, -s, +2s ...
        base = [rgb(c) for c in PAL["elements"][els[0]]]
        if len(els) > 1:
            base[rules["accent_tone"]] = rgb(PAL["elements"][els[1]][rules["accent_tone"]])
        line_pal[line] = [shift_hue(c, step) for c in base]
    return {sp["name"].lower(): line_pal[sp["line_id"]] for sp in species}


def save(im: Image.Image, rel: str) -> None:
    path = os.path.join(DST, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    im.save(path, optimize=True)


def test_spirling(f: str, pals: dict) -> Image.Image:
    p = pals[os.path.basename(f).rsplit("_", 1)[0]]
    return recolour(Image.open(f), lambda x, y: p)


def build() -> None:
    for f in sorted(glob.glob(os.path.join(SRC, "chars", "*.png"))):
        p = [rgb(c) for c in PAL["chars"][os.path.basename(f)[:-4]]]
        save(recolour(Image.open(f), lambda x, y: p), "chars/" + os.path.basename(f))
    for f in sorted(glob.glob(os.path.join(SRC, "fx", "*.png"))):
        p = [rgb(c) for c in PAL["elements"][PAL["fx"][os.path.basename(f).split("_")[0]]]]
        save(recolour(Image.open(f), lambda x, y: p), "fx/" + os.path.basename(f))
    save(colour_atlas(Image.open(os.path.join(SRC, "tiles", "overworld.png")).convert("RGBA")), "tiles/overworld.png")


def colour_atlas(im: Image.Image) -> Image.Image:
    w, h = im.size
    px = im.load()
    kp = {k: [rgb(c) for c in PAL["tiles"][k]] for k in KINDS}
    grass_px: dict = {}  # (x, y) -> True where a cell pixel is the grass underneath
    for col, kind in enumerate(KINDS):
        if kind not in ON_GRASS:
            continue
        for row in range(h // TILE):
            ox, oy = col * TILE, row * TILE
            if px[ox, oy][3] == 0 and px[ox + 8, oy + 8][3] == 0:
                continue
            best, best_n = None, -1
            for v in range(4):  # grass variants live in column 0, rows 0..3
                n = sum(px[ox + x, oy + y] == px[x, v * TILE + y] for y in range(TILE) for x in range(TILE))
                if n > best_n:
                    best, best_n = v, n
            for y in range(TILE):
                for x in range(TILE):
                    if px[ox + x, oy + y] == px[x, best * TILE + y]:
                        grass_px[(ox + x, oy + y)] = True
    return recolour(im, lambda x, y: kp["GRASS"] if (x, y) in grass_px else kp[KINDS[x // TILE]])


def check() -> int:
    bad = 0
    n = 0
    for f in sorted(glob.glob(os.path.join(SRC, "**", "*.png"), recursive=True)):
        rel = os.path.relpath(f, SRC)
        if rel.startswith("spirlings"):
            continue
        g = os.path.join(DST, rel)
        if not os.path.exists(g):
            print("missing:", rel); bad += 1; continue
        a, b = Image.open(f).convert("RGBA"), Image.open(g).convert("RGBA")
        n += 1
        if a.size != b.size:
            print("size differs:", rel); bad += 1; continue
        if list(a.getchannel("A").getdata()) != list(b.getchannel("A").getdata()):
            print("alpha differs:", rel); bad += 1
        if rel.startswith("tiles"):
            for ty in range(0, b.height, TILE):
                for tx in range(0, b.width, TILE):
                    cell = b.crop((tx, ty, tx + TILE, ty + TILE))
                    kind = KINDS[tx // TILE]
                    allowed = {rgb(c) for c in PAL["tiles"][kind]}
                    if kind in ON_GRASS:
                        allowed |= {rgb(c) for c in PAL["tiles"]["GRASS"]}
                    cols = {p[:3] for p in cell.getdata() if p[3] > 0}
                    if not cols <= allowed:
                        print("tile colours off palette:", kind, tx, ty); bad += 1
        else:
            cols = {p[:3] for p in b.getdata() if p[3] > 0}
            if len(cols) > 4:
                print("more than 4 colours:", rel, len(cols)); bad += 1
    print("era2 check: %d files, %d problems" % (n, bad))
    return 1 if bad else 0


def sheet(path: str) -> None:
    fronts = sorted(glob.glob(os.path.join(SRC, "spirlings", "*_front.png")))
    cols, cell, m = 9, 56, 16
    rows = (len(fronts) + cols - 1) // cols
    gw = cols * cell
    atlas1 = Image.open(os.path.join(SRC, "tiles", "overworld.png")).convert("RGBA")
    W = m * 3 + max(gw, atlas1.width) * 2
    H = m * 3 + rows * cell + atlas1.height
    bg = (232, 226, 214, 255)
    out = Image.new("RGBA", (W, H), bg)
    pals = spirling_palettes()
    for side, root in enumerate((SRC, DST)):
        x0 = m + side * (max(gw, atlas1.width) + m)
        for i, f in enumerate(fronts):
            im = Image.open(f).convert("RGBA") if side == 0 else test_spirling(f, pals)
            out.alpha_composite(im, (x0 + (i % cols) * cell, m + (i // cols) * cell))
        at = Image.open(os.path.join(root, "tiles", "overworld.png")).convert("RGBA")
        out.alpha_composite(at, (x0, m * 2 + rows * cell))
    from PIL import ImageDraw
    d = ImageDraw.Draw(out)
    d.text((m + max(gw, atlas1.width) + m, 2), "TEST ONLY: spirlings stay Era I ink, not shipped", fill=(120, 40, 40, 255))
    d.text((m, 2), "Era I", fill=(60, 40, 50, 255))
    out = out.resize((W * 2, H * 2), Image.NEAREST)
    out.save(path)
    print("contact sheet:", path, out.size)


if __name__ == "__main__":
    if "--check" not in sys.argv:
        build()
    rc = check()
    if "--sheet" in sys.argv:
        sheet(sys.argv[sys.argv.index("--sheet") + 1])
    sys.exit(rc)
