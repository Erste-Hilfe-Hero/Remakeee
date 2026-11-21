#!/usr/bin/env python3
"""Era V preview: builds idle / attack / hit frame strips from base battle sprites exactly as
scripts/battle/presenter/BattleAnim.gd does (values from data/era5_anim.json) and writes an
animated GIF and a sheet PNG per species, plus a battle-camera demo GIF.

Herkunft: all frames are derived from the project's own generated sprites; no outside art.
Usage: era5_anim_preview.py OUT_DIR SPECIES [SPECIES ...]
"""
import json, os, sys
from PIL import Image, ImageDraw

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = json.load(open(os.path.join(ROOT, "data/era5_anim.json")))
KINDS = ["idle", "attack", "hit"]
SCALE = 3


def sprite(species):
    for era in range(4, 0, -1):
        p = os.path.join(ROOT, f"art/era{era}/spirlings/{species.lower()}_front.png")
        if os.path.exists(p):
            return Image.open(p).convert("RGBA")
    raise SystemExit(f"no sprite for {species}")


def frames(base, kind):
    c = CFG["strips"][kind]
    dxs, dys, fl = c.get("dx", []), c.get("dy", []), c.get("flash", [])
    n = max(len(dxs) or len(dys), 1)
    col = tuple(int(CFG["flash_color"][i:i + 2], 16) for i in (0, 2, 4))
    out = []
    for f in range(n):
        dx = -(dxs[f] if f < len(dxs) else 0)
        dy = dys[f] if f < len(dys) else 0
        fr = Image.new("RGBA", base.size, (0, 0, 0, 0))
        src = base
        if f < len(fl) and fl[f]:
            a = base.split()[3]
            src = Image.new("RGBA", base.size, col + (255,))
            src.putalpha(a)
        fr.paste(src, (dx, dy), src)
        out.append(fr)
    return out


def on_bg(img, bg=(242, 227, 194, 255)):
    b = Image.new("RGBA", img.size, bg)
    b.alpha_composite(img)
    return b.convert("RGB").resize((img.width * SCALE, img.height * SCALE), Image.NEAREST)


def main():
    out_dir, species = sys.argv[1], sys.argv[2:]
    os.makedirs(out_dir, exist_ok=True)
    for sp in species:
        base = sprite(sp)
        seq, durs, rows = [], [], []
        for k in KINDS:
            fs = frames(base, k)
            ms = int(1000 / CFG["strips"][k]["fps"])
            reps = 3 if k == "idle" else 1
            for _ in range(reps):
                seq += [on_bg(f) for f in fs]
                durs += [ms] * len(fs)
            rows.append(fs)
        seq[0].save(os.path.join(out_dir, f"{sp.lower()}_anim.gif"), save_all=True,
                    append_images=seq[1:], duration=durs, loop=0, disposal=2)
        w, h = base.size
        sheet = Image.new("RGBA", (w * max(len(r) for r in rows), h * len(rows)), (242, 227, 194, 255))
        for y, r in enumerate(rows):
            for x, f in enumerate(r):
                sheet.alpha_composite(f, (x * w, y * h))
        sheet.convert("RGB").resize((sheet.width * SCALE, sheet.height * SCALE), Image.NEAREST).save(
            os.path.join(out_dir, f"{sp.lower()}_sheet.png"))
    if len(species) >= 2:
        camera_demo(out_dir, species[0], species[1])


def camera_demo(out_dir, a, b):
    W, H = 144, 120
    cam = CFG["camera"]
    pa, pb = (8, 56), (80, 4)
    ra, rb = sprite(a), sprite(b).transpose(Image.FLIP_LEFT_RIGHT)
    atk, hit = frames(ra, "attack"), frames(rb, "hit")
    mid = ((pa[0] + 28 + pb[0] + 28) / 2, (pa[1] + 28 + pb[1] + 28) / 2)
    share = cam["pan_share"]
    pv = (W / 2 + (mid[0] - W / 2) * share, H / 2 + (mid[1] - H / 2) * share)
    steps = 6
    zooms = [1 + (cam["zoom"] - 1) * min(i / steps, 1) for i in range(steps + 1)]
    plan = [(1.0, 0, 0)] * 3 + [(z, 0, 0) for z in zooms] + \
        [(cam["zoom"], i, 0) for i in range(len(atk))] + \
        [(cam["zoom"], len(atk) - 1, j) for j in range(len(hit))] + \
        [(z, 0, 0) for z in reversed(zooms)] + [(1.0, 0, 0)] * 3
    seq = []
    for z, ai, hi in plan:
        field = Image.new("RGBA", (W, H), (242, 227, 194, 255))
        d = ImageDraw.Draw(field)
        d.ellipse((pa[0] - 4, pa[1] + 48, pa[0] + 60, pa[1] + 60), fill=(196, 138, 94, 255))
        d.ellipse((pb[0] - 4, pb[1] + 48, pb[0] + 60, pb[1] + 60), fill=(196, 138, 94, 255))
        fa = atk[ai].transpose(Image.FLIP_LEFT_RIGHT)
        field.alpha_composite(fa, pa)
        field.alpha_composite(hit[hi], pb)
        nw, nh = int(W * z), int(H * z)
        big = field.resize((nw, nh), Image.NEAREST)
        ox, oy = int(pv[0] * z - pv[0]), int(pv[1] * z - pv[1])
        view = big.crop((ox, oy, ox + W, oy + H))
        seq.append(view.convert("RGB").resize((W * SCALE, H * SCALE), Image.NEAREST))
    seq[0].save(os.path.join(out_dir, "battle_camera.gif"), save_all=True,
                append_images=seq[1:], duration=60, loop=0)


if __name__ == "__main__":
    main()
