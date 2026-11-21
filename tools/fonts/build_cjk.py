#!/usr/bin/env python3
"""Builds art/fonts/chimora_cjk_<size>px_<code>.otf for Japanese, Korean and both Chinese scripts.

Two sizes (plan Chimora 100, item 59: 8 px hanzi merged into blots at Era I/II): 10 px glyphs
behind the small pixel font, 12 px glyphs behind the large and bold ones. Both answer to the
game's one font size (PixelFont.BASE_SIZE = 8): unitsPerEm is scaled so size 8 draws the design
size 1:1 on the pixel grid.

The glyphs are Fusion Pixel Font 10px and 12px proportional by TakWolf (SIL Open Font License 1.1, see
art/fonts/OFL.txt). Each language gets the glyph forms of its own region (Japanese kanji, Simplified
and Traditional hanzi look different) and only the characters its texts in data/i18n/<code>/ use,
plus all kana and the CJK punctuation, so the files stay small. Subsetting makes a Modified Version
under the OFL, so the fonts are renamed ("Chimora CJK Pixel"); the OFL's Reserved Font Names are not used. The outlines move
down one row so the vertical metrics are exactly those of the pixel font they sit behind: 10 px
glyphs 7 above the baseline and 2 below (the small font), 12 px glyphs 9 above and 3 below (the
large font). Line heights, and every layout measured with them, stay as they were.

Source: the npm package @vp-tw/cjk-web-fonts-fusion-pixel-font (unofficial WOFF2 packaging of the
upstream release, one file per Unicode block):
  mkdir -p /tmp/fp && curl -sL https://registry.npmjs.org/@vp-tw/cjk-web-fonts-fusion-pixel-font/-/cjk-web-fonts-fusion-pixel-font-0.0.1.tgz | tar xz -C /tmp/fp
  pip install fonttools brotli
  python3 tools/fonts/build_cjk.py /tmp/fp/package [codes...]
Run again after a CJK translation adds characters (tests/unit/test_i18n_languages.gd fails then).
"""
import glob, json, os, sys
from fontTools.ttLib import TTFont
from fontTools.merge import Merger
from fontTools import subset
from fontTools.pens.t2CharStringPen import T2CharStringPen
from fontTools.pens.transformPen import TransformPen

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
LANGS = {"ja": "ja", "ko": "ko", "zh_CN": "zh_hans", "zh_TW": "zh_hant"}
OUT = os.path.join(ROOT, "art/fonts")
BASE = 8
# Design size: (rows above the baseline, rows below, rows the outlines move down).
SIZES = {10: (7, 2, 1), 12: (9, 3, 1)}
# The few rare hanzi the 10 and 12 px sets lack come from a tiny 8 px font behind them.
SPARE = 8
SPARE_METRICS = (7, 2, 0)
# Always kept: kana, CJK punctuation, full-width forms, a few symbols.
ALWAYS = [(0x3000, 0x303F), (0x3040, 0x309F), (0x30A0, 0x30FF), (0xFF00, 0xFFEF), (0x2010, 0x2027),
          (0x2190, 0x2193), (0x25A0, 0x25CF), (0x2605, 0x2606), (0x3131, 0x318E)]

# The language list shows every language's own name (Loc.LANGUAGE_NAMES).
NAMES = {"ja": "日本語", "ko": "한국어", "zh_CN": "简体中文", "zh_TW": "繁體中文"}

def used_chars(code):
    chars = set(NAMES[code])
    for p in glob.glob(os.path.join(ROOT, "data/i18n", code, "*.json")):
        for v in json.load(open(p, encoding="utf-8")).get("strings", {}).values():
            chars.update(v)
    return {ord(c) for c in chars if ord(c) > 0x7F}

def build(pkg, code, folder, size, only=None):
    want = set(only) if only is not None else used_chars(code)
    if only is None:
        for a, b in ALWAYS:
            want.update(range(a, b + 1))
    parts = []
    tmp = os.path.join("/tmp", "chimora_cjk_%s_%d" % (code, size))
    os.makedirs(tmp, exist_ok=True)
    for i, f in enumerate(sorted(glob.glob(os.path.join(pkg, "dist/%dpx/proportional" % size, folder, "*.woff2")))):
        if "Basic-Latin" in f or "Private-Use" in f:
            continue
        font = TTFont(f)
        have = set(font.getBestCmap()) & want
        if not have:
            continue
        opts = subset.Options()
        opts.flavor = None
        opts.layout_features = []
        opts.name_IDs = ["*"]
        opts.notdef_outline = True
        sub = subset.Subsetter(opts)
        sub.populate(unicodes=sorted(have))
        sub.subset(font)
        font.flavor = None
        # The merger needs unique names across parts.
        p = os.path.join(tmp, "%03d.otf" % i)
        font.save(p)
        parts.append(p)
    merged = Merger().merge(parts)
    for t in ("vhea", "vmtx", "GPOS", "GSUB"):
        if t in merged:
            del merged[t]
    upm = merged["head"].unitsPerEm
    px = upm // size
    above, below, down = SIZES.get(size, SPARE_METRICS)
    if down:
        _shift_down(merged, down * px)
    # Size 8 draws one design pixel per screen pixel.
    new_upm = px * BASE
    merged["head"].unitsPerEm = new_upm
    if "CFF " in merged:
        merged["CFF "].cff.topDictIndex[0].FontMatrix = [1.0 / new_upm, 0, 0, 1.0 / new_upm, 0, 0]
    merged["hhea"].ascent = above * px
    merged["hhea"].descent = -below * px
    merged["hhea"].lineGap = 0
    os2 = merged["OS/2"]
    os2.sTypoAscender, os2.sTypoDescender, os2.sTypoLineGap = above * px, -below * px, 0
    os2.usWinAscent, os2.usWinDescent = above * px, below * px
    family = "Chimora CJK Pixel %d %s" % (size, code.replace("_", " "))
    name = merged["name"]
    for rec in list(name.names):
        if rec.nameID in (1, 3, 4, 6, 16, 17, 18, 21, 22):
            name.removeNames(nameID=rec.nameID)
    for nid, text in ((1, family), (2, "Regular"), (3, family + " Regular"), (4, family),
                      (6, family.replace(" ", "")), (5, "Version 1.0")):
        name.setName(text, nid, 3, 1, 0x409)
        name.setName(text, nid, 1, 0, 0)
    if "CFF " in merged:
        cff = merged["CFF "].cff
        cff.fontNames = [family.replace(" ", "")]
        top = cff.topDictIndex[0]
        for k in ("FullName", "FamilyName"):
            if hasattr(top, k):
                setattr(top, k, family)
    os.makedirs(OUT, exist_ok=True)
    out = os.path.join(OUT, "chimora_cjk_%dpx_%s.otf" % (size, code))
    merged.save(out)
    cmap = merged.getBestCmap()
    missing = {c for c in (want if only is not None else used_chars(code)) if c not in cmap}
    print("%s %dpx: %d glyphs, %d bytes -> %s" % (code, size, len(merged.getGlyphOrder()), os.path.getsize(out), out))
    if missing and only is None:
        print("  not in the font: " + "".join(chr(c) for c in sorted(missing)))
    return missing

def _shift_down(font, dy):
    """Moves every CFF outline down by dy units."""
    cff = font["CFF "].cff
    top = cff.topDictIndex[0]
    cs = top.CharStrings
    gs = font.getGlyphSet()
    for name in font.getGlyphOrder():
        g = gs[name]
        pen = T2CharStringPen(g.width, gs)
        g.draw(TransformPen(pen, (1, 0, 0, 1, 0, -dy)))
        new = pen.getCharString(private=cs[name].private, globalSubrs=cs[name].globalSubrs)
        cs[name] = new

if __name__ == "__main__":
    pkg = sys.argv[1] if len(sys.argv) > 1 else "/tmp/fp/package"
    for code, folder in LANGS.items():
        if len(sys.argv) > 2 and code not in sys.argv[2:]:
            continue
        spare = os.path.join(OUT, "chimora_cjk_%dpx_%s.otf" % (SPARE, code))
        if os.path.exists(spare):
            os.remove(spare)
        gaps = set()
        for size in SIZES:
            gaps |= build(pkg, code, folder, size)
        if gaps:
            left = build(pkg, code, folder, SPARE, gaps)
            if left:
                print("  %s: no glyph in any size: %s" % (code, "".join(chr(c) for c in sorted(left))))
