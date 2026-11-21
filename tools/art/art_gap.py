#!/usr/bin/env python3
"""Spirling art coverage per origin era and region.

    python3 tools/art/art_gap.py          print the table
    python3 tools/art/art_gap.py --check  exit 1 if a Spirling of data/spirlings.json, or a kind
                                          named in an encounter table or Tamer team, has no art

A Spirling has art when art/era<its era>/spirlings/<name>_front.png and _back.png exist (or the
same file in an older era, the way EraManager.sprite_path walks back) and data/gleam_palettes.json
holds its Gleam palette. "spec" counts the kinds of tools/art/lines/<region>.py, "drawn" the spec
kinds whose sprites are on disk; a region with drawn > in data waits for its data step.
"""
import glob, importlib, json, os, sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
REGION_ERA = {"veydal": 1, "ashmere": 1, "corvane": 1, "solenne": 1,
              "vellmarch": 2, "quillmarch": 3, "halcyra": 4, "quivermoor": 5}
TARGET = 70


def has_art(name, era, facing):
    return any(os.path.exists(os.path.join(ROOT, "art", "era%d" % e, "spirlings", "%s_%s.png" % (name.lower(), facing)))
               for e in range(era, 0, -1))


def used_species():
    """Every kind named by a "species" or "stand_in" key in data/*.json and data/maps/*.json."""
    out = {}

    def walk(o, src):
        if isinstance(o, dict):
            for k, v in o.items():
                if k in ("species", "stand_in") and isinstance(v, str) and v:
                    out.setdefault(v, src)
                walk(v, src)
        elif isinstance(o, list):
            for v in o:
                walk(v, src)
    for f in sorted(glob.glob(os.path.join(ROOT, "data", "*.json")) + glob.glob(os.path.join(ROOT, "data", "maps", "*.json"))):
        walk(json.load(open(f, encoding="utf-8")), os.path.relpath(f, ROOT))
    return out


def main():
    species = json.load(open(os.path.join(ROOT, "data", "spirlings.json"), encoding="utf-8"))
    gleam = json.load(open(os.path.join(ROOT, "data", "gleam_palettes.json"), encoding="utf-8"))["palettes"]
    sys.path.insert(0, os.path.join(ROOT, "tools", "art", "lines"))
    rows = {r: dict(era=e, data=0, missing=[], spec=0, drawn=0) for r, e in REGION_ERA.items()}
    by_name = {}
    for sp in species:
        era = int(sp.get("era", 1))
        row = rows.setdefault(sp.get("region", "?"), dict(era=era, data=0, missing=[], spec=0, drawn=0))
        row["data"] += 1
        by_name[sp["name"]] = era
        lacks = [f for f in ("front", "back") if not has_art(sp["name"], era, f)]
        if sp["name"] not in gleam:
            lacks.append("gleam")
        if lacks:
            row["missing"].append("%s (%s)" % (sp["name"], ", ".join(lacks)))
    for region, row in rows.items():
        if not os.path.exists(os.path.join(ROOT, "tools", "art", "lines", region + ".py")):
            continue
        mod = importlib.import_module(region)
        names = [n for line in mod.LINES for n in line["names"]]
        row["spec"] = len(names)
        era = getattr(mod, "ERA", row["era"])
        row["drawn"] = sum(1 for n in names if has_art(n, era, "front") and has_art(n, era, "back"))
    print("%-11s %3s %8s %12s %6s %6s %s" % ("region", "era", "in data", "without art", "spec", "drawn", "own kinds short of %d" % TARGET))
    bad = 0
    for region, row in sorted(rows.items(), key=lambda kv: (kv[1]["era"], kv[0])):
        bad += len(row["missing"])
        print("%-11s %3d %8d %12d %6d %6d %d" % (region, row["era"], row["data"], len(row["missing"]), row["spec"],
                                               row["drawn"], max(0, TARGET - max(row["data"], row["drawn"]))))
        for m in row["missing"]:
            print("   no art:", m)
    for name, src in sorted(used_species().items()):
        if name not in by_name:
            print("   unknown kind in %s: %s" % (src, name))
            bad += 1
    print("Spirlings in data: %d, without art: %d" % (len(species), bad))
    return 1 if bad and "--check" in sys.argv else 0


if __name__ == "__main__":
    sys.exit(main())
