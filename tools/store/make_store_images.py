"""Builds the store screenshots and the Google Play feature graphic from game screenshots.

1. Render the raw screens in all 14 languages (needs a display):
     for l in en de fr es it ja ko zh_CN zh_TW pt_BR ru pl tr nl; do
       xvfb-run -a godot --path . --rendering-driver opengl3 -s res://tools/screenshot.gd -- /tmp/shots/$l $l
     done
2. python3 tools/store/make_store_images.py /tmp/shots [lang ...]   (needs Pillow and fonttools)

Writes (fastlane folder layout, so `fastlane supply` / `deliver` can upload them later):
  store/android/<lang>/images/phoneScreenshots/N.png   1080 x 1920 (Google Play phone)
  store/android/<lang>/images/featureGraphic.png       1024 x 500
  store/android/<lang>/images/icon.png                 512 x 512
  store/ios/screenshots/<lang>/N_iphone69.png          1320 x 2868 (App Store 6.9", required size)
  store/ios/iap_review.png                             720 x 1280 (App Review picture of the shop, in-app purchases)
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
    "fr": [
        "Une aventure rétro en pixel art",
        "Pars de Brindlewick avec ton partenaire",
        "Combats tactiques au tour par tour, huit éléments",
        "Gagne la confiance des Spirlings avec l'appel d'écho",
        "Scelle les Failles et affronte leurs Gardiens",
        "Explore falaises, marais et grottes",
    ],
    "es": [
        "Una aventura retro en píxeles",
        "Empieza en Brindlewick con tu compañero",
        "Combates tácticos por turnos con ocho elementos",
        "Gánate a los Spirlings con la llamada de eco",
        "Sella las Grietas y enfréntate a sus Guardianes",
        "Explora acantilados, marismas y cuevas",
    ],
    "it": [
        "Un'avventura retrò in pixel art",
        "Inizia a Brindlewick con il tuo partner",
        "Battaglie tattiche a turni con otto elementi",
        "Conquista gli Spirling con il richiamo d'eco",
        "Sigilla le Fratture e sfida i loro Guardiani",
        "Esplora scogliere, paludi e grotte",
    ],
    "ja": [
        "レトロなドット絵の旅",
        "パートナーとBrindlewickから旅立とう",
        "8つの属性で戦うタクティカルなターンバトル",
        "エコーの呼び声でSpirlingと心を通わせよう",
        "裂け目を封じ、その番人に立ち向かえ",
        "崖や湿地、ほら穴を探検しよう",
    ],
    "ko": [
        "레트로 도트 모험",
        "파트너와 함께 Brindlewick에서 출발하세요",
        "8가지 속성의 전략 턴제 배틀",
        "에코 부름으로 Spirling의 마음을 얻으세요",
        "균열을 봉인하고 수호자에 맞서세요",
        "절벽, 습지, 동굴을 탐험하세요",
    ],
    "zh_CN": [
        "复古像素之旅",
        "与伙伴一起从Brindlewick出发",
        "八种元素的战术回合制战斗",
        "用回声呼唤赢得Spirling的信任",
        "封印裂隙，迎战它们的守护者",
        "探索悬崖、沼泽与洞穴",
    ],
    "zh_TW": [
        "復古像素之旅",
        "與夥伴一起從Brindlewick出發",
        "八種元素的戰術回合制戰鬥",
        "用回聲呼喚贏得Spirling的信任",
        "封印裂隙，迎戰它們的守護者",
        "探索懸崖、沼澤與洞穴",
    ],
    "pt_BR": [
        "Uma aventura retrô em pixel art",
        "Comece em Brindlewick com seu parceiro",
        "Batalhas táticas por turnos com oito elementos",
        "Conquiste os Spirlings com o chamado de eco",
        "Sele as Fendas e enfrente seus Guardiões",
        "Explore penhascos, pântanos e cavernas",
    ],
    "ru": [
        "Ретро-приключение в пикселях",
        "Начни путь в Brindlewick вместе с партнёром",
        "Тактические пошаговые бои, восемь стихий",
        "Завоюй доверие Spirlings зовом эха",
        "Запечатай Разломы и сразись с их Стражами",
        "Исследуй утёсы, болота и пещеры",
    ],
    "pl": [
        "Retro przygoda w pikselach",
        "Zacznij w Brindlewick ze swoim partnerem",
        "Taktyczne walki turowe, osiem żywiołów",
        "Zdobądź zaufanie Spirlingów wołaniem echa",
        "Zapieczętuj Szczeliny i zmierz się ze Strażnikami",
        "Odkrywaj klify, mokradła i jaskinie",
    ],
    "tr": [
        "Retro bir piksel macerası",
        "Partnerinle Brindlewick'ten yola çık",
        "Sekiz elementli taktik sıra tabanlı savaşlar",
        "Yankı çağrısıyla Spirling'lerin güvenini kazan",
        "Yarıkları mühürle, Muhafızlarıyla yüzleş",
        "Uçurumları, bataklıkları ve mağaraları keşfet",
    ],
    "nl": [
        "Een retro-pixelavontuur",
        "Begin in Brindlewick met je partner",
        "Tactische beurtgevechten met acht elementen",
        "Win het vertrouwen van Spirlings met de echoroep",
        "Verzegel de Scheuren en versla hun Wachters",
        "Verken kliffen, moerassen en grotten",
    ],
}
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
# Game language -> (Play folder, App Store folder), same pairs as tools/release_check.py TEXT_LANGS.
LANG_DIR = {
    "de": ("de-DE", "de-DE"), "en": ("en-US", "en-US"), "fr": ("fr-FR", "fr-FR"), "es": ("es-ES", "es-ES"),
    "it": ("it-IT", "it"), "ja": ("ja-JP", "ja"), "ko": ("ko-KR", "ko"), "zh_CN": ("zh-CN", "zh-Hans"),
    "zh_TW": ("zh-TW", "zh-Hant"), "pt_BR": ("pt-BR", "pt-BR"), "ru": ("ru-RU", "ru"), "pl": ("pl-PL", "pl"),
    "tr": ("tr-TR", "tr"), "nl": ("nl-NL", "nl-NL"),
}
# CJK captions: the game's own 8 px CJK pixel fonts (art/fonts, OFL) for CJK glyphs, DejaVu for the rest.
CJK = {"ja", "ko", "zh_CN", "zh_TW"}
NO_LINE_START = set("ー、。，．！？）」』・ゃゅょっァィゥェォャュョッ")


def native(path: str) -> Image.Image:
    """tools/screenshot.gd saves at 3x; go back to the 144 x 256 game pixels."""
    img = Image.open(path).convert("RGB")
    return img.resize((img.width // 3, img.height // 3), Image.NEAREST)


def _fonts(lang: str) -> tuple[ImageFont.FreeTypeFont, ImageFont.FreeTypeFont | None, int]:
    """Latin font, CJK font (or None) and the size both are drawn at."""
    if lang in CJK:
        return ImageFont.truetype(FONT, 16), ImageFont.truetype(f"art/fonts/chimora_cjk_8px_{lang}.otf", 16), 16
    return ImageFont.truetype(FONT, 12), None, 12


def _runs(text: str, latin, cjk) -> list[tuple[str, object]]:
    """Splits text into runs that one font can draw (CJK glyphs from the CJK font)."""
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


_CMAPS: dict[str, set[int]] = {}


def _cmap(font) -> set[int]:
    if font.path not in _CMAPS:
        from fontTools.ttLib import TTFont
        _CMAPS[font.path] = set(TTFont(font.path).getBestCmap())
    return _CMAPS[font.path]


def _width(probe, text: str, latin, cjk) -> float:
    return sum(probe.textlength(t, font=f) for t, f in _runs(text, latin, cjk))


def pixel_text(text: str, max_w: int, scale: int, lang: str = "en") -> Image.Image:
    """Text drawn without anti-aliasing at a small size, then scaled up, so it looks like pixels.
    CJK text is drawn at 16 px (the 8 px pixel font doubled, so Latin names inside stay readable) and
    scaled by 2/3 of the Latin scale."""
    latin, cjk, size = _fonts(lang)
    if cjk is not None:
        scale = max(3, scale * 2 // 3)
    # Japanese and Chinese have no spaces: wrap between any two characters. Korean wraps at spaces.
    by_char = cjk is not None and lang != "ko"
    words = list(text) if by_char else text.split()
    joiner = "" if by_char else " "
    lines, cur = [], ""
    probe = ImageDraw.Draw(Image.new("L", (1, 1)))
    for w in words:
        test = cur + joiner + w if cur else w
        if _width(probe, test, latin, cjk) * scale > max_w and cur:
            if by_char and w in NO_LINE_START and len(cur) > 1:
                # Never start a line with a long vowel mark or punctuation: take the last character along.
                lines.append(cur[:-1])
                cur = cur[-1] + w
            else:
                lines.append(cur)
                cur = w
        else:
            cur = test
    lines.append(cur)
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


def frame(w: int, h: int, game: Image.Image, scale: int, caption: str, text_scale: int, top: int, lang: str = "en") -> Image.Image:
    out = backdrop(w, h, text_scale)
    g = game.resize((game.width * scale, game.height * scale), Image.NEAREST)
    gx, gy = (w - g.width) // 2, top
    border = text_scale
    d = ImageDraw.Draw(out)
    d.rectangle((gx - 2 * border, gy - 2 * border, gx + g.width + 2 * border - 1, gy + g.height + 2 * border - 1), fill=INK[3])
    d.rectangle((gx - border, gy - border, gx + g.width + border - 1, gy + g.height + border - 1), fill=INK[1])
    out.paste(g, (gx, gy))
    t = pixel_text(caption, w - 8 * text_scale, text_scale, lang)
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
    t = pixel_text(FEATURE[lang], box, 4, lang)
    out.paste(t, (48 + (box - 48 - t.width) // 2, (h - t.height) // 2), t)
    return out


def main() -> None:
    src = sys.argv[1] if len(sys.argv) > 1 else "/tmp/shots"
    icon = Image.open("art/icon/icon_512.png")
    only = sys.argv[2:]
    for lang, (play, ios) in LANG_DIR.items():
        if only and lang not in only:
            continue
        shots = [native(os.path.join(src, lang, s + ".png")) for s in SHOTS]
        a_dir = f"store/android/{play}/images/phoneScreenshots"
        i_dir = f"store/ios/screenshots/{ios}"
        os.makedirs(a_dir, exist_ok=True)
        os.makedirs(i_dir, exist_ok=True)
        for n, (shot, cap) in enumerate(zip(shots, CAPTIONS[lang]), 1):
            # Play: 1080 x 1920, game at 6x (864 x 1536).
            frame(1080, 1920, shot, 6, cap, 6, 300, lang).save(f"{a_dir}/{n}.png", optimize=True)
            # App Store 6.9": 1320 x 2868, game at 8x (1152 x 2048).
            frame(1320, 2868, shot, 8, cap, 8, 600, lang).save(f"{i_dir}/{n}_iphone69.png", optimize=True)
        img_dir = f"store/android/{play}/images"
        feature_graphic(lang, shots[0]).save(f"{img_dir}/featureGraphic.png", optimize=True)
        icon.save(f"{img_dir}/icon.png")
        print("store images written for", play, ios)
    # App Review picture for every in-app purchase (where it is sold): the English shop, 5x (720 x 1280).
    shop = os.path.join(src, "en", "06_shop.png")
    if os.path.exists(shop) and (not only or "en" in only):
        s = native(shop)
        s.resize((s.width * 5, s.height * 5), Image.NEAREST).save("store/ios/iap_review.png", optimize=True)
        print("store/ios/iap_review.png written")


if __name__ == "__main__":
    main()
