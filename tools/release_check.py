"""Release readiness check for Google Play and the App Store.

  python3 tools/release_check.py           report, fails only on broken store material (CI runs this)
  python3 tools/release_check.py --strict  also fails while Ali's open items remain (use before a v* tag)

Errors (always fail): store texts too long or missing, screenshots or icons with the wrong size,
Android and iOS versions that disagree.
Open items (fail only with --strict): placeholder bundle ID, placeholders in the legal texts and in
LegalInfo.gd, a site address that is not an own domain yet.
"""
from __future__ import annotations
import json

import glob
import os
import re
import subprocess
import sys

from PIL import Image

LANGS = ["de-DE", "en-US"]
# Store texts in all 14 game languages (docs/I18N.md): (Google Play folder, App Store folder).
# Every language has its own screenshots and graphics too (tools/store/make_store_images.py).
TEXT_LANGS = [("de-DE", "de-DE"), ("en-US", "en-US"), ("fr-FR", "fr-FR"), ("es-ES", "es-ES"), ("it-IT", "it"),
              ("pt-BR", "pt-BR"), ("nl-NL", "nl-NL"), ("pl-PL", "pl"), ("tr-TR", "tr"), ("ru-RU", "ru"),
              ("ja-JP", "ja"), ("ko-KR", "ko"), ("zh-CN", "zh-Hans"), ("zh-TW", "zh-Hant")]
LIMITS_ANDROID = {"title.txt": 30, "short_description.txt": 80, "full_description.txt": 4000, "changelogs/default.txt": 500}
LIMITS_IOS = {"name.txt": 30, "subtitle.txt": 30, "description.txt": 4000, "keywords.txt": 100,
              "promotional_text.txt": 170, "release_notes.txt": 4000, "support_url.txt": 255, "privacy_url.txt": 255}
IMAGES = {
    "store/android/{l}/images/featureGraphic.png": (1024, 500),
    "store/android/{l}/images/icon.png": (512, 512),
}
ICONS = {"art/icon/icon_1024.png": (1024, 1024), "art/icon/icon_192.png": (192, 192),
         "art/icon/adaptive_fg_432.png": (432, 432), "art/icon/adaptive_bg_432.png": (432, 432),
         "art/icon/adaptive_mono_432.png": (432, 432)}
# [DOMAIN] is filled in by tools/site/build_site.py, so it is not an open item.
PLACEHOLDER = re.compile(r"\[(NAME|ADRESSE|ADDRESS|E-MAIL|EMAIL|TELEFON|PHONE)\]")

errors: list[str] = []
todo: list[str] = []


def read(path: str) -> str:
    return open(path, encoding="utf-8").read()


def preset_values(key: str) -> list[str]:
    return re.findall(r"^%s=\"?([^\"\n]*)\"?$" % re.escape(key), read("export_presets.cfg"), re.M)


def check_texts() -> None:
    for play, ios in TEXT_LANGS:
        for base, limits in (("store/android/" + play, LIMITS_ANDROID), ("store/ios/metadata/" + ios, LIMITS_IOS)):
            for name, limit in limits.items():
                p = os.path.join(base, name)
                if not os.path.exists(p):
                    errors.append("missing " + p)
                    continue
                n = len(read(p).strip())
                if n == 0 or n > limit:
                    errors.append("%s has %d characters (allowed 1-%d)" % (p, n, limit))
        kw = "store/ios/metadata/%s/keywords.txt" % ios
        if os.path.exists(kw) and "offline" in read(kw):
            errors.append(kw + ": the game is online only")


def check_images() -> None:
    for lang, ios_lang in TEXT_LANGS:
        for pattern, size in IMAGES.items():
            p = pattern.format(l=lang)
            if not os.path.exists(p) or Image.open(p).size != size:
                errors.append("%s must be %dx%d" % (p, *size))
        shots = sorted(glob.glob("store/android/%s/images/phoneScreenshots/*.png" % lang))
        if len(shots) < 2:
            errors.append("Google Play needs at least 2 phone screenshots for " + lang)
        for p in shots:
            w, h = Image.open(p).size
            if not (320 <= min(w, h) and max(w, h) <= 3840 and max(w, h) <= 2 * min(w, h)):
                errors.append(p + " has a size Google Play does not accept")
        ios = sorted(glob.glob("store/ios/screenshots/%s/*_iphone69.png" % ios_lang))
        if not ios:
            errors.append("App Store needs 6.9\" iPhone screenshots for " + ios_lang)
        for p in ios:
            if Image.open(p).size not in ((1320, 2868), (1290, 2796)):
                errors.append(p + " must be 1320x2868 or 1290x2796")
    if not os.path.exists("store/ios/iap_review.png") or min(Image.open("store/ios/iap_review.png").size) < 640:
        errors.append("store/ios/iap_review.png (App Review picture of the shop) missing or smaller than 640 px")
    for p, size in ICONS.items():
        if not os.path.exists(p) or Image.open(p).size != size:
            errors.append("%s must be %dx%d" % (p, *size))
    icon = "art/icon/icon_1024.png"
    if os.path.exists(icon) and Image.open(icon).mode not in ("RGB", "P", "L"):
        errors.append(icon + " must have no transparency (App Store rule)")


def check_presets() -> None:
    names = set(preset_values("version/name")) | set(preset_values("application/short_version"))
    if len(names) > 1:
        errors.append("version names differ between presets: " + ", ".join(sorted(names)))
    ids = set(preset_values("package/unique_name")) | set(preset_values("application/bundle_identifier"))
    if len(ids) > 1:
        errors.append("Android package and iOS bundle ID differ: " + ", ".join(sorted(ids)))
    if "com.chimora.game" in ids:
        todo.append("Bundle ID is still the old placeholder com.chimora.game")
    if preset_values("application/targeted_device_family") != ["0"]:
        errors.append("iOS preset should be iPhone only (targeted_device_family=0), or add iPad screenshots")
    if "ITSAppUsesNonExemptEncryption" not in read("export_presets.cfg"):
        errors.append("iOS preset lacks ITSAppUsesNonExemptEncryption in additional_plist_content")


# Android permissions the game may ask for. Play Billing adds com.android.vending.BILLING through its
# own manifest; anything else new must be a deliberate change here (plan item 4107).
ALLOWED_PERMISSIONS = {"vibrate", "internet", "access_network_state"}
# Ad and analytics SDKs stay out of the game (AGENTS.md rule 4, plan item 4012).
AD_SDKS = re.compile(r"admob|applovin|unityads|unity_ads|ironsource|levelplay|firebase|analytics|adjust|appsflyer"
                     r"|facebook|chartboost|vungle|mopub|tapjoy|gameanalytics|amplitude|mixpanel|flurry", re.I)


def check_permissions() -> None:
    text = read("export_presets.cfg")
    on = set(re.findall(r"^permissions/([a-z_]+)=true$", text, re.M))
    extra = sorted(on - ALLOWED_PERMISSIONS)
    if extra:
        errors.append("new Android permissions in export_presets.cfg: " + ", ".join(extra))
    for custom in re.findall(r"^permissions/custom_permissions=PackedStringArray\((.*)\)$", text, re.M):
        if custom.strip():
            errors.append("custom Android permissions in export_presets.cfg: " + custom)


def check_sdks() -> None:
    files = glob.glob("addons/*/plugin.cfg") + glob.glob("addons/*/*.gdextension") + glob.glob("plugins/*/android/build.gradle")
    names = [os.path.basename(d) for d in glob.glob("addons/*") + glob.glob("plugins/*")]
    for n in names:
        if AD_SDKS.search(n):
            errors.append("ad or analytics plugin in the project: " + n)
    for f in files:
        m = AD_SDKS.search(read(f))
        if m:
            errors.append("%s mentions the ad or analytics SDK %r" % (f, m.group(0)))


def check_legal() -> None:
    for p in sorted(glob.glob("docs/legal/*.md")):
        if p.endswith(("CHECKLISTE_ALI.md", "README.md", "STORE_COMPLIANCE.md", "IP_PATENT_AUDIT.md")):
            continue
        body = re.sub(r"<!--.*?-->", "", read(p), flags=re.S)
        found = sorted(set(PLACEHOLDER.findall(body)))
        if found:
            todo.append("%s: fill %s" % (p, ", ".join("[%s]" % f for f in found)))
    li = read("scripts/core/LegalInfo.gd")
    if ".example" in li:
        todo.append("scripts/core/LegalInfo.gd: CONTACT is still a placeholder email")
    if "sslip.io" in li:
        todo.append("scripts/core/LegalInfo.gd: SITE uses the server's sslip.io address (fine for launch, own domain later)")


JWT = re.compile(r"eyJ[A-Za-z0-9_-]{8,}\.([A-Za-z0-9_-]{8,})\.[A-Za-z0-9_-]{8,}")
SECRET_WORDS = ("service_role", "SERVICE_ROLE_KEY", "JWT_SECRET=", "POSTGRES_PASSWORD=")


def jwt_role(token_payload: str) -> str:
    import base64, json as _json
    try:
        pad = "=" * (-len(token_payload) % 4)
        return str(_json.loads(base64.urlsafe_b64decode(token_payload + pad)).get("role", ""))
    except Exception:
        return ""


def check_keys() -> None:
    """Plan item 3882: only the public anon key may ever be inside the game."""
    roots = ["data", "scripts", "scenes", "project.godot", "export_presets.cfg"]
    for root in roots:
        paths = [root] if os.path.isfile(root) else [os.path.join(dp, f) for dp, _, fs in os.walk(root) for f in fs]
        for p in paths:
            if p.endswith((".png", ".ogg", ".wav", ".import", ".ttf")):
                continue
            try:
                text = open(p, encoding="utf-8").read()
            except (UnicodeDecodeError, OSError):
                continue
            for m in JWT.finditer(text):
                role = jwt_role(m.group(1))
                if role != "anon":
                    errors.append("%s holds a key with role %r; the game may only carry the anon key" % (p, role or "?"))
            for w in SECRET_WORDS:
                if w in text and not p.endswith("release_check.py"):
                    errors.append("%s mentions %s; server secrets never go into the game" % (p, w))


# The fixed store price list (0.99 to 99.99 EUR, item 4078).
PRICE_CENTS = {99, 199, 299, 399, 499, 599, 699, 799, 899, 999, 1199, 1299, 1499, 1999, 2499, 2999, 3999, 4999, 7999, 9999}


def check_products() -> None:
    """Every product ID of data/shop.json is in store/products.json and back (item 4077),
    and every price is on the fixed price list (item 4078)."""
    shop = json.loads(read("data/shop.json"))
    store = json.loads(read("store/products.json"))
    rows = store if isinstance(store, list) else store.get("products", [])
    game = {str(o["product_id"]): o for o in shop["offers"] if o.get("product_id") and not o.get("rg_only")}
    listed = {str(p["product_id"]): p for p in rows}
    for pid in sorted(set(game) - set(listed)):
        errors.append("product %s is in data/shop.json but not in store/products.json" % pid)
    for pid in sorted(set(listed) - set(game)):
        errors.append("product %s is in store/products.json but not in data/shop.json" % pid)
    table = subprocess.run([sys.executable, "tools/shop/make_shop_table.py", "--check"], capture_output=True, text=True)
    if table.returncode != 0:
        errors.append("docs/MONETIZATION.md: shop table is out of date, run tools/shop/make_shop_table.py")
    for pid, o in sorted(game.items()):
        cents = int(o.get("eur_cents", 0))
        if cents not in PRICE_CENTS:
            errors.append("product %s costs %d cents, not a price from the fixed list" % (pid, cents))
    # The purchases help page (docs/legal/KAEUFE.md, item 4044) lists every Riftglass pack with its price.
    help_page = read("docs/legal/KAEUFE.md")
    for o in shop["offers"]:
        if o.get("kind") != "currency":
            continue
        n = sum(int(g.get("n", 0)) for g in o.get("grants", []) if g.get("t") == "rg")
        c = int(o["eur_cents"])
        de = "| %d Rissglas | %d,%02d € |" % (n, c // 100, c % 100)
        en = "| %d Riftglass | %d.%02d EUR |" % (n, c // 100, c % 100)
        for row in (de, en):
            if row not in help_page:
                errors.append("docs/legal/KAEUFE.md: row '%s' is missing or has another price" % row)


def main() -> None:
    check_keys()
    check_texts()
    check_images()
    check_presets()
    check_permissions()
    check_sdks()
    check_legal()
    check_products()
    for e in errors:
        print("ERROR:", e)
    for t in todo:
        print("OPEN: ", t)
    print("release check: %d errors, %d open items" % (len(errors), len(todo)))
    if errors or ("--strict" in sys.argv and todo):
        sys.exit(1)


if __name__ == "__main__":
    main()
