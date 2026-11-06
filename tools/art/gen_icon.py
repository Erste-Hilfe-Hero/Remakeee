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
    main()
