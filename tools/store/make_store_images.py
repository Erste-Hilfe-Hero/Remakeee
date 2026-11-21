"""Builds the store screenshots and the Google Play feature graphic from game screenshots
(plan Chimora 100, items 86, 87, 97). Every picture is a screen of the running game or Spirling art as
the game draws it; nothing shows a feature the game does not have.

1. Render the raw screens in all 14 languages (needs a display):
     for l in en de fr es it ja ko zh_CN zh_TW pt_BR ru pl tr nl; do
       xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/store_shots.gd -- /tmp/shots/$l $l
     done
2. python3 tools/store/make_store_images.py /tmp/shots [--out DIR] [locale or game language ...]
   (needs Pillow and fonttools)

The set, the same in every locale (store/ios/screenshot_captions/<locale>.txt, one caption per line):
  1 monster hero (Era IV Spirlings, one Gleam with its glints)   2 3v3 battle in Era V (whole screen:
                                                                  the text box height differs per language)
  3 unfurl before and after                                       4 one town in Eras I to IV, 2 x 2
  5 story line (Wren, Act I)                                      6 live duel with a friend
  7 Spirlog page                                                  8 shop: Looks list, Riftglass prices only
No money prices and no Discord note in any picture.

Writes (fastlane folder layout), under --out (default: the repo):
  store/ios/screenshots/<locale>/N_iphone69.png          1320 x 2868 (App Store 6.9", all 20 locales)
  store/ios/screenshots_ipad13/<locale>/N_ipad13.png     2064 x 2752 (App Store 13" iPad; the app is
                                                         iPhone-only today, so these are kept apart and
                                                         not uploaded until iPad is switched on)
  store/android/<lang>/images/phoneScreenshots/N.png     1080 x 2160 (Google Play phone, 14 languages)
  store/android/<lang>/images/featureGraphic.png         1024 x 500
  store/android/<lang>/images/icon.png                   512 x 512
Only own game art is used, so the images follow docs/IP_HYGIENE.md.
"""
from __future__ import annotations

import argparse
import math
import os

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
INK = [(0x2A, 0x1E, 0x2C), (0x6A, 0x42, 0x56), (0xC4, 0x8A, 0x5E), (0xF2, 0xE3, 0xC2)]
FONT = "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf"
CAPTIONS = "store/ios/screenshot_captions"
SHOT_COUNT = 8

FEATURE = {
    "de": "Verbünde dich. Versiegle die Risse.",
    "en": "Bond. Explore. Seal the Rifts.",
    "fr": "Lie-toi. Explore. Scelle les Failles.",
    "es": "Únete. Explora. Sella las Grietas.",
    "it": "Lègati. Esplora. Sigilla le Fratture.",
    "ja": "絆を結び、旅をし、裂け目を封じよ。",
    "ko": "유대를 맺고, 탐험하고, 균열을 봉인하라.",
    "zh_CN": "结伴，探索，封印裂隙。",
    "zh_TW": "結伴，探索，封印裂隙。",
    "pt_BR": "Crie laços. Explore. Sele as Fendas.",
    "ru": "Дружи. Исследуй. Запечатай Разломы.",
    "pl": "Zaprzyjaźnij się. Odkrywaj. Zapieczętuj Szczeliny.",
    "tr": "Bağ kur. Keşfet. Yarıkları mühürle.",
    "nl": "Verbind. Verken. Verzegel de Scheuren.",
}
# App Store locale -> game language of its screens (the store text of pt-PT says the game is pt-BR).
APP_LOCALES = {
    "en-US": "en", "en-GB": "en", "en-AU": "en", "en-CA": "en", "de-DE": "de", "fr-FR": "fr", "fr-CA": "fr",
    "es-ES": "es", "es-MX": "es", "pt-BR": "pt_BR", "pt-PT": "pt_BR", "it": "it", "nl-NL": "nl", "pl": "pl",
    "tr": "tr", "ru": "ru", "ja": "ja", "ko": "ko", "zh-Hans": "zh_CN", "zh-Hant": "zh_TW",
}
# Game language -> (Play folder, App Store locale whose captions it uses), as tools/release_check.py TEXT_LANGS.
PLAY = {
    "de": ("de-DE", "de-DE"), "en": ("en-US", "en-US"), "fr": ("fr-FR", "fr-FR"), "es": ("es-ES", "es-ES"),
    "it": ("it-IT", "it"), "ja": ("ja-JP", "ja"), "ko": ("ko-KR", "ko"), "zh_CN": ("zh-CN", "zh-Hans"),
    "zh_TW": ("zh-TW", "zh-Hant"), "pt_BR": ("pt-BR", "pt-BR"), "ru": ("ru-RU", "ru"), "pl": ("pl-PL", "pl"),
    "tr": ("tr-TR", "tr"), "nl": ("nl-NL", "nl-NL"),
}
# (name, width, height, caption pixel size, file pattern)
IPHONE = ("iphone69", 1320, 2868, 7)
IPAD = ("ipad13", 2064, 2752, 10)
PHONE_PLAY = ("play", 1080, 2160, 6)

# Hero picture: [file, x, y (share of the art area, feet), width (share of the canvas width)].
HERO = [
    ["hero_glintheron", 0.27, 0.30, 0.42], ["hero_gildaurus", 0.76, 0.27, 0.40],
    ["hero_noonregent", 0.52, 0.64, 0.66],
    ["hero_eaveprowl", 0.22, 0.80, 0.40], ["hero_lumothane", 0.80, 0.78, 0.38],
    ["hero_dewstag", 0.30, 0.99, 0.38], ["hero_orremarch_gleam", 0.75, 1.00, 0.36],
]
GLEAM = "hero_orremarch_gleam"
# Unfurl: the square around the sprite in the middle of the screen.
UNFURL_BOX = (45, 150, 225, 330)
ERAS = ["o1_era1_brindlewick", "o2_era2_brindlewick", "o3_era3_brindlewick", "o4_era4_brindlewick"]
ERA_NAMES = ["I", "II", "III", "IV"]

# CJK captions: the game's own pixel fonts (art/fonts, OFL) for CJK glyphs, DejaVu for the rest.
CJK = {"ja", "ko", "zh_CN", "zh_TW"}
NO_LINE_START = set("ー、。，．！？）」』・ゃゅょっァィゥェォャュョッ：")


def load(src: str, lang: str, name: str) -> Image.Image:
    """A raw screen back at game pixels (the tool saves some at 2x or 3x). Sprites stay as they are."""
    img = Image.open(os.path.join(src, lang, name + ".png"))
    if name.startswith("hero_") or name == "glint":
        return img.convert("RGBA")
    native = 144 if name.startswith(("o1", "o2", "t01")) else 180 if name.startswith("o3") else 270
    div = max(1, img.width // native)
    return img.convert("RGB").resize((img.width // div, img.height // div), Image.NEAREST)


def scaled(img: Image.Image, w: int, h: int) -> Image.Image:
    """Pixel art at any size: whole-number upscale first, then one smooth step, so every game
    pixel keeps the same size."""
    k = max(1, math.ceil(max(w / img.width, h / img.height)))
    big = img.resize((img.width * k, img.height * k), Image.NEAREST)
    return big if big.size == (w, h) else big.resize((w, h), Image.LANCZOS)


def fit(img: Image.Image, w: int, h: int) -> Image.Image:
    s = min(w / img.width, h / img.height)
    return scaled(img, max(1, round(img.width * s)), max(1, round(img.height * s)))


def cover(img: Image.Image, w: int, h: int) -> Image.Image:
    s = max(w / img.width, h / img.height)
    cw, ch = w / s, h / s
    x0, y0 = (img.width - cw) / 2, (img.height - ch) / 2
    return scaled(img.crop((round(x0), round(y0), round(x0 + cw), round(y0 + ch))), w, h)


def _fonts(lang: str):
    if lang in CJK:
        return ImageFont.truetype(FONT, 16), ImageFont.truetype(os.path.join(ROOT, f"art/fonts/chimora_cjk_10px_{lang}.otf"), 16), 16
    return ImageFont.truetype(FONT, 12), None, 12


_CMAPS: dict[str, set[int]] = {}


def _cmap(font) -> set[int]:
    if font.path not in _CMAPS:
        from fontTools.ttLib import TTFont
        _CMAPS[font.path] = set(TTFont(font.path).getBestCmap())
    return _CMAPS[font.path]


def _runs(text: str, latin, cjk) -> list[tuple[str, object]]:
    if cjk is None:
        return [(text, latin)]
    cmap = _cmap(cjk)
    runs: list[tuple[str, object]] = []
    for ch in text:
        f = cjk if ord(ch) > 0x2000 and ord(ch) in cmap else latin
        if runs and runs[-1][1] is f:
            runs[-1] = (runs[-1][0] + ch, f)
        else:
            runs.append((ch, f))
    return runs


def _width(probe, text: str, latin, cjk) -> float:
    return sum(probe.textlength(t, font=f) for t, f in _runs(text, latin, cjk))


def _balanced(words: list[str], joiner: str, n: int, max_w: float, width, by_char: bool) -> list[str] | None:
    """The same words in [param n] lines of the most even width (a full line and a stray word
    read badly), or None when no such split fits."""
    k = len(words)
    best: dict[tuple[int, int], tuple[float, list[str]] | None] = {}

    def go(i: int, left: int):
        if (i, left) in best:
            return best[(i, left)]
        res = None
        if left == 1:
            t = joiner.join(words[i:])
            w = width(t)
            res = (w, [t]) if w <= max_w else None
        else:
            for j in range(i + 1, k - left + 2):
                if by_char and j < k and words[j] in NO_LINE_START:
                    continue
                t = joiner.join(words[i:j])
                w = width(t)
                if w > max_w:
                    break
                rest = go(j, left - 1)
                if rest is not None and (res is None or max(w, rest[0]) < res[0]):
                    res = (max(w, rest[0]), [t] + rest[1])
        best[(i, left)] = res
        return res

    r = go(0, n) if k >= n else None
    return r[1] if r else None


def pixel_text(text: str, max_w: int, scale: int, lang: str = "en") -> Image.Image:
    """Text drawn without anti-aliasing at a small size, then scaled up, so it looks like pixels.
    CJK text is drawn at 16 px (the pixel font doubled) and scaled by 2/3 of the Latin scale."""
    latin, cjk, size = _fonts(lang)
    if cjk is not None:
        scale = max(3, scale * 2 // 3)
    by_char = cjk is not None and lang != "ko"
    words = list(text) if by_char else text.split()
    joiner = "" if by_char else " "
    lines, cur = [], ""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    for w in words:
        test = cur + joiner + w if cur else w
        if _width(probe, test, latin, cjk) * scale > max_w and cur:
            if by_char and w in NO_LINE_START and len(cur) > 1:
                lines.append(cur[:-1])
                cur = cur[-1] + w
            else:
                lines.append(cur)
                cur = w
        else:
            cur = test
    lines.append(cur)
    if len(lines) > 1:
        lines = _balanced(words, joiner, len(lines), max_w / scale, lambda t: _width(probe, t, latin, cjk), by_char) or lines
    lh = size + 4
    w = int(max(_width(probe, l, latin, cjk) for l in lines)) + 2
    img = Image.new("RGBA", (w, lh * len(lines)), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    for i, l in enumerate(lines):
        x = (w - _width(probe, l, latin, cjk)) // 2
        for t, f in _runs(l, latin, cjk):
            d.text((x + 1, i * lh + 1), t, font=f, fill=INK[0] + (255,))
            d.text((x, i * lh), t, font=f, fill=INK[3] + (255,))
            x += probe.textlength(t, font=f)
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


def framed(out: Image.Image, img: Image.Image, x: int, y: int, px: int) -> None:
    """Pastes [img] with the two-ink pixel border of the store set."""
    d = ImageDraw.Draw(out)
    b = max(2, px // 2)
    d.rectangle((x - 2 * b, y - 2 * b, x + img.width + 2 * b - 1, y + img.height + 2 * b - 1), fill=INK[3])
    d.rectangle((x - b, y - b, x + img.width + b - 1, y + img.height + b - 1), fill=INK[1])
    out.paste(img, (x, y))


def shadow(out: Image.Image, cx: int, cy: int, w: int, px: int) -> None:
    """A dithered ellipse under a Spirling's feet, in big pixels."""
    d = ImageDraw.Draw(out)
    h = max(px, w // 8)
    for yy in range(-h // 2, h // 2, px):
        half = int(w / 2 * math.sqrt(max(0.0, 1 - (2 * yy / h) ** 2)))
        for xx in range(-half, half, px):
            if ((xx + yy) // px) % 2 == 0:
                d.rectangle((cx + xx, cy + yy, cx + xx + px - 1, cy + yy + px - 1), fill=INK[1])


def hero(src: str, lang: str, w: int, h: int, px: int) -> Image.Image:
    out = backdrop(w, h, px)
    # Laid out on a portrait strip, so the group keeps its shape on the wide iPad canvas.
    bw = min(w, int(h * 0.58))
    # The glint shape of the Gleam entrance (ElementFx "glint"), in the light ink so it shows on the night sky.
    glint = load(src, lang, "glint")
    glint = Image.composite(Image.new("RGBA", glint.size, INK[3] + (255,)), Image.new("RGBA", glint.size, (0, 0, 0, 0)), glint.getchannel("A"))
    for name, fx, fy, fw in HERO:
        spr = load(src, lang, name)
        bbox = spr.getbbox() or (0, 0, spr.width, spr.height)
        spr = spr.crop(bbox)
        k = max(1, round(bw * fw / 96))
        big = spr.resize((spr.width * k, spr.height * k), Image.NEAREST)
        cx, feet = int((w - bw) / 2 + bw * fx), int(h * 0.06 + (h * 0.86) * fy)
        x, y = cx - big.width // 2, feet - big.height
        shadow(out, cx, feet, int(big.width * 0.8), k)
        out.paste(big, (x, y), big)
        if name == GLEAM:
            gk = max(1, round(bw * 0.05 / glint.width))
            g = glint.resize((glint.width * gk, glint.height * gk), Image.NEAREST)
            for gx, gy in [(-0.05, 0.05), (0.92, 0.15), (0.15, -0.12), (0.8, 0.75), (0.45, -0.2)]:
                out.paste(g, (x + int(big.width * gx) - g.width // 2, y + int(big.height * gy) - g.height // 2), g)
    return out


def unfurl(src: str, lang: str, w: int, h: int, px: int) -> Image.Image:
    out = backdrop(w, h, px)
    a, b = (load(src, lang, n).crop(UNFURL_BOX) for n in ("u1_before", "u3_after"))
    gap = 40
    nat_h = a.height + b.height + gap
    s = min((w * 0.86) / a.width, h / nat_h)
    pa, pb = scaled(a, round(a.width * s), round(a.height * s)), scaled(b, round(b.width * s), round(b.height * s))
    y = int((h - nat_h * s) / 2)
    framed(out, pa, (w - pa.width) // 2, y, px)
    yb = y + pa.height + int(gap * s)
    framed(out, pb, (w - pb.width) // 2, yb, px)
    # A pixel arrow from the old form down to the new one.
    d = ImageDraw.Draw(out)
    cx, top, bot = w // 2, y + pa.height + 3 * px, yb - 3 * px
    aw = max(px, int(4 * s))
    d.rectangle((cx - aw, top, cx + aw, bot - 3 * aw), fill=INK[3])
    d.polygon([(cx - 4 * aw, bot - 4 * aw), (cx + 4 * aw, bot - 4 * aw), (cx, bot)], fill=INK[3])
    return out


def eras(src: str, lang: str, w: int, h: int, px: int) -> Image.Image:
    out = backdrop(w, h, px)
    gap = 3 * px
    cw, ch = (w - 3 * gap) // 2, (h - 3 * gap) // 2
    for i, name in enumerate(ERAS):
        img = load(src, lang, name)
        # Below the quest banner: the town is the subject.
        img = img.crop((0, int(img.height * 0.08), img.width, img.height))
        cell = cover(img, cw, ch)
        x, y = gap + (i % 2) * (cw + gap), gap + (i // 2) * (ch + gap)
        framed(out, cell, x, y, px)
        tag = pixel_text(ERA_NAMES[i], cw, px, "en")
        d = ImageDraw.Draw(out)
        d.rectangle((x, y, x + tag.width + 4 * px - 1, y + tag.height + 2 * px - 1), fill=INK[0])
        out.paste(tag, (x + 2 * px, y + px), tag)
    return out


def screen(name: str):
    def make(src: str, lang: str, w: int, h: int, px: int) -> Image.Image:
        out = backdrop(w, h, px)
        img = fit(load(src, lang, name), w - 4 * px, h)
        framed(out, img, (w - img.width) // 2, (h - img.height) // 2, px)
        return out
    return make


SHOTS = [hero, screen("b1_era5_3v3"), unfurl, eras, screen("s1_story"), screen("l1_duel"), screen("m1_spirlog"), screen("m2_shop_looks")]


def picture(n: int, src: str, lang: str, size: tuple, caption: str, cap_lang: str) -> Image.Image:
    _, w, h, px = size
    out = backdrop(w, h, px)
    t = pixel_text(caption, w - 10 * px, px, cap_lang)
    band = max(int(h * 0.15), t.height + 8 * px)
    art = SHOTS[n](src, lang, w, h - band - 2 * px, px)
    out.paste(art, (0, band))
    out.paste(t, ((w - t.width) // 2, (band - t.height) // 2), t)
    return out


def captions(locale: str) -> list[str]:
    with open(os.path.join(ROOT, CAPTIONS, locale + ".txt"), encoding="utf-8") as f:
        lines = [l.strip() for l in f.read().strip().split("\n")]
    if len(lines) != SHOT_COUNT:
        raise SystemExit(f"{CAPTIONS}/{locale}.txt needs {SHOT_COUNT} lines, has {len(lines)}")
    return lines


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
    t = pixel_text(FEATURE[lang], box, 4, lang)
    out.paste(t, (48 + (box - 48 - t.width) // 2, (h - t.height) // 2), t)
    return out


def save(img: Image.Image, path: str) -> None:
    os.makedirs(os.path.dirname(path), exist_ok=True)
    # Few colours: a palette PNG is a fraction of the size and looks the same.
    q = img.convert("RGB").quantize(colors=256, method=Image.Quantize.MEDIANCUT, dither=Image.Dither.NONE)
    q.save(path, optimize=True)


def main() -> None:
    ap = argparse.ArgumentParser()
    ap.add_argument("src", nargs="?", default="/tmp/shots")
    ap.add_argument("only", nargs="*", help="App Store locales or game languages")
    ap.add_argument("--out", default=ROOT)
    ap.add_argument("--no-ipad", action="store_true")
    a = ap.parse_args()
    for loc, lang in APP_LOCALES.items():
        if a.only and loc not in a.only and lang not in a.only:
            continue
        caps = captions(loc)
        for n, cap in enumerate(caps):
            save(picture(n, a.src, lang, IPHONE, cap, lang), f"{a.out}/store/ios/screenshots/{loc}/{n + 1}_iphone69.png")
            if not a.no_ipad:
                save(picture(n, a.src, lang, IPAD, cap, lang), f"{a.out}/store/ios/screenshots_ipad13/{loc}/{n + 1}_ipad13.png")
        print("App Store pictures written for", loc)
    icon = Image.open(os.path.join(ROOT, "art/icon/icon_512.png"))
    for lang, (play, loc) in PLAY.items():
        if a.only and play not in a.only and lang not in a.only and loc not in a.only:
            continue
        for n, cap in enumerate(captions(loc)):
            save(picture(n, a.src, lang, PHONE_PLAY, cap, lang), f"{a.out}/store/android/{play}/images/phoneScreenshots/{n + 1}.png")
        img_dir = f"{a.out}/store/android/{play}/images"
        save(feature_graphic(lang, load(a.src, lang, "t01_title")), f"{img_dir}/featureGraphic.png")
        icon.save(f"{img_dir}/icon.png")
        print("Play pictures written for", play)


if __name__ == "__main__":
    main()
