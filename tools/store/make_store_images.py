"""Builds the store screenshots and the Google Play feature graphic from game screenshots.

1. Render the raw screens in both languages (needs a display):
     xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- /tmp/shots/de de
     xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- /tmp/shots/en en
2. python3 tools/store/make_store_images.py /tmp/shots

Writes (fastlane folder layout, so `fastlane supply` / `deliver` can upload them later):
  store/android/<lang>/images/phoneScreenshots/N.png   1080 x 1920 (Google Play phone)
  store/android/<lang>/images/featureGraphic.png       1024 x 500
  store/android/<lang>/images/icon.png                 512 x 512
  store/ios/screenshots/<lang>/N_iphone69.png          1320 x 2868 (App Store 6.9", required size)
Only own game art is used, so the images follow docs/IP_HYGIENE.md.
"""
from __future__ import annotations

import os
import sys

from PIL import Image, ImageDraw, ImageFont

INK = [(0x2A, 0x1E, 0x2C), (0x6A, 0x42, 0x56), (0xC4, 0x8A, 0x5E), (0xF2, 0xE3, 0xC2)]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"

SHOTS = ["01_title", "02_ow_brindlewick", "03_battle", "04_bond", "05_battle_boss", "02_ow_crowcrest"]
CAPTIONS = {
    "de": [
        "Ein Retro-Pixel-Abenteuer",
        "Beginne in Brindlewick mit deinem Partner",
        "Taktische Rundenkämpfe mit acht Elementen",
        "Gewinne Spirlings mit dem Echo-Ruf",
        "Versiegle die Risse und ihre Wächter",
        "Erkunde Klippen, Marschen und Höhlen",
    ],
    "en": [
        "A retro pixel adventure",
        "Start in Brindlewick with your partner",
        "Tactical turn-based battles, eight elements",
        "Win Spirlings over with the echo call",
        "Seal the Rifts and face their Wardens",
        "Explore cliffs, marshes and caves",
    ],
}
FEATURE = {"de": "Verbünde dich. Versiegle die Risse.", "en": "Bond. Explore. Seal the Rifts."}
LANG_DIR = {"de": "de-DE", "en": "en-US"}


def native(path: str) -> Image.Image:
    """tools/screenshot.gd saves at 3x; go back to the 144 x 256 game pixels."""
    img = Image.open(path).convert("RGB")
    return img.resize((img.width // 3, img.height // 3), Image.NEAREST)


def pixel_text(text: str, max_w: int, scale: int) -> Image.Image:
    """Text drawn without anti-aliasing at a small size, then scaled up, so it looks like pixels."""
    size = 12
    font = ImageFont.truetype(FONT, size)
    words, lines, cur = text.split(), [], ""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    for w in words:
        test = (cur + " " + w).strip()
        if probe.textlength(test, font=font) * scale > max_w and cur:
            lines.append(cur)
            cur = w
        else:
            cur = test
    lines.append(cur)
    lh = size + 4
    w = int(max(probe.textlength(l, font=font) for l in lines)) + 2
    img = Image.new("RGBA", (w, lh * len(lines)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    for i, l in enumerate(lines):
        lw = probe.textlength(l, font=font)
        d.text(((w - lw) // 2 + 1, i * lh + 1), l, font=font, fill=INK[0] + (255,))
        d.text(((w - lw) // 2, i * lh), l, font=font, fill=INK[3] + (255,))
    return img.resize((img.width * scale, img.height * scale), Image.NEAREST)


def backdrop(w: int, h: int, px: int) -> Image.Image:
    """Dark ink sky with a dithered band, drawn in big pixels."""
    sw, sh = w // px + 1, h // px + 1
    small = Image.new("RGB", (sw, sh), INK[0])
    p = small.load()
    for y in range(sh):
        for x in range(sw):
            if y > sh * 0.55 and (x + y) % 2 == 0:
                p[x, y] = INK[1]
    for i in range(40):
        x, y = (i * 37) % sw, (i * 53) % max(1, int(sh * 0.5))
        p[x, y] = INK[2] if i % 3 else INK[3]
    return small.resize((sw * px, sh * px), Image.NEAREST).crop((0, 0, w, h))


def frame(w: int, h: int, game: Image.Image, scale: int, caption: str, text_scale: int, top: int) -> Image.Image:
    out = backdrop(w, h, text_scale)
    g = game.resize((game.width * scale, game.height * scale), Image.NEAREST)
    gx, gy = (w - g.width) // 2, top
    border = text_scale
    d = ImageDraw.Draw(out)
    d.rectangle((gx - 2 * border, gy - 2 * border, gx + g.width + 2 * border - 1, gy + g.height + 2 * border - 1), fill=INK[3])
    d.rectangle((gx - border, gy - border, gx + g.width + border - 1, gy + g.height + border - 1), fill=INK[1])
    out.paste(g, (gx, gy))
    t = pixel_text(caption, w - 8 * text_scale, text_scale)
    ty = max(text_scale * 2, (gy - 2 * border - t.height) // 2)
    out.paste(t, ((w - t.width) // 2, ty), t)
    return out


def feature_graphic(lang: str, title_shot: Image.Image) -> Image.Image:
    w, h = 1024, 500
    out = backdrop(w, h, 4)
    # Title art (top part of the title screen) on the right, slogan on the left.
    art = title_shot.crop((0, 0, 144, 140)).resize((144 * 3, 140 * 3), Image.NEAREST)
    ax, ay = w - art.width - 48, (h - art.height) // 2
    d = ImageDraw.Draw(out)
    d.rectangle((ax - 6, ay - 6, ax + art.width + 5, ay + art.height + 5), fill=INK[3])
    d.rectangle((ax - 3, ay - 3, ax + art.width + 2, ay + art.height + 2), fill=INK[1])
    out.paste(art, (ax, ay))
    box = ax - 96
    t = pixel_text(FEATURE[lang], box, 4)
    out.paste(t, (48 + (box - 48 - t.width) // 2, (h - t.height) // 2), t)
    return out


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shots"
    icon = Image.open("art/icon/icon_512.png")
    for lang, folder in LANG_DIR.items():
        shots = [native(os.path.join(src, lang, s + ".png")) for s in SHOTS]
        a_dir = f"store/android/{folder}/images/phoneScreenshots"
        i_dir = f"store/ios/screenshots/{folder}"
        os.makedirs(a_dir, exist_ok=True)
        os.makedirs(i_dir, exist_ok=True)
        for n, (shot, cap) in enumerate(zip(shots, CAPTIONS[lang]), 1):
            # Play: 1080 x 1920, game at 6x (864 x 1536).
            frame(1080, 1920, shot, 6, cap, 6, 300).save(f"{a_dir}/{n}.png", optimize=True)
            # App Store 6.9": 1320 x 2868, game at 8x (1152 x 2048).
            frame(1320, 2868, shot, 8, cap, 8, 600).save(f"{i_dir}/{n}_iphone69.png", optimize=True)
        img_dir = f"store/android/{folder}/images"
        feature_graphic(lang, shots[0]).save(f"{img_dir}/featureGraphic.png", optimize=True)
        icon.save(f"{img_dir}/icon.png")
        print("store images written for", folder)


if __name__ == "__main__":
    main()
