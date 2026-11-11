#!/usr/bin/env python3
"""Era IV (Panorama) Spirling art pipeline, design plan 311-313: 96x96 painted sprites with
soft shading and a 2-frame breathing idle.

    python3 tools/art/gen_era4.py               write art/era4/spirlings/ for species with "era": 4
    python3 tools/art/gen_era4.py --sheet DIR   also write sample sheets (any species) to DIR

Herkunft: every pixel comes from the project's own Era I drawings (art/era1/spirlings/) and
the project's own element palettes (tools/art/era2_palettes.json). Nothing is traced or sampled.

Steps per sprite: Era I shade index (0..3) -> float shade field -> smooth upscale to 96 ->
top-left light falloff -> quantise to an 8-tone ramp built from the element's 4 tones ->
dark outline. Frame "_b" is the breath: the upper body squashed by 2 px, feet fixed.
Owner decision 2026-11-10: existing Spirlings keep their Era I look, so only era-4 species ship.
"""
import json, os, sys
from PIL import Image, ImageFilter

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "art", "era1", "spirlings")
DST = os.path.join(ROOT, "art", "era4", "spirlings")
PAL = json.load(open(os.path.join(ROOT, "tools", "art", "era2_palettes.json"), encoding="utf-8"))
SIZE = 96
TONES = 8
BREATH_PX = 2


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


INK = [rgb(h) for h in PAL["ink"]]


def ramp(element):
    four = [rgb(h) for h in PAL["elements"].get(element, PAL["ink"])]
    out = []
    for i in range(TONES):
        t = i / (TONES - 1) * 3
        a, b = four[int(t)], four[min(int(t) + 1, 3)]
        f = t - int(t)
        out.append(tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return out


def shade_index(px):
    return min(range(4), key=lambda i: sum((px[k] - INK[i][k]) ** 2 for k in range(3)))


def paint(src, element):
    w, h = src.size
    shade = Image.new("L", (w, h), 0)
    alpha = Image.new("L", (w, h), 0)
    for y in range(h):
        for x in range(w):
            p = src.getpixel((x, y))
            if p[3] > 0:
                shade.putpixel((x, y), shade_index(p) * 85)
                alpha.putpixel((x, y), 255)
    shade = shade.resize((SIZE, SIZE), Image.BICUBIC).filter(ImageFilter.GaussianBlur(0.8))
    alpha = alpha.resize((SIZE, SIZE), Image.NEAREST)
    pal = ramp(element)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    for y in range(SIZE):
        for x in range(SIZE):
            if alpha.getpixel((x, y)) == 0:
                continue
            edge = any(not (0 <= x + dx < SIZE and 0 <= y + dy < SIZE) or alpha.getpixel((x + dx, y + dy)) == 0
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
            if edge:
                out.putpixel((x, y), pal[0] + (255,))
                continue
            light = 1.0 - (x + y) / (2.0 * SIZE)  # soft light from the top left
            v = shade.getpixel((x, y)) / 255.0 + (light - 0.5) * 0.3
            out.putpixel((x, y), pal[max(1, min(TONES - 1, round(v * (TONES - 1))))] + (255,))
    return out


def breath(img):
    box = img.getbbox()
    if not box:
        return img.copy()
    top, bottom = box[1], box[3]
    split = top + (bottom - top) * 6 // 10
    upper = img.crop((0, top, SIZE, split))
    upper = upper.resize((SIZE, max(1, split - top - BREATH_PX)), Image.NEAREST)
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.crop((0, split, SIZE, SIZE)), (0, split))
    out.paste(upper, (0, top + BREATH_PX), upper)
    return out


def species():
    return json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))


def render(sp, facing):
    path = os.path.join(SRC, "%s_%s.png" % (sp["name"].lower(), facing))
    if not os.path.exists(path):
        return None
    a = paint(Image.open(path).convert("RGBA"), sp["elements"][0])
    return a, breath(a)


def sheet(sps, path):
    cols = 4
    cell = SIZE + 8
    rows = (len(sps) + cols - 1) // cols
    img = Image.new("RGBA", (cols * cell * 3, rows * cell), (238, 230, 210, 255))
    for i, sp in enumerate(sps):
        old = Image.open(os.path.join(SRC, "%s_front.png" % sp["name"].lower())).convert("RGBA")
        a, b = render(sp, "front")
        x, y = (i % cols) * cell * 3, (i // cols) * cell
        img.paste(old.resize((SIZE, SIZE), Image.NEAREST), (x + 4, y + 4), old.resize((SIZE, SIZE), Image.NEAREST))
        img.paste(a, (x + cell + 4, y + 4), a)
        img.paste(b, (x + cell * 2 + 4, y + 4), b)
    img.save(path)


def main():
    args = sys.argv[1:]
    sps = species()
    os.makedirs(DST, exist_ok=True)
    for sp in sps:
        if int(sp.get("era", 1)) < 4:
            continue
        for facing in ("front", "back"):
            r = render(sp, facing)
            if r:
                r[0].save(os.path.join(DST, "%s_%s.png" % (sp["name"].lower(), facing)))
                r[1].save(os.path.join(DST, "%s_%s_b.png" % (sp["name"].lower(), facing)))
    if "--sheet" in args:
        out = args[args.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        solenne = [s for s in sps if s.get("region") == "solenne"
                   and os.path.exists(os.path.join(SRC, "%s_front.png" % s["name"].lower()))]
        sheet(solenne, os.path.join(out, "era4_spirlings_solenne.png"))
        sheet([s for s in sps if s.get("region") == "veydal"][:12], os.path.join(out, "era4_spirlings_veydal.png"))


if __name__ == "__main__":
    main()
