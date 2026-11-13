#!/usr/bin/env python3
"""Sprite tier coverage: per era, how many Spirling kinds have a front sprite, a back sprite,
menu icons and a pose sheet (tools/art/gen_tiers.py, data/sprite_tiers.json).

    python3 tools/art/tier_coverage.py           print the table (Markdown)
    python3 tools/art/tier_coverage.py --check   exit 1 when a kind of data/spirlings.json, or a kind
                                                 named by a wild table or Tamer team, lacks a part

"In data" counts the kinds of data/spirlings.json by their "era"; "art" counts the ids with a front
sprite in art/eraN/spirlings/ (a region's art can be ahead of its data). "Used" are the kinds named
as "species" or "stand_in" anywhere in data/*.json and data/maps/*.json.
"""
import glob, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
CFG = json.load(open(os.path.join(ROOT, "data", "sprite_tiers.json"), encoding="utf-8"))
ERAS = sorted(int(e) for e in CFG["tiers"])
PARTS = ["front", "back", "icon", "anim"]


def part_path(era, kid, part):
    sub, name = {"front": ("spirlings", kid + "_front.png"), "back": ("spirlings", kid + "_back.png"),
                 "icon": ("spirling_icons", kid + ".png"), "anim": ("spirling_anim", kid + ".png")}[part]
    return os.path.join(ROOT, "art", f"era{era}", sub, name)


def has(era, kid, part):
    return os.path.exists(part_path(era, kid, part))


def art_ids(era):
    d = os.path.join(ROOT, "art", f"era{era}", "spirlings")
    return sorted(f[:-len("_front.png")] for f in os.listdir(d) if f.endswith("_front.png")) if os.path.isdir(d) else []


def collect(node, into):
    if isinstance(node, dict):
        for k, v in node.items():
            if k in ("species", "stand_in") and isinstance(v, str) and v:
                into.add(v)
            collect(v, into)
    elif isinstance(node, list):
        for v in node:
            collect(v, into)


def used_kinds():
    out = set()
    for p in sorted(glob.glob(os.path.join(ROOT, "data", "*.json")) + glob.glob(os.path.join(ROOT, "data", "maps", "*.json"))):
        collect(json.load(open(p, encoding="utf-8")), out)
    return out


def main():
    data = json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))
    era_of = {s["name"]: int(s.get("era", 1)) for s in data}
    used = {k for k in used_kinds() if k in era_of}
    rows, missing = [], []
    for era in ERAS:
        ids = art_ids(era)
        in_data = [n for n, e in era_of.items() if e == era]
        counts = {p: sum(has(era, k, p) for k in ids) for p in PARTS}
        used_here = [n for n in in_data if n in used]
        full = 0
        for n in in_data:
            lacks = [p for p in PARTS if not has(era, n.lower(), p)]
            if lacks:
                missing.append(f"{n} (era {era}): no {', '.join(lacks)}")
            elif n in used:
                full += 1
        t = CFG["tiers"][str(era)]
        frames = "/".join(str(len(t["anim"][k]["cells"])) for k in CFG["kinds"])
        rows.append((era, t["label"], t["canvas"], len(t["poses"]), frames, len(in_data), len(ids),
                     counts["front"], counts["back"], counts["icon"], counts["anim"], f"{full}/{len(used_here)}"))
    print("| Era | Tier | Canvas | Poses | Frames idle/attack/hit | In data | Art | Front | Back | Icon | Anim | Used kinds complete |")
    print("|---|---|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        print("| " + " | ".join(str(c) for c in r) + " |")
    tot = [sum(r[i] for r in rows) for i in range(5, 11)]
    print(f"| all | | | | | {tot[0]} | {tot[1]} | {tot[2]} | {tot[3]} | {tot[4]} | {tot[5]} | "
          f"{sum(int(r[11].split('/')[0]) for r in rows)}/{len(used)} |")
    if missing:
        print(f"\n{len(missing)} kind(s) of data/spirlings.json lack a part:")
        print("\n".join(missing[:40]))
    if "--check" in sys.argv and missing:
        sys.exit(1)


if __name__ == "__main__":
    main()
