#!/usr/bin/env python3
"""Scales the six legendary sprites (80x80 natives from gen_legendaere_neu18.py) to the Era I
battle size of 56x56 (EraManager.BATTLE_SPRITE_SIZE) for art/era1/spirlings/.

Each target pixel takes the most common opaque colour of the source pixels under it (darker wins a
tie, so outlines survive), so the four inks stay exact. The back view is the mirrored front
until a drawn back exists.

  python3 tools/art/legendaries_neu18.py <folder with <name>_native.png>
"""
import os
import sys

from PIL import Image, ImageOps

NAMES = ["hallowmur", "scriptorax", "lumivane", "zephyrel", "monolurk", "vorlucent"]
SIZE = 56
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "art", "era1", "spirlings")


def shrink(im: Image.Image, size: int) -> Image.Image:
    im = im.convert("RGBA")
    alpha = im.getchannel("A").resize((size, size), Image.BOX)
    out = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    src, dst = im.load(), out.load()
    f = im.width / size
    for y in range(size):
        for x in range(size):
            if alpha.getpixel((x, y)) < 128:
                continue
            count = {}
            for yy in range(int(y * f), min(int((y + 1) * f + 0.999), im.height)):
                for xx in range(int(x * f), min(int((x + 1) * f + 0.999), im.width)):
                    c = src[xx, yy]
                    if c[3] > 0:
                        count[c] = count.get(c, 0) + 1
            dst[x, y] = max(count, key=lambda c: (count[c], -sum(c[:3])))
    return out


def main() -> None:
    folder = sys.argv[1]
    for n in NAMES:
        front = shrink(Image.open(os.path.join(folder, n + "_native.png")), SIZE)
        front.save(os.path.join(OUT, n + "_front.png"))
        ImageOps.mirror(front).save(os.path.join(OUT, n + "_back.png"))
        print(n)


if __name__ == "__main__":
    main()
