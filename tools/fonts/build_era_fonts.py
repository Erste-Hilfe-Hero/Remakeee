#!/usr/bin/env python3
"""Builds Chimora's own text fonts of the later eras from the glyph sheets in tools/fonts/src/.

  etch10  "Chimora Etch"      10 px, Era III (Etching)
  pano12  "Chimora Panorama"  12 px, Eras IV and V (Panorama, Living)

Every glyph is drawn by hand for this game in src/<id>.txt (see the header there). The fonts
cover English and German (A-Z, a-z, digits, punctuation, umlauts and sharp s); every other
character falls back to the Chimora pixel font and its CJK fonts at runtime (scripts/ui/EraFont.gd).

Writes:
  scripts/ui/EraFontGlyphs.gd       the glyph tables the game builds its FontFile from
  art/fonts/chimora_<id>.png        a specimen sheet of each font (review only)

Run after changing a glyph:  python3 tools/fonts/build_era_fonts.py
Check without writing:       python3 tools/fonts/build_era_fonts.py --check
"""
import os, re, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(ROOT, "tools/fonts/src")
OUT_GD = os.path.join(ROOT, "scripts/ui/EraFontGlyphs.gd")
OUT_PNG = os.path.join(ROOT, "art/fonts/chimora_%s.png")
FONTS = [("etch10", "Chimora Etch"), ("pano12", "Chimora Panorama")]
# What a font has to draw itself: English and German text.
REQUIRED = (" ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789"
            ".,!?:;'\"-+=/\\()[]<>%&#*_^~@$|`{}" "ÄÖÜäöüß€≈")
SPEC = re.compile(r"^(?:(\d+)\|)?([.#/]+)$")
SPECIMEN = ["ABCDEFGHIJKLMNOPQRSTUVWXYZ", "abcdefghijklmnopqrstuvwxyz", "0123456789 .,!?:;'\"-+=/\\()[]<>",
            "%&#*_^~@$|`{} ÄÖÜäöüß€≈", "Sphinx of black quartz, judge my vow.",
            "Zwölf Boxkämpfer jagen Viktor quer", "über den großen Sylter Deich."]


def parse(font_id):
    """Returns (cell_w, cell_h, ascent, space, {char: rows}); rows have the glyph's own width."""
    cell = None
    space = 3
    glyphs = {}
    for n, raw in enumerate(open(os.path.join(SRC, font_id + ".txt"), encoding="utf-8"), 1):
        line = raw.rstrip("\n")
        parts = line.split()
        if not parts:
            continue
        if parts[0] == "cell" and len(parts) == 4:
            cell = tuple(int(v) for v in parts[1:])
            continue
        if parts[0] == "space" and len(parts) == 2:
            space = int(parts[1])
            continue
        m = SPEC.match(parts[1]) if len(parts) == 2 else None
        if m is None:
            if parts[0].startswith("#"):
                continue
            raise SystemExit("%s.txt:%d: not a glyph line: %s" % (font_id, n, line))
        ch = " " if parts[0] == "SP" else parts[0]
        if len(ch) != 1:
            raise SystemExit("%s.txt:%d: one character per glyph: %s" % (font_id, n, parts[0]))
        if ch in glyphs:
            raise SystemExit("%s.txt:%d: glyph %s drawn twice" % (font_id, n, ch))
        rows = m.group(2).split("/")
        w = len(rows[0])
        if any(len(r) != w for r in rows):
            raise SystemExit("%s.txt:%d: rows of %s differ in width" % (font_id, n, ch))
        rows = ["." * w] * int(m.group(1) or 0) + rows
        if cell is None:
            raise SystemExit("%s.txt: 'cell W H ASCENT' has to come first" % font_id)
        if w > cell[0] or len(rows) > cell[1]:
            raise SystemExit("%s.txt:%d: %s is larger than the %dx%d cell" % (font_id, n, ch, cell[0], cell[1]))
        rows += ["." * w] * (cell[1] - len(rows))
        if ch != " " and all(r[0] == "." for r in rows):
            raise SystemExit("%s.txt:%d: %s has an empty first column" % (font_id, n, ch))
        if ch != " " and all(r[-1] == "." for r in rows):
            raise SystemExit("%s.txt:%d: %s has an empty last column" % (font_id, n, ch))
        glyphs[ch] = rows
    missing = [c for c in REQUIRED if c not in glyphs]
    if missing:
        raise SystemExit("%s.txt: missing glyphs: %s" % (font_id, "".join(missing)))
    return cell[0], cell[1], cell[2], space, glyphs


def gd_string(s):
    return '"' + s.replace("\\", "\\\\").replace('"', '\\"') + '"'


def gd_source(fonts):
    out = ["class_name EraFontGlyphs", "extends RefCounted",
           "## Glyph tables of Chimora's own era fonts (EN and DE), built by",
           "## tools/fonts/build_era_fonts.py from tools/fonts/src/*.txt. Do not edit by hand.",
           "## EraFont turns a table into a bitmap FontFile; EraText says which era uses which.", "",
           "const FONTS: Dictionary = {"]
    for font_id, name, (cw, chh, asc, space, glyphs) in fonts:
        out.append('\t%s: {"name": %s, "cell_w": %d, "cell_h": %d, "ascent": %d, "space": %d, "glyphs": {'
                   % (gd_string(font_id), gd_string(name), cw, chh, asc, space))
        for ch, rows in glyphs.items():
            out.append("\t\t%s: [%s]," % (gd_string(ch), ", ".join(gd_string(r) for r in rows)))
        out.append("\t}},")
    out.append("}")
    return "\n".join(out) + "\n"


def text_width(text, glyphs, space):
    return sum((space if c == " " else len(glyphs[c][0]) + 1) for c in text)


def specimen(path, cell_h, space, glyphs):
    from PIL import Image
    scale, pad, lead = 2, 4, 2
    w = max(text_width(t, glyphs, space) for t in SPECIMEN) + pad * 2
    h = len(SPECIMEN) * (cell_h + lead) + pad * 2
    img = Image.new("RGB", (w, h), (0xF4, 0xF1, 0xE6))
    px = img.load()
    for li, text in enumerate(SPECIMEN):
        x = pad
        y = pad + li * (cell_h + lead)
        for c in text:
            if c == " ":
                x += space
                continue
            for ry, row in enumerate(glyphs[c]):
                for rx, v in enumerate(row):
                    if v == "#":
                        px[x + rx, y + ry] = (0x2A, 0x1E, 0x2C)
            x += len(glyphs[c][0]) + 1
    img.resize((w * scale, h * scale), Image.NEAREST).save(path)


def main():
    fonts = [(fid, name, parse(fid)) for fid, name in FONTS]
    src = gd_source(fonts)
    if "--check" in sys.argv:
        if not os.path.exists(OUT_GD) or open(OUT_GD, encoding="utf-8").read() != src:
            raise SystemExit("scripts/ui/EraFontGlyphs.gd is stale: run python3 tools/fonts/build_era_fonts.py")
        print("era fonts: up to date")
        return
    with open(OUT_GD, "w", encoding="utf-8") as fh:
        fh.write(src)
    for fid, _name, (_cw, chh, _asc, space, glyphs) in fonts:
        specimen(OUT_PNG % fid, chh, space, glyphs)
        print("%s: %d glyphs" % (fid, len(glyphs)))


if __name__ == "__main__":
    main()
