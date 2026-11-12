#!/usr/bin/env python3
"""Sprite tiers: builds every derived Spirling sprite from the front/back art of its origin era.

    python3 tools/art/gen_tiers.py              write art/eraN/spirling_icons/ and art/eraN/spirling_anim/
    python3 tools/art/gen_tiers.py --check      exit 1 when a derived file is missing or stale
    python3 tools/art/gen_tiers.py --sheet DIR  also write one contact sheet per era (and a GIF) to DIR:
                                                front, back, icons x2, Gleam form, then the Era V
                                                battle frames (idle, attack, hit) front and back

Herkunft: every pixel is taken from the project's own sprites in art/eraN/spirlings/. Poses are
nearest-pixel remaps (stretch about the feet, lean, squash), so a derived frame only holds colours
of its base sprite: an Era I kind stays in four inks, an evolution line keeps its shared look, and
the Gleam shader recolours every frame like the base. Rules per tier: data/sprite_tiers.json.

Per kind, in the era folder of its art:
  spirling_icons/<id>.png   menu icons, one cell per size in "icon_sizes", side by side
  spirling_anim/<id>.png    pose sheet: row 0 front, row 1 back, one canvas-sized cell per pose
An Era IV breath frame drawn by gen_era4.py (<id>_front_b.png) is used as the "breath" pose.
"""
import json, math, os, sys
from collections import Counter
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = json.load(open(os.path.join(ROOT, "data", "sprite_tiers.json"), encoding="utf-8"))
ERAS = sorted(int(e) for e in CFG["tiers"])
FLASH = json.load(open(os.path.join(ROOT, "data", "era5_anim.json"), encoding="utf-8"))["flash_color"]
FACINGS = ["front", "back"]
# Gleam hues are keyed by line, so every stage of a line gleams alike (GleamRules.material).
LINE = {s["name"].lower(): s.get("line_id") or s["name"].lower()
        for s in json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))}
# Front art faces left, back art faces right: the sign of "forward" on the x axis.
FORWARD = {"front": -1, "back": 1}


def era_dir(era, sub="spirlings"):
    return os.path.join(ROOT, "art", f"era{era}", sub)


def kinds(era):
    """Ids with a front sprite in this era's folder."""
    d = era_dir(era)
    if not os.path.isdir(d):
        return []
    return sorted(f[:-len("_front.png")] for f in os.listdir(d) if f.endswith("_front.png"))


def load(era, kid, facing, suffix=""):
    p = os.path.join(era_dir(era), f"{kid}_{facing}{suffix}.png")
    return Image.open(p).convert("RGBA") if os.path.exists(p) else None


def pose(img, p, facing):
    """Nearest-pixel remap of img into pose p; the feet (bottom row of the drawing) stay put."""
    if not any(k in p for k in ("sy", "sx", "shear")):
        return img.copy()
    box = img.getbbox()
    if box is None:
        return img.copy()
    w, h = img.size
    x0, y0, x1, y1 = box[0], box[1], box[2] - 1, box[3] - 1
    height = y1 - y0 + 1
    cx = (x0 + x1) / 2.0
    sy, sx = float(p.get("sy", 1.0)), float(p.get("sx", 1.0))
    shear = float(p.get("shear", 0.0)) * FORWARD[facing]
    anchor = y1 - (1.0 - float(p.get("top", 1.0))) * height
    src = img.load()
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    dst = out.load()
    for y in range(h):
        ys = y if y > anchor else int(round(anchor - (anchor - y) / sy))
        if ys < 0 or ys >= h:
            continue
        lean = shear * (y1 - y) / height if y <= y1 else 0.0
        for x in range(w):
            xs = int(round(cx + (x - lean - cx) / sx))
            if 0 <= xs < w:
                px = src[xs, ys]
                if px[3] > 0:
                    dst[x, y] = px
    return out


def sheet(era, kid):
    """Pose sheet: one row per facing, one cell per pose."""
    tier = CFG["tiers"][str(era)]
    poses = tier["poses"]
    base = {f: load(era, kid, f) for f in FACINGS}
    size = base["front"].size[0]
    out = Image.new("RGBA", (size * len(poses), size * len(FACINGS)), (0, 0, 0, 0))
    for row, facing in enumerate(FACINGS):
        img = base[facing]
        if img is None:
            continue
        for col, p in enumerate(poses):
            drawn = load(era, kid, facing, "_b") if p["name"] == "breath" else None
            out.paste(drawn if drawn is not None else pose(img, p, facing), (col * size, row * size))
    return out


def shrink(img, size):
    """Icon of size x size: each icon pixel takes the most common colour of its source block; a
    block that is mostly outline keeps the outline, so eyes and edges survive."""
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    box = img.getbbox()
    if box is None:
        return out
    crop = img.crop(box)
    w, h = crop.size
    scale = min(1.0, size / max(w, h))
    nw, nh = max(1, round(w * scale)), max(1, round(h * scale))
    src = crop.load()
    dark = min((c for _, c in crop.getcolors(w * h) if c[3] > 0), key=lambda c: c[0] * 299 + c[1] * 587 + c[2] * 114)
    ox, oy = (size - nw) // 2, size - nh
    dst = out.load()
    for y in range(nh):
        ya, yb = int(y * h / nh), max(int((y + 1) * h / nh), int(y * h / nh) + 1)
        for x in range(nw):
            xa, xb = int(x * w / nw), max(int((x + 1) * w / nw), int(x * w / nw) + 1)
            block = [src[i, j] for j in range(ya, min(yb, h)) for i in range(xa, min(xb, w))]
            solid = [c for c in block if c[3] > 0]
            if len(solid) * 3 < len(block) or not solid:
                continue
            count = Counter(solid)
            if count[dark] * 5 >= len(solid) * 2:
                dst[ox + x, oy + y] = dark
            else:
                count.pop(dark, None)
                dst[ox + x, oy + y] = count.most_common(1)[0][0]
    # Drop specks: a pixel with no neighbour is noise at this size.
    for y in range(size):
        for x in range(size):
            if dst[x, y][3] and not any(
                    dst[i, j][3] for j in range(max(y - 1, 0), min(y + 2, size)) for i in range(max(x - 1, 0), min(x + 2, size)) if (i, j) != (x, y)):
                dst[x, y] = (0, 0, 0, 0)
    return out


def icons(era, kid):
    sizes = CFG["icon_sizes"]
    front = load(era, kid, "front")
    out = Image.new("RGBA", (sum(sizes), max(sizes)), (0, 0, 0, 0))
    x = 0
    for s in sizes:
        out.paste(shrink(front, s), (x, 0))
        x += s
    return out


def packed(img):
    """Indexed PNG when the colours fit (smaller files, same pixels)."""
    cols = img.getcolors(255)
    if cols is None:
        return img
    table = [(0, 0, 0, 0)] + sorted({c for _, c in cols if c[3] > 0})
    if any(c[3] != 255 for c in table[1:]):
        return img
    index = {c: i for i, c in enumerate(table)}
    out = Image.new("P", img.size, 0)
    out.putdata([index[c] if c[3] > 0 else 0 for c in img.getdata()])
    out.putpalette([v for c in table for v in c[:3]])
    out.info["transparency"] = 0
    return out


def targets():
    for era in ERAS:
        for kid in kinds(era):
            yield os.path.join(era_dir(era, "spirling_icons"), kid + ".png"), lambda e=era, k=kid: icons(e, k)
            yield os.path.join(era_dir(era, "spirling_anim"), kid + ".png"), lambda e=era, k=kid: sheet(e, k)


def same(path, img):
    if not os.path.exists(path):
        return False
    old = Image.open(path).convert("RGBA")
    return old.size == img.size and old.tobytes() == img.tobytes()


def timeline(era, kid, facing, kind):
    """Frames of one strip as drawn in battle (canvas plus margin), for the contact sheets."""
    tier = CFG["tiers"][str(era)]
    a = tier["anim"][kind]
    sh = Image.open(os.path.join(era_dir(era, "spirling_anim"), kid + ".png")).convert("RGBA")
    size = sh.size[1] // 2
    row = FACINGS.index(facing)
    pad = 12
    flash = tuple(int(FLASH[i:i + 2], 16) for i in (0, 2, 4))
    frames = []
    for i, cell in enumerate(a["cells"]):
        fr = Image.new("RGBA", (size + pad * 2, size + pad), (0, 0, 0, 0))
        if cell != -1:
            c = max(cell, 0)
            img = sh.crop((c * size, row * size, (c + 1) * size, (row + 1) * size))
            if cell == -2:
                img = Image.composite(Image.new("RGBA", img.size, flash + (255,)), Image.new("RGBA", img.size, (0, 0, 0, 0)), img.split()[3])
            dx = (a.get("dx") or [0] * 99)[i] * FORWARD[facing]
            dy = (a.get("dy") or [0] * 99)[i]
            fr.alpha_composite(img, (pad + dx, pad + dy))
        frames.append(fr)
    return frames


def godot_hash(text):
    """String.hash() of Godot (djb2), so the sheet shows the Gleam hue the game uses."""
    h = 5381
    for ch in text:
        h = ((h << 5) + h + ord(ch)) & 0xFFFFFFFF
    return h


def gleam(img, era, kid):
    """The Gleam form as the game's shaders draw it: ink swap for Era I, hue turn for later tiers."""
    out = img.copy()
    px = out.load()
    if era == 1:
        pals = json.load(open(os.path.join(ROOT, "data", "gleam_palettes.json"), encoding="utf-8"))
        to_rgb = lambda h: tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))
        pal = {k.lower(): v for k, v in pals["palettes"].items()}.get(kid)
        if pal is None:
            return out
        swap = {to_rgb(a): to_rgb(b) for a, b in zip(pals["ink"], pal)}
        for y in range(out.height):
            for x in range(out.width):
                c = px[x, y]
                if c[3] and c[:3] in swap:
                    px[x, y] = swap[c[:3]] + (c[3],)
        return out
    g = CFG["gleam"]
    turn = g["hue_shift"] + ((godot_hash(LINE.get(kid, kid)) % g["steps"]) / (g["steps"] - 1) - 0.5) * 2 * g["spread"]
    a = turn * 2 * math.pi
    ca, sa, k = math.cos(a), math.sin(a), 0.57735026919
    for y in range(out.height):
        for x in range(out.width):
            r, gr, b, al = px[x, y]
            if not al:
                continue
            v = (r / 255, gr / 255, b / 255)
            cross = (k * (v[2] - v[1]), k * (v[0] - v[2]), k * (v[1] - v[0]))
            dot = k * sum(v)
            px[x, y] = tuple(max(0, min(255, round((v[i] * ca + cross[i] * sa + k * dot * (1 - ca)) * 255))) for i in range(3)) + (al,)
    return out


def contact_sheet(era, out_dir, limit=24):
    ids = kinds(era)
    if not ids:
        return None
    tier = CFG["tiers"][str(era)]
    step = max(1, len(ids) // limit)
    ids = ids[::step][:limit]
    size, scale, pad = tier["canvas"], 2, 12
    cell_w = size + pad * 2
    kinds_ = CFG["kinds"]
    per = [sum(len(tier["anim"][k]["cells"]) for k in kinds_)] * 2
    cols = 3 + per[0] + per[1]
    row_h = size + pad
    bg = (242, 227, 194, 255) if era == 1 else (150, 170, 150, 255)
    img = Image.new("RGBA", (cols * cell_w + sum(CFG["icon_sizes"]) * 2 + 36, row_h * len(ids)), bg)
    for r, kid in enumerate(ids):
        x = 0
        for facing in FACINGS:
            b = load(era, kid, facing)
            if b is not None:
                img.alpha_composite(b, (x + pad, r * row_h + pad))
            x += cell_w
        ic = Image.open(os.path.join(era_dir(era, "spirling_icons"), kid + ".png")).convert("RGBA")
        ix = 0
        for s in CFG["icon_sizes"]:
            one = ic.crop((ix, 0, ix + s, s))
            img.alpha_composite(one.resize((s * 2, s * 2), Image.NEAREST), (x + ix * 2 + 6, r * row_h + 2))
            ix += s
            x += 6
        x += ic.width * 2 + 12
        img.alpha_composite(gleam(load(era, kid, "front"), era, kid), (x + pad, r * row_h + pad))
        x += cell_w
        for facing in FACINGS:
            if load(era, kid, facing) is None:
                continue
            for k in kinds_:
                for fr in timeline(era, kid, facing, k):
                    img.alpha_composite(fr, (x, r * row_h))
                    x += cell_w
    img = img.resize((img.width * scale, img.height * scale), Image.NEAREST)
    head = Image.new("RGBA", (img.width, 16 + img.height), bg)
    head.alpha_composite(img, (0, 16))
    ImageDraw.Draw(head).text((6, 2), f"Era {era} {tier['label']}: front | back | icons 14, 16, 32 px (x2) | Gleam | "
                              f"Era V battle frames idle, attack, hit: front, then back", fill=(40, 30, 44, 255))
    img = head
    path = os.path.join(out_dir, f"era{era}_{tier['label'].lower()}_tier.png")
    img.convert("RGB").save(path, optimize=True)
    # A GIF of the first kinds: idle loop, attack, hit, as an Era V battle plays them.
    gif_ids = ids[:6]
    frames, durations = [], []
    for k in kinds_ + ["idle"]:
        a = tier["anim"][k]
        tl = [timeline(era, kid, "front", k) for kid in gif_ids]
        for rep in range(3 if a.get("loop") else 1):
            for i in range(len(a["cells"])):
                fr = Image.new("RGBA", (cell_w * len(gif_ids), row_h), bg)
                for c in range(len(gif_ids)):
                    fr.alpha_composite(tl[c][i], (c * cell_w, 0))
                frames.append(fr.resize((fr.width * 3, fr.height * 3), Image.NEAREST).convert("P", palette=Image.ADAPTIVE))
                durations.append(int(1000 / a["fps"]))
    frames[0].save(os.path.join(out_dir, f"era{era}_{tier['label'].lower()}_anim.gif"), save_all=True, append_images=frames[1:], duration=durations, loop=0)
    return path


def main():
    check = "--check" in sys.argv
    stale, written = [], 0
    for path, build in targets():
        img = build()
        if same(path, img):
            continue
        if check:
            stale.append(os.path.relpath(path, ROOT))
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        packed(img).save(path, optimize=True)
        written += 1
    if check:
        if stale:
            print(f"{len(stale)} derived sprite file(s) missing or stale, run python3 tools/art/gen_tiers.py:")
            print("\n".join(stale[:20]))
            sys.exit(1)
        print("sprite tiers up to date")
        return
    print(f"wrote {written} file(s)")
    if "--sheet" in sys.argv:
        out = sys.argv[sys.argv.index("--sheet") + 1]
        os.makedirs(out, exist_ok=True)
        for era in ERAS:
            p = contact_sheet(era, out)
            if p:
                print(p)


if __name__ == "__main__":
    main()
