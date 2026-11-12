#!/usr/bin/env python3
"""Speaker portraits for the dialogue box of the later eras (docs/ERA_FEEL_TEXT.md).

Own figures, drawn here from a small set of hand-written shapes (head, hair or headwear, brows,
eyes, mouth, coat) and a colour recipe per speaker. Nothing is traced or taken from elsewhere.

  art/era5/portraits/<id>.png   96x32: three 32 px busts (resting, blink, speaking) - Era V
  art/era4/portraits/<id>.png   12x12 head for the name plate - Era IV

The speakers are the ids of data/era_text.json "speakers"; the script stops when a speaker
there has no recipe below (and the other way round).
Run: python3 tools/art/gen_portraits.py
"""
from __future__ import annotations

import json
import os

from PIL import Image

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
DATA = os.path.join(ROOT, "data/era_text.json")
OUT5 = os.path.join(ROOT, "art/era5/portraits")
OUT4 = os.path.join(ROOT, "art/era4/portraits")
S = 32
ICON = 12
SKIN = {"pale": "f6dcc6", "light": "f1c9a5", "olive": "c69a6b", "tan": "d9a577", "brown": "a66c44", "dark": "6e452c"}


def rgb(h: str) -> tuple:
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16))


def mix(a: tuple, b: tuple, t: float) -> tuple:
    return tuple(int(round(a[i] + (b[i] - a[i]) * t)) for i in range(3))


def dark(c: tuple, t: float = 0.3) -> tuple:
    return mix(c, (20, 12, 28), t)


def light(c: tuple, t: float = 0.3) -> tuple:
    return mix(c, (255, 250, 236), t)


class Layer:
    """Pixels of the figure; None = nothing drawn yet."""

    def __init__(self, size: int = S):
        self.size = size
        self.px = [[None] * size for _ in range(size)]

    def set(self, x: int, y: int, c) -> None:
        if 0 <= x < self.size and 0 <= y < self.size:
            self.px[y][x] = c

    def get(self, x: int, y: int):
        if 0 <= x < self.size and 0 <= y < self.size:
            return self.px[y][x]
        return None

    def ellipse(self, cx: float, cy: float, rx: float, ry: float, c, y_from: int = 0, y_to: int = 99) -> None:
        for y in range(max(0, y_from), min(self.size, y_to + 1)):
            for x in range(self.size):
                if ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0:
                    self.px[y][x] = c

    def rect(self, x0: int, y0: int, x1: int, y1: int, c) -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                self.set(x, y, c)

    def row(self, y: int, x0: int, x1: int, c) -> None:
        self.rect(x0, y, x1, y, c)


def bust(r: dict, frame: int) -> Image.Image:
    """One 32 px bust. frame 0 resting, 1 eyes shut, 2 mouth open."""
    skin = rgb(SKIN[r["skin"]])
    skin_d = dark(skin, 0.22)
    hair = rgb(r["hair"])
    hair_d = dark(hair, 0.3)
    hair_l = light(hair, 0.25)
    coat = rgb(r["coat"])
    coat_d = dark(coat, 0.3)
    coat_l = light(coat, 0.25)
    trim = rgb(r.get("trim", "e6c9a0"))
    wear = rgb(r.get("wear", r["coat"]))
    wear_d = dark(wear, 0.3)
    wear_l = light(wear, 0.25)
    bg = rgb(r["bg"])
    style = r["hairstyle"]
    extras = r.get("extras", [])
    cx, cy = 15.5, 14.0
    rx = {"round": 7.6, "long": 6.8, "square": 7.4}[r.get("face", "round")]
    ry = {"round": 8.0, "long": 8.8, "square": 8.2}[r.get("face", "round")]
    f = Layer()

    # Hair or cloth that falls behind the head and shoulders.
    if style in ("long", "braid"):
        f.ellipse(cx, cy - 1, rx + 2.2, ry + 1.5, hair_d)
        f.rect(int(cx - rx - 2), int(cy), int(cx + rx + 2) + 1, 27, hair_d)
    if style in ("hood", "scarf"):
        f.ellipse(cx, cy - 1, rx + 3.0, ry + 2.4, wear_d)
        f.rect(int(cx - rx - 2), int(cy), int(cx + rx + 2) + 1, 26, wear_d)

    # Shoulders and coat.
    for x in range(2, 30):
        top = 25 + int(round(((x - cx) / 13.0) ** 2 * 5))
        for y in range(top, S):
            c = coat
            if x < 6 or (x - 2) < (y - top):
                c = coat if x > 5 else coat_d
            if x > 24:
                c = coat_d
            if y == top:
                c = coat_l
            f.set(x, y, c)
    # Neck and collar.
    f.rect(13, 20, 18, 26, skin_d)
    collar = r.get("collar", "v")
    if collar == "v":
        for i in range(5):
            f.row(25 + i, 12 + i, 19 - i, skin_d if i < 2 else coat_d)
            f.set(11 + i, 25 + i, trim)
            f.set(20 - i, 25 + i, trim)
    elif collar == "high":
        f.rect(11, 22, 20, 25, coat_l)
        f.rect(11, 22, 12, 25, coat)
        f.rect(15, 22, 16, 31, coat_d)
    else:  # band
        f.rect(11, 24, 20, 25, trim)
        f.rect(15, 26, 16, 31, dark(trim, 0.2))

    # Head.
    f.ellipse(cx, cy, rx, ry, skin)
    if r.get("face") == "square":
        f.rect(int(cx - rx + 1.5), int(cy + 2), int(cx + rx - 1), int(cy + ry - 2), skin)
    for y in range(S):
        for x in range(S):
            if f.px[y][x] == skin and x > cx + rx - 3.2:
                f.px[y][x] = skin_d
    # Ears.
    for ex in (int(cx - rx - 0.5), int(cx + rx + 1.0)):
        f.rect(ex, 14, ex, 16, skin_d if ex > cx else skin)
    # Shadow under the chin.
    f.row(int(cy + ry) + 1, 13, 18, dark(skin_d, 0.25))

    hair_top = int(cy - ry) - 1
    brow_y = 11

    def cap(lo: int, c_main, c_dark, c_light) -> None:
        """Hair over the skull down to row lo, lighter on the left."""
        for y in range(hair_top, lo + 1):
            for x in range(S):
                d = ((x - cx) / (rx + 1.0)) ** 2 + ((y - cy) / (ry + 1.4)) ** 2
                if d <= 1.0 and (y <= lo - 2 or abs(x - cx) > rx - 3.5 + (lo - y)):
                    c = c_main
                    if x > cx + 3:
                        c = c_dark
                    elif x < cx - 2 and y < lo - 2 and (x + y) % 3 == 0:
                        c = c_light
                    f.set(x, y, c)

    if style == "short":
        cap(9, hair, hair_d, hair_l)
    elif style == "spiky":
        cap(9, hair, hair_d, hair_l)
        for i, x in enumerate(range(8, 24, 3)):
            h = 2 + (i % 2)
            for k in range(h):
                f.set(x + (k // 2), hair_top - k, hair if x < 17 else hair_d)
                f.set(x + 1, hair_top - k + 1, hair if x < 17 else hair_d)
    elif style in ("long", "braid"):
        cap(10, hair, hair_d, hair_l)
        f.rect(int(cx - rx - 1), 9, int(cx - rx) + 1, 24, hair)
        f.rect(int(cx + rx), 9, int(cx + rx + 2), 24, hair_d)
        if style == "braid":
            for y in range(18, 30):
                f.rect(5, y, 7, y, hair if y % 3 else hair_d)
            f.rect(5, 29, 7, 30, trim)
    elif style == "bun":
        cap(9, hair, hair_d, hair_l)
        f.ellipse(cx, hair_top - 1.5, 3.4, 3.0, hair)
        f.ellipse(cx + 1.2, hair_top - 1.0, 1.8, 1.8, hair_d)
        f.row(hair_top + 1, int(cx - 2), int(cx + 2), trim)
    elif style == "balding":
        for y in range(10, 17):
            f.rect(int(cx - rx - 1), y, int(cx - rx) + 1, y, hair)
            f.rect(int(cx + rx), y, int(cx + rx + 2), y, hair_d)
        f.set(int(cx - 2), hair_top + 2, light(skin, 0.5))
        f.set(int(cx - 1), hair_top + 2, light(skin, 0.5))
    elif style == "bald":
        f.set(int(cx - 3), hair_top + 3, light(skin, 0.5))
        f.set(int(cx - 2), hair_top + 2, light(skin, 0.5))
    elif style in ("hood", "scarf"):
        cap(9 if style == "hood" else 10, wear, wear_d, wear_l)
        f.rect(int(cx - rx - 1), 9, int(cx - rx) + 1, 22, wear)
        f.rect(int(cx + rx), 9, int(cx + rx + 2), 22, wear_d)
        if style == "scarf":
            f.row(10, int(cx - rx) + 1, int(cx + rx), wear_l)
            f.rect(int(cx - rx), 21, int(cx + rx) + 1, 23, wear)
            f.rect(int(cx + 2), 21, int(cx + rx) + 1, 23, wear_d)
            f.rect(9, 23, 11, 27, wear)
        else:
            f.set(int(cx), hair_top - 1, wear)
            f.set(int(cx) + 1, hair_top - 1, wear_d)
    elif style == "hat":
        cap(8, hair, hair_d, hair_l)
        f.rect(int(cx - rx) + 1, hair_top - 3, int(cx + rx), 7, wear)
        f.rect(int(cx + 2), hair_top - 3, int(cx + rx), 7, wear_d)
        f.row(hair_top - 4, int(cx - rx) + 2, int(cx + rx) - 1, wear_l)
        f.row(6, int(cx - rx) + 1, int(cx + rx), trim)
        f.rect(2, 8, 29, 9, wear)
        f.row(9, 2, 29, wear_d)
        f.row(8, 3, 14, wear_l)
    elif style == "bandana":
        cap(9, hair, hair_d, hair_l)
        f.rect(int(cx - rx), 7, int(cx + rx) + 1, 9, wear)
        f.row(7, int(cx - rx) + 1, int(cx), wear_l)
        f.row(9, int(cx - rx), int(cx + rx) + 1, wear_d)
        f.rect(int(cx + rx) + 1, 9, int(cx + rx) + 3, 10, wear)
        f.rect(int(cx + rx) + 2, 11, int(cx + rx) + 4, 14, wear_d)

    # Brows.
    brow = dark(hair if style not in ("bald",) else skin_d, 0.35)
    kind = r.get("brows", "flat")
    for side in (-1, 1):
        bx = int(cx + side * 3.5)
        xs = [bx - 1, bx, bx + 1]
        for i, x in enumerate(xs):
            dy = 0
            inner = (i == 2) if side < 0 else (i == 0)
            outer = (i == 0) if side < 0 else (i == 2)
            if kind == "angry" and inner:
                dy = 1
            if kind == "soft" and outer:
                dy = 1
            if kind == "raised" and side > 0:
                dy = -1
            f.set(x, brow_y + dy, brow)
        if kind == "heavy":
            for x in xs:
                f.set(x, brow_y + 1, brow)
    # Eyes.
    eye = rgb(r.get("eyes", "2a1e2c"))
    eye_y = 14
    for side in (-1, 1):
        ex = int(cx + side * 3.5)
        if "patch" in extras and side > 0:
            f.rect(ex - 2, eye_y - 2, ex + 2, eye_y + 1, (26, 20, 30))
            for i in range(0, 9):
                f.set(ex - 2 - i, eye_y - 2 - (i // 3), (26, 20, 30))
            continue
        if frame == 1:
            f.row(eye_y + 1, ex - 1, ex + 1, dark(skin_d, 0.5))
        else:
            f.set(ex - 1, eye_y, (250, 248, 240))
            f.set(ex, eye_y, eye)
            f.set(ex - 1, eye_y + 1, (250, 248, 240))
            f.set(ex, eye_y + 1, dark(eye, 0.4))
            f.set(ex + 1, eye_y + 1, dark(skin_d, 0.3))
            f.row(eye_y - 1, ex - 1, ex + 1, dark(skin_d, 0.5))
    if "glasses" in extras:
        g = (60, 52, 70)
        for side in (-1, 1):
            ex = int(cx + side * 3.5)
            for x in range(ex - 2, ex + 3):
                f.set(x, eye_y - 2, g)
                f.set(x, eye_y + 2, g)
            for y in range(eye_y - 1, eye_y + 2):
                f.set(ex - 2, y, g)
                f.set(ex + 2, y, g)
        f.row(eye_y - 1, int(cx) - 0, int(cx) + 1, g)
    if "monocle" in extras:
        g = rgb("d8b24a")
        ex = int(cx + 3.5)
        for x in range(ex - 2, ex + 3):
            f.set(x, eye_y - 2, g)
            f.set(x, eye_y + 2, g)
        for y in range(eye_y - 1, eye_y + 2):
            f.set(ex - 2, y, g)
            f.set(ex + 2, y, g)
        for y in range(eye_y + 3, eye_y + 9):
            f.set(ex + 2, y, g)
    if "scar" in extras:
        sc = light(skin, 0.45)
        for i in range(6):
            f.set(int(cx - 6) + i // 2 + 1, eye_y - 4 + i, sc)
    # Nose.
    f.set(int(cx) + 1, 16, skin_d)
    f.set(int(cx) + 1, 17, skin_d)
    f.set(int(cx), 18, dark(skin_d, 0.15))
    # Cheeks and age.
    if "blush" in extras:
        for side in (-1, 1):
            f.row(17, int(cx + side * 5) - 1, int(cx + side * 5), mix(skin, (232, 120, 110), 0.45))
    if "wrinkles" in extras:
        w = dark(skin_d, 0.2)
        f.set(int(cx - 5), 17, w)
        f.set(int(cx - 4), 18, w)
        f.set(int(cx + 6), 17, w)
        f.set(int(cx + 5), 18, w)
        if style in ("bald", "balding"):
            f.row(9, int(cx - 2), int(cx + 2), w)
    if "freckles" in extras:
        fr = dark(skin, 0.25)
        for p in ((-5, 17), (-3, 18), (4, 18), (6, 17)):
            f.set(int(cx + p[0]), p[1], fr)
    # Beard and moustache before the mouth, so the mouth shows on top.
    mouth_y = 20
    if "beard" in extras:
        for y in range(18, int(cy + ry) + 3):
            for x in range(S):
                d = ((x - cx) / (rx + 0.6)) ** 2 + ((y - cy) / (ry + 2.6)) ** 2
                if d <= 1.0 and (y >= 20 or abs(x - cx) >= rx - 2.5):
                    f.set(x, y, hair if x <= cx + 2 else hair_d)
        f.row(19, int(cx - 3), int(cx + 3), hair)
    if "stubble" in extras:
        st = mix(skin, hair, 0.35)
        for y in range(19, int(cy + ry) + 1):
            for x in range(int(cx - rx) + 2, int(cx + rx)):
                if f.get(x, y) in (skin, skin_d) and (x + y) % 2 == 0:
                    f.set(x, y, st)
    if "moustache" in extras:
        f.row(19, int(cx - 3), int(cx + 4), hair_d)
        f.set(int(cx - 4), 20, hair_d)
        f.set(int(cx + 5), 20, hair_d)
    # Mouth.
    lip = dark(mix(skin, (170, 60, 70), 0.55), 0.25)
    m = r.get("mouth", "flat")
    mx = int(cx)
    if frame == 2:
        f.rect(mx - 1, mouth_y, mx + 2, mouth_y + 1, (70, 26, 40))
        f.row(mouth_y, mx - 1, mx + 2, lip)
        f.row(mouth_y + 1, mx, mx + 1, (198, 92, 96))
    elif m == "smile":
        f.row(mouth_y + 1, mx - 1, mx + 2, lip)
        f.set(mx - 2, mouth_y, lip)
        f.set(mx + 3, mouth_y, lip)
    elif m == "smirk":
        f.row(mouth_y + 1, mx - 1, mx + 2, lip)
        f.set(mx + 3, mouth_y, lip)
    elif m == "frown":
        f.row(mouth_y, mx - 1, mx + 2, lip)
        f.set(mx - 2, mouth_y + 1, lip)
        f.set(mx + 3, mouth_y + 1, lip)
    else:
        f.row(mouth_y + 1, mx - 1, mx + 2, lip)
    if "earring" in extras:
        f.set(int(cx - rx - 0.5), 17, rgb("f0c64a"))
        f.set(int(cx - rx - 0.5), 18, rgb("d8a430"))
    if "flower" in extras:
        fx, fy = int(cx - rx), 8
        for p in ((0, -1), (-1, 0), (1, 0), (0, 1)):
            f.set(fx + p[0], fy + p[1], rgb("f4a6c0"))
        f.set(fx, fy, rgb("f6e27a"))
    if "leaf" in extras:
        for p in ((0, 0), (1, -1), (2, -1), (1, 0), (2, -2)):
            f.set(int(cx + 2) + p[0], hair_top + 2 + p[1], rgb("6fae4e"))
    if "pin" in extras:
        f.rect(8, 27, 9, 28, rgb("f0c64a"))
        f.set(8, 27, rgb("fff2b0"))

    # Background, a dark outline around the figure, then the figure.
    img = Image.new("RGBA", (S, S))
    out = img.load()
    line = dark(bg, 0.72)
    for y in range(S):
        for x in range(S):
            c = f.px[y][x]
            if c is None:
                near = any(f.get(x + dx, y + dy) is not None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)))
                if near:
                    c = line
                else:
                    band = (x + y) // 8
                    c = light(bg, 0.16) if band % 2 == 0 else bg
                    if y > 26:
                        c = dark(c, 0.12)
            out[x, y] = c + (255,)
    return img


def icon(r: dict) -> Image.Image:
    """The 12 px head for the Era IV name plate: skull, hair or headwear, two eyes."""
    skin = rgb(SKIN[r["skin"]])
    hair = rgb(r["hair"])
    wear = rgb(r.get("wear", r["coat"]))
    coat = rgb(r["coat"])
    style = r["hairstyle"]
    f = Layer(ICON)
    f.rect(1, 9, 10, 11, coat)
    f.rect(8, 9, 10, 11, dark(coat, 0.3))
    f.rect(2, 2, 9, 9, skin)
    f.rect(3, 1, 8, 1, skin)
    f.rect(3, 10, 8, 10, skin)
    f.rect(8, 3, 9, 9, dark(skin, 0.22))
    top = wear if style in ("hood", "scarf", "hat", "bandana") else hair
    if style not in ("bald",):
        if style == "balding":
            f.rect(2, 4, 2, 6, hair)
            f.rect(9, 4, 9, 6, dark(hair, 0.3))
        else:
            f.rect(3, 1, 8, 1, top)
            f.rect(2, 2, 9, 3, top)
            f.rect(7, 2, 9, 3, dark(top, 0.3))
            f.set(2, 4, top)
            f.set(9, 4, dark(top, 0.3))
    if style in ("long", "braid", "hood", "scarf"):
        f.rect(1, 3, 1, 9, top)
        f.rect(2, 4, 2, 8, top)
        f.rect(10, 3, 10, 9, dark(top, 0.3))
        f.rect(9, 4, 9, 8, dark(top, 0.3))
    if style == "hat":
        f.rect(0, 3, 11, 3, wear)
        f.rect(7, 3, 11, 3, dark(wear, 0.3))
        f.rect(3, 0, 8, 0, wear)
    if style == "bun":
        f.rect(5, 0, 6, 0, hair)
    if style == "bandana":
        f.rect(3, 0, 8, 1, hair)
        f.rect(10, 3, 11, 5, dark(wear, 0.3))
    if style == "spiky":
        for x in (3, 5, 7):
            f.set(x, 0, hair)
    extras = r.get("extras", [])
    f.set(4, 6, (36, 26, 40))
    f.set(7, 6, (36, 26, 40))
    if "patch" in extras:
        f.rect(6, 5, 8, 6, (26, 20, 30))
    if "glasses" in extras or "monocle" in extras:
        f.set(7, 5, (60, 52, 70))
        f.set(8, 6, (60, 52, 70))
    if "beard" in extras:
        f.rect(3, 8, 8, 10, hair)
        f.rect(2, 7, 2, 9, hair)
        f.rect(9, 7, 9, 9, dark(hair, 0.3))
    elif "moustache" in extras:
        f.rect(4, 8, 7, 8, dark(hair, 0.3))
    else:
        f.rect(5, 8, 6, 8, dark(mix(skin, (170, 60, 70), 0.55), 0.25))
    img = Image.new("RGBA", (ICON, ICON))
    out = img.load()
    for y in range(ICON):
        for x in range(ICON):
            c = f.px[y][x]
            if c is not None:
                out[x, y] = c + (255,)
            elif any(f.get(x + dx, y + dy) is not None for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1))):
                out[x, y] = (36, 26, 40, 255)
    return img


def R(skin, hair, hairstyle, coat, bg, **kw) -> dict:
    d = {"skin": skin, "hair": hair, "hairstyle": hairstyle, "coat": coat, "bg": bg}
    d.update(kw)
    return d


# One recipe per speaker id of data/era_text.json. Colours follow the figures' overworld coats.
RECIPES = {
    # The Wayfarer's circle.
    "kestra": R("light", "a8442c", "spiky", "2f7f7a", "bfe0d2", eyes="3f7a4a", brows="angry", mouth="smirk", extras=["scar", "freckles"], trim="f0d9a0"),
    "aldo": R("tan", "e8e4da", "balding", "2f4468", "cfd9e6", brows="soft", mouth="smile", extras=["beard", "wrinkles"], collar="high"),
    "mirela": R("light", "cfcad2", "bun", "6a4a86", "e6d9ee", brows="soft", mouth="smile", extras=["wrinkles", "blush"], trim="f0c64a", collar="band"),
    "corin": R("dark", "1e1a22", "short", "b08a3a", "eadfb8", brows="flat", mouth="flat", extras=["stubble"], trim="f6efdc"),
    "veit": R("pale", "241c28", "long", "5a4a3a", "d6ccc0", face="long", eyes="5a3a6a", brows="angry", mouth="frown", extras=["moustache"], collar="high"),
    "ysolde": R("pale", "f2f0ea", "long", "4c5a80", "dfe6f2", face="long", brows="soft", mouth="flat", extras=["glasses", "wrinkles"], collar="band"),
    # Wardens of the story.
    "senna": R("tan", "5a3a22", "braid", "c0562f", "f2d6c0", eyes="6a3a1e", brows="flat", mouth="smile", trim="f0c64a"),
    "joral": R("brown", "2a2420", "short", "5f6f86", "d5dde8", face="square", brows="heavy", mouth="flat", extras=["beard"]),
    "tovan": R("olive", "d9d4c8", "balding", "7a5a3a", "e8dcc6", brows="heavy", mouth="frown", extras=["moustache", "wrinkles"], collar="high"),
    "ilse": R("light", "c9a24a", "braid", "5a8a5a", "d6ead2", eyes="3f7a4a", brows="soft", mouth="smile", extras=["glasses", "freckles", "leaf"]),
    "brisa": R("pale", "d8dde6", "long", "8a8a8a", "e4ecf2", face="long", eyes="5a86a8", brows="raised", mouth="smirk", extras=["earring"]),
    "darrow": R("tan", "4a3626", "hat", "3e3a46", "d2ccd6", wear="2e2a36", brows="heavy", mouth="flat", extras=["stubble", "scar"], trim="c4432f", collar="high"),
    "odalys": R("brown", "1e1a22", "hood", "8a3a2a", "f0d2c2", wear="b4532f", eyes="c98a2a", brows="flat", mouth="flat", extras=["earring"], trim="f0c64a"),
    "aurelio": R("tan", "e6c25a", "short", "c9a227", "f6ecc0", eyes="8a5a1e", brows="raised", mouth="smile", extras=["pin"], trim="fff2b0"),
    "kaia": R("brown", "16222a", "braid", "2a7a8a", "c6e6ea", eyes="2a7a8a", brows="flat", mouth="smile", trim="f6efdc", collar="band"),
    "emrys": R("pale", "eeeae0", "hood", "4a4266", "dcd6ee", wear="5a5080", face="long", brows="soft", mouth="flat", extras=["beard", "wrinkles"]),
    # Heads of the clans.
    "vash": R("olive", "2a2430", "bald", "4a4a6a", "d2d2e2", face="square", brows="heavy", mouth="frown", extras=["patch", "stubble"], collar="high"),
    "fenrick": R("light", "b4432a", "short", "7a2a2a", "f0d0c8", face="square", brows="heavy", mouth="smirk", extras=["beard"], trim="f0c64a"),
    "ottilie": R("pale", "3a2a3a", "bun", "5a2a4a", "ead2e2", face="long", brows="raised", mouth="smirk", extras=["monocle", "earring"], trim="d8b24a", collar="band"),
    "grell": R("pale", "9a969e", "scarf", "2a2a2a", "d6d2d6", wear="2e2a30", brows="angry", mouth="frown", extras=["wrinkles"], collar="high"),
    "sable": R("tan", "2a2420", "hood", "3a5a3a", "d2e2cc", wear="2f4a30", eyes="3a5a3a", brows="angry", mouth="flat", extras=["scar"]),
    "wren": R("light", "5a3a2a", "bandana", "8a3a5a", "f0d2de", wear="c0507a", eyes="6a3a1e", brows="raised", mouth="smile", extras=["freckles", "blush"]),
    # Wardens of Halcyra (Era IV).
    "isaura": R("olive", "c8ccd6", "bun", "3a4a7a", "d2dcf2", face="long", eyes="3a4a7a", brows="flat", mouth="flat", extras=["glasses"], trim="f0c64a", collar="band"),
    "halloran": R("tan", "d0c8b8", "hat", "8a9aa2", "e2eaea", wear="e6e2d6", brows="heavy", mouth="flat", extras=["beard", "wrinkles"], trim="5a86a8"),
    "veronne": R("brown", "1a1620", "long", "8a2a4a", "f0d0d8", face="long", eyes="8a2a4a", brows="raised", mouth="smirk", extras=["earring"], trim="f0c64a"),
    "aurek": R("light", "e2c060", "short", "c9a227", "f6eab8", face="square", brows="flat", mouth="smirk", extras=["moustache", "pin"], trim="fff2b0", collar="high"),
    # Wardens of Quivermoor (Era V).
    "maudrey": R("pale", "8a8490", "hood", "6a6470", "e6e2e6", wear="8e8894", face="long", eyes="c98a2a", brows="soft", mouth="flat", extras=["wrinkles"], trim="f6e27a"),
    "ossian": R("olive", "6a4a2a", "bald", "4a7a3a", "d6ecc8", face="square", eyes="3f7a4a", brows="heavy", mouth="smile", extras=["beard", "leaf"]),
    "corran": R("brown", "2a2420", "bandana", "2f6a8a", "cfe6f0", wear="e0a030", brows="raised", mouth="smile", extras=["stubble", "earring"]),
    "sabeline": R("light", "d0507a", "long", "5a9a5a", "f6dce6", eyes="5a9a5a", brows="soft", mouth="smile", extras=["flower", "blush"], trim="f4a6c0"),
}


def main() -> None:
    speakers = sorted(json.load(open(DATA, encoding="utf-8"))["speakers"].keys())
    if speakers != sorted(RECIPES.keys()):
        only_data = sorted(set(speakers) - set(RECIPES))
        only_here = sorted(set(RECIPES) - set(speakers))
        raise SystemExit("speakers and recipes differ: no recipe for %s, no speaker for %s" % (only_data, only_here))
    os.makedirs(OUT5, exist_ok=True)
    os.makedirs(OUT4, exist_ok=True)
    for sid in speakers:
        sheet = Image.new("RGBA", (S * 3, S))
        for frame in range(3):
            sheet.paste(bust(RECIPES[sid], frame), (S * frame, 0))
        sheet.save(os.path.join(OUT5, sid + ".png"))
        icon(RECIPES[sid]).save(os.path.join(OUT4, sid + ".png"))
    print("portraits: %d speakers" % len(speakers))


if __name__ == "__main__":
    main()
