"""Contact sheet of every act's town tiles (buildings design plan item 9): houses with each door
role (healer, shop, Rift gate, house), wide and narrow houses, fence, sign, lamp, spring and Rift
gate, drawn from each act's own atlas with the same rules as the game (preview_map.render).
Usage: python3 tools/art/buildings_sheet.py [out.png] [scale]   (default build/previews/buildings.png)
"""
import os
import sys

from PIL import Image, ImageDraw

import preview_map as pm

ACTS = ["veydal", "corvane", "ashmere", "solenne"]
ROWS = ["..............",
        ".RRR..RRR.RRRR",
        ".RRR..RRR.RRRR",
        ".HDH..HDH.HHDH",
        "..............",
        ".RRRRR..RR.RRR",
        ".HDHHH..DH.HDH",
        "..............",
        ".#####.S.L.o..",
        "..............",
        "...X......*...",
        ".............."]
WARPS = [{"x": 2, "y": 3, "to": "rest_spring"}, {"x": 7, "y": 3, "to": "sheet_guild"},
         {"x": 12, "y": 3, "to": "sheet_rift"}]


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else os.path.join(pm.ROOT, "build", "previews", "buildings.png")
    s = int(sys.argv[2]) if len(sys.argv) > 2 else 4
    imgs = [(a, pm.render({"region": a, "rows": ROWS, "warps": WARPS, "outdoor": True, "biome": "field"})) for a in ACTS]
    w, h = imgs[0][1].size
    sheet = Image.new("RGBA", ((w * s + 12) * 2 + 12, (h * s + 24) * 2 + 12), (42, 30, 44, 255))
    draw = ImageDraw.Draw(sheet)
    for i, (act, im) in enumerate(imgs):
        x, y = 12 + (i % 2) * (w * s + 12), 12 + (i // 2) * (h * s + 24)
        draw.text((x, y), act + ": doors healer, shop, Rift gate; houses; fence, sign, lamp, spring; Rift",
                  fill=(242, 227, 194, 255))
        sheet.paste(im.resize((w * s, h * s), Image.NEAREST), (x, y + 14))
    os.makedirs(os.path.dirname(out) or ".", exist_ok=True)
    sheet.save(out)
    print("wrote", out)


if __name__ == "__main__":
    main()
