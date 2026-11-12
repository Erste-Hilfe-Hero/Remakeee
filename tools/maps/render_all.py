"""Renders every map and floor in data/maps/ to PNG with tools/art/preview_map.render (the same
tile rules as TilesetFactory), one image per map plus a contact sheet per region.
Usage: python3 tools/maps/render_all.py <out_dir> [prefix] [--era2] [--marks]
--marks outlines every cell tools/maps/audit_maps.py flags in red.
--era2 renders with the shared Era II atlas (art/era2/tiles/overworld.png) instead of the
region's Era I atlas, the way TilesetFactory.atlas_path() picks it once Era II is active.
"""
import json
import os
import sys

from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, "..", "art"))
from preview_map import ROOT, load_level, render  # noqa: E402


def map_ids() -> list:
    out = []
    for f in sorted(os.listdir(os.path.join(ROOT, "data", "maps"))):
        if not f.endswith(".json"):
            continue
        mid = f[:-5]
        out.append(mid)
        d = json.load(open(os.path.join(ROOT, "data", "maps", f)))
        # Floors without rows (echo_path slots) are built at runtime (EchoPath) and are skipped.
        out += ["%s@%d" % (mid, i + 1) for i, fl in enumerate(d.get("floors", [])) if "rows" in fl]
    return out


def with_blocks(d: dict) -> dict:
    """Puzzle blocks drawn closed, the way the map looks on a first visit (MapData.blocks)."""
    rows = [list(r) for r in d["rows"]]
    for b in d.get("blocks", []):
        x, y = int(b["x"]), int(b["y"])
        if 0 <= y < len(rows) and 0 <= x < len(rows[y]):
            rows[y][x] = str(b.get("closed", "@"))
    d = dict(d)
    d["rows"] = ["".join(r) for r in rows]
    return d


def sheet(images: list, out: str, cols: int = 6) -> None:
    cw = max(i.width for _, i in images) + 8
    ch = max(i.height for _, i in images) + 20
    rows = (len(images) + cols - 1) // cols
    s = Image.new("RGBA", (cols * cw + 8, rows * ch + 8), (32, 26, 34, 255))
    dr = ImageDraw.Draw(s)
    for n, (mid, img) in enumerate(images):
        x, y = 8 + (n % cols) * cw, 8 + (n // cols) * ch
        dr.text((x, y), mid, fill=(242, 227, 194, 255))
        s.paste(img, (x, y + 12), img)
    s.save(out)


def main() -> None:
    out_dir = sys.argv[1]
    prefix = sys.argv[2] if len(sys.argv) > 2 and not sys.argv[2].startswith("--") else ""
    atlas = os.path.join(ROOT, "art", "era2", "tiles", "overworld.png") if "--era2" in sys.argv else ""
    os.makedirs(out_dir, exist_ok=True)
    marks = {}
    if "--marks" in sys.argv:
        from audit_maps import audit
        for f in audit():
            marks.setdefault(f["map"], []).append(f)
    by_region = {}
    for mid in map_ids():
        d = load_level(mid)
        d["id"] = mid
        img = render(with_blocks(d), atlas)
        dr = ImageDraw.Draw(img)
        for f in marks.get(mid, []):
            x, y = max(int(f["x"]), 0), max(int(f["y"]), 0)
            dr.rectangle((x * 16, y * 16, x * 16 + 15, y * 16 + 15), outline=(230, 40, 40, 255), width=2)
        img.save(os.path.join(out_dir, "%s%s.png" % (prefix, mid.replace("@", "_f"))))
        by_region.setdefault(d.get("region", "veydal"), []).append((mid, img))
    for region, imgs in by_region.items():
        sheet(imgs, os.path.join(out_dir, "%ssheet_%s.png" % (prefix, region)))
    print("rendered", sum(len(v) for v in by_region.values()), "maps")


if __name__ == "__main__":
    main()
