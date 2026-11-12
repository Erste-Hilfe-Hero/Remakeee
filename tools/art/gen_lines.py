"""Era I sprites for whole Spirling lines, grown from one base form (owner rule: 70 per act).

A line is one spec: a body plan ("quad", "biped", "bird", "serpent", "fish", "bug", "shell",
"spirit", "plant") plus features (ears, horn, crest, tail, back, marks, extras) and three tones.
Every stage of the line is drawn from that same spec. A later stage is the same drawing scaled
up around the feet and given more detail (more spikes, crest points, marks, longer horns), so
the silhouette core, tones and signature features carry through the whole line.

The specs live in tools/art/lines/<region>.py (LINES). Drawing uses gen_spirlings.render, so the
look is the Era I 4-tone style (outline, base, top-left highlight, dithered shadow).

Run from the repo root:
  python3 tools/art/gen_lines.py <region> [--sheet out.png]
Writes art/era1/spirlings/<name>_front.png and _back.png (56 x 56) for every species of the
region's lines, plus a .import sidecar for new files, and optionally a contact sheet.
"""
from __future__ import annotations

import hashlib
import importlib
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from gen_spirlings import BACK_DROP, E, P, S, Stamp, render, shift_down  # noqa: E402

ROOT = os.path.dirname(os.path.dirname(HERE))
OUT = os.path.join(ROOT, "art", "era1", "spirlings")

# Scale and detail level per stage, by line length. The last form is drawn at full size.
STAGES = {1: [(0.92, 1)], 2: [(0.7, 0), (1.0, 2)], 3: [(0.62, 0), (0.8, 1), (1.0, 2)]}


class G:
    """Collects parts in final-size coordinates and scales them around the feet."""

    def __init__(self, scale: float, ax: float = 30.0, gy: float = 53.0):
        self.s, self.ax, self.gy = scale, ax, gy
        self.parts: list = []

    def X(self, x):
        return self.ax + (x - self.ax) * self.s

    def Y(self, y):
        return self.gy - (self.gy - y) * self.s

    def e(self, cx, cy, rx, ry, tone="mid", **kw):
        self.parts.append(E(self.X(cx), self.Y(cy), max(rx * self.s, 1.3), max(ry * self.s, 1.3), tone, **kw))

    def p(self, pts, tone="mid", **kw):
        self.parts.append(P([(self.X(x), self.Y(y)) for x, y in pts], tone, **kw))

    def st(self, x, y, rows, face=True):
        self.parts.append(Stamp(int(round(self.X(x))), int(round(self.Y(y))), rows, face))


def arc(cx, cy, rx, ry, a0, a1, n):
    """n points on an ellipse arc, angles in degrees (screen space, -90 = top)."""
    if n == 1:
        a = math.radians((a0 + a1) / 2)
        return [(cx + rx * math.cos(a), cy + ry * math.sin(a))]
    out = []
    for i in range(n):
        a = math.radians(a0 + (a1 - a0) * i / (n - 1))
        out.append((cx + rx * math.cos(a), cy + ry * math.sin(a)))
    return out


# --- Body plans ------------------------------------------------------------------------------
# Each plan returns anchors: body (bx, by, brx, bry), head (hx, hy, hr), tail root (tx, ty),
# ridge (an ellipse arc for back features), and draws itself through layer callbacks.

def plan_anchors(sp):
    plan = sp["plan"]
    k = sp.get("size", 0)  # -1 slim .. +1 bulky
    if plan == "quad":
        brx = 14 + 2 * sp.get("long", 0) + k
        by = 37 - 3 * sp.get("legs", 0)
        bry = 9 + k
        neck = sp.get("neck", False)
        hx, hy = (32 - brx + 1, by - 15) if neck else (32 - brx - 1, by - 7)
        return dict(body=(32, by, brx, bry), head=(hx, hy, 8 + max(k, 0)), tail=(32 + brx - 3, by - 3),
                    ridge=(32, by, brx - 2, bry, -150, -35))
    if plan == "biped":
        bry = 12 + k
        return dict(body=(31, 52 - bry - 3, 10 + k, bry), head=(26, 52 - 2 * bry - 9, 10), tail=(39, 44),
                    ridge=(31, 52 - bry - 3, 10 + k, bry, -40, 30))
    if plan == "bird":
        return dict(body=(33, 37, 12 + k, 10 + k), head=(21, 22, 8), tail=(42, 38),
                    ridge=(21, 22, 8, 7, -120, -40))
    if plan == "serpent":
        return dict(body=(34, 47, 17 + k, 5), head=(17, 22, 8), tail=(48, 46),
                    ridge=(27, 34, 6, 9, -60, 20))
    if plan == "fish":
        return dict(body=(30, 28, 15 + k, 10 + k), head=(20, 27, 8), tail=(43, 28),
                    ridge=(30, 28, 15 + k, 10 + k, -140, -40))
    if plan == "bug":
        return dict(body=(34, 39, 14 + k, 10 + k), head=(17, 40, 7), tail=(46, 36),
                    ridge=(34, 39, 14 + k, 10 + k, -150, -30))
    if plan == "shell":
        return dict(body=(33, 39, 16 + k, 12 + k), head=(13, 40, 7), tail=(48, 46),
                    ridge=(33, 39, 16 + k, 12 + k, -155, -25))
    if plan == "spirit":
        return dict(body=(30, 33, 12 + k, 12 + k), head=(28, 31, 10), tail=(40, 40),
                    ridge=(30, 33, 12 + k, 12 + k, -150, -30))
    if plan == "plant":
        return dict(body=(30, 39, 11 + k, 12 + k), head=(28, 36, 9), tail=(40, 44),
                    ridge=(30, 39, 11 + k, 12 + k, -160, -20))
    raise ValueError(plan)


def draw_body(g, sp, A, d, tones):
    plan = sp["plan"]
    body, head, accent = tones
    bx, by, brx, bry = A["body"]
    hx, hy, hr = A["head"]
    if plan == "quad":
        foot = 52
        top = by + bry - 4
        ry = (foot - top) / 2
        g.e(bx - brx + 7, top + ry, 3, ry, "dark")
        g.e(bx + brx - 6, top + ry, 3, ry, "dark")
        g.e(bx, by, brx, bry, body)
        g.e(bx - brx + 4, top + ry + 1, 3.5, ry, "dark")
        g.e(bx + brx - 9, top + ry + 1, 3.5, ry, "dark")
        if sp.get("neck"):
            g.p([(hx + 2, hy + 4), (hx + 9, hy - 1), (bx - brx + 9, by - 2), (bx - brx + 4, by + 5)], body)
    elif plan == "biped":
        g.e(bx - 5, 51, 5, 3, "dark")
        g.e(bx + 6, 51, 5, 3, "dark")
        if sp.get("pillar"):
            g.p([(bx - brx, by + bry), (bx - brx + 4, by - bry - 4), (bx + brx - 4, by - bry - 4), (bx + brx, by + bry)], body)
            for i in range(1 + d):
                g.st(bx - 2, by - 4 + 5 * i, ["030", "333", "030"] if i % 2 == 0 else ["3.3", ".3.", "3.3"], face=False)
        else:
            g.e(bx, by, brx, bry, body)
            g.e(bx, by + 3, brx - 4, bry - 5, "light" if body != "light" else "mid", outline=False)
    elif plan == "bird":
        g.p([(bx - 2, by + 9), (bx - 1, 52), (bx + 1, 52), (bx + 1, by + 9)], "ink", outline=False)
        g.p([(bx + 4, by + 9), (bx + 5, 52), (bx + 7, 52), (bx + 6, by + 9)], "ink", outline=False)
        g.e(bx, by, brx, bry, body)
        g.p([(hx + 3, hy + 3), (hx + 8, hy - 2), (bx - 4, by - 6), (bx - 8, by + 2)], body)
    elif plan == "serpent":
        g.e(bx, by, brx, bry, body)
        g.e(bx - 3, by - 8, brx - 5, 5, body)
        g.p([(hx + 3, hy + 4), (hx + 9, hy + 1), (bx - 4, by - 10), (bx - 11, by - 7)], body)
    elif plan == "fish":
        g.e(bx, 51, 10, 2, "dark", outline=False, shade=False)
        g.e(bx, by, brx, bry, body)
        g.e(bx - 2, by + 4, brx - 5, bry - 6, "light" if body != "light" else "mid", outline=False)
    elif plan == "bug":
        for i, lx in enumerate((bx - 8, bx, bx + 8)):
            g.p([(lx, by + 6), (lx - 3, 52), (lx - 1, 52), (lx + 2, by + 6)], "ink", outline=False)
        g.e(bx, by, brx, bry, body)
        g.p([(bx - 1, by - bry + 1), (bx + 1, by - bry + 1), (bx + 1, by + bry - 2), (bx - 1, by + bry - 2)],
            "ink", outline=False, shade=False)
    elif plan == "shell":
        g.e(bx - 9, 50, 4, 3, "dark")
        g.e(bx + 9, 50, 4, 3, "dark")
        g.e(bx, by, brx, bry, body)
        g.e(bx, by + bry - 2, brx - 1, 3, "dark", outline=False, shade=False)
    elif plan == "spirit":
        g.e(bx, 51, 8, 2, "dark", outline=False, shade=False)
        g.p([(bx - 9, by + 4), (bx - 4, by + 18), (bx + 2, by + 10), (bx + 6, by + 19), (bx + 10, by + 4)], body)
        g.e(bx, by, brx, bry, body)
    elif plan == "plant":
        g.p([(bx - 6, by + 9), (bx - 10, 52), (bx - 4, 52), (bx - 2, by + 10)], "dark")
        g.p([(bx + 6, by + 9), (bx + 10, 52), (bx + 4, 52), (bx + 2, by + 10)], "dark")
        g.e(bx, by, brx, bry, body)


def draw_head(g, sp, A, d, tones):
    plan = sp["plan"]
    _, head, accent = tones
    hx, hy, hr = A["head"]
    if plan in ("quad", "biped", "bird", "serpent", "bug", "shell"):
        g.e(hx, hy, hr, hr - 1 if plan != "serpent" else hr - 2, head)
    snout = sp.get("snout")
    if snout == "long":
        g.p([(hx - 3, hy - 1), (hx - hr - 6, hy + 1), (hx - hr - 5, hy + 5), (hx - 2, hy + 5)], head)
    elif snout == "short":
        g.e(hx - hr + 1, hy + 3, 4, 3, head)
    elif snout == "beak" or plan == "bird":
        g.p([(hx - hr + 2, hy - 2), (hx - hr - 6 - d, hy + 2), (hx - hr + 2, hy + 4)], accent if accent != head else "light")


FRONTAL = ("spirit", "plant", "biped")


def draw_face(g, sp, A, d):
    hx, hy, hr = A["head"]
    ex, ey = int(hx - hr * 0.5), int(hy - 2)
    kind = sp.get("eye", "small")
    rows = {
        "small": ["00", "30", "00"],
        "big": [".00.", "0330", "0300", "0000", ".00."],
        "glow": ["000", "033", "000"],
        "slit": ["000", "030", "000"],
        "sleepy": ["000", ".0."],
        "twin": ["00.00", "30.30", "00.00"],
    }[kind]
    if kind == "big":
        ex, ey = ex - 1, ey - 1
    if kind == "twin":
        ex -= 2
    if sp["plan"] in FRONTAL:
        ex, ey = int(hx - 6), int(hy - 3)
        g.st(ex + 7, ey, rows)
    g.st(ex, ey, rows)
    m = sp.get("mouth")
    if sp["plan"] in FRONTAL:
        hx, hr = hx + 4, 4
        hy += 1
    if m == "smile":
        g.st(hx - hr + 2, hy + 3, ["0.0", ".0."])
    elif m == "line":
        g.st(hx - hr + 1, hy + 3, ["000"])
    elif m == "fang":
        g.st(hx - hr + 1, hy + 3, ["000", "3.."])


# --- Features --------------------------------------------------------------------------------

def tail(g, sp, A, d, tones):
    kind = sp.get("tail")
    if not kind:
        return
    tx, ty = A["tail"]
    body, head, accent = tones
    L = 1.0 + 0.15 * d
    if kind == "flame":
        g.p([(tx, ty + 3), (tx + 6 * L, ty - 6 * L), (tx + 9 * L, ty - 16 * L), (tx + 13 * L, ty - 8 * L),
             (tx + 12 * L, ty), (tx + 4, ty + 6)], accent)
        if d >= 1:
            g.p([(tx + 5, ty), (tx + 9 * L, ty - 9 * L), (tx + 10 * L, ty - 1)], "light", outline=False)
    elif kind == "fan":
        g.p([(tx, ty), (tx + 10 * L, ty - 14 * L), (tx + 15 * L, ty - 8 * L), (tx + 15 * L, ty + 2), (tx + 2, ty + 5)], accent)
        for i in range(d + 1):
            g.p([(tx + 3, ty + 1), (tx + (9 + 2 * i) * L, ty - (11 - 5 * i) * L), (tx + (10 + 2 * i) * L, ty - (9 - 5 * i) * L)],
                "dark", outline=False, shade=False)
    elif kind == "whip":
        g.p([(tx - 1, ty - 1), (tx + 9 * L, ty - 5 * L), (tx + 16 * L, ty - 14 * L), (tx + 18 * L, ty - 12 * L),
             (tx + 11 * L, ty - 1 * L), (tx + 1, ty + 4)], body)
        if d >= 1:
            g.p([(tx + 15 * L, ty - 13 * L), (tx + 20 * L, ty - 18 * L), (tx + 19 * L, ty - 10 * L)], accent)
    elif kind == "club":
        g.p([(tx - 1, ty - 1), (tx + 9 * L, ty - 3), (tx + 10 * L, ty + 2), (tx + 1, ty + 4)], body)
        g.e(tx + 12 * L, ty, 4 + d, 4 + d, accent)
    elif kind == "leaf":
        g.p([(tx, ty + 2), (tx + 6 * L, ty - 8 * L), (tx + 16 * L, ty - 14 * L), (tx + 13 * L, ty - 3 * L), (tx + 3, ty + 5)], accent)
        g.p([(tx + 3, ty + 2), (tx + 13 * L, ty - 11 * L), (tx + 13 * L, ty - 10 * L)], "dark", outline=False, shade=False)
    elif kind == "sting":
        segs = 4 + d
        r = 9 + d
        cx, cy = tx + 2, ty - r + 2
        for i in range(segs):
            a = math.radians(70 - 210 * i / (segs - 1))
            g.e(cx + r * math.cos(a), cy + r * math.sin(a), 3.4, 3.4, body)
        a = math.radians(-140)
        sx, sy = cx + r * math.cos(a), cy + r * math.sin(a)
        g.p([(sx - 1, sy - 2), (sx - 7, sy + 5), (sx + 2, sy + 2)], accent)
    elif kind == "fluff":
        g.e(tx + 4, ty - 2, 5 + d, 5 + d, accent)
    elif kind == "fin":
        g.p([(tx, ty), (tx + 11 * L, ty - 10 * L), (tx + 8 * L, ty), (tx + 11 * L, ty + 10 * L)], accent)
    elif kind == "ray":
        for i in range(2 + d):
            a = math.radians(-60 + 35 * i)
            g.p([(tx, ty - 1), (tx + 14 * L * math.cos(a), ty + 14 * L * math.sin(a)),
                 (tx + 12 * L * math.cos(a + 0.25), ty + 12 * L * math.sin(a + 0.25)), (tx, ty + 2)], accent)
    elif kind == "plume":
        for i in range(2 + d):
            a = math.radians(-50 + 22 * i)
            g.p([(tx, ty), (tx + 15 * L * math.cos(a), ty + 15 * L * math.sin(a) - 4),
                 (tx + 13 * L * math.cos(a + 0.3), ty + 13 * L * math.sin(a + 0.3) - 3), (tx, ty + 3)],
                accent if i % 2 == 0 else body)


def back(g, sp, A, d, tones):
    kind = sp.get("back")
    if not kind:
        return
    body, head, accent = tones
    cx, cy, rx, ry, a0, a1 = A["ridge"]
    n = sp.get("back_n", 3) + d
    pts = arc(cx, cy, rx, ry, a0, a1, n)
    for i, (x, y) in enumerate(pts):
        nx, ny = (x - cx) / max(rx, 1), (y - cy) / max(ry, 1)
        ln = math.hypot(nx, ny) or 1
        nx, ny = nx / ln, ny / ln
        if kind == "spikes":
            L = 5 + d + (i % 2)
            g.p([(x - 2.5 * ny, y + 2.5 * nx), (x + 2.5 * ny, y - 2.5 * nx), (x + nx * L + 1, y + ny * L)], accent)
        elif kind == "crystals":
            L = 6 + 2 * d - (i % 2) * 2
            g.p([(x - 2 * ny, y + 2 * nx), (x + 2 * ny, y - 2 * nx), (x + nx * L, y + ny * L - 1)], "light")
        elif kind == "plates":
            g.e(x + nx * 2, y + ny * 2, 3 + d * 0.5, 3 + d * 0.5, accent)
        elif kind == "leaves":
            g.p([(x, y + 1), (x + nx * 7 - 2, y + ny * 7), (x + nx * 9 + 3, y + ny * 8 - 1)], accent)
    if kind == "sail" and pts:
        top = [(x + (x - cx) / max(rx, 1) * (6 + 2 * d), y + (y - cy) / max(ry, 1) * (6 + 2 * d)) for x, y in pts]
        g.p([pts[0]] + top + [pts[-1]], accent)
        for x, y in top[1:-1]:
            g.p([(x, y), (x + 1, y), ((x + cx) / 2 + 1, (y + cy) / 2), ((x + cx) / 2, (y + cy) / 2)], "dark",
                outline=False, shade=False)
    if kind == "hump":
        x, y = pts[len(pts) // 2]
        g.e(x, y - 1, 6 + d, 5 + d, accent)


def ears(g, sp, A, d, tones):
    kind = sp.get("ears")
    if not kind:
        return
    hx, hy, hr = A["head"]
    t = sp.get("ear_tone", "dark")
    top = hy - hr + 2
    if kind == "pointed":
        h = 7 + d
        g.p([(hx + 1, top + 1), (hx + 5, top - h), (hx + 8, top + 2)], t)
        g.p([(hx - 6, top + 2), (hx - 3, top - h), (hx + 1, top + 1)], t)
    elif kind == "big":
        h = 12 + d
        g.p([(hx + 1, top + 2), (hx + 9, top - h), (hx + 11, top + 4)], t)
        g.p([(hx - 7, top + 3), (hx - 4, top - h - 1), (hx + 2, top + 1)], t)
        g.p([(hx - 4, top), (hx - 3, top - h + 4), (hx, top)], "light", outline=False, shade=False)
    elif kind == "long":
        h = 12 + 2 * d
        g.p([(hx + 1, top + 2), (hx + 8, top - h), (hx + 12, top - h + 2), (hx + 5, top + 3)], t)
        g.p([(hx - 4, top + 2), (hx - 1, top - h - 1), (hx + 3, top - h), (hx + 2, top + 2)], t)
    elif kind == "round":
        g.e(hx + 4, top - 1, 3.5 + d * 0.5, 3.5 + d * 0.5, t)
        g.e(hx - 4, top, 3.5 + d * 0.5, 3.5 + d * 0.5, t)
    elif kind == "fin":
        g.p([(hx + 3, hy - 3), (hx + 12 + d, hy - 9 - d), (hx + 9, hy + 2)], t)
    elif kind == "antenna":
        for ox, lean in ((-2, -5), (3, -1)):
            g.p([(hx + ox, top + 1), (hx + ox + lean, top - 8 - d), (hx + ox + lean + 1, top - 8 - d),
                 (hx + ox + 1, top + 1)], "ink", outline=False, shade=False)
            g.e(hx + ox + lean + 0.5, top - 9 - d, 1.8, 1.8, t)


def horns(g, sp, A, d, tones):
    kind = sp.get("horn")
    if not kind:
        return
    body, head, accent = tones
    hx, hy, hr = A["head"]
    top = hy - hr + 2
    t = sp.get("horn_tone", "light")
    if kind == "single":
        h = 7 + 2 * d
        g.p([(hx - 4, top + 2), (hx - 6, top - h), (hx + 1, top + 1)], t)
    elif kind == "twin":
        h = 6 + 2 * d
        g.p([(hx + 2, top + 1), (hx + 6, top - h), (hx + 5, top + 3)], t)
        g.p([(hx - 4, top + 2), (hx - 5, top - h), (hx, top + 1)], t)
    elif kind == "curl":
        r = 3 + d
        g.e(hx + 5, top + 1, r + 1, r + 1, t)
        g.e(hx + 5, top + 1, max(r - 1.5, 1), max(r - 1.5, 1), "dark", outline=False, shade=False)
    elif kind == "back":
        h = 5 + 2 * d
        g.p([(hx - 3, top + 3), (hx + h + 2, top - h), (hx + 5, top + 5)], t)
    elif kind == "antler":
        h = 7 + 2 * d
        for ox in (-3, 4):
            g.p([(hx + ox, top + 2), (hx + ox + 1, top - h), (hx + ox + 2, top - h), (hx + ox + 2, top + 2)], t, outline=True)
            for j in range(1 + d):
                yy = top - 3 - j * 3
                g.p([(hx + ox + 1, yy), (hx + ox + 5, yy - 3), (hx + ox + 5, yy - 2), (hx + ox + 2, yy + 1)], t)
    elif kind == "gem":
        g.e(hx - 1, top - 1, 2.5 + d * 0.5, 2.5 + d * 0.5, "light")


def crest(g, sp, A, d, tones):
    n = sp.get("crest")
    if not n:
        return
    body, head, accent = tones
    hx, hy, hr = A["head"]
    pts = arc(hx + 2, hy, hr + 1, hr, -150, -10, n + d)
    poly = [(hx - hr + 2, hy - 2)]
    for i, (x, y) in enumerate(pts):
        nx, ny = (x - hx - 2) / (hr + 1), (y - hy) / hr
        L = 5 + d + (2 if i == len(pts) // 2 else 0)
        poly += [(x + nx * L + 2, y + ny * L), (x + nx * 1.5 + 3, y + ny * 1.5 + 1)]
    poly.append((hx + hr, hy + 1))
    g.p(poly, sp.get("crest_tone", accent))


def extras_behind(g, sp, A, d, tones):
    body, head, accent = tones
    bx, by, brx, bry = A["body"]
    hx, hy, hr = A["head"]
    ex = sp.get("extras", ())
    if "halo" in ex:
        r = hr + 4 + d
        if d >= 1:
            for i in range(6 + 2 * d):
                a = math.radians(-180 + 360 * i / (6 + 2 * d))
                g.p([(hx + 2 + (r - 1) * math.cos(a - 0.2), hy - 2 + (r - 1) * math.sin(a - 0.2)),
                     (hx + 2 + (r + 4) * math.cos(a), hy - 2 + (r + 4) * math.sin(a)),
                     (hx + 2 + (r - 1) * math.cos(a + 0.2), hy - 2 + (r - 1) * math.sin(a + 0.2))], "light")
        g.e(hx + 2, hy - 2, r, r, "light")
    if "mane" in ex:
        n = 7 + 2 * d
        for i in range(n):
            a = math.radians(-200 + 260 * i / (n - 1))
            r = hr + 3
            g.p([(hx + 1 + r * 0.6 * math.cos(a - 0.4), hy + r * 0.6 * math.sin(a - 0.4)),
                 (hx + 1 + (r + 4) * math.cos(a), hy + (r + 4) * math.sin(a)),
                 (hx + 1 + r * 0.6 * math.cos(a + 0.4), hy + r * 0.6 * math.sin(a + 0.4))], accent)
        g.e(hx + 1, hy, hr + 3, hr + 2, accent)
    if "ball" in ex:
        r = 10 + d
        cx, cy = bx + brx - 6, by - bry - 3
        g.e(cx, cy, r, r, "light")
        g.e(cx, cy, r - 4, r - 4, "mid", outline=False)
        for i in range(4 + 2 * d):
            a = math.radians(-90 + 360 * i / (4 + 2 * d))
            g.st(cx + (r - 2) * math.cos(a), cy + (r - 2) * math.sin(a), ["3"], face=False)
    if "wings" in ex:
        w = 1.0 + 0.12 * d
        g.e(bx + 8, by - 15 * w, 8 * w, 11 * w, "dark")
        g.e(bx - 1, by - 16 * w, 8 * w, 12 * w, accent)
        for i in range(1 + d):
            g.st(bx - 3, by - 22 * w + 6 * i, [".0.", "030", ".0."], face=False)
    if "fins" in ex:
        g.p([(bx - 4, by - 8), (bx + 2, by - 16 - 2 * d), (bx + 10, by - 8)], accent)
    if "petals" in ex:
        n = 5 + d
        for i in range(n):
            a = math.radians(-170 + 160 * i / (n - 1))
            g.e(bx + (brx + 1) * math.cos(a), by - 2 + (bry + 1) * math.sin(a), 4 + d * 0.5, 4 + d * 0.5,
                accent if i % 2 == 0 else "light")
    if "flame" in ex:
        h = 10 + 3 * d
        g.p([(bx - 9, by - 4), (bx - 6, by - bry - h + 4), (bx - 2, by - bry - 2), (bx + 1, by - bry - h),
             (bx + 5, by - bry - 3), (bx + 8, by - bry - h + 6), (bx + 10, by - 4)], accent)
    if "sun" in ex:
        r = 5 + d
        g.e(bx + brx - 2, by - bry - 2, r, r, "light")
    if "palm" in ex:
        n = 3 + d
        for i in range(n):
            a = math.radians(-160 + 140 * i / max(n - 1, 1))
            g.p([(bx, by - bry + 1), (bx + 15 * math.cos(a) - 2, by - bry + 1 + 13 * math.sin(a)),
                 (bx + 17 * math.cos(a + 0.12), by - bry + 3 + 11 * math.sin(a + 0.12)), (bx + 2, by - bry + 3)], accent)
    if "spines" in ex:
        for (x, y) in arc(bx, by, brx, bry, -170, 10, 6 + 2 * d):
            nx, ny = (x - bx) / brx, (y - by) / bry
            g.p([(x - 1, y), (x + 1, y), (x + nx * 3, y + ny * 3)], "ink", outline=False, shade=False)


def extras_front(g, sp, A, d, tones):
    body, head, accent = tones
    bx, by, brx, bry = A["body"]
    hx, hy, hr = A["head"]
    ex = sp.get("extras", ())
    if "claws" in ex:
        r = 4 + d
        cx, cy = hx - hr - 1, hy + 4
        t = sp.get("claw_tone", "light")
        g.e(cx + 2, cy, 3 + d * 0.5, 3 + d * 0.5, t)
        g.p([(cx + 1, cy - 2), (cx - r - 1, cy - r - 1), (cx - r - 2, cy - 1)], t)
        g.p([(cx + 1, cy + 2), (cx - r - 1, cy + r), (cx - r - 2, cy + 1)], t)
    if "arms" in ex:
        g.e(bx - brx, by + 5, 3, 4, "dark")
        g.e(bx + brx, by + 5, 3, 4, "dark")
        if d >= 1:
            g.e(bx - brx - 1, by + 9, 2.5, 2.5, accent)
            g.e(bx + brx + 1, by + 9, 2.5, 2.5, accent)
    if "leafarms" in ex:
        g.p([(bx - brx + 2, by), (bx - brx - 8 - d, by - 4 - d), (bx - brx - 5, by + 4)], accent)
        g.p([(bx + brx - 2, by), (bx + brx + 8 + d, by - 5 - d), (bx + brx + 5, by + 4)], accent)
    if "wing" in ex:
        g.e(bx + 3, by - 1, brx - 3, bry - 3, accent)
        for i in range(d + 1):
            g.p([(bx + 1 + 3 * i, by + 1), (bx + 8 + 2 * i, by + bry - 2 - i), (bx + 9 + 2 * i, by + bry - 3 - i)],
                "dark", outline=False, shade=False)
    if "hindleg" in ex:
        g.p([(bx + 2, by + 2), (bx + 14 + d, by - 8), (bx + 16 + d, by - 6), (bx + 8, by + 8), (bx + 14, 52), (bx + 11, 52),
             (bx + 3, by + 7)], accent)
    if "shellpat" in ex:
        for i, (x, y) in enumerate(arc(bx, by, brx * 0.55, bry * 0.5, -165, -15, 3 + d)):
            g.e(x, y, 2.5, 2, "light" if body != "light" else "mid", outline=False, shade=False)
    if "cap" in ex:
        g.e(bx, by - bry + 2, brx + 5 + d, 6 + d, accent)
        for i, (x, y) in enumerate(arc(bx, by - bry + 2, brx + 1 + d, 3 + d, -160, -20, 3 + d)):
            g.st(x, y, ["33", "33"], face=False)
    if "eyes4" in ex:
        g.st(hx - 2, hy - hr + 3, ["0.0"])
    marks(g, sp, A, d)


def marks(g, sp, A, d):
    kind = sp.get("marks")
    if not kind:
        return
    bx, by, brx, bry = A["body"]
    n = 1 + d + sp.get("marks_n", 1)
    if kind == "spots":
        for i, (x, y) in enumerate(arc(bx, by, brx * 0.55, bry * 0.45, -160, 20, n)):
            g.st(x, y, ["33", "33"], face=False)
    elif kind == "stripes":
        for i in range(n):
            x = bx - brx * 0.5 + i * (brx * 1.1 / max(n - 1, 1))
            y0, y1 = (by + 1, by + bry - 2) if sp["plan"] in FRONTAL else (by - bry + 1, by - bry * 0.1)
            g.p([(x, y0), (x + 2, y0), (x + 1, y1), (x - 1, y1)], "dark",
                outline=False, shade=False)
    elif kind == "stars":
        for (x, y) in arc(bx, by, brx * 0.5, bry * 0.45, -150, 10, n):
            g.st(x - 1, y - 1, [".3.", "333", ".3."], face=False)
    elif kind == "band":
        g.e(bx, by, brx - 1, 2 + d * 0.5, "light", outline=False, shade=False)
    elif kind == "rings":
        for i in range(n):
            x = bx - brx * 0.5 + i * (brx * 1.1 / max(n - 1, 1))
            g.st(x, by - 2, ["0", "3", "0"], face=False)


def build(sp: dict, scale: float, d: int) -> list:
    g = G(scale)
    A = plan_anchors(sp)
    tones = tuple(sp.get("tones", ("mid", "light", "dark")))
    tail(g, sp, A, d, tones)
    if sp["plan"] not in ("shell",):
        back(g, sp, A, d, tones)
    extras_behind(g, sp, A, d, tones)
    ears(g, sp, A, d, tones)
    draw_body(g, sp, A, d, tones)
    if sp["plan"] == "shell":
        back(g, sp, A, d, tones)
    if not sp.get("crest_front"):
        crest(g, sp, A, d, tones)
    draw_head(g, sp, A, d, tones)
    horns(g, sp, A, d, tones)
    if sp.get("crest_front"):
        crest(g, sp, A, d, tones)
    extras_front(g, sp, A, d, tones)
    draw_face(g, sp, A, d)
    return g.parts


def stages(line: dict):
    """(name, parts) per species of the line, base form first."""
    names = line["names"]
    out = []
    for name, (scale, d) in zip(names, STAGES[len(names)]):
        spec = dict(line["art"])
        out.append((name, build(spec, scale, d)))
    return out


def _import_sidecar(png: str) -> None:
    side = png + ".import"
    if os.path.exists(side):
        return
    rel = "res://" + os.path.relpath(png, ROOT).replace(os.sep, "/")
    md5 = hashlib.md5(rel.encode()).hexdigest()
    base = os.path.basename(png)
    alphabet = "abcdefghijklmnopqrstuvwxy0123456789"
    h = int(hashlib.sha1(rel.encode()).hexdigest(), 16)
    uid = ""
    for _ in range(13):
        uid += alphabet[h % len(alphabet)]
        h //= len(alphabet)
    with open(side, "w") as f:
        f.write(IMPORT_TEMPLATE.format(uid=uid, base=base, md5=md5, rel=rel))


IMPORT_TEMPLATE = """[remap]

importer="texture"
type="CompressedTexture2D"
uid="uid://{uid}"
path="res://.godot/imported/{base}-{md5}.ctex"
metadata={{
"vram_texture": false
}}

[deps]

source_file="{rel}"
dest_files=["res://.godot/imported/{base}-{md5}.ctex"]

[params]

compress/mode=0
compress/high_quality=false
compress/lossy_quality=0.7
compress/uastc_level=0
compress/rdo_quality_loss=0.0
compress/hdr_compression=1
compress/normal_map=0
compress/channel_pack=0
mipmaps/generate=false
mipmaps/limit=-1
roughness/mode=0
roughness/src_normal=""
process/channel_remap/red=0
process/channel_remap/green=1
process/channel_remap/blue=2
process/channel_remap/alpha=3
process/fix_alpha_border=true
process/premult_alpha=false
process/normal_map_invert_y=false
process/hdr_as_srgb=false
process/hdr_clamp_exposure=false
process/size_limit=0
detect_3d/compress_to=1
"""


def load_lines(region: str) -> list:
    sys.path.insert(0, os.path.join(HERE, "lines"))
    return importlib.import_module(region).LINES


def sheet(lines: list, path: str, title: str) -> None:
    from PIL import Image, ImageDraw
    from px import PALETTE
    z = 2
    cell = S * z
    rows = len(lines)
    w = 8 + 3 * (2 * cell + 8) + 8
    h = 34 + rows * (cell + 16)
    img = Image.new("RGBA", (w, h), PALETTE[3] + (255,))
    dr = ImageDraw.Draw(img)
    dr.text((8, 8), title, fill=PALETTE[0] + (255,))
    for r, line in enumerate(lines):
        y = 30 + r * (cell + 16)
        for i, (name, parts) in enumerate(stages(line)):
            x = 8 + i * (2 * cell + 8)
            front = render(parts).image().resize((cell, cell), Image.NEAREST)
            bk = shift_down(render(parts, back=True).mirrored(), BACK_DROP).image().resize((cell, cell), Image.NEAREST)
            dr.rectangle([x, y, x + 2 * cell - 1, y + cell - 1], fill=(0xE6, 0xD3, 0xAE, 255))
            img.alpha_composite(front, (x, y))
            img.alpha_composite(bk, (x + cell, y))
            dr.text((x + 2, y + cell + 2), "%s  %s" % (name, "/".join(e[:3] for e in line["elements"])),
                    fill=PALETTE[0] + (255,))
    img.save(path)


def main() -> None:
    region = sys.argv[1]
    lines = load_lines(region)
    os.makedirs(OUT, exist_ok=True)
    for line in lines:
        for name, parts in stages(line):
            front = os.path.join(OUT, f"{name.lower()}_front.png")
            render(parts).save(front)
            back_png = os.path.join(OUT, f"{name.lower()}_back.png")
            shift_down(render(parts, back=True).mirrored(), BACK_DROP).save(back_png)
            _import_sidecar(front)
            _import_sidecar(back_png)
    if "--sheet" in sys.argv:
        sheet(lines, sys.argv[sys.argv.index("--sheet") + 1], "%s - %d new Spirlings" % (
            region.capitalize(), sum(len(l["names"]) for l in lines)))


if __name__ == "__main__":
    main()
