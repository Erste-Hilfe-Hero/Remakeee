"""Release readiness check for Google Play and the App Store.

  python3 tools/release_check.py           report, fails only on broken store material (CI runs this)
  python3 tools/release_check.py --strict  also fails while Ali's open items remain (use before a v* tag)

Errors (always fail): store texts too long or missing, screenshots or icons with the wrong size,
Android and iOS versions that disagree.
Open items (fail only with --strict): placeholder bundle ID, placeholders in the legal texts and in
LegalInfo.gd, a site address that is not an own domain yet.
"""
from __future__ import annotations

import glob
import os
import re
import sys

from PIL import Image

LANGS = ["de-DE", "en-US"]
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
    for lang in LANGS:
        for base, limits in (("store/android/" + lang, LIMITS_ANDROID), ("store/ios/metadata/" + lang, LIMITS_IOS)):
            for name, limit in limits.items():
                p = os.path.join(base, name)
                if not os.path.exists(p):
                    errors.append("missing " + p)
                    continue
                n = len(read(p).strip())
                if n == 0 or n > limit:
                    errors.append("%s has %d characters (allowed 1-%d)" % (p, n, limit))
        kw = "store/ios/metadata/%s/keywords.txt" % lang
        if os.path.exists(kw) and "offline" in read(kw):
            errors.append(kw + ": the game is online only")


def check_images() -> None:
    for lang in LANGS:
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
        ios = sorted(glob.glob("store/ios/screenshots/%s/*_iphone69.png" % lang))
        if not ios:
            errors.append("App Store needs 6.9\" iPhone screenshots for " + lang)
        for p in ios:
            if Image.open(p).size not in ((1320, 2868), (1290, 2796)):
                errors.append(p + " must be 1320x2868 or 1290x2796")
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


def main() -> None:
    check_keys()
    check_texts()
    check_images()
    check_presets()
    check_legal()
    for e in errors:
        print("ERROR:", e)
    for t in todo:
        print("OPEN: ", t)
    print("release check: %d errors, %d open items" % (len(errors), len(todo)))
    if errors or ("--strict" in sys.argv and todo):
        sys.exit(1)


if __name__ == "__main__":
    main()
