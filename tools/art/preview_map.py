"""Renders data/maps/<id>.json to a PNG with the Era I atlas (same variant rules as
TilesetFactory.atlas_coords), for reviewing map layouts without starting Godot.
Usage: python3 tools/art/preview_map.py <map_id> [out.png] [scale]
       python3 tools/art/preview_map.py --region veydal [out.png]
The region mode (area 3 item 897) puts every map of a region on one sheet, placed by its grid
cell in data/world_layout.json, so gaps in the layout show at a glance. Default output:
build/previews/<region>.png. A map id may name a floor: "copper_deep@2".
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
          "@": "ROCK", "w": "WADE", "B": "BOULDER", "P": "PLATE", "k": "CRACKED", "v": "VINES",
          "Y": "PLANK"}
MASKED = {"PATH", "WATER", "ROOF", "WALL", "FENCE", "CLIFF", "PIER", "WADE"}
SCATTERED = {"GRASS", "TALL_GRASS", "TREE", "FLOWER", "REEDS", "SCREE", "ROCK"}
JOINS = {"PATH": {"DOOR", "SIGN"}, "WALL": {"DOOR"}, "FENCE": {"SIGN"},
         "WATER": {"REEDS", "PIER", "WADE"}, "WADE": {"WATER"}, "PIER": {"PATH", "STAIRS"}, "CLIFF": {"STAIRS"}}


def load_level(map_id: str) -> dict:
    file, _, level = map_id.partition("@")
    d = json.load(open(os.path.join(ROOT, "data", "maps", file + ".json")))
    if level:
        floor = dict(d["floors"][int(level) - 1])
        for k in ("name", "region"):
            floor.setdefault(k, d.get(k))
        return floor
    return d


def region_look(region) -> dict:
    """The region's own inks from data/region_looks.json ({} = shared inks)."""
    looks = json.load(open(os.path.join(ROOT, "data", "region_looks.json")))
    look = looks.get("regions", {}).get(region or "", {})
    return look if isinstance(look, dict) else {}


def ink_swap(img: Image.Image, inks) -> Image.Image:
    """Recolours an Era I image from the shared inks to `inks`, as the screen filter does."""
    from px import PALETTE
    table = {PALETTE[i]: tuple(int(h[j:j + 2], 16) for j in (0, 2, 4)) for i, h in enumerate(inks)}
    out = img.convert("RGBA")
    out.putdata([table.get(p[:3], p[:3]) + (p[3],) for p in out.getdata()])
    return out


SHADE_FROM = {"WALL", "ROOF", "DOOR"}


def door_roles(d: dict) -> dict:
    """Same rules as MapData.door_roles(): 1 healer, 2 shop, 3 Rift gate, else 0 (house)."""
    rows = d["rows"]
    doors = [(x, y) for y, r in enumerate(rows) for x, ch in enumerate(r) if ch == "D"]
    roles, warped = {}, set()
    for w in d.get("warps", []):
        cell = (int(w["x"]), int(w["y"]))
        if cell not in doors:
            continue
        warped.add(cell)
        to = str(w["to"])
        if "rift" in to or to.startswith("undrawn"):
            roles[cell] = 3
        elif "spring" in to:
            roles[cell] = 1
        elif any(s in to for s in ("guild", "shop", "market", "bazaar")):
            roles[cell] = 2
    if d.get("outdoor") and d.get("biome") == "town":
        free = [c for c in doors if c not in roles and c not in warped]
        hp = d.get("heal_point")
        if hp and 1 not in roles.values() and free:
            best = min(free, key=lambda c: (abs(c[0] - hp[0]) + abs(c[1] - hp[1]), c[1], c[0]))
            roles[best] = 1
            free.remove(best)
        if 2 not in roles.values() and free:
            roles[free[0]] = 2
    return roles


def render(d: dict, atlas_path: str = "") -> Image.Image:
    rows = d["rows"]
    tiles = os.path.join(ROOT, "art", "era1", "tiles")
    regional = os.path.join(tiles, "overworld_%s.png" % d.get("region", "veydal"))
    atlas = Image.open(atlas_path or (regional if os.path.exists(regional) else os.path.join(tiles, "overworld.png")))
    roles = door_roles(d)
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
                if k == "GRASS" and kind(x - 1, y, k) in SHADE_FROM:
                    v += 4
            elif k == "DOOR":
                v = roles.get((x, y), 0)
            col = K[k]
            img.paste(atlas.crop((col * 16, v * 16, col * 16 + 16, v * 16 + 16)), (x * 16, y * 16))
    for n in d.get("npcs", []):
        style = n.get("sprite", "villager")
        sheet_path = os.path.join(ROOT, "art", "era1", "chars", style + ".png")
        if not os.path.exists(sheet_path):
            sheet_path = os.path.join(ROOT, "art", "era1", "chars", "villager.png")
        sheet = Image.open(sheet_path)
        look = region_look(d.get("region"))
        if "palette" in look:
            sheet = ink_swap(sheet, look["palette"])
        col = ["down", "up", "left", "right"].index(n.get("facing", "down"))
        fr = sheet.crop((col * 16, 0, col * 16 + 16, 16))
        img.paste(fr, (int(n["x"]) * 16, int(n["y"]) * 16), fr)
    return img


def region_sheet(region: str, out: str) -> None:
    from PIL import ImageDraw
    layout = json.load(open(os.path.join(ROOT, "data", "world_layout.json")))
    places = {k: v for k, v in layout["maps"].items() if v.get("region") == region and "pos" in v}
    if not places:
        raise SystemExit("no maps in region %s" % region)
    cell_w, cell_h, label = 12 * 8, 40 * 8, 12
    xs = [p["pos"][0] for p in places.values()]
    ys = [p["pos"][1] for p in places.values()]
    x0, y0 = min(xs), min(ys)
    sheet = Image.new("RGBA", ((max(xs) - x0 + 1) * (cell_w + 8) + 8, (max(ys) - y0 + 1) * (cell_h + label + 8) + 8),
                      (42, 30, 44, 255))
    draw = ImageDraw.Draw(sheet)
    for pid, p in sorted(places.items()):
        d = load_level(pid)
        img = render(d)
        img.thumbnail((cell_w, cell_h), Image.NEAREST)
        px = 8 + (p["pos"][0] - x0) * (cell_w + 8)
        py = 8 + (p["pos"][1] - y0) * (cell_h + label + 8)
        draw.text((px, py), pid, fill=(242, 227, 194, 255))
        sheet.paste(img, (px, py + label), img)
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print("wrote", out)


def main() -> None:
    if sys.argv[1] == "--region":
        region = sys.argv[2]
        out = sys.argv[3] if len(sys.argv) > 3 else os.path.join(ROOT, "build", "previews", region + ".png")
        region_sheet(region, out)
        return
    map_id = sys.argv[1]
    out = sys.argv[2] if len(sys.argv) > 2 else f"{map_id}.png"
    scale = int(sys.argv[3]) if len(sys.argv) > 3 else 2
    img = render(load_level(map_id))
    img.resize((img.width * scale, img.height * scale), Image.NEAREST).save(out)


if __name__ == "__main__":
    main()
