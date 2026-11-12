#!/usr/bin/env python3
"""Era II (Wash, limited colour) battle sprites for the Spirling lines of an Era II region.

    python3 tools/art/gen_era2.py <region>            write art/era2/spirlings/<name>_front.png / _back.png
    python3 tools/art/gen_era2.py <region> --check    only verify the files (exit 1 on a problem)
    python3 tools/art/gen_era2.py <region> --sheet P  also write a contact sheet to P

The lines come from tools/art/lines/<region>.py (same spec format as gen_lines.py, ERA = 2).
Shapes are built with the gen_lines.py body plans and features, so a later stage is the same
drawing grown up, plus the Era II features below (mask, rivets, gear, lantern, hood, candle,
chimney, collar, batwings, bell, hook tail).

The Era II look is the limited-colour handheld step after Era I's four inks:
  - 56 x 56 like Era I (EraManager.BATTLE_SPRITE_SIZE), front faces left,
  - at most 8 colours per sprite, the same 8 for every stage of a line: a coloured outline
    (never black), 3 tones of the line's main colour, 3 of its accent, and one cream,
  - flat cel shading: highlight on the top-left edge, a solid shadow band bottom-right,
    no dithering (Era I dithers its shadows).
Main colour = the line's first element, accent = second element (or the spec's "accent").
Lines sharing a main element are spread a few degrees of hue apart so they stay distinct.
"""
from __future__ import annotations

import colorsys
import importlib
import math
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

import gen_lines as GL  # noqa: E402
from gen_spirlings import BACK_DROP, S, Stamp  # noqa: E402
from px import Canvas  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "era2", "spirlings")
MAX_COLOURS = 8
HUE_STEP = 11  # degrees between lines that share a main element

# Shadow, base, light per element (original values).
RAMPS = {
    "EMBER": ("a33a2c", "dd6440", "f6a65e"),
    "TIDE": ("2c5c9c", "4290d2", "92ccee"),
    "BLOOM": ("33703a", "56a24a", "a4d472"),
    "VOLT": ("9c7a1c", "d8b02e", "f4e072"),
    "STONE": ("6c5c4e", "9c8a76", "ccbea2"),
    "GALE": ("3a7c76", "5eb2a6", "aae2d2"),
    "LUMEN": ("a8823c", "e0c060", "f8eab0"),
    "UMBRA": ("40305e", "6c5292", "a48cc8"),
    "INK": ("1e2c4c", "364c7c", "6e84b4"),
    "ECHO": ("8c3e6c", "c46e9e", "eeb4d4"),
    "RUST": ("6e3e20", "a6663a", "d49a64"),
    "MASK": ("4a4458", "7c7690", "c4c0d2"),
}
CREAM = "f6eed8"

# Era I shade name -> (base, shadow, highlight) index into a 4-tone ramp [outline, shadow, base, light].
SHADES = {"light": (3, 2, 3), "mid": (2, 1, 3), "dark": (1, 0, 2), "ink": (0, 0, 1)}


def rgb(h: str) -> tuple:
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hue(c: tuple, deg: float) -> tuple:
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
    r, g, b = colorsys.hls_to_rgb((h + deg / 360) % 1, l, s)
    return (round(r * 255), round(g * 255), round(b * 255))


def outline_of(c: tuple) -> tuple:
    return tuple(max(10, round(v * 0.42)) for v in c)


def line_palette(line: dict, step: float) -> list:
    """The 8 colours of a line: 0 outline, 1-3 main, 4-6 accent, 7 cream."""
    els = line["elements"]
    acc = line["art"].get("accent") or (els[1] if len(els) > 1 else line.get("cover", els[0]))
    main = [hue(rgb(c), step) for c in RAMPS[els[0]]]
    accent = [rgb(c) for c in RAMPS[acc]]
    if acc == els[0]:
        accent = [hue(c, 40) for c in accent]
    return [outline_of(main[0])] + main + accent + [rgb(CREAM)]


# Material ramps as palette indices [outline, shadow, base, light].
MATS = {"B": (0, 1, 2, 3), "A": (0, 4, 5, 6), "P": (0, 3, 3, 7)}


def token(t: str) -> tuple:
    """Part tone -> (material, shade). Plain Era I shades: light parts are pale (cream), others main."""
    if ":" in t:
        m, s = t.split(":")
        return m, s
    return ("P" if t == "light" else "B"), t


def render(parts: list, back: bool = False) -> Canvas:
    """Index canvas (0..7) of the parts; cel shading without dither."""
    c = Canvas(S, S)
    for part in parts:
        if back and part.face:
            continue
        if isinstance(part, Stamp):
            # Stamp digits: 0 outline, 1 main shadow, 2 main base, 3 cream.
            for y, row in enumerate(part.rows):
                for x, ch in enumerate(row):
                    if ch in "0123":
                        c.set(part.x + x, part.y + y, (0, 1, 2, 7)[int(ch)])
            continue
        inside = [[part.mask(x, y) for x in range(S)] for y in range(S)]

        def ins(x, y):
            return 0 <= x < S and 0 <= y < S and inside[y][x]

        mat, shade = token(part.tone)
        ramp = MATS[mat]
        base, shadow, hi = (ramp[i] for i in SHADES[shade])
        if part.outline:
            for y in range(S):
                for x in range(S):
                    if not inside[y][x] and (ins(x - 1, y) or ins(x + 1, y) or ins(x, y - 1) or ins(x, y + 1)):
                        c.set(x, y, 0)
        for y in range(S):
            for x in range(S):
                if not inside[y][x]:
                    continue
                v = base
                if part.shade:
                    if not ins(x + 1, y + 1) or not ins(x + 1, y) or not ins(x + 2, y + 2):
                        v = shadow
                    elif not ins(x - 1, y - 1) or not ins(x, y - 1):
                        v = hi
                c.set(x, y, v)
    return c


def shift_down(c: Canvas, dy: int) -> Canvas:
    out = Canvas(S, S)
    for y in range(S - dy):
        out.px[y + dy] = list(c.px[y])
    return out


def to_image(c: Canvas, pal: list) -> Image.Image:
    img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    px = img.load()
    for y in range(S):
        for x in range(S):
            v = c.px[y][x]
            if v is not None:
                px[x, y] = pal[v] + (255,)
    return img


# --- Era II features ----------------------------------------------------------------------

def hook_tail(g, sp, A, d):
    if sp.get("tail") != "hook":
        return
    tx, ty = A["tail"]
    L = 1.0 + 0.15 * d
    # shaft rising from the tail root, then a metal hook curling back over it
    g.p([(tx - 1, ty), (tx + 4 * L, ty - 11 * L), (tx + 7 * L, ty - 10 * L), (tx + 3, ty + 3)], "B:mid")
    cx, cy, r = tx + 8 * L, ty - 14 * L, 3 + d
    pts = [(cx + (r + 1.6) * math.cos(math.radians(a)), cy + (r + 1.6) * math.sin(math.radians(a))) for a in range(90, -181, -20)]
    pts += [(cx + (r - 1.4) * math.cos(math.radians(a)), cy + (r - 1.4) * math.sin(math.radians(a))) for a in range(-180, 91, 20)]
    g.p(pts, "A:light")
    g.p([(cx - r - 3, cy + 1), (cx - r + 1, cy + 4 + d), (cx - r + 1.5, cy - 1)], "A:light")


def batwings(g, sp, A, d):
    if "batwings" not in sp.get("extras", ()):
        return
    bx, by, brx, bry = A["body"]
    w = 1.0 + 0.15 * d
    for side in (-1, 1):
        x0 = bx + side * (brx - 3)
        tips = [(x0 + side * 16 * w, by - 14 * w), (x0 + side * 18 * w, by - 2), (x0 + side * 14 * w, by + 6 * w)]
        pts = [(x0, by - 6), tips[0]]
        for i in range(1, len(tips)):
            (ax, ay), (cx, cy) = tips[i - 1], tips[i]
            pts.append(((ax + cx) / 2 - side * 3, (ay + cy) / 2))
            pts.append((cx, cy))
        pts.append((x0, by + 5))
        g.p(pts, "A:dark" if side > 0 else "A:mid")
        for (tx, ty) in tips:
            g.p([(x0, by - 1), (tx, ty), (tx - side, ty + 1)], "B:dark", outline=False, shade=False)


def bell(g, sp, A, d):
    if "bell" not in sp.get("extras", ()):
        return
    bx, by, brx, bry = A["body"]
    top, rim, w = by - bry - 3, by + 15, brx + 5 + d
    g.e(bx, rim + 3 + d * 0.5, 3 + d * 0.5, 3 + d * 0.5, "A:mid")
    dome = GL.arc(bx, top + brx * 0.8, brx * 0.8, brx * 0.8, -180, 0, 9)
    g.p([(bx - w, rim)] + [(bx - brx * 0.8, top + brx * 0.8 + 3)] + dome + [(bx + brx * 0.8, top + brx * 0.8 + 3), (bx + w, rim)], "B:mid")
    g.p([(bx - w - 1, rim - 3), (bx + w + 1, rim - 3), (bx + w + 1, rim + 1), (bx - w - 1, rim + 1)], "A:mid")
    g.p([(bx - 3, top - 4 - d), (bx + 3, top - 4 - d), (bx + 3, top + 1), (bx - 3, top + 1)], "A:mid")


def gear(g, sp, A, d):
    if "gear" not in sp.get("extras", ()):
        return
    bx, by, brx, bry = A["body"]
    cx, cy, r = bx + brx * 0.35, by - bry - 1, 6 + 1.5 * d
    n = 6 + 2 * d
    for i in range(n):
        a = 2 * math.pi * i / n
        ca, sa = math.cos(a), math.sin(a)
        g.p([(cx + (r - 1) * ca - 1.6 * sa, cy + (r - 1) * sa + 1.6 * ca), (cx + (r + 3) * ca - 1.4 * sa, cy + (r + 3) * sa + 1.4 * ca),
             (cx + (r + 3) * ca + 1.4 * sa, cy + (r + 3) * sa - 1.4 * ca), (cx + (r - 1) * ca + 1.6 * sa, cy + (r - 1) * sa - 1.6 * ca)],
            "A:mid")
    g.e(cx, cy, r, r, "A:mid")
    g.e(cx, cy, r * 0.4, r * 0.4, "B:dark")


def chimney(g, sp, A, d):
    if "chimney" not in sp.get("extras", ()):
        return
    bx, by, brx, bry = A["body"]
    for i in range(1 + (d + 1) // 2):
        x = bx + 2 + 6 * i
        top = by - bry - 7 - 2 * d + 3 * i
        g.p([(x - 2, by - bry + 3), (x - 2, top), (x + 2, top), (x + 2, by - bry + 3)], "A:dark")
        g.p([(x - 3, top - 2), (x + 3, top - 2), (x + 3, top + 1), (x - 3, top + 1)], "A:mid")
        g.e(x + 2, top - 5, 3 + d * 0.5, 2.5 + d * 0.5, "P:light")
        if d >= 1:
            g.e(x + 6, top - 9, 2.5 + d * 0.5, 2 + d * 0.5, "P:light")


def hood(g, sp, A, d, front: bool):
    if "hood" not in sp.get("extras", ()):
        return
    hx, hy, hr = A["head"]
    if not front:
        g.e(hx + 3, hy - 1, hr + 3, hr + 2 + d * 0.5, "A:dark")
        g.p([(hx + 3, hy + 2), (hx + hr + 8 + 2 * d, hy + hr + 6), (hx + hr + 2, hy + hr + 3)], "A:dark")
    else:
        pts = GL.arc(hx + 1, hy, hr + 1.5, hr + 0.5, -175, -5, 8)
        inner = GL.arc(hx + 2, hy + 1, hr - 1, hr - 3.5, -5, -175, 8)
        g.p(pts + inner, "A:mid")


def collar(g, sp, A, d):
    if "collar" not in sp.get("extras", ()):
        return
    hx, hy, hr = A["head"]
    n = 4 + d
    for i, (x, y) in enumerate(GL.arc(hx + 2, hy + hr * 0.9, hr * 0.85, 3, 10, 170, n)):
        g.e(x, y, 2.6 + 0.3 * d, 2.2, "P:light" if i % 2 == 0 else "A:light")


def mask(g, sp, A, d):
    if "mask" not in sp.get("extras", ()):
        return
    hx, hy, hr = A["head"]
    t = sp.get("mask_tone", "P:light")
    if sp["plan"] in GL.FRONTAL:
        g.p([(hx - 9, hy - 5), (hx + 1, hy - 3), (hx + 11, hy - 5), (hx + 10, hy + 1), (hx + 1, hy + 2), (hx - 8, hy + 1)], t)
        if d >= 1:
            g.p([(hx + 10, hy - 5), (hx + 14 + d, hy - 9 - d), (hx + 11, hy)], t)
            g.p([(hx - 8, hy - 5), (hx - 12 - d, hy - 9 - d), (hx - 8, hy)], t)
    else:
        x0 = hx - hr - 1
        g.p([(x0, hy - 4), (hx + 2, hy - 5), (hx + 4, hy - 1), (hx + 1, hy + 2), (x0 + 1, hy + 1)], t)
        if d >= 1:
            g.p([(hx + 2, hy - 5), (hx + 8 + 2 * d, hy - 9 - d), (hx + 4, hy - 1)], t)


def rivets(g, sp, A, d):
    if "rivets" not in sp.get("extras", ()):
        return
    bx, by, brx, bry = A["body"]
    for i, (x, y) in enumerate(GL.arc(bx, by, brx * 0.6, bry * 0.5, -160, 30, 3 + d)):
        g.e(x + (i % 2), y, 2.4, 1.8, "A:mid", outline=False, shade=False)
        g.st(x, y - 1, ["3"], face=False)


def lantern(g, sp, A, d):
    if "lantern" not in sp.get("extras", ()):
        return
    hx, hy, hr = A["head"]
    top = hy - hr + 1
    ex, ey = hx - hr - 4 - d, top - 6 - 2 * d
    sx, sy = hx - 1, top + 2
    for i in range(9):  # stalk from the head to the lamp
        t = i / 8
        x = sx + (ex - sx) * t
        y = sy + (ey - 3 - sy) * t - 4 * math.sin(math.pi * t)
        g.e(x, y, 1.1, 1.1, "B:dark", outline=False, shade=False)
    g.p([(ex - 3, ey - 1), (ex + 3, ey - 1), (ex + 2, ey + 6 + d), (ex - 2, ey + 6 + d)], "P:light")
    g.p([(ex - 3, ey - 3), (ex + 3, ey - 3), (ex + 3, ey), (ex - 3, ey)], "A:dark", shade=False)
    g.st(ex - 1, ey + 2, ["33", "33"], face=False)


def candles(g, sp, A, d):
    if "candle" not in sp.get("extras", ()):
        return
    hx, hy, hr = A["head"]
    top = hy - hr + 1
    for i in range(1 + d):
        x = hx + 3 - 5 * i + (2 if d == 2 else 0)
        h = 5 + d - i
        g.p([(x - 2, top + 1), (x - 2, top - h), (x + 2, top - h), (x + 2, top + 1)], "P:light", shade=False)
        g.p([(x - 2, top - h - 1), (x, top - h - 7), (x + 2, top - h - 1)], sp.get("flame_tone", "A:light"))


def build(sp: dict, scale: float, d: int) -> list:
    g = GL.G(scale)
    A = GL.plan_anchors(sp)
    t = tuple(sp.get("tones", ("mid", "light", "dark")))
    tones = ("B:" + t[0], "B:" + t[1], "A:" + t[2])
    GL.tail(g, sp, A, d, tones)
    hook_tail(g, sp, A, d)
    if sp["plan"] != "shell":
        GL.back(g, sp, A, d, tones)
    gear(g, sp, A, d)
    chimney(g, sp, A, d)
    GL.extras_behind(g, sp, A, d, tones)
    batwings(g, sp, A, d)
    GL.ears(g, sp, A, d, tones)
    hood(g, sp, A, d, front=False)
    GL.draw_body(g, sp, A, d, tones)
    if sp["plan"] == "shell":
        GL.back(g, sp, A, d, tones)
    bell(g, sp, A, d)
    rivets(g, sp, A, d)
    collar(g, sp, A, d)
    if not sp.get("crest_front"):
        GL.crest(g, sp, A, d, tones)
    GL.draw_head(g, sp, A, d, tones)
    GL.horns(g, sp, A, d, tones)
    candles(g, sp, A, d)
    if sp.get("crest_front"):
        GL.crest(g, sp, A, d, tones)
    hood(g, sp, A, d, front=True)
    GL.extras_front(g, sp, A, d, tones)
    mask(g, sp, A, d)
    lantern(g, sp, A, d)
    GL.draw_face(g, sp, A, d)
    return g.parts


def stages(line: dict):
    names = line["names"]
    return [(n, build(dict(line["art"]), sc, d)) for n, (sc, d) in zip(names, GL.STAGES[len(names)])]


def palettes(lines: list) -> dict:
    seen: dict = {}
    out = {}
    for line in lines:
        k = line["elements"][0]
        n = seen.get(k, 0)
        seen[k] = n + 1
        step = ((n + 1) // 2) * (1 if n % 2 else -1) * HUE_STEP + line["art"].get("hue", 0)
        out[line["id"]] = line_palette(line, step)
    return out


def sprites(lines: list):
    """(name, front image, back image) for every species of the lines."""
    pals = palettes(lines)
    for line in lines:
        for name, parts in stages(line):
            front = to_image(render(parts), pals[line["id"]])
            back = to_image(shift_down(render(parts, back=True).mirrored(), BACK_DROP), pals[line["id"]])
            yield line, name, front, back


def problems(img: Image.Image) -> list:
    out = []
    px = img.load()
    cols = {px[x, y][:3] for y in range(img.height) for x in range(img.width) if px[x, y][3] > 0}
    if img.size != (S, S):
        out.append("size %s" % (img.size,))
    if len(cols) > MAX_COLOURS:
        out.append("%d colours > %d" % (len(cols), MAX_COLOURS))
    if (0, 0, 0) in cols:
        out.append("pure black")
    if len(cols) < 4:
        out.append("only %d colours" % len(cols))
    return out


def sheet(lines: list, path: str, title: str) -> None:
    z = 2
    cell = S * z
    w = 8 + 3 * (2 * cell + 8) + 8
    h = 34 + len(lines) * (cell + 16)
    img = Image.new("RGBA", (w, h), (0xEE, 0xEA, 0xE0, 255))
    dr = ImageDraw.Draw(img)
    dr.text((8, 8), title, fill=(0x30, 0x2A, 0x3A, 255))
    rows: dict = {}
    for line, name, front, back in sprites(lines):
        rows.setdefault(line["id"], (line, []))[1].append((name, front, back))
    for r, (line, items) in enumerate(rows.values()):
        y = 30 + r * (cell + 16)
        for i, (name, front, back) in enumerate(items):
            x = 8 + i * (2 * cell + 8)
            dr.rectangle([x, y, x + 2 * cell - 1, y + cell - 1], fill=(0xFF, 0xFC, 0xF4, 255))
            img.alpha_composite(front.resize((cell, cell), Image.NEAREST), (x, y))
            img.alpha_composite(back.resize((cell, cell), Image.NEAREST), (x + cell, y))
            dr.text((x + 2, y + cell + 2), "%s  %s" % (name, "/".join(e[:4] for e in line["elements"])),
                    fill=(0x30, 0x2A, 0x3A, 255))
    img.save(path)


def main(argv: list) -> int:
    region = argv[0]
    lines = GL.load_lines(region)
    check = "--check" in argv
    os.makedirs(OUT, exist_ok=True)
    bad = 0
    n = 0
    for line, name, front, back in sprites(lines):
        for side, img in (("front", front), ("back", back)):
            path = os.path.join(OUT, "%s_%s.png" % (name.lower(), side))
            if check:
                if not os.path.exists(path):
                    print("missing:", path)
                    bad += 1
                    continue
                img = Image.open(path).convert("RGBA")
            else:
                img.save(path, optimize=True)
                GL._import_sidecar(path)
            for p in problems(img):
                print("%s: %s" % (path, p))
                bad += 1
            n += 1
    if "--sheet" in argv:
        sheet(lines, argv[argv.index("--sheet") + 1], "%s - %d Era II Spirlings" % (
            region.capitalize(), sum(len(l["names"]) for l in lines)))
    print("era2 %s: %d sprites, %d problems" % (region, n, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
