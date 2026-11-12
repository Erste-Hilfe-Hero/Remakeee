#!/usr/bin/env python3
"""Era V (Living) Spirling art pipeline: 96 x 96 battle sprites for a region's own Era V lines.

    python3 tools/art/gen_era5.py REGION              write art/era5/spirlings/<name>_front.png / _back.png
    python3 tools/art/gen_era5.py REGION --check      only verify the files on disk (exit 1 on a problem)
    python3 tools/art/gen_era5.py REGION --sheet PNG  also write a contact sheet

Herkunft: every sprite is built from the line specs in tools/art/lines/REGION.py with the
project's own body plans (tools/art/gen_lines.py) and the project's own element tones
(tools/art/era2_palettes.json plus the own values in MORE). Nothing is traced or sampled.

Look (handheld generation 5: bigger sprites that are animated in battle): every part of a body
plan is sampled natively at 96 px (no upscaled pixels), lit on its own as a soft volume with the
light from the top left, and quantised to a 12-tone ramp. The first element colours the body,
the second the parts the spec draws in its "dark" tone; a kind with one element gets a
hue-turned accent. Outlines take the darkest tone of the part's own colour, never black.
All stages of a line share one spec, so a later stage is the earlier one grown up.
There is no breath frame: Era V idle, attack and hit strips are built at runtime from the base
sprite (data/era5_anim.json).
"""
import colorsys, json, os, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
sys.path.insert(0, HERE)
import gen_lines as GL
from gen_spirlings import BACK_DROP, S as SRC, Stamp

DST = os.path.join(ROOT, "art", "era5", "spirlings")
PAL = json.load(open(os.path.join(ROOT, "tools", "art", "era2_palettes.json"), encoding="utf-8"))
SIZE = 96
K = SIZE / SRC
TONES = 12
MAX_COLOURS = 2 * TONES + 2
# Four tones (dark to light) for the elements era2_palettes.json does not cover (own values).
MORE = {
    "INK": ["16182c", "34385e", "7478a4", "d4d8ec"],
    "ECHO": ["36284c", "74589c", "b49cd6", "eee6fa"],
    "RUST": ["3c1c12", "8c4022", "cc7c46", "f2d2ae"],
    "MASK": ["2c182c", "6c385c", "b4769a", "f2dcea"],
    "ACID": ["2a3a10", "6c9020", "b4d44c", "eef8b8"],
    "FROST": ["1e3448", "5c8cac", "a8d0e4", "f0fafe"],
    "GILT": ["4c3410", "ac7a1c", "eac24e", "fcf2c2"],
    "ZENITH": ["22385e", "5882c4", "a6caf2", "f2f8ff"],
}
BASE = {"light": 0.74, "mid": 0.54, "dark": 0.50, "ink": 0.10}
ACCENT_TONES = ("dark",)
LIGHT_GAIN = 2.6


def rgb(h):
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def turn(c, deg):
    h, s, v = colorsys.rgb_to_hsv(*(k / 255 for k in c))
    return tuple(round(k * 255) for k in colorsys.hsv_to_rgb((h + deg / 360) % 1.0, s, v))


def ramp(element, hue=0):
    four = [turn(rgb(h), hue) for h in PAL["elements"].get(element, MORE.get(element, PAL["ink"]))]
    out = []
    for i in range(TONES):
        t = i / (TONES - 1) * 3
        a, b = four[int(t)], four[min(int(t) + 1, 3)]
        f = t - int(t)
        out.append(tuple(round(a[k] + (b[k] - a[k]) * f) for k in range(3)))
    return out


def line_ramps(line):
    els = line["elements"]
    hue = line["art"].get("hue", 0)
    main = ramp(els[0], hue)
    accent = ramp(els[1], hue) if len(els) > 1 else ramp(els[0], hue + 40)
    return main, accent


def part_mask(part):
    """The part's shape sampled at 96 px (its coordinates are in the 56 px plan space)."""
    m = Image.new("L", (SIZE, SIZE), 0)
    px = m.load()
    f = part.mask
    for y in range(SIZE):
        sy = (y + 0.5) / K - 0.5
        for x in range(SIZE):
            if f((x + 0.5) / K - 0.5, sy):
                px[x, y] = 255
    return m


def render(parts, ramps, back=False):
    main, accent = ramps
    val = Image.new("L", (SIZE, SIZE), 0)    # brightness 0..255
    mat = Image.new("L", (SIZE, SIZE), 0)    # 0 main, 255 accent, 128 eye shine
    line = Image.new("L", (SIZE, SIZE), 0)   # 255 = outline pixel
    alpha = Image.new("L", (SIZE, SIZE), 0)
    for part in parts:
        if back and part.face:
            continue
        if isinstance(part, Stamp):
            for r, row in enumerate(part.rows):
                for c, ch in enumerate(row):
                    if ch == ".":
                        continue
                    box = [round((part.x + c) * K), round((part.y + r) * K),
                           round((part.x + c + 1) * K) - 1, round((part.y + r + 1) * K) - 1]
                    v = int(ch)
                    ImageDraw.Draw(alpha).rectangle(box, fill=255)
                    ImageDraw.Draw(line).rectangle(box, fill=255 if v == 0 else 0)
                    ImageDraw.Draw(mat).rectangle(box, fill=128 if v == 3 else 0)
                    ImageDraw.Draw(val).rectangle(box, fill=(0, 90, 150, 255)[v])
            continue
        m = part_mask(part)
        if m.getbbox() is None:
            continue
        m_mat = 255 if part.tone in ACCENT_TONES else 0
        if part.outline:
            ring = ImageChops.subtract(m.filter(ImageFilter.MaxFilter(3)), m)
            line.paste(255, (0, 0), ring)
            mat.paste(m_mat, (0, 0), ring)
            alpha.paste(255, (0, 0), ring)
        base = BASE[part.tone]
        if part.shade:
            h = m.filter(ImageFilter.GaussianBlur(3.2))
            lit = ImageChops.subtract(ImageChops.offset(h, -2, -2), ImageChops.offset(h, 2, 2), 1.0, 128)
            v = lit.point(lambda p: max(0, min(255, round(255 * base + (p - 128) * LIGHT_GAIN))))
        else:
            v = Image.new("L", (SIZE, SIZE), round(255 * base))
        val.paste(v, (0, 0), m)
        mat.paste(m_mat, (0, 0), m)
        line.paste(0, (0, 0), m)
        alpha.paste(255, (0, 0), m)
    out = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    o, a, vv, mm, ll = out.load(), alpha.load(), val.load(), mat.load(), line.load()
    shine = tuple(min(255, c + 10) for c in main[-1])
    for y in range(SIZE):
        for x in range(SIZE):
            if not a[x, y]:
                continue
            r = accent if mm[x, y] == 255 else main
            if ll[x, y]:
                o[x, y] = r[0] + (255,)
            elif mm[x, y] == 128:
                o[x, y] = shine + (255,)
            else:
                v = vv[x, y] / 255.0 + (0.5 - (x + y) / (2.0 * SIZE)) * 0.12
                o[x, y] = r[max(1, min(TONES - 1, round(v * (TONES - 1))))] + (255,)
    if back:
        out = out.transpose(Image.FLIP_LEFT_RIGHT)
        drop = round(BACK_DROP * K)
        moved = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
        moved.paste(out.crop((0, 0, SIZE, SIZE - drop)), (0, drop))
        out = moved
    return out


def sprites(lines):
    """(line, name, front, back) for every kind of the lines."""
    for line in lines:
        ramps = line_ramps(line)
        for name, parts in GL.stages(line):
            yield line, name, render(parts, ramps), render(parts, ramps, back=True)


def problems(img):
    out = []
    if img.size != (SIZE, SIZE):
        return ["size %s" % (img.size,)]
    cols, soft = set(), 0
    raw = img.tobytes()
    for i in range(0, len(raw), 4):
        r, g, b, a = raw[i:i + 4]
        if a == 0:
            continue
        if a < 255:
            soft += 1
        cols.add((r, g, b))
    if soft:
        out.append("%d soft-edged pixels" % soft)
    if (0, 0, 0) in cols:
        out.append("pure black")
    if not 8 <= len(cols) <= MAX_COLOURS:
        out.append("%d colours, want 8 to %d" % (len(cols), MAX_COLOURS))
    return out


def sheet(drawn, path, title):
    w = 8 + 3 * (2 * SIZE + 8) + 8
    h = 34 + len(drawn) * (SIZE + 16)
    img = Image.new("RGBA", (w, h), (232, 236, 226, 255))
    dr = ImageDraw.Draw(img)
    dr.text((8, 8), title, fill=(36, 44, 40, 255))
    for r, (line, items) in enumerate(drawn):
        y = 30 + r * (SIZE + 16)
        for i, (name, front, back) in enumerate(items):
            x = 8 + i * (2 * SIZE + 8)
            dr.rectangle([x, y, x + 2 * SIZE - 1, y + SIZE - 1], fill=(206, 214, 200, 255))
            img.alpha_composite(front, (x, y))
            img.alpha_composite(back, (x + SIZE, y))
            dr.text((x + 2, y + SIZE + 2), "%s  %s" % (name, "/".join(e[:4] for e in line["elements"])),
                    fill=(36, 44, 40, 255))
    img.save(path)


def main(argv):
    region = argv[0]
    lines = GL.load_lines(region)
    check = "--check" in argv
    os.makedirs(DST, exist_ok=True)
    bad = n = 0
    drawn = {}
    for line, name, front, back in sprites(lines):
        drawn.setdefault(line["id"], (line, []))[1].append((name, front, back))
        for side, img in (("front", front), ("back", back)):
            path = os.path.join(DST, "%s_%s.png" % (name.lower(), side))
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
        sheet(list(drawn.values()), argv[argv.index("--sheet") + 1], "%s - %d Era V Spirlings (96 px)" % (
            region.capitalize(), sum(len(l["names"]) for l in lines)))
    print("era5 %s: %d sprites, %d problems" % (region, n, bad))
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
