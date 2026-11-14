"""Tiny pixel-art helpers shared by the Era I art generators.

Everything is drawn on an index canvas: None = transparent, 0..3 = the four Era I shades
(0 darkest, 3 lightest). `save()` maps indices to the fixed Era I inks.
"""
from __future__ import annotations

import math
from PIL import Image

# Era I "Ink" palette (same values as EraManager.INK_PALETTE), darkest to lightest.
PALETTE = [(0x2A, 0x1E, 0x2C), (0x6A, 0x42, 0x56), (0xC4, 0x8A, 0x5E), (0xF2, 0xE3, 0xC2)]


class Canvas:
    def __init__(self, w: int, h: int, fill=None):
        self.w, self.h = w, h
        self.px = [[fill] * w for _ in range(h)]

    def get(self, x: int, y: int):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.px[y][x]
        return None

    def set(self, x: int, y: int, v) -> None:
        if 0 <= x < self.w and 0 <= y < self.h:
            self.px[y][x] = v

    def rect(self, x: int, y: int, w: int, h: int, v) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, v)

    def hline(self, x0: int, x1: int, y: int, v) -> None:
        for x in range(x0, x1 + 1):
            self.set(x, y, v)

    def vline(self, x: int, y0: int, y1: int, v) -> None:
        for y in range(y0, y1 + 1):
            self.set(x, y, v)

    def checker(self, x: int, y: int, w: int, h: int, a, b, phase: int = 0) -> None:
        for yy in range(y, y + h):
            for xx in range(x, x + w):
                self.set(xx, yy, a if (xx + yy + phase) % 2 == 0 else b)

    def ascii(self, ox: int, oy: int, rows: list[str], mirror: bool = False) -> None:
        """Stamps rows of '.', '0'..'3' (dot = leave as is)."""
        for y, row in enumerate(rows):
            if mirror:
                row = row[::-1]
            for x, ch in enumerate(row):
                if ch in "0123":
                    self.set(ox + x, oy + y, int(ch))

    def blit(self, other: "Canvas", ox: int, oy: int) -> None:
        for y in range(other.h):
            for x in range(other.w):
                v = other.px[y][x]
                if v is not None:
                    self.set(ox + x, oy + y, v)

    def mirrored(self) -> "Canvas":
        c = Canvas(self.w, self.h)
        for y in range(self.h):
            c.px[y] = list(reversed(self.px[y]))
        return c

    def image(self) -> Image.Image:
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        for y in range(self.h):
            for x in range(self.w):
                v = self.px[y][x]
                if v is not None:
                    img.putpixel((x, y), PALETTE[v] + (255,))
        return img

    def save(self, path: str) -> None:
        self.image().save(path)


# --- Shape masks ---------------------------------------------------------------------

def ellipse_mask(cx: float, cy: float, rx: float, ry: float):
    def inside(x: float, y: float) -> bool:
        dx = (x + 0.5 - cx) / rx
        dy = (y + 0.5 - cy) / ry
        return dx * dx + dy * dy <= 1.0
    return inside


def poly_mask(points: list[tuple[float, float]]):
    def inside(x: float, y: float) -> bool:
        px, py = x + 0.5, y + 0.5
        n = len(points)
        c = False
        j = n - 1
        for i in range(n):
            xi, yi = points[i]
            xj, yj = points[j]
            if (yi > py) != (yj > py) and px < (xj - xi) * (py - yi) / (yj - yi + 1e-9) + xi:
                c = not c
            j = i
        return c
    return inside


def rect_mask(x0: float, y0: float, x1: float, y1: float):
    def inside(x: float, y: float) -> bool:
        return x0 <= x < x1 and y0 <= y < y1
    return inside


def union(*masks):
    def inside(x: float, y: float) -> bool:
        return any(m(x, y) for m in masks)
    return inside


def minus(a, b):
    def inside(x: float, y: float) -> bool:
        return a(x, y) and not b(x, y)
    return inside
