#!/usr/bin/env python3
"""Overworld figures for Eras III-V and the emote bubbles for Eras II-V (docs/ERA_FEEL_CHARS.md).

Source: the own Era I sheets in art/era1/chars (64x32, four inks). Each ink of a figure belongs
to a zone (hat or hair, band, skin, top, trim, trousers, shoes) by where it sits, and every
zone gets its own colour from PALETTES below, so a figure carries far more than four colours.

  Era III  art/era3/actors/<style>.png  16x16 frames, light from the top left (3 tones per
           zone), left and right foot, running poses, a wading pose
           (wading boots, knee-deep in water, on foot)
  Era IV   art/era4/actors/<style>.png  16x24 frames (longer body and legs drawn new), coloured
           outlines, half steps, head-turn rows
  Era V    art/era5/actors/<style>.png  like IV plus rim light, breathing and blinking rows, and
           four season outfits side by side (spring, summer, autumn, winter)
  Emotes   art/eraN/actors/emotes.png   16x16 bubbles, one column per kind, one row per frame

Rows, kinds and seasons come from data/era_actor_look.json. Sheets have 4 columns: down, up,
left, right. Run: python3 tools/art/gen_era_chars.py   (--check compares with the files)
"""
from __future__ import annotations

import colorsys, io, json, os, sys
from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = json.load(open(os.path.join(ROOT, "data", "era_actor_look.json"), encoding="utf-8"))
INK = [(0x2A, 0x1E, 0x2C), (0x6A, 0x42, 0x56), (0xC4, 0x8A, 0x5E), (0xF2, 0xE3, 0xC2)]
T = 16
DIRS = ["down", "up", "left", "right"]
CW = {"down": "left", "left": "up", "up": "right", "right": "down"}
CCW = {v: k for k, v in CW.items()}

# Zone colours per figure: H hat or hair, A band, S skin, T top, R trim, P trousers, O shoes.
PALETTES = {
    "tamer": {"F": "6e4a2a", "H": "3d5fa8", "A": "e8c24a", "S": "f0c8a0", "T": "c8503c", "R": "f2ead8", "P": "3a4460", "O": "5a3a28"},
    "tamer_f": {"F": "d8b45a", "H": "a8436a", "A": "f0d870", "S": "f2ccaa", "T": "3a8a8a", "R": "f6eede", "P": "4a3a5c", "O": "6a4030"},
    "villager": {"H": "7a5230", "A": "a87a44", "S": "eec09a", "T": "6e9a4a", "R": "e8dcb8", "P": "5a4a3a", "O": "4a3424"},
    "ranger": {"H": "3e6a44", "A": "c8a850", "S": "e4b890", "T": "4e7a52", "R": "d8cc9a", "P": "4a4030", "O": "3a2c20"},
    "elder": {"H": "d8d4e0", "A": "9a8ab0", "S": "e8c4a8", "T": "7a6a9e", "R": "c8b8e0", "P": "5a4e78", "O": "3e3450"},
    "warden": {"H": "50546e", "A": "d8b04a", "S": "e0b490", "T": "5a5e80", "R": "d8dce8", "P": "3c4058", "O": "2c2e40"},
    "stranger": {"H": "8a3e3a", "A": "d8a060", "S": "e4b48c", "T": "7a4a40", "R": "c89868", "P": "4a3430", "O": "3a2824"},
    "stranger_hat": {"H": "4e5a52", "A": "a8b09a", "S": "dcae88", "T": "5a6a5e", "R": "b8b89a", "P": "3e4640", "O": "2e322e"},
    "stranger_runner": {"H": "c8742a", "A": "f0c060", "S": "e8b88c", "T": "8a6238", "R": "d8b078", "P": "5a4428", "O": "3c2c1c"},
    "stranger_kid": {"H": "5a5a8e", "A": "a8a8d8", "S": "f2cca8", "T": "6a6aa0", "R": "c8c8e8", "P": "44446a", "O": "30304a"},
}
ROBED = {"elder", "warden"}
SHORT = {"stranger_kid"}
BELTED = {"tamer", "tamer_f", "villager", "ranger"}
ORB = {"first_voice"}
ORB_RAMP = ["2e2440", "6a5a9e", "b4a8d8", "f4f0fa"]
OUTLINE = (0x22, 0x1c, 0x2a)
WATER = {"~": "dcecf4", "v": "6a9ab8"}

# Era IV/V legs, 6 rows. K outline, P trousers (Q = the far leg, darker), O shoes.
TALL_LEGS = {
    "down": {
        "stand": ["...KPPK..KPPK...", "...KPPK..KPPK...", "...KPPK..KPPK...", "...KPPK..KPPK...", "...KOOK..KOOK...", "...KKKK..KKKK..."],
        "half": ["...KPPK..KPPK...", "...KPPK..KPPK...", "...KPPK..KPPK...", "...KOOK..KPPK...", "...KKKK..KOOK...", ".........KKKK..."],
        "step": ["...KPPK..KPPK...", "...KPPK..KPPK...", "...KOOK..KPPK...", "...KKKK..KPPK...", ".........KOOK...", ".........KKKK..."],
        "run": ["...KPPK..KPPK...", "...KOOK..KPPK...", "...KKKK..KPPK...", ".........KPPK...", ".........KOOK...", ".........KKKK..."],
    },
    "right": {
        "stand": ["......KPPK......", "......KPPK......", "......KPPK......", "......KPPK......", "......KOOOK.....", "......KKKKK....."],
        "half": ["......KPPPK.....", ".....KQQKPK.....", ".....KQKKPPK....", ".....KQK.KPK....", "....KOOK.KOOK...", "....KKKK.KKKKK.."],
        "step": [".....KQQPPK.....", "....KQQKKPPK....", "...KQQK..KPPK...", "...KQK....KPK...", "..KOOK....KOOK..", "..KKKK....KKKKK."],
        "run": [".....KQQPPK.....", "...KKQQKKPPK....", "..KOQQK..KPPK...", "..KOK.....KPPK..", "..KK......KOOK..", "..........KKKKK."],
    },
}
TALL_HEM = {
    "down": {
        "stand": ["..KTTTTTTTTTTK..", "..KTTtTTTTtTTK..", "..KTTtTTTTtTTK..", "..KTTTTTTTTTTK..", "..KKKKKKKKKKKK..", "...KK......KK..."],
        "step": ["..KTTTTTTTTTTK..", "..KTTtTTTTtTTK..", "..KTTTtTTtTTTK..", "..KTTTTTTTTTTK..", "..KKKKKKKKKKKK..", "...KK..........."],
    },
    "right": {
        "stand": ["...KTTTTTTtK....", "...KTTTTTTtK....", "...KTTtTTTtK....", "...KTTTTTTTK....", "...KKKKKKKKK....", "....KK..KK......"],
        "step": ["...KTTTTTTtK....", "...KTTTTTTtK....", "...KTTTtTTtK....", "...KTTTTTTTK....", "...KKKKKKKKK....", "......KKK......."],
    },
}
SHORT_LEGS = {  # 4 rows for the kid
    "down": {
        "stand": ["....KPK..KPK....", "....KPK..KPK....", "....KOK..KOK....", "....KKK..KKK...."],
        "half": ["....KPK..KPK....", "....KOK..KPK....", "....KKK..KOK....", ".........KKK...."],
        "step": ["....KOK..KPK....", "....KKK..KPK....", ".........KOK....", ".........KKK...."],
        "run": ["....KOK..KPK....", "....KKK..KPK....", ".........KOK....", ".........KKK...."],
    },
    "right": {
        "stand": ["......KPPK......", "......KPPK......", "......KOOK......", "......KKKK......"],
        "half": ["......KQPK......", ".....KQKPK......", ".....KOKOK......", ".....KKKKK......"],
        "step": [".....KQKPK......", "....KQK.KPK.....", "....KOK.KOK.....", "....KKK.KKK....."],
        "run": [".....KQKPK......", "...KOQK.KPK.....", "...KK...KOK.....", "........KKK....."],
    },
}

# Emote glyphs, 7 wide: # main colour, + second colour.
GLYPHS = {
    "alert": [["..##...", "..##...", "..##...", "..##...", ".......", "..##..."], ["..##...", "..##...", "..##...", "..##...", ".......", "..##..."]],
    "question": [[".###...", "#..##..", "...##..", "..##...", ".......", "..##..."], [".###...", "#..##..", "...##..", "..##...", ".......", "..##..."]],
    "dots": [[".......", ".......", ".......", "#.#.#..", ".......", "......."], [".......", ".......", "#......", "..#.#..", ".......", "......."]],
    "heart": [[".#.#...", "#####..", "#####..", ".###...", "..#....", "......."], ["##.##..", "#####..", "#####..", ".###...", "..#....", "......."]],
    "note": [["..###..", "..#+#..", "..#.#..", ".##.##.", ".##.##.", "......."], ["..###..", "..#+#..", "..#.#..", "###.#..", "###.##.", ".....#."]],
    "zzz": [["###....", ".#.....", "###.++.", "....+..", "....++.", "......."], [".###...", "..#....", ".###++.", ".....+.", "....++.", "......."]],
    "drop": [["..#....", "..#....", ".###...", "#+###..", "#####..", ".###..."], [".......", "..#....", ".###...", "#+###..", "#####..", ".###..."]],
}
GLYPH_COL = {"alert": ("d83c3c", "f0a0a0"), "question": ("3a6ad0", "a0b8f0"), "dots": ("5a5a6a", "a0a0b0"),
             "heart": ("e05088", "f8b0c8"), "note": ("2e9a5a", "a0e0b8"), "zzz": ("6a5ab8", "b8b0e8"),
             "drop": ("3a90d0", "d0ecfa")}


def rgb(h: str) -> tuple:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def tone(c: tuple, k: float, cool: float = 0.0) -> tuple:
    """Lighter (k > 0) or darker (k < 0); shadows drift to violet, lights to yellow."""
    if k < 0:  # darker: scale the colour itself, then let the hue sink a little
        c = tuple(v * (1 + k) for v in c)
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
    if k < 0:
        s = min(1.0, s * 1.06)
        if s > 0.05:  # warm colours sink toward red, cool ones toward blue (never through green)
            h = (h + (-0.02 if (h < 0.2 or h > 0.9) else 0.03 if h < 0.45 else 0.02) * (1 + cool)) % 1
    else:
        l = l + (1 - l) * k
        if s > 0.05 and 0.02 < h < 0.6:
            h = h + (0.13 - h) * 0.10
    r, g, b = colorsys.hls_to_rgb(h, max(0.0, min(1.0, l)), s)
    return (round(r * 255), round(g * 255), round(b * 255))


def shift(c: tuple, dh: float = 0.0, dl: float = 0.0, ds: float = 0.0) -> tuple:
    h, l, s = colorsys.rgb_to_hls(*(v / 255 for v in c))
    r, g, b = colorsys.hls_to_rgb((h + dh) % 1, max(0.0, min(1.0, l + dl)), max(0.0, min(1.0, s + ds)))
    return (round(r * 255), round(g * 255), round(b * 255))


def blank(w: int, h: int) -> list:
    return [[None] * w for _ in range(h)]


def source(style: str) -> dict:
    """{dir: [stand, step]} as 16x16 grids of ink index (None = empty)."""
    im = Image.open(os.path.join(ROOT, "art", "era1", "chars", style + ".png")).convert("RGBA")
    idx = {c: i for i, c in enumerate(INK)}
    out = {}
    for col, d in enumerate(DIRS):
        out[d] = []
        for fr in range(2):
            g = blank(T, T)
            for y in range(T):
                for x in range(T):
                    r, gg, b, a = im.getpixel((col * T + x, fr * T + y))
                    if a:
                        g[y][x] = idx[(r, gg, b)]
            out[d].append(g)
    return out


# Head inks that are not hat, band, skin: the elder's white hair and beard around a small face,
# the Warden's hood with a dark opening and lit eyes.
HEAD_ZONES = {"elder": "KHSH", "warden": "KHAE"}


# The Wayfarer's own look (skin tone, hair colour, coat from the new-game screen and the shop)
# is painted in at run time: head inks below the cap brim, and which colours belong to skin (S),
# hair (F) and coat (T) go to data/era_actor_zones.json with their tone step.
LOOKS = {"tamer": "KFFS", "tamer_f": "KFFS"}
GROUPS = {"S": "skin", "s": "skin", "F": "hair", "T": "coat", "t": "coat"}
REC: dict = {}
OTHER: dict = {}


def note(era: int, style: str, z: str, c: tuple, k: float) -> None:
    if style not in LOOKS:
        return
    hexc = "%02x%02x%02x" % c
    if z in GROUPS:
        REC.setdefault((era, style), {}).setdefault(GROUPS[z], {})[hexc] = k
    else:
        OTHER.setdefault((era, style), set()).add(hexc)


def zones(g: list, robed: bool, style: str = "", facing: str = "down") -> list:
    """Ink index grid -> zone letter grid."""
    out = blank(T, T)
    for y in range(T):
        for x in range(T):
            v = g[y][x]
            if v is None:
                continue
            if y < 8:
                z = HEAD_ZONES.get(style, "KHAS")[v]
                if style in LOOKS:  # the Wayfarer: cap with a badge above the brim, hair below it
                    z = ("KHAA" if y <= 3 else LOOKS[style])[v]
            elif y < 13:
                z = ("KTGS" if facing == "up" else "KTRS")[v]
            elif robed:
                z = "KTTS"[v]
            else:
                z = "KTPS"[v]
                if v == 0 and y == 14 and g[y - 1][x] is not None:
                    z = "O"
            out[y][x] = z
    return out


def stamp(dst: list, rows: list, oy: int, mirror: bool = False) -> None:
    for y, row in enumerate(rows):
        if mirror:
            row = row[::-1]
        for x, ch in enumerate(row):
            if ch != "." and 0 <= oy + y < len(dst):
                dst[oy + y][x] = ch


def paste(dst: list, src: list, y0: int, y1: int, oy: int, ox: int = 0) -> None:
    """Rows y0..y1-1 of src onto dst at row oy, shifted ox."""
    for y in range(y0, y1):
        for x in range(T):
            v = src[y][x]
            ty, tx = oy + y - y0, x + ox
            if v is not None and 0 <= ty < len(dst) and 0 <= tx < T:
                dst[ty][tx] = v


def mirrored(g: list) -> list:
    return [row[::-1] for row in g]


def swap_far(g: list) -> list:
    sw = {"P": "Q", "Q": "P"}
    return [[sw.get(v, v) for v in row] for row in g]


def eyes(g: list) -> list:
    """Cells of the eyes: outline pixels inside the face."""
    out = []
    for y in range(1, 8):
        for x in range(1, T - 1):
            if g[y][x] == "K" and g[y - 1][x] == "S" and None not in (g[y][x - 1], g[y][x + 1], g[y + 1][x]):
                out.append((x, y))
    return out


def face_of(d: str) -> str:
    return "right" if d == "left" else d


class Figure:
    """Poses of one figure as zone grids, for one sheet height."""

    def __init__(self, style: str, tall: bool):
        self.style, self.tall = style, tall
        self.robed, self.short = style in ROBED, style in SHORT
        src = source(style)
        self.z = {d: [zones(g, self.robed, style, d) for g in src[d]] for d in ("down", "up", "right")}
        self.h = 24 if tall else 16
        # Body rows of the long figure: the 5 source rows stretched.
        self.body_map = [8, 9, 10, 10, 11, 12] if self.short else [8, 9, 9, 10, 10, 11, 12]

    def _legs(self, d: str, pose: str, foot: str) -> list:
        """Leg rows for the long figure."""
        table = SHORT_LEGS if self.short else (TALL_HEM if self.robed else TALL_LEGS)
        rows = table["right" if d == "right" else "down"]
        key = pose if pose in rows else ("step" if pose == "run" else "stand")
        art = rows[key] if self.short else [rows[key][0]] + rows[key]  # one more row of leg
        g = blank(T, len(art))
        stamp(g, art, 0, mirror=(d != "right" and foot == "r"))
        if d == "right" and foot == "r":
            g = swap_far(g)
        return g

    def pose(self, d: str, pose: str = "stand", foot: str = "l", head: str = "", lean: bool = False,
             sag: int = 0, blink: bool = False, wade: bool = False, head_flip: bool = False) -> list:
        """One frame facing d (down, up or right). head: other direction the head looks in."""
        g = blank(T, self.h)
        stand = self.z[d][0]
        hd = self.z[head][0] if head else stand
        if head_flip:
            hd = mirrored(hd)
        if not self.tall:
            base = self.z[d][1] if pose in ("step", "run") else stand
            body = [row[:] for row in base]
            for y in range(8):
                body[y] = [None] * T
            if pose in ("step", "run") and foot == "r":
                if d == "right":
                    for y in range(13, T):
                        body[y] = [("Q" if v == "P" and x >= 8 else v) for x, v in enumerate(body[y])]
                else:
                    for y in range(13, T):
                        body[y] = body[y][::-1]
            elif pose in ("step", "run") and d == "right":
                for y in range(13, T):
                    body[y] = [("Q" if v == "P" and x < 8 else v) for x, v in enumerate(body[y])]
            if pose == "run":
                self._pump(body, 10, 9, foot, d)
            if wade:
                paste(g, stand, 8, 12, 10)
                self._water(g, 13)
                paste(g, hd, 0, 8, 2)
            else:
                paste(g, body, 8, T, 8)
                paste(g, hd, 0, 8, 1 if lean else sag, (1 if d == "right" and lean else 0))
        else:
            n = len(self.body_map)
            legs = self._legs(d, pose, foot)
            top = self.h - 1 - len(legs) - n - 8  # first head row
            bmap = self.body_map
            if sag:
                bmap = bmap[:2] + bmap[3:]
            body = blank(T, len(bmap))
            for i, sy in enumerate(bmap):
                body[i] = stand[sy][:]
            if pose == "run":
                self._pump(body, bmap.index(10), bmap.index(10) - 1, foot, d)
            if wade:
                m = len(body) - 2
                paste(g, body, 0, m, self.h - 4 - m)
                self._water(g, self.h - 3)
                self._paste_head(g, hd, self.h - 4 - m - 8, 0)
            else:
                by = top + 8 + (n - len(bmap))
                paste(g, body, 0, len(body), by)
                # belt line between top and legs
                if self.style in BELTED:
                    for x in range(T):
                        if g[by + len(body) - 1][x] in ("T", "R"):
                            g[by + len(body) - 1][x] = "B"
                for y, row in enumerate(legs):
                    for x, v in enumerate(row):
                        if v is not None:
                            g[self.h - 1 - len(legs) + y][x] = v
                self._paste_head(g, hd, top + sag + (1 if lean else 0), 1 if d == "right" and lean else 0)
        if blink:
            for (x, y) in eyes(g):
                g[y][x] = "s"
        return g

    def _paste_head(self, g: list, hd: list, oy: int, ox: int) -> None:
        paste(g, hd, 0, 8, oy, ox)

    @staticmethod
    def _pump(body: list, hand_row: int, up_row: int, foot: str, d: str) -> None:
        """Running: one hand swings a row up."""
        xs = [x for x in range(T) if body[hand_row][x] == "S"]
        if not xs:
            return
        x = xs[0] if (foot == "l" or len(xs) == 1) else xs[-1]
        if body[up_row][x] not in (None, "K"):
            body[hand_row][x], body[up_row][x] = body[up_row][x], "S"

    def _water(self, g: list, y: int) -> None:
        """Shallow water around the shins: the Wayfarer wades on foot (wading boots)."""
        stamp(g, ["..~~~~~~~~~~~~..", ".v~~v~~~~~v~~v~.", "...v....v....v.."], y)


def orb_frames(tall: bool, rows: dict) -> dict:
    """The First Voice light: its two Era I frames on every row, on a soft ramp."""
    im = Image.open(os.path.join(ROOT, "art", "era1", "chars", "first_voice.png")).convert("RGBA")
    idx = {c: i for i, c in enumerate(INK)}
    h = 24 if tall else 16
    fr = []
    for f in range(2):
        g = blank(T, h)
        for y in range(T):
            for x in range(T):
                r, gg, b, a = im.getpixel((x, f * T + y))
                if a:
                    g[h - T + y][x] = "0123"[idx[(r, gg, b)]]
        fr.append(g)
    out = {}
    for name in rows:
        f = fr[1] if name in ("step_l", "step_r", "run_l", "run_r", "half_l", "half_r", "breathe") else fr[0]
        out[name] = {d: f for d in DIRS}
    return out


def poses(style: str, era: int) -> dict:
    """{row name: {dir: zone grid}} for one era."""
    rows = CFG["eras"][str(era)]["rows"]
    tall = CFG["eras"][str(era)]["frame"][1] > 16
    if style in ORB:
        return orb_frames(tall, rows)
    fig = Figure(style, tall)
    out = {}
    for name in rows:
        out[name] = {}
        for d in DIRS:
            f = face_of(d)
            if name == "stand":
                g = fig.pose(f)
            elif name in ("step_l", "step_r", "half_l", "half_r"):
                g = fig.pose(f, name[:-2], name[-1])
            elif name in ("run_l", "run_r"):
                g = fig.pose(f, "run", name[-1], lean=True)
            elif name == "wade":
                g = fig.pose(f, wade=True)
            elif name in ("head_cw", "head_ccw"):
                look = (CW if name == "head_cw" else CCW)[d]
                # Left-facing frames are mirrored at the end, so only a real "left" look flips.
                g = fig.pose(f, head=face_of(look), head_flip=(look == "left"))
            elif name == "breathe":
                g = fig.pose(f, sag=1)
            elif name == "blink":
                g = fig.pose(f, blink=True)
            else:
                raise SystemExit("unknown row " + name)
            out[name][d] = mirrored(g) if d == "left" else g
    return out


def season_palette(pal: dict, season: str) -> dict:
    p = {k: rgb(v) for k, v in pal.items()}
    if season == "summer":
        p["T"] = shift(p["T"], dl=0.10, ds=0.08)
        p["R"] = shift(p["R"], dl=0.04)
        p["P"] = shift(p["P"], dl=0.10)
    elif season == "autumn":
        p["T"] = shift(p["T"], dh=-0.035, dl=-0.07, ds=-0.05)
        p["R"] = rgb("d8a850")
        p["P"] = shift(p["P"], dh=-0.03, dl=-0.03)
    elif season == "winter":
        p["T"] = shift(p["T"], dh=0.03, dl=-0.10, ds=-0.12)
        p["R"] = rgb("f4f6fa")
        p["P"] = shift(p["P"], dl=-0.06)
    return p


def dress(g: list, season: str, robed: bool) -> list:
    """Season changes to the zone grid: short sleeves in summer, a scarf in winter."""
    out = [row[:] for row in g]
    h = len(g)
    if season == "summer" and not robed:
        for y in range(1, h):
            for x in range(T):
                if g[y][x] == "S" and g[y - 1][x] == "T" and y > 9:
                    out[y - 1][x] = "S"
                    if g[y - 2][x] == "T":
                        out[y - 2][x] = "S"
    if season == "winter":
        for y in range(1, h - 1):
            for x in range(T):
                # the row under the chin: a scarf
                if g[y][x] in ("T", "R") and g[y - 1][x] in ("S", "K", "H", "A") and _head_above(g, x, y):
                    out[y][x] = "C"
    return out


def _head_above(g: list, x: int, y: int) -> bool:
    return any(g[yy][x] in ("S", "H") for yy in range(max(0, y - 3), y))


STEP = {"t": -0.2, "s": -0.22}  # fold and closed-eye tones, relative to their zone


def render(g: list, pal: dict, era: int, style: str) -> Image.Image:
    """Zone grid -> RGBA image, shaded for the era."""
    h = len(g)
    im = Image.new("RGBA", (T, h), (0, 0, 0, 0))
    if style in ORB:
        ramp = [rgb(c) for c in ORB_RAMP]
        for y in range(h):
            for x in range(T):
                v = g[y][x]
                if v is None:
                    continue
                c = ramp[int(v)]
                if era >= 4 and v == "3" and _at(g, x, y - 1) == "3" and _at(g, x - 1, y) == "3":
                    c = (255, 255, 255)
                im.putpixel((x, y), c + (255,))
        if era >= 4:  # soft halo
            for y in range(h):
                for x in range(T):
                    if g[y][x] is None and any(_at(g, x + dx, y + dy) == "2" for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                        im.putpixel((x, y), ramp[2] + (90,))
        return im
    base = dict(pal)
    base.setdefault("Q", tone(pal["P"], -0.22))
    base.setdefault("B", tone(pal["O"], 0.08))
    base.setdefault("C", rgb("d84848"))
    base.setdefault("G", rgb("9a7448"))
    base.setdefault("E", rgb("f6eca0"))
    base["t"] = tone(pal["T"], STEP["t"])
    base["s"] = tone(pal["S"], STEP["s"])
    for k, v in WATER.items():
        base[k] = rgb(v)
    for y in range(h):
        for x in range(T):
            z = g[y][x]
            if z is None:
                continue
            k, cool, src = 0.0, 0.0, z
            if z == "K":
                c = OUTLINE
                src = ""
                if era >= 4:
                    near = [_at(g, x + dx, y + dy) for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1))]
                    near = [n for n in near if n not in (None, "K")]
                    edge = any(_at(g, x + dx, y + dy) is None for dx, dy in ((0, 1), (1, 0), (-1, 0), (0, -1)))
                    if near and edge:
                        src, k = near[0], -0.62
            elif z not in ("t", "s", "~", "w"):
                r, b, l, a = _at(g, x + 1, y), _at(g, x, y + 1), _at(g, x - 1, y), _at(g, x, y - 1)
                if z == "S" and _is_face(g, x, y):
                    if a in ("H", "A", "F", "K") and _at(g, x, y - 2) in ("H", "A", "F", "K"):
                        k = -0.14
                elif r in (None, "K") or b in (None, "K"):
                    k, cool = -0.24, (0.4 if era >= 5 else 0.0)
                    if era >= 5 and r in (None, "K") and b not in (None, "K") and _at(g, x + 2, y) is None:
                        k, cool = -0.10, 1.0  # rim light
                elif l in (None, "K") or a in (None, "K"):
                    k = 0.20
            if src:
                c = tone(base[src], k, cool) if k else base[src]
            note(era, style, src, c, STEP.get(src, 0.0) + k)
            im.putpixel((x, y), c + (255,))
    return im


def _at(g: list, x: int, y: int):
    if 0 <= y < len(g) and 0 <= x < T:
        return g[y][x]
    return None


def _is_face(g: list, x: int, y: int) -> bool:
    return not any(_at(g, x, yy) in ("T", "R", "C") for yy in range(0, y))


def sheet(style: str, era: int) -> Image.Image:
    cfg = CFG["eras"][str(era)]
    rows, fh = cfg["rows"], cfg["frame"][1]
    seasons = CFG["seasons"] if cfg["outfits"] == "season" else ["spring"]
    p = poses(style, era)
    out = Image.new("RGBA", (T * 4 * len(seasons), fh * len(rows)), (0, 0, 0, 0))
    for si, season in enumerate(seasons):
        pal = season_palette(PALETTES.get(style, {}), season) if style not in ORB else {}
        for name, r in rows.items():
            for col, d in enumerate(DIRS):
                g = p[name][d]
                if style not in ORB:
                    g = dress(g, season, style in ROBED)
                out.paste(render(g, pal, era, style), (si * T * 4 + col * T, r * fh))
    return out


def emotes(era: int) -> Image.Image:
    cfg = CFG["eras"][str(era)]
    kinds, frames, look = CFG["emote_kinds"], cfg["emote_frames"], cfg["emote_style"]
    out = Image.new("RGBA", (T * len(kinds), T * frames), (0, 0, 0, 0))
    paper, edge, shade = (250, 248, 240), (40, 34, 50), (206, 200, 214)
    for ki, kind in enumerate(kinds):
        for f in range(frames):
            ox, oy = ki * T, f * T
            px = out.load()
            if look in ("shadow", "live"):  # drop shadow
                for y in range(2, 13):
                    for x in range(3, 15):
                        if not ((x in (3, 14)) and (y in (2, 12))):
                            px[ox + x, oy + y] = (20, 16, 30, 70)
            for y in range(1, 12):
                for x in range(2, 14):
                    corner = (x in (2, 13)) and (y in (1, 11))
                    if corner:
                        continue
                    border = x in (2, 13) or y in (1, 11) or ((x in (3, 12)) and (y in (2, 10)))
                    c = edge if border else paper
                    if not border and look != "flat" and (y == 10 or x == 12):
                        c = shade
                    if not border and look in ("shadow", "live") and y == 2 and 4 <= x <= 7:
                        c = (255, 255, 255)
                    px[ox + x, oy + y] = c + (255,)
            if look != "flat":  # tail
                for (x, y, c) in ((6, 11, paper), (7, 11, paper), (5, 12, edge), (6, 12, paper), (7, 12, edge), (6, 13, edge)):
                    px[ox + x, oy + y] = c + (255,)
            main, second = (rgb(c) for c in GLYPH_COL[kind])
            if look == "flat":
                second = main
            gl = GLYPHS[kind][f if frames > 1 else 0]
            for y, row in enumerate(gl):
                for x, ch in enumerate(row):
                    if ch == "#":
                        px[ox + 5 + x, oy + 3 + y] = main + (255,)
                    elif ch == "+":
                        px[ox + 5 + x, oy + 3 + y] = second + (255,)
    return out


def outputs() -> dict:
    out = {}
    for era in (3, 4, 5):
        for style in CFG["styles"]:
            out[f"art/era{era}/actors/{style}.png"] = sheet(style, era)
    for era in (2, 3, 4, 5):
        out[f"art/era{era}/actors/emotes.png"] = emotes(era)
    return out


ZONES_PATH = "data/era_actor_zones.json"


def zone_table() -> str:
    """Call after outputs(): the Wayfarer's skin, hair and coat colours per era sheet."""
    doc = {"_doc": "Made by tools/art/gen_era_chars.py, do not edit. Per era and Wayfarer sheet: the sheet colours "
                   "that are skin, hair and coat, each with its tone step (below 0 darker, above 0 lighter). "
                   "EraActorLook.player_sheet() repaints them in the player's own look."}
    for (era, style), groups in sorted(REC.items()):
        used = {}
        for name, cols in groups.items():
            for c in cols:
                assert c not in used and c not in OTHER[(era, style)], (era, style, name, c)
                used[c] = name
        doc.setdefault(str(era), {})[style] = {n: dict(sorted(groups[n].items())) for n in sorted(groups)}
    return json.dumps(doc, indent=1) + "\n"


def png(im: Image.Image) -> bytes:
    b = io.BytesIO()
    im.save(b, "PNG", optimize=True)
    return b.getvalue()


def main() -> None:
    check = "--check" in sys.argv
    bad = []
    for rel, im in outputs().items():
        path = os.path.join(ROOT, rel)
        if check:
            if not os.path.exists(path) or Image.open(path).convert("RGBA").tobytes() != im.tobytes():
                bad.append(rel)
            continue
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(png(im))
    table = zone_table()
    zpath = os.path.join(ROOT, ZONES_PATH)
    if check:
        if not os.path.exists(zpath) or open(zpath, encoding="utf-8").read() != table:
            bad.append(ZONES_PATH)
    else:
        open(zpath, "w", encoding="utf-8").write(table)
    if bad:
        print("out of date (run tools/art/gen_era_chars.py):\n  " + "\n  ".join(bad))
        sys.exit(1)
    print("era figures: %d files %s" % (len(outputs()), "match" if check else "written"))


if __name__ == "__main__":
    main()
