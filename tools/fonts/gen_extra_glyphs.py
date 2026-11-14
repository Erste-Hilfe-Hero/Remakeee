#!/usr/bin/env python3
"""Writes scripts/ui/PixelFontExtra.gd: the accented Latin letters and the Cyrillic alphabet of the
Chimora pixel font, for French, Italian, Spanish, Portuguese, Polish, Turkish, Dutch and Russian.

Accented letters are composed from the base glyphs in scripts/ui/PixelFont.gd and an accent drawn
here (lower case: the accent sits in the two rows above the x-height; capitals: the letter is
squashed by a row, as the German umlauts are). Letters without a base (Cyrillic, ł, œ, ¿ ...) are
drawn by hand below. All glyphs are our own (5x9 grid, 7 rows above the baseline, 2 below).
Run after changing a glyph: python3 tools/fonts/gen_extra_glyphs.py
"""
import os, re, unicodedata

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = open(os.path.join(ROOT, "scripts/ui/PixelFont.gd"), encoding="utf-8").read()
BASE = {}
for m in re.finditer(r'^\t"((?:\\.|[^"\\])+)": \[([^\]]*)\]', SRC, re.M):
    key = m.group(1).encode("utf-8").decode("unicode_escape") if "\\" in m.group(1) else m.group(1)
    rows = re.findall(r'"([.#]{5})"', m.group(2))
    if len(rows) == 9:
        BASE[key] = rows

E5 = "....."
# Lower-case accents: two rows above the x-height (rows 0 and 1).
LOW = {
    "́": ["...#.", "..#.."],   # acute
    "̀": [".#...", "..#.."],   # grave
    "̂": ["..#..", ".#.#."],   # circumflex
    "̃": [".#..#", "#.##."],   # tilde
    "̈": [".#.#.", E5],        # diaeresis (as ä ö ü)
    "̇": ["..#..", E5],        # dot above
    "̆": ["#...#", ".###."],   # breve
    "̊": [".###.", ".#.#."],   # ring
    "̄": [".###.", E5],        # macron
}
# Capital accents: one row on top of the squashed letter.
CAP = {
    "́": "...#.", "̀": ".#...", "̂": ".#.#.", "̃": ".##.#", "̈": "#...#",
    "̇": "..#..", "̆": ".###.", "̊": "..#..", "̄": "#####",
}
# Marks below the baseline (rows 7 and 8).
BELOW = {"̧": ["..#..", ".##.."], "̨": ["...#.", "...##"]}

def squash(body, n):
    """Drops n rows from a 7-row capital, first rows that repeat the row above."""
    rows = list(body)
    for _ in range(n):
        for i in (3, 2, 4, 1, 5):
            if i < len(rows) - 1 and rows[i] == rows[i - 1]:
                del rows[i]
                break
        else:
            del rows[len(rows) // 2]
    return rows

def touches(a, b):
    return any(x == "#" and y == "#" for x, y in zip(a, b))

def compose(ch):
    d = unicodedata.normalize("NFD", ch)
    base, marks = d[0], d[1:]
    if base == "i" and marks:
        base = "ı"
    g = list(HAND.get(base) or BASE.get(base) or [])
    if not g:
        return None
    for mk in marks:
        if mk in BELOW:
            if g[7] != E5 or g[8] != E5:
                return None
            g[7:9] = BELOW[mk]
        elif base.isupper():
            body = g[:7]
            top = CAP[mk]
            if touches(top, body[0]) or (mk == "̈" and body[0][0] == "#"):
                body = [top, E5] + squash(body, 2)
            else:
                body = [top] + squash(body, 1)
            g[:7] = body
        else:
            if g[0] != E5 or g[1] != E5:
                return None
            g[0:2] = LOW[mk]
    return g

def R(*rows):
    rows = list(rows)
    return rows + [E5] * (9 - len(rows))

def LOWB(*body, below=(E5, E5)):
    """A lower-case glyph from its five x-height rows (2-6) and two rows below."""
    return [E5, E5] + list(body) + list(below)

HAND = {
    # Latin letters without a simple base + accent.
    "ı": LOWB(".##..", "..#..", "..#..", "..#..", ".###."),
    "ł": R(".##..", "..#..", "..#..", "..##.", ".##..", "..#..", ".###."),
    "Ł": R("#....", "#....", "#.#..", "##...", "#....", "#....", "#####"),
    "œ": LOWB(".#.#.", "#.#.#", "#.###", "#.#..", ".#.##"),
    "Œ": R(".####", "#.#..", "#.#..", "#.###", "#.#..", "#.#..", ".####"),
    "æ": LOWB("##.#.", "..#.#", ".####", "#.#..", ".#.##"),
    "Æ": R(".####", "#.#..", "#.#..", "#####", "#.#..", "#.#..", "#.###"),
    "ð": R(".#.#.", "..#..", ".#.#.", "....#", ".####", "#...#", ".###."),
    "Ð": R(".###.", ".#..#", ".#..#", "###.#", ".#..#", ".#..#", ".###."),
    "þ": [E5, "#....", "#....", "####.", "#...#", "#...#", "####.", "#....", "#...."],
    "Þ": R("#....", "####.", "#...#", "#...#", "####.", "#....", "#...."),
    "ø": LOWB(".####", "#..##", "#.#.#", "##..#", "####."),
    "Ø": R(".####", "#..##", "#.#.#", "#.#.#", "#.#.#", "##..#", "####."),
    "¿": R("..#..", E5, "..#..", ".#...", "#....", "#...#", ".###."),
    "¡": R("..#..", E5, "..#..", "..#..", "..#..", "..#..", "..#.."),
    "ª": R(".###.", "#..#.", ".###.", E5, ".###."),
    "º": R(".##..", "#..#.", ".##..", E5, ".##.."),
    "°": R(".#...", "#.#..", ".#...", E5),
    "·": R(E5, E5, E5, "..#..", E5),
    "…": R(E5, E5, E5, E5, E5, E5, "#.#.#"),
    "–": R(E5, E5, E5, "####.", E5),
    "—": R(E5, E5, E5, "#####", E5),
    "‘": R("..#..", ".#...", ".#..."),
    "’": R("..#..", "..#..", ".#..."),
    "‚": R(E5, E5, E5, E5, E5, "..#..", "..#..", ".#..."),
    "“": R(".#.#.", "#.#..", "#.#.."),
    "”": R(".#.#.", ".#.#.", "#.#.."),
    "„": R(E5, E5, E5, E5, E5, ".#.#.", ".#.#.", "#.#.."),
    "«": R(E5, E5, "..#.#", ".#.#.", "#.#..", ".#.#.", "..#.#"),
    "»": R(E5, E5, "#.#..", ".#.#.", "..#.#", ".#.#.", "#.#.."),
    "×": R(E5, "#...#", ".#.#.", "..#..", ".#.#.", "#...#", E5),
    "№": R("#..#.", "##.#.", "#.##.", "#..#.", "#..#.", E5, "...##"),
    " ": R(),
    # Cyrillic capitals (shapes shared with Latin letters come from the base glyphs).
    "Б": R("#####", "#....", "#....", "####.", "#...#", "#...#", "####."),
    "Г": R("#####", "#....", "#....", "#....", "#....", "#....", "#...."),
    "Д": [".###.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", ".#.#.", "#####", "#...#", E5],
    "Ж": R("#.#.#", "#.#.#", ".###.", "..#..", ".###.", "#.#.#", "#.#.#"),
    "З": R(".###.", "#...#", "....#", "..##.", "....#", "#...#", ".###."),
    "И": R("#...#", "#...#", "#..##", "#.#.#", "##..#", "#...#", "#...#"),
    "Л": R(".####", ".#..#", ".#..#", ".#..#", ".#..#", ".#..#", "##..#"),
    "П": R("#####", "#...#", "#...#", "#...#", "#...#", "#...#", "#...#"),
    "У": R("#...#", "#...#", "#...#", ".####", "....#", "#...#", ".###."),
    "Ф": R("..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#.."),
    "Ц": ["#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#..#.", "#####", "....#", E5],
    "Ч": R("#...#", "#...#", "#...#", ".####", "....#", "....#", "....#"),
    "Ш": R("#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"),
    "Щ": ["#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####", "....#", E5],
    "Ъ": R("##...", ".#...", ".#...", ".###.", ".#..#", ".#..#", ".###."),
    "Ы": R("#...#", "#...#", "#...#", "##..#", "#.#.#", "#.#.#", "##..#"),
    "Ь": R("#....", "#....", "#....", "####.", "#...#", "#...#", "####."),
    "Э": R(".###.", "#...#", "....#", "..###", "....#", "#...#", ".###."),
    "Ю": R("#..#.", "#.#.#", "#.#.#", "###.#", "#.#.#", "#.#.#", "#..#."),
    "Я": R(".####", "#...#", "#...#", ".####", "..#.#", ".#..#", "#...#"),
    # Cyrillic small letters.
    "б": R("..##.", ".#...", "#....", "####.", "#...#", "#...#", ".###."),
    "в": LOWB("####.", "#...#", "####.", "#...#", "####."),
    "г": LOWB("#####", "#....", "#....", "#....", "#...."),
    "д": LOWB(".###.", ".#.#.", ".#.#.", ".#.#.", "#####", below=("#...#", E5)),
    "ж": LOWB("#.#.#", ".###.", "..#..", ".###.", "#.#.#"),
    "з": LOWB("####.", "....#", ".###.", "....#", "####."),
    "и": LOWB("#...#", "#..##", "#.#.#", "##..#", "#...#"),
    "к": LOWB("#...#", "#..#.", "###..", "#..#.", "#...#"),
    "л": LOWB(".####", ".#..#", ".#..#", ".#..#", "##..#"),
    "м": LOWB("#...#", "##.##", "#.#.#", "#...#", "#...#"),
    "н": LOWB("#...#", "#...#", "#####", "#...#", "#...#"),
    "п": LOWB("#####", "#...#", "#...#", "#...#", "#...#"),
    "т": LOWB("#####", "..#..", "..#..", "..#..", "..#.."),
    "ф": [E5, "..#..", ".###.", "#.#.#", "#.#.#", "#.#.#", ".###.", "..#..", E5],
    "ц": LOWB("#..#.", "#..#.", "#..#.", "#..#.", "#####", below=("....#", E5)),
    "ч": LOWB("#...#", "#...#", ".####", "....#", "....#"),
    "ш": LOWB("#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####"),
    "щ": LOWB("#.#.#", "#.#.#", "#.#.#", "#.#.#", "#####", below=("....#", E5)),
    "ъ": LOWB("##...", ".#...", ".###.", ".#..#", ".###."),
    "ы": LOWB("#...#", "#...#", "##..#", "#.#.#", "##..#"),
    "ь": LOWB("#....", "#....", "####.", "#...#", "####."),
    "э": LOWB("####.", "....#", "..###", "....#", "####."),
    "ю": LOWB("#..#.", "#.#.#", "###.#", "#.#.#", "#..#."),
    "я": LOWB(".####", "#...#", ".####", ".#..#", "#...#"),
}
# Cyrillic letters that look like Latin ones reuse those glyphs.
SAME = {"А": "A", "В": "B", "Е": "E", "К": "K", "М": "M", "Н": "H", "О": "O", "Р": "P", "С": "C",
        "Т": "T", "Х": "X", "а": "a", "е": "e", "о": "o", "р": "p", "с": "c", "у": "y", "х": "x",
        "І": "I", "і": "i", "Ѕ": "S", "ѕ": "s", "Ј": "J", "ј": "j"}

COMPOSED = (
    "ÀÁÂÃÄÅÇÈÉÊËÌÍÎÏÑÒÓÔÕÖÙÚÛÜÝàáâãäåçèéêëìíîïñòóôõöùúûüýÿŸ"
    "ĄąĆćĘęŃńŚśŹźŻżĞğİŞşŌōŪūĀāĒēĪī"
    "ЁёЙй")

def main():
    out = {}
    for ch, rows in HAND.items():
        out[ch] = rows
    for ch, src in SAME.items():
        out[ch] = BASE[src]
    for ch in COMPOSED:
        if ch in BASE:
            continue
        nfd = unicodedata.normalize("NFD", ch)
        base = nfd[0]
        if base in ("Е", "е", "И", "и"):
            # Cyrillic Ё and Й: the base comes from the Latin E/e or the hand-drawn И/и.
            g = compose(ch.translate(str.maketrans({"Ё": "Ë", "ё": "ë"}))) if base in "Ее" else None
            if g is None:
                g = list(HAND[base])
                mk = nfd[1]
                if base.isupper():
                    g[:7] = [CAP[mk]] + squash(g[:7], 1)
                else:
                    g[0:2] = LOW[mk]
        else:
            g = compose(ch)
        if g is None:
            raise SystemExit("cannot compose %r" % ch)
        out[ch] = g
    for ch, g in out.items():
        assert len(g) == 9 and all(len(r) == 5 and set(r) <= {".", "#"} for r in g), ch
    lines = ["class_name PixelFontExtra",
             "extends RefCounted",
             "## Accented Latin letters and Cyrillic for the Chimora pixel font (French, Italian, Spanish,",
             "## Portuguese, Polish, Turkish, Dutch, Russian). Same 5x9 grid as PixelFont.GLYPHS, merged into",
             "## the font by PixelFont. Generated by tools/fonts/gen_extra_glyphs.py, do not edit by hand.",
             "",
             "const GLYPHS: Dictionary[String, Array] = {"]
    for ch in sorted(out, key=ord):
        key = "\\u%04x" % ord(ch) if ord(ch) in (0xa0,) else ch
        lines.append('\t"%s": [%s],' % (key, ", ".join('"%s"' % r for r in out[ch])))
    lines.append("}")
    path = os.path.join(ROOT, "scripts/ui/PixelFontExtra.gd")
    open(path, "w", encoding="utf-8").write("\n".join(lines) + "\n")
    print("%d glyphs -> %s" % (len(out), path))

if __name__ == "__main__":
    main()
