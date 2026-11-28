"""App icon for the stores and the home screen (Era I "Ink" palette).

Draws a 64 x 64 pixel scene (night sky, rising Rift moon, the starter Kindlop on a hill) and
scales it up with nearest neighbour, so the icon stays crisp pixel art at every size.

Writes into art/icon/:
  icon_1024.png               iOS / App Store (no transparency, no rounded corners: Apple masks it)
  icon_512.png                Google Play listing icon
  icon_192.png                Android legacy launcher icon
  adaptive_fg_432.png         Android adaptive icon, foreground (Spirling, transparent)
  adaptive_bg_432.png         Android adaptive icon, background (sky, moon, hill)
  adaptive_mono_432.png       Android 13+ themed icon (one colour, transparent)
Run from the repo root: python3 tools/art/gen_icon.py

  python3 tools/art/gen_icon.py --variant   only the icon variant "face" (plan Chimora 100, item 88):
      a 32 x 32 front face of a crystal-eared Spirling (own drawing, made here) on the night sky
      with the Rift moon ring, dark tone and strong contrast for the 60 px search size. Writes
      store/icon_variants/face_1024.png, face_512.png, face_192.png and a side-by-side preview with the
      current icon at 60, 120 and 1024 px to production/qa/evidence/c100-storeart/. The app icon
      itself stays the default; the variant is for a Product Page Optimization test, which needs it
      in the binary as an alternate icon first.
"""
from __future__ import annotations

import math
import os

from PIL import Image

import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from px import PALETTE  # noqa: E402

OUT = "art/icon"
N = 64
SPRITE = "art/era1/spirlings/kindlop_front.png"


def background() -> Image.Image:
    img = Image.new("RGB", (N, N), PALETTE[0])
    p = img.load()
    # Soft dithered glow in the lower sky.
    for y in range(N):
        for x in range(N):
            if y > 30 and (x + y) % 2 == 0 and y > 46 - (x % 3):
                p[x, y] = PALETTE[1]
    # Rift moon: ring of light with a dark crack.
    cx, cy, r = 32, 26, 19
    for y in range(N):
        for x in range(N):
            d = math.hypot(x + 0.5 - cx, y + 0.5 - cy)
            if d <= r:
                p[x, y] = PALETTE[2] if d > r - 3 else PALETTE[1]
                if d <= r - 6 and (x + y) % 2 == 0:
                    p[x, y] = PALETTE[2]
    for i, (x, y) in enumerate([(30, 9), (31, 13), (33, 17), (32, 21), (34, 25), (33, 29), (35, 33)]):
        p[x, y] = PALETTE[3]
        p[x + 1, y] = PALETTE[3]
        if i % 2:
            p[x, y + 1] = PALETTE[3]
    # Stars.
    for x, y in [(6, 7), (12, 18), (55, 9), (50, 20), (8, 30), (58, 33), (20, 5)]:
        p[x, y] = PALETTE[3]
    # Hill.
    for x in range(N):
        top = 50 + int(3 * math.cos((x - 32) / 12.0))
        for y in range(top, N):
            p[x, y] = PALETTE[3] if y == top else PALETTE[2]
    return img


def foreground(size: int) -> Image.Image:
    """Kindlop centred, with a 1 px dark outline so it reads on the sky."""
    spr = Image.open(SPRITE).convert("RGBA")
    spr = spr.crop(spr.getbbox())
    layer = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    x0 = (size - spr.width) // 2
    y0 = size - spr.height - (size // 8)
    a = spr.split()[3]
    outline = Image.new("RGBA", spr.size, PALETTE[0] + (255,))
    for dx, dy in [(-1, 0), (1, 0), (0, -1), (0, 1)]:
        layer.paste(outline, (x0 + dx, y0 + dy), a)
    layer.paste(spr, (x0, y0), spr)
    return layer


# Face variant: own palette, dark sky and warm fur so the face reads at 60 px.
FACE = {
    ".": (0x16, 0x0F, 0x1A), ",": (0x2A, 0x1E, 0x2C), "r": (0x6A, 0x42, 0x56), "R": (0xC4, 0x8A, 0x5E),
    "s": (0xF2, 0xE3, 0xC2), "o": (0x12, 0x0A, 0x10), "f": (0xE8, 0x7A, 0x2E), "F": (0xFF, 0xB0, 0x5A),
    "d": (0xA8, 0x46, 0x1E), "c": (0xF6, 0xE6, 0xC8), "b": (0x4C, 0x9C, 0xE8), "B": (0xC8, 0xEC, 0xFF),
    "n": (0x2A, 0x58, 0xA8), "e": (0xFF, 0xE0, 0x4A), "p": (0x12, 0x0A, 0x10), "w": (0xFF, 0xFF, 0xFF),
}
FN = 32


def face_variant() -> Image.Image:
    """32 x 32 face icon, drawn cell by cell from simple shapes, mirrored down the middle."""
    g = [["." for _ in range(FN)] for _ in range(FN)]

    def put(x: int, y: int, c: str, mirror: bool = True) -> None:
        if 0 <= x < FN and 0 <= y < FN:
            g[y][x] = c
            if mirror:
                g[y][FN - 1 - x] = c

    # Night sky: two inks, a dithered lower glow and a few stars.
    for y in range(FN):
        for x in range(FN):
            g[y][x] = "," if y > 4 and (x + y) % 2 == 0 and y > 22 else "."
    # Rift moon ring behind the head.
    for y in range(FN):
        for x in range(FN):
            d = math.hypot(x + 0.5 - 16, y + 0.5 - 15)
            if 13.2 <= d <= 15.2:
                g[y][x] = "R"
            elif 12.2 <= d < 13.2:
                g[y][x] = "r"
    for x, y in [(2, 3), (29, 5), (4, 27), (27, 28), (1, 14)]:
        g[y][x] = "s"
    # Head: wide ellipse, darker lower half, cheek tufts.
    for y in range(FN):
        for x in range(FN // 2):
            dx, dy = (x + 0.5 - 16) / 10.5, (y + 0.5 - 19) / 8.6
            if dx * dx + dy * dy <= 1.0:
                put(x, y, "d" if y >= 22 else "f")
    for y, x0 in [(19, 4), (20, 4), (21, 3), (22, 4), (23, 5)]:
        for x in range(x0, 7):
            put(x, y, "d" if y >= 22 else "f")
    # Crystal ears: tips out to the sides, bases on the head.
    for y in range(1, 13):
        t = (y - 1) / 11
        left, right = round(5 + t * 2), round(5 + t * 9)
        for x in range(left, right + 1):
            put(x, y, "b")
        put(left, y, "B")
        if right - left > 2:
            put(left + 1, y, "B")
            put(right, y, "n")
    # Highlight on the brow.
    for x, y in [(9, 13), (10, 12), (11, 12), (12, 12), (13, 12)]:
        put(x, y, "F")
    # Rift mark on the forehead.
    for x, y, c in [(15, 12, "B"), (15, 13, "b"), (14, 13, "b"), (15, 14, "n")]:
        put(x, y, c)
    # Muzzle.
    for y in range(FN):
        for x in range(FN // 2):
            dx, dy = (x + 0.5 - 16) / 5.2, (y + 0.5 - 23.5) / 3.8
            if dx * dx + dy * dy <= 1.0:
                put(x, y, "c")
    # Eyes: glowing, slit pupils, heavy brows for a stern look.
    for x in range(9, 13):
        for y in range(16, 19):
            put(x, y, "e")
    put(9, 16, "w")
    for y in range(16, 19):
        put(11, y, "p")
    for x, y in [(8, 14), (9, 14), (10, 15), (11, 15), (12, 15), (13, 16)]:
        put(x, y, "o")
    # Nose, mouth and fangs.
    for x, y in [(15, 21), (14, 21), (15, 22)]:
        put(x, y, "o")
    for x, y in [(15, 24), (14, 25), (13, 25)]:
        put(x, y, "o")
    put(13, 26, "w")
    # Outline: every head cell next to sky gets the dark line.
    body = set("fFdcbBnepwo")
    out = [row[:] for row in g]
    for y in range(FN):
        for x in range(FN):
            if g[y][x] not in body:
                if any(0 <= x + dx < FN and 0 <= y + dy < FN and g[y + dy][x + dx] in body
                       for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                    out[y][x] = "o"
    img = Image.new("RGB", (FN, FN))
    img.putdata([FACE[c] for row in out for c in row])
    return img


def write_variant() -> None:
    d = "store/icon_variants"
    os.makedirs(d, exist_ok=True)
    face = face_variant()
    big = face.resize((1024, 1024), Image.NEAREST)
    big.save(f"{d}/face_1024.png")
    big.resize((512, 512), Image.NEAREST).save(f"{d}/face_512.png")
    big.resize((192, 192), Image.LANCZOS).save(f"{d}/face_192.png")
    # Side by side with the current icon at 60, 120 and 1024 px (stores scale down smoothly).
    cur = Image.open(f"{OUT}/icon_1024.png").convert("RGB")
    sizes, pad = [60, 120, 1024], 24
    w = sum(sizes) * 1 + pad * (len(sizes) + 1)
    sheet = Image.new("RGB", (w, 2 * 1024 + 3 * pad), (0xF4, 0xF4, 0xF4))
    for row, icon in enumerate([cur, big]):
        x = pad
        for s in sizes:
            sheet.paste(icon.resize((s, s), Image.LANCZOS), (x, pad + row * (1024 + pad)))
            x += s + pad
    ev = "production/qa/evidence/c100-storeart"
    os.makedirs(ev, exist_ok=True)
    sheet.save(f"{ev}/icon_variant_face_preview.png", optimize=True)
    print("icon variant written to", d, "and", ev)


def up(img: Image.Image, size: int) -> Image.Image:
    return img.resize((size, size), Image.NEAREST)


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    bg = background()
    fg = foreground(N)
    # Full icon: sky at 16x, Kindlop at 10x so the Rift moon still shows around it.
    full = up(bg, 1024).convert("RGBA")
    spr = fg.crop(fg.getbbox())
    spr = spr.resize((spr.width * 10, spr.height * 10), Image.NEAREST)
    full.alpha_composite(spr, ((1024 - spr.width) // 2, 50 * 16 + 48 - spr.height))
    full = full.convert("RGB")
    full.save(f"{OUT}/icon_1024.png")
    full.resize((512, 512), Image.NEAREST).save(f"{OUT}/icon_512.png")
    full.resize((192, 192), Image.LANCZOS).save(f"{OUT}/icon_192.png")
    # Adaptive icons: 432 px layers, launchers crop to the inner 66 % (safe zone = 288 px).
    # The 64 px art is drawn into the safe zone (64 * 4.5 = 288) and centred.
    def adaptive(layer: Image.Image, mode: str) -> Image.Image:
        canvas = Image.new(mode, (432, 432), PALETTE[0] if mode == "RGB" else (0, 0, 0, 0))
        canvas.paste(layer.resize((288, 288), Image.NEAREST), (72, 72))
        return canvas
    bg_big = up(bg, 432)  # background fills the whole layer (it is cropped anyway)
    bg_big.save(f"{OUT}/adaptive_bg_432.png")
    adaptive(fg, "RGBA").save(f"{OUT}/adaptive_fg_432.png")
    mono = Image.new("RGBA", fg.size, (0, 0, 0, 0))
    mono.paste(Image.new("RGBA", fg.size, (255, 255, 255, 255)), (0, 0), fg.split()[3])
    adaptive(mono, "RGBA").save(f"{OUT}/adaptive_mono_432.png")
    print("icons written to", OUT)


if __name__ == "__main__":
    if "--variant" in sys.argv[1:]:
        write_variant()
    else:
        main()
