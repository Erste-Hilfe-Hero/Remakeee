#!/usr/bin/env python3
"""World statistics per map (area 3 item 903): size, hidden finds, Wayfarers and wild cells.
Also the list of Wayfarer Gear and where each piece is given out (item 1062).

Usage: python3 tools/world_stats.py            prints the table and writes it into docs/WORLD.md
       python3 tools/world_stats.py --check    fails if docs/WORLD.md is out of date
The table sits between the markers <!-- world-stats:start --> and <!-- world-stats:end -->.
"""
import glob
import json
import os
import sys

ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
DOC = os.path.join(ROOT, "docs", "WORLD.md")
START = "<!-- world-stats:start -->"
END = "<!-- world-stats:end -->"
GEAR_START = "<!-- gear-givers:start -->"
GEAR_END = "<!-- gear-givers:end -->"
# Tiles where wild Spirlings hide: ferns, reeds, scree and wading water (TilesetFactory).
WILD = set(",%:w")


def levels(m):
    """The top level and every floor of a map file."""
    yield m
    for f in m.get("floors", []):
        yield f


def stats():
    layout = json.load(open(os.path.join(ROOT, "data", "world_layout.json")))["maps"]
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "maps", "*.json"))):
        mid = os.path.basename(path)[:-5]
        m = json.load(open(path))
        place = layout.get(mid, {})
        region = m.get("region", "veydal")
        kind = place.get("kind", "inside" if "inside" in place else "")
        sizes, finds, wayfarers, wild = [], 0, 0, 0
        for lv in levels(m):
            rows = lv.get("rows", [])
            if rows:
                sizes.append("%dx%d" % (len(rows[0]), len(rows)))
            finds += len(lv.get("secrets", []))
            wayfarers += sum(1 for n in lv.get("npcs", []) if "trainer" in n)
            wild += sum(1 for r in rows for ch in r if ch in WILD) if m.get("encounters") or lv.get("encounters") else 0
        out.append((region, mid, kind, " + ".join(sizes), finds, wayfarers, wild))
    order = {"veydal": 0, "corvane": 1, "ashmere": 2}
    out.sort(key=lambda r: (order.get(r[0], 9), r[1]))
    return out


def gear_givers():
    """(gear id, name, map, region, giver, flag) for every give_item of a Wayfarer Gear item."""
    items = json.load(open(os.path.join(ROOT, "data", "items.json")))
    gear = {i["id"]: i["name"] for i in items if str(i.get("description", "")).startswith("Wayfarer Gear")}
    out = []
    for path in sorted(glob.glob(os.path.join(ROOT, "data", "dialogue", "*.json"))):
        fid = os.path.basename(path)[:-5]
        d = json.load(open(path))
        for key, e in d.items():
            if not isinstance(e, dict):
                continue
            act = str(e.get("action", "")).split()
            if len(act) < 2 or act[0] != "give_item" or act[1] not in gear:
                continue
            ref = "%s/%s" % (fid, key)
            mid, region, who = fid, "", key
            mpath = os.path.join(ROOT, "data", "maps", fid + ".json")
            if os.path.exists(mpath):
                m = json.load(open(mpath))
                region = m.get("region", "veydal")
                for lv in levels(m):
                    for n in lv.get("npcs", []) + lv.get("signs", []):
                        if n.get("dialogue") == ref:
                            who = "%s (%d, %d)" % (n.get("id", "sign"), n["x"], n["y"])
            out.append((act[1], gear[act[1]], mid, region, who, str(e.get("flag", ""))))
    return sorted(out)


def gear_table(rows):
    lines = ["| Gear | Name | Map | Region | Given by | Flag |", "| --- | --- | --- | --- | --- | --- |"]
    for r in rows:
        lines.append("| `%s` | %s | `%s` | %s | %s | `%s` |" % r)
    return "\n".join(lines)


def replace_block(doc, start, end, body, heading):
    block = "%s\n%s\n%s" % (start, body, end)
    if start in doc and end in doc:
        return doc[:doc.index(start)] + block + doc[doc.index(end) + len(end):]
    return doc.rstrip("\n") + "\n\n" + heading + "\n\nWritten by `python3 tools/world_stats.py`.\n\n" + block + "\n"


def table(rows):
    lines = ["| Region | Map | Kind | Size | Finds | Wayfarers | Wild cells |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for r in rows:
        lines.append("| %s | `%s` | %s | %s | %d | %d | %d |" % r)
    total = (sum(r[4] for r in rows), sum(r[5] for r in rows), sum(r[6] for r in rows))
    lines.append("| | **%d maps** | | | **%d** | **%d** | **%d** |" % ((len(rows),) + total))
    return "\n".join(lines)


def main(argv):
    doc = open(DOC).read()
    new = replace_block(doc, START, END, table(stats()), "## World statistics (item 903)")
    new = replace_block(new, GEAR_START, GEAR_END, gear_table(gear_givers()), "## Wayfarer Gear and where it is given (item 1062)")
    if "--check" in argv:
        if new != doc:
            print("docs/WORLD.md world statistics or gear list are out of date: run python3 tools/world_stats.py")
            return 1
        print("world statistics up to date")
        return 0
    if new != doc:
        open(DOC, "w").write(new)
    print(table(stats()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
