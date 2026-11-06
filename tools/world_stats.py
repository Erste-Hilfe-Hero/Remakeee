#!/usr/bin/env python3
"""World statistics per map (area 3 item 903): size, hidden finds, Wayfarers and wild cells.

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


def table(rows):
    lines = ["| Region | Map | Kind | Size | Finds | Wayfarers | Wild cells |",
             "| --- | --- | --- | --- | --- | --- | --- |"]
    for r in rows:
        lines.append("| %s | `%s` | %s | %s | %d | %d | %d |" % r)
    total = (sum(r[4] for r in rows), sum(r[5] for r in rows), sum(r[6] for r in rows))
    lines.append("| | **%d maps** | | | **%d** | **%d** | **%d** |" % ((len(rows),) + total))
    return "\n".join(lines)


def main(argv):
    block = "%s\n%s\n%s" % (START, table(stats()), END)
    doc = open(DOC).read()
    if START in doc and END in doc:
        new = doc[:doc.index(START)] + block + doc[doc.index(END) + len(END):]
    else:
        new = doc.rstrip("\n") + "\n\n## World statistics (item 903)\n\nWritten by `python3 tools/world_stats.py`.\n\n" + block + "\n"
    if "--check" in argv:
        if new != doc:
            print("docs/WORLD.md world statistics are out of date: run python3 tools/world_stats.py")
            return 1
        print("world statistics up to date")
        return 0
    if new != doc:
        open(DOC, "w").write(new)
    print(table(stats()))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
