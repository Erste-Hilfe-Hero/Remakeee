"""Store listing check for every App Store locale and Play language (plan Chimora 100, items 95, 96, 98).

  python3 tools/store/listing_check.py      fails on any broken listing text (CI runs this)

App Store, store/ios/metadata/<locale>/ for all 20 locales Chimora is listed in:
  name 30, subtitle 30, keywords 100, promotional_text 170, description 4000, release_notes 4000.
  The name starts with "Chimora". The subtitle carries search words, not the game's own word "Spirling".
  Keywords: comma separated, no spaces, no item twice, no word that the name or subtitle already has,
  and no word that the other locale indexed in the same storefront already carries (SHARED_INDEX).
In-App Event texts, store/ios/in_app_events/<locale>/: name 30, short_description 50, long_description 120.
Screenshot captions, store/ios/screenshot_captions/<locale>.txt (tools/store/make_store_images.py): one line
  per picture, CAPTION_LINES of them, each at most CAPTION_MAX characters, no money signs and no Discord
  (plan Chimora 100, items 86, 87, 97; Play uses the captions of its language's main locale).
Google Play, store/android/<lang>/ for the 14 game languages: title 30, short 80, full 4000, changelog 500.
Every text: no franchise term (the pattern of tools/ip_check.sh) and no other game's name (OTHER_GAMES).
"""
from __future__ import annotations

import base64
import os
import re
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))

APP_LOCALES = ["en-US", "en-GB", "en-AU", "en-CA", "de-DE", "fr-FR", "fr-CA", "es-ES", "es-MX", "pt-BR", "pt-PT",
               "it", "nl-NL", "pl", "tr", "ru", "ja", "ko", "zh-Hans", "zh-Hant"]
PLAY_LANGS = ["de-DE", "en-US", "fr-FR", "es-ES", "it-IT", "pt-BR", "nl-NL", "pl-PL", "tr-TR", "ru-RU", "ja-JP",
              "ko-KR", "zh-CN", "zh-TW"]
LIMITS_IOS = {"name.txt": 30, "subtitle.txt": 30, "keywords.txt": 100, "promotional_text.txt": 170,
              "description.txt": 4000, "release_notes.txt": 4000}
LIMITS_EVENT = {"name.txt": 30, "short_description.txt": 50, "long_description.txt": 120}
LIMITS_PLAY = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000,
               "changelogs/default.txt": 500}
# Locales Apple indexes together in one storefront (store/README.md): their keyword fields must not
# repeat each other's words, or the extra field is wasted.
SHARED_INDEX = [("en-US", "es-MX"), ("en-CA", "fr-CA"), ("en-GB", "en-AU")]
# Other monster games: never named in our store texts (docs/IP_HYGIENE.md, no comparisons).
OTHER_GAMES = re.compile(r"evocreo|neo ?monsters|aniimo|voidpet|nexomon|coromon|temtem|cassette ?beasts|siralim"
                         r"|monster super league|bulu monster|wild tamer|monster masters|dragonvale|negamon|nevomove"
                         r"|digimon|yo-?kai|palworld|monster ?hunter|dragon ?quest|monster ?sanctuary|ooblets", re.I)
CJK = re.compile(r"[぀-ヿ㐀-鿿가-힯]")
CAPTION_LINES = 8
CAPTION_MAX = 60
NOT_IN_CAPTIONS = re.compile(r"discord|[€$£¥₩₽]", re.I)


def franchise_pattern() -> re.Pattern | None:
    m = re.search(r"^pattern=\"\$\(printf '%s' '([A-Za-z0-9+/=]+)'", open(os.path.join(ROOT, "tools/ip_check.sh")).read(), re.M)
    return re.compile(base64.b64decode(m.group(1)).decode("utf-8"), re.I) if m else None


def words(text: str) -> set[str]:
    return {w for w in re.findall(r"[^\W_]+", text.lower()) if not CJK.search(w)}


def keyword_items(text: str) -> list[str]:
    return [k for k in text.strip().split(",")]


def read(path: str) -> str:
    with open(path, encoding="utf-8") as f:
        return f.read().strip()


def check_lengths(root: str, base: str, limits: dict, errors: list[str]) -> dict[str, str]:
    texts = {}
    for name, limit in limits.items():
        p = os.path.join(base, name)
        if not os.path.exists(p):
            errors.append("missing " + os.path.relpath(p, root))
            continue
        t = read(p)
        texts[name] = t
        if not 0 < len(t) <= limit:
            errors.append("%s has %d characters (allowed 1-%d)" % (os.path.relpath(p, root), len(t), limit))
    return texts


def check_keywords(loc: str, kw: str, name: str, subtitle: str, errors: list[str]) -> None:
    items = keyword_items(kw)
    where = "store/ios/metadata/%s/keywords.txt" % loc
    if " " in kw or any(not k for k in items):
        errors.append(where + ": no spaces and no empty items (Apple splits on commas)")
    seen: set[str] = set()
    for k in items:
        if k.lower() in seen:
            errors.append("%s: %r is listed twice" % (where, k))
        seen.add(k.lower())
    taken = words(name + " " + subtitle)
    for k in items:
        if CJK.search(k):
            if k in name or k in subtitle:
                errors.append("%s: %r is already in the name or subtitle" % (where, k))
        elif words(k) & taken:
            errors.append("%s: %r repeats a word of the name or subtitle" % (where, k))
    if "chimora" in kw.lower():
        errors.append(where + ": the brand is in the name already")
    if "offline" in kw.lower():
        errors.append(where + ": the game is online only")


def check(root: str = ROOT) -> list[str]:
    errors: list[str] = []
    ios: dict[str, dict[str, str]] = {}
    files: list[str] = []
    for loc in APP_LOCALES:
        base = os.path.join(root, "store/ios/metadata", loc)
        t = check_lengths(root, base, LIMITS_IOS, errors)
        ios[loc] = t
        files += [os.path.join(base, n) for n in t]
        name, sub = t.get("name.txt", ""), t.get("subtitle.txt", "")
        if name and not name.startswith("Chimora"):
            errors.append("store/ios/metadata/%s/name.txt must start with Chimora" % loc)
        if "spirling" in sub.lower():
            errors.append("store/ios/metadata/%s/subtitle.txt: use search words, not Spirling" % loc)
        if "keywords.txt" in t:
            check_keywords(loc, t["keywords.txt"], name, sub, errors)
        if "description.txt" in t and "497" not in t["description.txt"]:
            errors.append("store/ios/metadata/%s/description.txt: name the 497 Spirlings" % loc)
        cap = os.path.join(root, "store/ios/screenshot_captions", loc + ".txt")
        if not os.path.exists(cap):
            errors.append("missing " + os.path.relpath(cap, root))
        else:
            files.append(cap)
            lines = read(cap).split("\n")
            if len(lines) != CAPTION_LINES or any(not l.strip() for l in lines):
                errors.append("%s needs %d non-empty lines, one per picture" % (os.path.relpath(cap, root), CAPTION_LINES))
            for l in lines:
                if len(l) > CAPTION_MAX:
                    errors.append("%s: %r is longer than %d characters" % (os.path.relpath(cap, root), l, CAPTION_MAX))
                if NOT_IN_CAPTIONS.search(l):
                    errors.append("%s: %r: no prices and no Discord in the pictures" % (os.path.relpath(cap, root), l))
        ev = os.path.join(root, "store/ios/in_app_events", loc)
        files += [os.path.join(ev, n) for n in check_lengths(root, ev, LIMITS_EVENT, errors)]
    for a, b in SHARED_INDEX:
        if "keywords.txt" not in ios[a] or "keywords.txt" not in ios[b]:
            continue
        for x, y in ((a, b), (b, a)):
            other = words(ios[y].get("name.txt", "") + " " + ios[y].get("subtitle.txt", "") + " " + ios[y]["keywords.txt"].replace(",", " "))
            for k in keyword_items(ios[x]["keywords.txt"]):
                if words(k) & other:
                    errors.append("store/ios/metadata/%s/keywords.txt: %r is already indexed through %s (same storefront)" % (x, k, y))
    for lang in PLAY_LANGS:
        base = os.path.join(root, "store/android", lang)
        t = check_lengths(root, base, LIMITS_PLAY, errors)
        files += [os.path.join(base, n) for n in t]
        if t.get("title.txt") and not t["title.txt"].startswith("Chimora"):
            errors.append("store/android/%s/title.txt must start with Chimora" % lang)
    banned = franchise_pattern()
    for p in files:
        text = read(p)
        for rx in (banned, OTHER_GAMES):
            m = rx.search(text) if rx else None
            if m:
                errors.append("%s names %r: no other game's or franchise's names (docs/IP_HYGIENE.md)" % (os.path.relpath(p, root), m.group(0)))
    return errors


def main() -> None:
    errors = check()
    for e in errors:
        print("ERROR:", e)
    print("listing check: %d App Store locales, %d Play languages, %d errors" % (len(APP_LOCALES), len(PLAY_LANGS), len(errors)))
    sys.exit(1 if errors else 0)


if __name__ == "__main__":
    main()
