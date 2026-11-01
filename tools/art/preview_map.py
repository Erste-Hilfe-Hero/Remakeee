"""Renders data/maps/<id>.json to a PNG with the Era I atlas (same variant rules as
TilesetFactory.atlas_coords), for reviewing map layouts without starting Godot.
Usage: python3 tools/art/preview_map.py <map_id> [out.png] [scale]
"""
import json
import os
import sys

from PIL import Image

from gen_tiles import KINDS, K

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
LEGEND = {".": "GRASS", ",": "TALL_GRASS", "_": "PATH", "~": "WATER", "T": "TREE", "H": "WALL",
          "R": "ROOF", "D": "DOOR", "f": "FLOOR", "#": "FENCE", "S": "SIGN", "*": "FLOWER",
          "C": "COUNTER", "W": "INNER_WALL", "o": "SPRING", "X": "RIFT", "^": "CLIFF",
          "=": "STAIRS", "%": "REEDS", ":": "SCREE", "+": "PIER", "|": "TOWER", "L": "LAMP",
          "@": "ROCK"}
MASKED = {"PATH", "WATER", "ROOF", "WALL", "FENCE", "CLIFF", "PIER"}
SCATTERED = {"GRASS", "TALL_GRASS", "TREE", "FLOWER", "REEDS", "SCREE", "ROCK"}
JOINS = {"PATH": {"DOOR", "SIGN"}, "WALL": {"DOOR"}, "FENCE": {"SIGN"},
         "WATER": {"REEDS", "PIER"}, "PIER": {"PATH", "STAIRS"}, "CLIFF": {"STAIRS"}}


def main() -> None:
    map_id = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else f"{map_id}.png"
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    d = json.load(open(os.path.join(ROOT, "data", "maps", map_id + ".json")))
    rows = d["rows"]
    atlas = Image.open(os.path.join(ROOT, "art", "era1", "tiles", "overworld.png"))
    h, w = len(rows), max(len(r) for r in rows)
    img = Image.new("RGBA", (w * 16, h * 16))

    def kind(x: int, y: int, default: str) -> str:
        if 0 <= y < h and 0 <= x < len(rows[y]):
            return LEGEND[rows[y][x]]
        return default

    for y in range(h):
        for x in range(len(rows[y])):
            k = LEGEND[rows[y][x]]
            v = 0
            if k in MASKED:
                for bit, (dx, dy) in zip((1, 2, 4, 8), ((0, -1), (1, 0), (0, 1), (-1, 0))):
                    o = kind(x + dx, y + dy, k)
                    if o == k or o in JOINS.get(k, set()):
                        v |= bit
            elif k in SCATTERED:
                v = abs(x * 7 + y * 13 + (x * y) % 5) % 4
            col = K[k]
            img.paste(atlas.crop((col * 16, v * 16, col * 16 + 16, v * 16 + 16)), (x * 16, y * 16))
    for n in d.get("npcs", []):
        style = n.get("sprite", "villager")
        sheet = Image.open(os.path.join(ROOT, "art", "era1", "chars", style + ".png"))
        col = ["down", "up", "left", "right"].index(n.get("facing", "down"))
        fr = sheet.crop((col * 16, 0, col * 16 + 16, 16))
        img.paste(fr, (int(n["x"]) * 16, int(n["y"]) * 16), fr)
    img.resize((w * 16 * scale, h * 16 * scale), Image.NEAREST).save(out)


if __name__ == "__main__":
    main()
